require "pathname"

module Precious
  module Views
    class Page < Layout
      include HasPage

      attr_reader :content, :page, :header, :footer
      DATE_FORMAT    = "%Y-%m-%d %H:%M:%S"
      DEFAULT_AUTHOR = 'you'
      @@to_xml       = { :save_with => Nokogiri::XML::Node::SaveOptions::DEFAULT_XHTML ^ 1, :indent => 0, :encoding => 'UTF-8' }

      def title
        h1 = page_header_from_content(@content)
        h1 = h1 || @page.url_path_title
        
        if h1
          return File.basename(h1)
        end
        
        h1
      end

      def page_header
        title()
      end

      def content
        content_without_page_header(@content)
      end

      def author
        page_versions = @page.versions
        first         = page_versions ? page_versions.first : false
        return DEFAULT_AUTHOR unless first
        first.author.name.respond_to?(:force_encoding) ? first.author.name.force_encoding('UTF-8') : first.author.name
      end

      def date
        page_versions = @page.versions
        first         = page_versions ? page_versions.first : false
        return Time.now.strftime(DATE_FORMAT) unless first
        first.authored_date.strftime(DATE_FORMAT)
      end

      def noindex
        @version ? true : false
      end

      def editable
        @editable and @user_authorized
      end

      def page_exists
        @page_exists
      end

      def allow_editing
        @allow_editing and @user_authorized
      end

      def allow_uploads
        @allow_uploads
      end

      def upload_dest
        @upload_dest
      end

      def has_header
        if @header
          @header.formatted_data.strip.empty? ? false : true
        else
          @header = (@page.header || false)
          !!@header
        end
      end

      def header_content
        has_header && @header.formatted_data
      end

      def header_format
        has_header && @header.format.to_s
      end

      def has_footer
        if @footer
          @footer.formatted_data.strip.empty? ? false : true
        else
          @footer = (@page.footer || false)
          !!@footer
        end
      end

      def footer_content
        has_footer && @footer.formatted_data
      end

      def footer_format
        has_footer && @footer.format.to_s
      end

      def bar_side
        @bar_side.to_s
      end

      def has_sidebar
        if @sidebar
          @sidebar.formatted_data.strip.empty? ? false : true
        else
          @sidebar = (@page.sidebar || false)
          !!@sidebar
        end
      end

      def sidebar_content
        has_sidebar && @sidebar.formatted_data
      end

      def sidebar_format
        has_sidebar && @sidebar.format.to_s
      end

      def has_toc
        !@toc_content.nil?
      end

      def toc_content
        @toc_content
      end

      def mathjax
        @mathjax
      end

      def mathjax_config
        @mathjax_config
      end

      def use_identicon
        @page.wiki.user_icons == 'identicon'
      end

      # Access to embedded metadata.
      #
      # Examples
      #
      #   {{#metadata}}{{name}}{{/metadata}}
      #
      # Returns Hash.
      def metadata
        @page.metadata
      end
      
      def is_home
        @page.path == "Home.md"
      end

      private

      # Wraps page formatted data to Nokogiri::HTML document.
      #
      def build_document(content)
        Nokogiri::HTML::fragment(%{<div id="gollum-root">} + content.to_s + %{</div>}, 'UTF-8')
      end

      # Finds header node inside Nokogiri::HTML document.
      #
      def find_header_node(doc)
          header = doc.css("#gollum-root > h1:first-child")
          if header.empty?
            header = doc.css("#gollum-root > .toc + h1 > a:not(.anchor)")
          elsif header.empty?
            header = doc.css("#gollum-root > .toc + h1")
          end
          
          header
      end

      # Extracts title from page if present.
      #
      def page_header_from_content(content)
        doc   = build_document(content)
        title = find_header_node(doc).inner_text.strip
        title = nil if title.empty?
        title
      end

      # Returns page content without title if it was extracted.
      #
      def content_without_page_header(content)
        doc = build_document(content)
          if @h1_title
            title = find_header_node(doc)
            title.remove unless title.empty?
          end
        # .inner_html will cause href escaping on UTF-8
        doc.css("div#gollum-root").children.to_xml(@@to_xml)
      end
    end
  end
end
