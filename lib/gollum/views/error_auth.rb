module Omnigollum
  module Views
    class Error_auth < Mustache
      self.template_path = File.expand_path("../../templates", __FILE__)
      self.template_name = 'Error_auth'
      
      def title
        @title
      end
      
      def subtext
        @subtext
      end

      def loginurl
        @auth[:route_prefix] + 'login' + (defined?(@auth_params) ? @auth_params : '')
      end
    end
  end
end
