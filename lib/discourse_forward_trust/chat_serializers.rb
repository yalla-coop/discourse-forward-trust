# frozen_string_literal: true

# Replaces the chat serializer parts of Yalla commit 4f86acaa3e.
# Prose's "new chat" screen reads groups[].users[].model (with `admin`) from
# /chat/api/chatables and crashes without `users`.
module DiscourseForwardTrust
  module ChatSerializers
    module ChatableUserSerializerExtension
      def can_chat
        SiteSetting.chat_enabled && object.guardian.can_chat? &&
          object.guardian.can_direct_message?
      end
    end

    module ChatablesSerializerExtension
      def groups
        by_id = (object.groups || []).index_by(&:id)
        super.map do |entry|
          group = by_id[entry["identifier"].to_s.delete_prefix("g-").to_i]
          group ? entry.merge("users" => forward_trust_group_users(group)) : entry
        end
      end

      private

      def forward_trust_group_users(group)
        group
          .users
          .map do |user|
            {
              identifier: "u-#{user.id}",
              model: ::Chat::ChatableUserSerializer.new(user, scope: scope, root: false),
              type: "user",
            }
          end
          .as_json
      end
    end

    def self.apply(plugin)
      plugin.send(:reloadable_patch) do
        ::Chat::ChatableUserSerializer.prepend(ChatableUserSerializerExtension)
        ::Chat::ChatablesSerializer.prepend(ChatablesSerializerExtension)
      end

      # Serializer NAME, not class: Discourse appends "Serializer" itself.
      plugin.add_to_serializer("chat/chatable_user", :admin) { object.admin? }

      plugin.add_to_serializer(:user, :ignored_usernames) do
        ::IgnoredUser.where(user_id: object.id).joins(:ignored_user).pluck(:username)
      end

      # Same as the chat plugin's definition, plus "false for yourself". Chat is
      # loaded before this plugin, so this definition wins.
      %i[user_card hidden_profile].each do |serializer|
        plugin.add_to_serializer(serializer, :can_chat_user) do
          next false if !SiteSetting.chat_enabled
          next false if scope.user.blank? || scope.user.id == object.id
          next false if !scope.user.user_option.chat_enabled || !object.user_option.chat_enabled
          scope.can_direct_message? && ::Guardian.new(object).can_chat?
        end
      end
    end
  end
end
