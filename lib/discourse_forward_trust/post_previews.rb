# frozen_string_literal: true

# Replaces Yalla commits fed449dc55, 51c2f73fc1, 3cf8b666e0 and 1f373c7c58.
# Prose shows post previews as full HTML with links, images and videos.
#
# The net production behaviour is reproduced exactly, including two quirks:
# - ExcerptParser treats strip_links/strip_images inverted (an explicit `true`
#   keeps them, an explicit `false` strips them; not passing them keeps them).
# - Post.excerpt returns the full cooked HTML and ignores maxlength.
module DiscourseForwardTrust
  module PostPreviews
    module ExcerptParserExtension
      def initialize(length, options = nil)
        super
        @strip_links = options[:strip_links] == false
        @strip_images = options[:strip_images] == false
      end

      def start_element(name, attributes = [])
        if name == "div" || name == "span"
          attrs = Hash[*attributes.flatten]
          css = attrs["class"]
          excerpt_block = css&.include?("excerpt") && !css.match?("excerpt hidden")
          if !excerpt_block && css&.include?("video-placeholder-container")
            src = attrs["data-video-src"]
            characters("[Video](#{src})") if src
            return
          end
        end
        super
      end
    end

    module PostClassExtension
      def excerpt(cooked, maxlength = nil, options = {})
        cooked
      end
    end

    module SearchPostSerializerExtension
      def include_blurb?
        true
      end

      def include_cooked?
        true
      end
    end

    module SearchTopicListItemSerializerExtension
      def include_image_url?
        true
      end

      def include_thumbnails?
        true
      end
    end

    def self.apply(plugin)
      # reloadable_patch is private in core, so it is called with send. It runs
      # the block now and again on every dev reload, so the patches survive it.
      plugin.send(:reloadable_patch) do
        ::ExcerptParser.prepend(ExcerptParserExtension)
        ::Post.singleton_class.prepend(PostClassExtension)
        ::SearchPostSerializer.prepend(SearchPostSerializerExtension)
        ::SearchTopicListItemSerializer.prepend(SearchTopicListItemSerializerExtension)

        # PostItemExcerpt is a module already included in five serializers, so
        # its methods are redefined in place rather than prepended.
        ::PostItemExcerpt.module_eval do
          def cooked
            @cooked ||= object.cooked || object.excerpt || PrettyText.cook(object.raw)
          end

          def excerpt
            return nil unless cooked
            @excerpt ||= cooked
          end
        end
      end
    end
  end
end
