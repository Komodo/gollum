require 'cgi'
require 'omniauth'
require 'mustache/sinatra'
require 'sinatra/base'

require File.expand_path '../helpers', __FILE__

module Omnigollum
  module Views; class Layout < Mustache; end; end
  module Models
    class OmniauthUserInitError < StandardError; end

    class User
      attr_reader :uid, :name, :email, :nickname, :provider
    end

    class OmniauthUser < User
      def initialize (hash, options)
        # Validity checks, don't trust providers
        @uid = hash['uid'].to_s.strip
        raise OmniauthUserInitError, "Insufficient data from authentication provider, uid not provided or empty" if @uid.empty?

        @name = hash['info']['name'].to_s.strip if hash['info'].has_key?('name')
        @name = options[:default_name] if !@name || @name.empty?

        raise OmniauthUserInitError, "Insufficient data from authentication provider, name not provided or empty" if !@name || @name.empty?

        @email = hash['info']['email'].to_s.strip if hash['info'].has_key?('email')
        @email = options[:default_email] if !@email || @email.empty?

        raise OmniauthUserInitError, "Insufficient data from authentication provider, email not provided or empty" if !@email || @email.empty?

        @nickname = hash['info']['nickname'].to_s.strip if hash['info'].has_key?('nickname')

        @provider = hash['provider']

        self
      end
    end
  end

  # Config class provides default values for omnigollum configuration, and an array
  # of all providers which have been enabled if a omniauth config block is passed to
  # eval_omniauth_config.
  class Config
    attr_accessor :default_options
    class << self; attr_accessor :default_options; end

    @default_options = {
      :protected_routes => [
        '/revert/*',
        '/revert',
        '/create/*',
        '/create',
        '/edit/*',
        '/edit',
        '/rename/*',
        '/rename/',
        '/upload/*',
        '/upload/',
        '/delete/*',
        '/delete'],

      :route_prefix => '/__omnigollum__',
      :dummy_auth   => true,
      :providers    => Proc.new { provider :github, '', '' },
      :path_base    => dir = File.expand_path(File.dirname(__FILE__)),
      :logo_suffix  => "_logo.png",
      :logo_missing => "omniauth", # Set to false to disable missing logos
      :path_images  => "#{dir}/public/images",
      :path_views   => "#{dir}/views",
      :path_templates => "#{dir}/templates",
      :default_name   => nil,
      :default_email  => nil,
      :provider_names => [],
      :authorized_users => [],
      :author_format => Proc.new { |user| user.nickname ? user.name + ' (' + user.nickname + ')' : user.name },
      :author_email => Proc.new { |user| user.email }
    }

    def initialize
      @default_options = self.class.default_options
    end

    # Register provider name
    #
    # name - Provider symbol
    # args - Arbitrary arguments
    def provider(name, *args)
      @default_options[:provider_names].push name
    end

    # Evaluate procedure calls in an omniauth config block/proc in the context
    # of this class.
    #
    # This allows us to learn about omniauth config items that would otherwise be inaccessible.
    #
    # block - Omniauth proc or block
    def eval_omniauth_config(&block)
      self.instance_eval(&block)
    end

    # Catches missing methods we haven't implemented, but which omniauth accepts
    # in its config block.
    #
    # args - Arbitrary list of arguments
    def method_missing(*args); end
  end

  module Sinatra
    def self.registered(app)
      # As options determine which routes are created, they must be set before registering omniauth
      config  = Omnigollum::Config.new

      options = app.settings.respond_to?(:omnigollum) ?
        config.default_options.merge(app.settings.send(:omnigollum)) :
        config.default_options

      # Set omniauth path prefix based on options
      OmniAuth.config.path_prefix = options[:route_prefix] + OmniAuth.config.path_prefix

      # Setup test_mode options
      if options[:dummy_auth]
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:default] = {
          'uid' => '12345',
          "info" => {
            "email"  => "user@example.com",
            "name"   => "example user"
            },
            'provider' => 'local'
          }
        end

      # Enable sinatra session support
      app.set :sessions,  true

      # Setup omniauth providers
      if !options[:providers].nil?
        app.use OmniAuth::Builder, &options[:providers]

        # You told omniauth, now tell us!
        config.eval_omniauth_config &options[:providers] if options[:provider_names].count == 0
      end

      # Stop browsers from screwing up our referrer information
      # FIXME: This is hacky...
      app.before '/favicon.ico' do
        halt 403 unless user_authed?
      end

      # Explicit login (user followed login link) clears previous redirect info
      app.before options[:route_prefix] + '/login' do
        kick_back if user_authed?
        @auth_params = "?origin=#{CGI.escape(request.referrer)}" unless request.referrer.nil?
        user_auth
      end

      app.before options[:route_prefix] + '/logout' do
        user_deauth
        kick_back
      end

      app.before options[:route_prefix] + '/auth/failure' do
        user_deauth
        @title    = 'Authentication failed'
        @subtext = "Provider did not validate your credentials (#{params[:message]}) - please retry or choose another login service"
        @auth_params = "?origin=#{CGI.escape(request.env['omniauth.origin'])}" unless request.env['omniauth.origin'].nil?
        show_error
      end

      app.before options[:route_prefix] + '/auth/:name/callback' do
        begin
          if !request.env['omniauth.auth'].nil?
            user = Omnigollum::Models::OmniauthUser.new(request.env['omniauth.auth'], options)

            session[:omniauth_user] = user

            # Update gollum's author hash, so commits are recorded correctly
            session['gollum.author'] = {
              :name => options[:author_format].call(user),
              :email => options[:author_email].call(user)
            }

            redirect request.env['omniauth.origin']
          elsif !user_authed?
            @title   = 'Authentication failed'
            @subtext = 'Omniauth experienced an error processing your request'
            @auth_params = "?origin=#{CGI.escape(request.env['omniauth.origin'])}" unless request.env['omniauth.origin'].nil?
            show_error
          end
        rescue StandardError => fail_reason
          @title   = 'Authentication failed'
          @subtext = fail_reason
          @auth_params = "?origin=#{CGI.escape(request.env['omniauth.origin'])}" unless request.env['omniauth.origin'].nil?
          show_error
        end
      end

      app.before options[:route_prefix] + '/images/:image.png' do
        content_type :png
        send_file options[:path_images] + '/' + params[:image] + '.png'
      end

      # Stop sinatra processing and hand off to omniauth
      app.before options[:route_prefix] + '/auth/:provider' do
        halt 404
      end

      # Pre-empt protected routes
      options[:protected_routes].each {|route| app.before(route) {user_auth unless user_authed?}}

      # Write the actual config back to the app instance
      app.set(:omnigollum, options)
    end
  end
end
