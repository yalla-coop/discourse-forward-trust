# frozen_string_literal: true

# Replaces Yalla commits fb087acfbb, 160a49046f, 081062113b, d66f43f15d,
# b327885ba6 and a7ecc2fc43.
#
# When a new member confirms their email at signup, the owners of each of the
# member's groups get an email so they can review them. Not on password reset.
#
# Production stopped Discourse firing :user_confirmed_email on password reset
# for every listener. The plugin can't change that, so only this handler
# ignores non-signup confirmations; Discourse's own webhook for that event
# fires as in stock Discourse.
module DiscourseForwardTrust
  module GroupOwnerEmail
    SCOPE_KEY = :discourse_forward_trust_email_token_scope

    module EmailTokenClassExtension
      def confirm(token, scope: nil, skip_reviewable: false)
        Thread.current[SCOPE_KEY] = scope
        super
      ensure
        Thread.current[SCOPE_KEY] = nil
      end
    end

    def self.apply(plugin)
      plugin.send(:reloadable_patch) { ::EmailToken.singleton_class.prepend(EmailTokenClassExtension) }

      plugin.on(:user_confirmed_email) do |user|
        next if Thread.current[SCOPE_KEY] != ::EmailToken.scopes[:signup]
        ::DiscourseForwardTrust::GroupOwnerEmail.notify_owners(user)
      end
    end

    def self.notify_owners(user)
      ::GroupUser
        .where(user_id: user.id)
        .pluck(:group_id)
        .each do |group_id|
          group = ::Group.find(group_id)
          group_name = group.full_name.presence || group.name
          group
            .group_users
            .where(owner: true)
            .map(&:user)
            .each { |owner| deliver(user.username, user.email, group_name, owner.email) }
        end
    end

    def self.deliver(user_name, user_email, group_name, owner_email)
      holding = group_name.downcase.include?("holding")
      subject =
        holding ? "New user registered to your holding group" : "New user registered to your group"
      first_line =
        if holding
          "A new user has been registered to your holding group #{group_name}."
        else
          "A new user has been registered to your group #{group_name}."
        end

      body = <<~TEXT
        Hello,

        #{first_line}

        Username: #{user_name}
        Email: #{user_email}

        Please review them and add to the appropriate groups.

        Best regards,
        The Team
      TEXT

      I18n.with_locale(SiteSetting.default_locale) do
        ::UserNotifications.build_email(
          owner_email,
          subject: subject,
          body: body,
          locale: SiteSetting.default_locale,
        ).deliver_now
      end
    end
  end
end
