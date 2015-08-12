require 'cgi'

module Precious
  module Views
    class Layout < Mustache
      include Rack::Utils
      alias_method :h, :escape_html

      attr_reader :name, :path

      def escaped_name
        CGI.escape(@name)
      end

      def title
        "Home"
      end

      def has_path
        !@path.nil?
      end

      def page_dir
        @page_dir
      end

      def base_url
        @base_url
      end

      def custom_path
        "#{@base_url}#{@page_dir.nil? ? '' : '/'}#{@page_dir}"
      end

      def css # custom css
        @css
      end

      def js # custom js
        @js
      end
      
      # Passthrough additional omniauth parameters for status bar
      def user_authed
        @user_authed
      end
      
      def user_is_admin
        @user.name == 'Naatan' # Todo: Put in config
      end
      
      def user_provider
        @user.provider
      end
      
      def user_name
        @user.name
      end
      
      def breadcrumb
        return unless @page
        # Not sure exactly why @path is not available here
        path       = Pathname.new(@page.path)

        # Always expose a link to the root of the wiki
        breadcrumbs = %{<ul class="breadcrumbs"><li><a href="#{@base_url}/">Home</a></li>}

        # Then for each directory, add a crumb
        path.descend do |crumb|
          title = File.basename(crumb, path.extname)
          # We reached the end of the trail
          next if title == "Index"
          breadcrumbs += %{<li><a href="#{@base_url}/#{crumb}">#{title}</a></li>}
        end

        breadcrumbs += "</ul>"
      end

    end
  end
end
