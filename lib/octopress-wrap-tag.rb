require "octopress-wrap-tag/version"

require "octopress-tag-helpers"
require "octopress-include-tag"
require "octopress-render-tag"
require "octopress-content-for"
require "jekyll"

# Inspired by jekyll-contentblocks https://github.com/rustygeldmacher/jekyll-contentblocks
#
module Octopress
  module Tags
    module Wrap
      class Tag < Liquid::Block

        def initialize(tag_name, markup, tokens)
          super
          @og_markup = @markup = markup
          @tag_name = tag_name
        end

        def render(context)
          return unless markup = TagHelpers::Conditional.parse(@markup, context)

          if markup =~ TagHelpers::Var::HAS_FILTERS
            markup = $1
            filters = $2
          end

          type = if markup =~ /^\s*yield\s(.+)/
            markup = $1
            'yield'
          elsif markup =~ /^\s*render\s(.+)/
            markup = $1
            'render'
          elsif markup =~ /^\s*include\s(.+)/
            markup = $1
            'include'
          else
            raise IOError.new "Wrap Failed: {% wrap #{@og_markup}%} - Which type of wrap: inlcude, yield, render? - Correct syntax: {% wrap type path or var [filters] [conditions] %}"
          end

          case type
          when 'yield'
            content = Octopress::Tags::Yield::Tag.new('yield', markup, []).render(context)
          when 'render'
            begin
              content = Octopress::Tags::Render::Tag.new('render', markup, []).render(context)
            rescue => error
              error_msg error
            end
          when 'include'
            begin
              content = Octopress::Tags::Include::Tag.new('include', markup, []).render(context)
            rescue => error
              error_msg error
            end
          end

          # just in case yield had a value
          old_yield = context.scopes.first['yield']
          context.scopes.first['yield'] = content
          
          content = super.strip
          context.scopes.first['yield'] = old_yield

          unless content.nil? || filters.nil?
            content = TagHelpers::Var.render_filters(content, filters, context)
          end

          content
        end

        def error_msg(error)
          error.message
          message = "Wrap failed: {% #{@tag_name} #{@og_markup}%}."
          message << $1 if error.message =~ /%}\.(.+)/
          raise IOError.new message
        end

        def content_for(markup, context)
          @block_name = TagHelpers::ContentFor.get_block_name(@tag_name, markup)
          TagHelpers::ContentFor.render(context, @block_name).strip
        end
      end
    end
  end
end

Liquid::Template.register_tag('wrap', Octopress::Tags::Wrap::Tag)

if defined? Octopress::Docs
  Octopress::Docs.add({
    name:        "Octopress Wrap Tag",
    gem:         "octopress-wrap-tag",
    version:     Octopress::Tags::Wrap::VERSION,
    description: "Wrap include, render, and yield tags",
    path:        File.expand_path(File.join(File.dirname(__FILE__), "../")),
    source_url:  "https://github.com/octopress/wrap-tag"
  })
end
