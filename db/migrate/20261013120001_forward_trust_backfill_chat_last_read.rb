# frozen_string_literal: true

class ForwardTrustBackfillChatLastRead < ActiveRecord::Migration[7.0]
  def up
    DiscourseForwardTrust::ChatMessageNotifications.backfill_last_read!
  end

  def down
  end
end
