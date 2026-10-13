# discourse-forward-trust

Forward Trust customisations for the community app. Until 2026 these were
edits inside Discourse's own files (yalla-coop/discourse); they live here so
Discourse can be upgraded as stock.

Each feature is one file in `lib/discourse_forward_trust/`, with the Yalla
commit it replaces named at the top. Behaviour is pinned by the safety net in
yalla-coop/discourse-upgrade-2026 (`spec/yalla`, `contract/`, Maestro).

## On every Discourse upgrade

Run the safety net. The places most likely to need attention:

- `post_previews.rb` overrides `ExcerptParser#initialize` and `#start_element`.
- `chat_message_notifications.rb` hooks `Chat::Notifier#notify_watching_users(except:)`.
- `chat_memberships.rb` reads the legacy `mobile_notification_level` column;
  if upstream drops it, the job falls back to `notification_level`.
