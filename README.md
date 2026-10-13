# discourse-forward-trust

Forward Trust customisations for the community app. Until 2026 these were
edits inside Discourse's own files (yalla-coop/discourse); they live here so
Discourse can be upgraded as stock.

Behaviour is pinned by the safety net in yalla-coop/discourse-upgrade-2026
(`spec/yalla`, `contract/`, Maestro).

## Features

Each feature is one file in `lib/discourse_forward_trust/`, with the Yalla
commits it replaces named at the top of the file.

| File | What it does | Replaces |
| --- | --- | --- |
| `serializer_family.rb` | Helper: adds a field to a serializer and all its subclasses without clobbering subclasses that define it themselves | (support) |
| `category_group_permissions.rb` | `group_permissions` on category serializers | `4f86acaa3e` (part) |
| `post_previews.rb` | Full cooked HTML and links in excerpts, video links, `cooked` in search | `fed449dc55`, `51c2f73fc1`, `3cf8b666e0`, `1f373c7c58` |
| `flagged_by_user.rb` | `flagged_by_user` on topic lists, topic view and search | `fe124c10cf`, `fb61063527` |
| `chat_memberships.rb` | Reads the legacy per-device chat levels; new memberships notify "always" | `fb0ad7f1f5`, `4814174c29`, `9c849ac9b8` and `68b411e9cd` (unread part) |
| `chat_message_notifications.rb` | A `chat_message` notification and the `:created_chat_notification` event (Lexicon sends the push) | `4f86acaa3e` (chat part), `d1b1f3be45`, `9c849ac9b8` |
| `chat_summary_emails.rb` | Keeps chat "while you were away" emails off unless the setting is on | none (keeps production's effective behaviour) |
| `chat_serializers.rb` | `admin` on chatable users, group `users` in chatables, `can_chat_user` false for yourself, `ignored_usernames` | `4f86acaa3e` (part) |
| `group_owner_email.rb` | Emails group owners when a member confirms their email at signup | `fb087acfbb`, `160a49046f`, `081062113b`, `d66f43f15d`, `b327885ba6`, `a7ecc2fc43` |

Rate limits are not in the plugin. They are environment variables, listed in
`deploy/forward-trust.env` in the upgrade repo, and copied into `app.yml`.

## Site setting

`forward_trust_chat_summary_emails` (default off). Production's chat summary
email query is broken (`PG::UndefinedTable`), so production sends none. The
plugin keeps that. Turn the setting on to start them.

## Migrations

1. `20261013120000` chat level defaults (already level 2 on production).
2. `20261013120001` one-time backfill: existing memberships get messages from
   before they joined marked read. The SQL is frozen in the migration.
3. `20261013120002` BEFORE INSERT triggers on `user_chat_channel_memberships`
   and `user_chat_thread_memberships`. A new membership starts with earlier
   messages read, including bulk inserts that skip Rails callbacks. **The
   triggers live in the database.** The migration's `down` drops them.
   Removing the plugin without rolling it back leaves them in place.

## On every Discourse upgrade

Run the safety net (`script/safety-net.sh full`). Re-check these overrides:

- `post_previews.rb`: `ExcerptParser#initialize` and `#start_element`,
  `Post.excerpt`, and the `PostItemExcerpt` redefinition.
- `chat_message_notifications.rb`: `Chat::Notifier#notify_watching_users(except:)`
  and the 5-second `enqueue_in`.
- `chat_summary_emails.rb`: `Chat::Mailer.send_unread_mentions_summary`.
- `chat_memberships.rb`: reads the legacy `mobile_notification_level` column;
  if upstream drops it, the job falls back to `notification_level`.
- Every file uses `plugin.send(:reloadable_patch)`, which is a private core API.
- `serializer_family.rb`: restores owner methods on subclasses that define the
  field themselves. Check it still matches `add_to_serializer`.
