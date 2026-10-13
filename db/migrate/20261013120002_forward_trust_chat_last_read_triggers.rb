# frozen_string_literal: true

# A new chat membership starts with the messages sent before it marked as read.
# Done in the database so it also covers bulk inserts (auto-join, add users,
# direct message channels), which skip Rails callbacks. Production's rule was
# purely by created_at (deleted messages are not filtered).
class ForwardTrustChatLastReadTriggers < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION forward_trust_channel_membership_last_read() RETURNS trigger AS $$
      BEGIN
        IF NEW.last_read_message_id IS NULL THEN
          NEW.last_read_message_id := (
            SELECT MAX(id) FROM chat_messages
             WHERE chat_channel_id = NEW.chat_channel_id
               AND created_at <= COALESCE(NEW.created_at, now())
          );
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
    execute "DROP TRIGGER IF EXISTS forward_trust_channel_membership_last_read ON user_chat_channel_memberships"
    execute <<~SQL
      CREATE TRIGGER forward_trust_channel_membership_last_read
      BEFORE INSERT ON user_chat_channel_memberships
      FOR EACH ROW EXECUTE FUNCTION forward_trust_channel_membership_last_read()
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION forward_trust_thread_membership_last_read() RETURNS trigger AS $$
      BEGIN
        IF NEW.last_read_message_id IS NULL THEN
          NEW.last_read_message_id := (
            SELECT MAX(id) FROM chat_messages
             WHERE thread_id = NEW.thread_id
               AND created_at <= COALESCE(NEW.created_at, now())
          );
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
    execute "DROP TRIGGER IF EXISTS forward_trust_thread_membership_last_read ON user_chat_thread_memberships"
    execute <<~SQL
      CREATE TRIGGER forward_trust_thread_membership_last_read
      BEFORE INSERT ON user_chat_thread_memberships
      FOR EACH ROW EXECUTE FUNCTION forward_trust_thread_membership_last_read()
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS forward_trust_channel_membership_last_read ON user_chat_channel_memberships"
    execute "DROP FUNCTION IF EXISTS forward_trust_channel_membership_last_read()"
    execute "DROP TRIGGER IF EXISTS forward_trust_thread_membership_last_read ON user_chat_thread_memberships"
    execute "DROP FUNCTION IF EXISTS forward_trust_thread_membership_last_read()"
  end
end
