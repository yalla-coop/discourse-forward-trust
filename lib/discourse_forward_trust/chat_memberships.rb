# frozen_string_literal: true

# Replaces Yalla commits fb0ad7f1f5 and 4814174c29, and the unread-count part
# of 9c849ac9b8 / 68b411e9cd.
#
# - Production still reads the old per-device levels (mobile_notification_level)
#   that upstream ignores since October 2024. Prose never writes them, so their
#   values are the column defaults.
# - "Messages sent before you joined are not unread": instead of editing five
#   SQL queries, a new membership starts with earlier messages marked read.
#   Discourse 2026.x does the same when someone follows a channel.
module DiscourseForwardTrust
  module ChatMemberships
    LEVELS = { never: 0, mention: 1, always: 2 }.freeze
    LEGACY_COLUMNS = %w[desktop_notification_level mobile_notification_level].freeze

    # False on a brand-new database before migrations have created the table.
    def self.table_ready?
      ::Chat::UserChatChannelMembership.table_exists?
    rescue ActiveRecord::NoDatabaseError
      false
    end

    def self.legacy_levels?
      table_ready? &&
        ::Chat::UserChatChannelMembership.column_names.include?("mobile_notification_level")
    end

    def self.apply(plugin)
      # reloadable_patch: in development Discourse reloads model classes when
      # code changes, which would silently drop these changes otherwise.
      plugin.send(:reloadable_patch) { patch_models }
    end

    def self.patch_models
      klass = ::Chat::UserChatChannelMembership
      return unless table_ready?

      if (klass.ignored_columns & LEGACY_COLUMNS).any?
        klass.ignored_columns = klass.ignored_columns - LEGACY_COLUMNS
        klass.reset_column_information
      end

      if legacy_levels? && !klass.defined_enums.key?("mobile_notification_level")
        klass.enum :desktop_notification_level, LEVELS, prefix: :desktop_notifications
        klass.enum :mobile_notification_level, LEVELS, prefix: :mobile_notifications
      end

      klass.after_create do
        next if last_read_message_id.present?
        earlier =
          ::Chat::Message.where(chat_channel_id: chat_channel_id).where(
            "created_at <= ?",
            created_at,
          ).maximum(:id)
        update_column(:last_read_message_id, earlier) if earlier
      end

      ::Chat::UserChatThreadMembership.after_create do
        next if last_read_message_id.present?
        earlier =
          ::Chat::Message.where(thread_id: thread_id).where("created_at <= ?", created_at).maximum(
            :id,
          )
        update_column(:last_read_message_id, earlier) if earlier
      end
    end
  end
end
