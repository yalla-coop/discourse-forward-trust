# frozen_string_literal: true

# Same defaults production has had since Yalla migration 20240710161417:
# new channel memberships notify "always" (2) on desktop and mobile.
class ForwardTrustChatNotificationDefaults < ActiveRecord::Migration[7.0]
  def up
    %i[desktop_notification_level mobile_notification_level].each do |column|
      next unless column_exists?(:user_chat_channel_memberships, column)
      change_column_default :user_chat_channel_memberships, column, 2
    end
  end

  def down
  end
end
