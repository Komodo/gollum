require 'omniauth'
require 'sinatra/base'

# ~*~ encoding: utf-8 ~*~
module Precious
  module Helpers
    # Extract the path string that Gollum::Wiki expects
    def extract_path(file_path)
      return nil if file_path.nil?
      last_slash = file_path.rindex("/")
      if last_slash
        file_path[0, last_slash]
      end
    end

    # Extract the 'page' name from the file_path
    def extract_name(file_path)
      if file_path[-1, 1] == "/"
        return nil
      end

      # File.basename is too eager to please and will return the last
      # component of the path even if it ends with a directory separator.
      ::File.basename(file_path)
    end

    def sanitize_empty_params(param)
      [nil, ''].include?(param) ? nil : CGI.unescape(param)
    end

    # Ensure path begins with a single leading slash
    def clean_path(path)
      if path
        (path[0] != '/' ? path.insert(0, '/') : path).gsub(/\/{2,}/, '/')
      end
    end

    # Remove all slashes from the start of string.
    # Remove all double slashes
    def clean_url url
      return url if url.nil?
      url.gsub('%2F', '/').gsub(/^\/+/, '').gsub('//', '/')
    end

    def forbid(msg = "Forbidden. This wiki is set to no-edit mode.")
      @message = msg
      status 403
      halt mustache :error
    end

    def not_found(msg = nil)
      @message = msg || "The requested page does not exist."
      status 404
      return mustache :error
    end
    
    def user_authed?
      session.has_key? :omniauth_user
    end
    
    def user_authorized?
      user = get_user
      options = settings.send(:omnigollum)
      
      return false unless session.has_key? :omniauth_user
      
      case (authorized_users = options[:authorized_users])
      when Regexp
        user_authorized = (user.email =~ authorized_users)
      when Array
        user_authorized = authorized_users.include?(user.email) || authorized_users.include?(user.nickname)
      else
        user_authorized = true
      end
      
      user_authorized
    end

    def user_auth
      @title   = 'Authentication is required'
      @subtext = 'Please choose a login service'
      show_login
    end

    def kick_back
      redirect '/'
      halt
    end

    def get_user
      session[:omniauth_user]
    end

    def user_deauth
      session.delete :omniauth_user
    end

    def auth_config
      options = settings.send(:omnigollum)

      @auth = {
        :route_prefix => options[:route_prefix],
        :providers    => options[:provider_names],
        :path_images  => options[:path_images],
        :logo_suffix  => options[:logo_suffix],
        :logo_missing => options[:logo_missing]
      }
    end

    def show_login
      options = settings.send(:omnigollum)

      # Don't bother showing the login screen, just redirect
      if options[:provider_names].count == 1
        if !request.params['origin'].nil?
          origin = request.params['origin']
        elsif !request.path.nil?
          origin = request.path
        else
          origin = '/'
        end

        redirect (request.script_name || '') + options[:route_prefix] + '/auth/' + options[:provider_names].first.to_s + "?origin=" +
           CGI.escape(origin)
      else
         auth_config
         require options[:path_views] + '/login'
         halt mustache Omnigollum::Views::Login
      end
    end

    def show_error
      options = settings.send(:omnigollum)
      auth_config
      require options[:path_views] + '/error_auth'
      halt mustache Omnigollum::Views::Error
    end

    def commit_message
      if user_authed?
        user = get_user
        return { :message => params[:message], :name => user.name, :email => user.email}
      else
        return { :message => params[:message]}
      end
    end

  end
end
