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

        # PostItemExcerpt is a module already included in several serializers,
        # so its methods are redefined in place rather than prepended.
        #
        # From Discourse 2026.x the stock module builds `cooked` from the post
        # the item points at (excerpt_source_post), uses its translation when
        # there is one, and hides it from viewers who can't see that post
        # (can_see_post_item_excerpt?, for example a bookmark of a post that has
        # since become private). Keep all of that and change only the result:
        # the full cooked HTML instead of a 300-character excerpt. Older
        # Discourse has none of these helpers, so each is used only if present.
        ::PostItemExcerpt.module_eval do
          def cooked
            @cooked ||=
              begin
                source = respond_to?(:excerpt_source_post, true) ? excerpt_source_post : nil
                translated =
                  if source && defined?(::ContentLocalization) &&
                       ::ContentLocalization.respond_to?(:translated_post_cooked)
                    ::ContentLocalization.translated_post_cooked(source, scope)
                  end
                translated || source&.cooked || object.cooked || object.excerpt ||
                  PrettyText.cook(object.raw)
              end
          end

          def excerpt
            if respond_to?(:can_see_post_item_excerpt?, true) && !can_see_post_item_excerpt?
              return nil
            end
            return nil unless cooked
            @excerpt ||= cooked
          end
        end
      end
    end
  end
end
