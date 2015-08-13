require 'cgi'

module Precious
  module Views
    class Layout < Mustache
      include Rack::Utils
      alias_method :h, :escape_html

      attr_reader :name, :path
      
      def title
        h1 = page_header_from_content(@content)
        h1 = h1 || @page.url_path_title
        
        if h1
          return File.basename(h1)
        end
        
        h1
      end

      def escaped_name
        CGI.escape(@name)
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
      
      def user_authorized
        @user_authorized
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
          name = File.basename(crumb, path.extname)
          next if name.downcase == "index"
          
          if name == File.basename(path, path.extname)
            name = title()
          end
          # We reached the end of the trail
          breadcrumbs += %{<li><a href="#{@base_url}/#{crumb}">#{name}</a></li>}
        end

        breadcrumbs += "</ul>"
      end
      
      def is_home
        if @page
          return @page.path == "Home.md"
        end
      end

    end
  end
end
