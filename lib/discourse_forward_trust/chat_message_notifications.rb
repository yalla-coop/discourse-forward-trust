# frozen_string_literal: true

# Replaces the notification part of Yalla commits 4f86acaa3e, d1b1f3be45 and
# 9c849ac9b8.
#
# For each new chat message, members who should hear about it get a
# `chat_message` notification row, and :created_chat_notification fires. The
# Lexicon plugin listens to that event to send the phone push.
#
# The job is delayed 5 seconds, as in production, so an active reader's client
# can advance last_read first (otherwise they'd be pushed what they're reading).
#
# Discourse's own Jobs::Chat::NotifyWatching still runs (desktop alerts,
# watched threads; R16 below changes who it leaves out); this job only adds
# what the app needs. Members are chosen exactly as production does:
# - following, chat enabled, not suspended, level "always" (or watching the thread)
# - mobile level not "never"
# - direct messages: everyone the sender may message
# - channels: mobile "always", or mobile "mention" and mentioned
#
# Ruling R16: a NEW message creates no `chat_mention` notification, as in
# production (its Chat::Notifier#notify_new had no notify_mentioned_users call).
# Mentioned members get the `chat_message` notification above instead. Editing
# a message to add a mention still creates one (notify_edit is stock, as in
# production). Because stock then sends mentioned members no mention alert, they
# are not left out of Discourse's NotifyWatching web alert either: production's
# NotifyWatching left out nobody.
module DiscourseForwardTrust
  module ChatMessageNotifications
    module NotifierExtension
      def notify_new
        @forward_trust_new_message = true
        super
      ensure
        @forward_trust_new_message = false
      end

      private

      def notify_mentioned_users(to_notify, already_notified_user_ids: [])
        return if @forward_trust_new_message
        super
      end

      # Stock calls this from notify_new only, with `except` = everyone mentioned
      # plus the sender.
      def notify_watching_users(except: [])
        super(except: @forward_trust_new_message ? [@user.id] : except)
        ::Jobs.enqueue_in(
          5.seconds,
          ::Jobs::DiscourseForwardTrust::ChatMessageNotifications,
          chat_message_id: @chat_message.id,
          mentioned_user_ids: except,
        )
      end
    end

    def self.apply(plugin)
      plugin.send(:reloadable_patch) { ::Chat::Notifier.prepend(NotifierExtension) }
    end
  end
end

module ::Jobs
  module DiscourseForwardTrust
    class ChatMessageNotifications < ::Jobs::Base
      def execute(args = {})
        @message =
          ::Chat::Message.includes(:user, chat_channel: :chatable).find_by(id: args[:chat_message_id])
        return if @message.nil?

        @channel = @message.chat_channel
        mentioned = Array(args[:mentioned_user_ids]).map(&:to_i)
        legacy = ::DiscourseForwardTrust::ChatMemberships.legacy_levels?

        members =
          ::Chat::UserChatChannelMembership
            .includes(:user)
            .joins(user: :user_option)
            .where(user_option: { chat_enabled: true })
            .where(chat_channel_id: @channel.id)
            .where(following: true)
            .where(
              "notification_level = :always OR users.id IN (SELECT user_id FROM user_chat_thread_memberships WHERE thread_id = :thread_id AND notification_level = :watching)",
              always: ::Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
              thread_id: @message.thread_id,
              watching: ::Chat::NotificationLevels.all[:watching],
            )
            .merge(::User.not_suspended)
        members = members.where("mobile_notification_level != 0") if legacy

        if @channel.direct_message_channel?
          allowed =
            ::UserCommScreener
              .new(acting_user: @message.user, target_user_ids: members.map(&:user_id))
              .allowing_actor_communication
          members.select { |m| allowed.include?(m.user_id) }.each { |m| notify(m) }
        else
          members.each do |membership|
            level = legacy ? membership.mobile_notification_level : "always"
            if level == "always" || (level == "mention" && mentioned.include?(membership.user_id))
              notify(membership)
            end
          end
        end
      end

      private

      def seen?(membership)
        (membership.last_read_message_id || 0) >= @message.id &&
          membership.created_at <= @message.created_at
      end

      def notify(membership)
        return unless membership.user.guardian.can_join_chat_channel?(@channel)
        return if seen?(membership)

        data = {
          chat_message_id: @message.id,
          chat_channel_id: @channel.id,
          channel_name: @channel.name,
          sender: @message.user.username,
          is_direct_message_channel: @channel.direct_message_channel?,
          message: @message.message,
        }
        unless @channel.direct_message_channel?
          data[:chat_channel_title] = @channel.title(membership.user)
          data[:chat_channel_slug] = @channel.slug
        end

        ::Notification.create!(
          notification_type: ::Notification.types[:chat_message],
          user_id: membership.user_id,
          high_priority: true,
          data: data.to_json,
          read: false,
        )
        ::DiscourseEvent.trigger(
          :created_chat_notification,
          data,
          membership.user_id,
          ::Notification.types[:chat_message],
        )
      end
    end
  end
end
