# frozen_string_literal: true

# One-time fix: memberships that existed before this plugin get their pre-join
# messages marked read, matching production's edited unread queries. New
# memberships get this from the BEFORE INSERT triggers (20261013120002).
#
# The SQL lives here, frozen, so later code changes can't alter what this
# migration does. A correlated subquery per row (using the chat_messages channel
# and thread indexes) avoids joining every membership to every earlier message.
# Only ever raises last_read_message_id.
class ForwardTrustBackfillChatLastRead < ActiveRecord::Migration[7.0]
  CHANNEL_SQL = <<~SQL
    UPDATE user_chat_channel_memberships m
    SET last_read_message_id = sub.max_id
    FROM (
      SELECT m2.id,
        (SELECT MAX(cm.id) FROM chat_messages cm
          WHERE cm.chat_channel_id = m2.chat_channel_id AND cm.created_at <= m2.created_at) AS max_id
      FROM user_chat_channel_memberships m2
    ) sub
    WHERE m.id = sub.id AND sub.max_id IS NOT NULL AND COALESCE(m.last_read_message_id, 0) < sub.max_id
  SQL

  THREAD_SQL = <<~SQL
    UPDATE user_chat_thread_memberships m
    SET last_read_message_id = sub.max_id
    FROM (
      SELECT m2.id,
        (SELECT MAX(cm.id) FROM chat_messages cm
          WHERE cm.thread_id = m2.thread_id AND cm.created_at <= m2.created_at) AS max_id
      FROM user_chat_thread_memberships m2
    ) sub
    WHERE m.id = sub.id AND sub.max_id IS NOT NULL AND COALESCE(m.last_read_message_id, 0) < sub.max_id
  SQL

  def up
    execute CHANNEL_SQL
    execute THREAD_SQL
  end

  def down
  end
end
