# frozen_string_literal: true

# name: discourse-forward-trust
# about: Forward Trust customisations for the community app, moved out of Discourse core
# version: 1.0.0
# authors: Yalla Cooperative
# url: https://github.com/yalla-coop/discourse-forward-trust
# required_version: 3.4.0.beta3

module ::DiscourseForwardTrust
  PLUGIN_NAME = "discourse-forward-trust"
end

after_initialize do
  # Files load here, not at the top of this file, because some of them use
  # Discourse classes (Jobs::Base, chat models) that only exist once Discourse
  # has started. Each feature: require its file, then apply it. Tasks 3-8 add
  # their two lines below, in task order.
  require_relative "lib/discourse_forward_trust/serializer_family"
  require_relative "lib/discourse_forward_trust/category_group_permissions"
  ::DiscourseForwardTrust::CategoryGroupPermissions.apply(self)
  require_relative "lib/discourse_forward_trust/flagged_by_user"
  ::DiscourseForwardTrust::FlaggedByUser.apply(self)
  require_relative "lib/discourse_forward_trust/post_previews"
  ::DiscourseForwardTrust::PostPreviews.apply(self)
  require_relative "lib/discourse_forward_trust/chat_serializers"
  ::DiscourseForwardTrust::ChatSerializers.apply(self)
  require_relative "lib/discourse_forward_trust/group_owner_email"
  ::DiscourseForwardTrust::GroupOwnerEmail.apply(self)
  require_relative "lib/discourse_forward_trust/chat_memberships"
  ::DiscourseForwardTrust::ChatMemberships.apply(self)
  require_relative "lib/discourse_forward_trust/chat_message_notifications"
  ::DiscourseForwardTrust::ChatMessageNotifications.apply(self)
  require_relative "lib/discourse_forward_trust/chat_summary_emails"
  ::DiscourseForwardTrust::ChatSummaryEmails.apply(self)
end
