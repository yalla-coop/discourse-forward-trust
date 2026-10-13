# frozen_string_literal: true

# Ruling R13. Production's Chat::Mailer query for the "while you were away"
# chat summary email is broken (it fails with PG::UndefinedTable), so
# production has never sent these emails. Stock Discourse would start sending
# them, so keep the effective behaviour: send nothing unless an admin turns on
# `forward_trust_chat_summary_emails`.
module DiscourseForwardTrust
  module ChatSummaryEmails
    module MailerExtension
      def send_unread_mentions_summary
        return unless SiteSetting.forward_trust_chat_summary_emails
        super
      end
    end

    def self.apply(plugin)
      plugin.send(:reloadable_patch) { ::Chat::Mailer.singleton_class.prepend(MailerExtension) }
    end
  end
end
