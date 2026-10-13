# frozen_string_literal: true

# A new chat membership starts with the messages sent before it marked as read.
# Done in the database so it also covers bulk inserts (auto-join, add users,
# direct message channels), which skip Rails callbacks. Production's rule was
# purely by created_at (deleted messages are not filtered).
#
# The trigger functions live in their own schema, `forward_trust`, not in
# `public` (ruling R11a). Discourse backs up only the public schema and
# restores it in one transaction that stops at the first error. Functions in
# public would be in the dump and collide ("already exists") with the ones
# already on the site, so every restore would fail. Discourse keeps its own
# functions in the `discourse_functions` schema for the same reason. The
# triggers themselves belong to the tables, so they are in the dump and point
# at forward_trust.*: a backup restores onto a site where this plugin is
# installed and migrated.
class ForwardTrustChatLastReadTriggers < ActiveRecord::Migration[7.0]
  def up
    # An earlier version of this migration put the functions in public.
    execute "DROP FUNCTION IF EXISTS public.forward_trust_channel_membership_last_read() CASCADE"
    execute "DROP FUNCTION IF EXISTS public.forward_trust_thread_membership_last_read() CASCADE"

    execute "CREATE SCHEMA IF NOT EXISTS forward_trust"

    execute <<~SQL
      CREATE OR REPLACE FUNCTION forward_trust.channel_membership_last_read() RETURNS trigger AS $$
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
      FOR EACH ROW EXECUTE FUNCTION forward_trust.channel_membership_last_read()
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION forward_trust.thread_membership_last_read() RETURNS trigger AS $$
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
      FOR EACH ROW EXECUTE FUNCTION forward_trust.thread_membership_last_read()
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS forward_trust_channel_membership_last_read ON user_chat_channel_memberships"
    execute "DROP TRIGGER IF EXISTS forward_trust_thread_membership_last_read ON user_chat_thread_memberships"
    # CASCADE: after a restore, Discourse keeps the old tables in the `backup`
    # schema for a few days, and their copies of the triggers use these functions.
    execute "DROP FUNCTION IF EXISTS forward_trust.channel_membership_last_read() CASCADE"
    execute "DROP FUNCTION IF EXISTS forward_trust.thread_membership_last_read() CASCADE"
    # Raises, rather than deleting it, if something else was put in the schema.
    execute "DROP SCHEMA IF EXISTS forward_trust"
  end
end
