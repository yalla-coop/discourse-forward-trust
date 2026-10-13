# frozen_string_literal: true

# Replaces Yalla commits fe124c10cf and fb61063527. Prose hides topics the
# member has flagged from lists and search using this field.
module DiscourseForwardTrust
  module FlaggedByUser
    # Flag types: off_topic 3, inappropriate 4, notify_user 6, notify_moderators 7,
    # spam 8, illegal 10, and 9. Unchanged in Discourse 2026.9.
    FLAG_TYPE_IDS = [3, 4, 6, 7, 8, 9, 10].freeze

    def self.apply(plugin)
      plugin.add_to_class(:topic, :flagged_by_user?) do |user|
        next false if user.nil?
        first_post = posts.where(post_number: 1).first
        next false if first_post.nil?
        ::PostAction.exists?(
          user_id: user.id,
          post_id: first_post.id,
          post_action_type_id: ::DiscourseForwardTrust::FlaggedByUser::FLAG_TYPE_IDS,
        )
      end

      SerializerFamily.add(plugin, ::ListableTopicSerializer, :flagged_by_user) do
        object.flagged_by_user?(scope.user)
      end

      plugin.add_to_serializer(:topic_view, :flagged_by_user) do
        object.topic.flagged_by_user?(scope.user)
      end
    end
  end
end
