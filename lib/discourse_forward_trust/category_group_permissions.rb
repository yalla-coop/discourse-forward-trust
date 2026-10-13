# frozen_string_literal: true

# Replaces Yalla commit 4f86acaa3e (part): BasicCategorySerializer#group_permissions.
# Prose reads it from /categories.json and passes it to the app.
module DiscourseForwardTrust
  module CategoryGroupPermissions
    def self.apply(plugin)
      SerializerFamily.add(plugin, ::BasicCategorySerializer, :group_permissions) do
        perms =
          object
            .category_groups
            .joins(:group)
            .includes(:group)
            .merge(::Group.visible_groups(scope&.user, "groups.name ASC", include_everyone: true))
            .map { |cg| { permission_type: cg.permission_type, group_name: cg.group.name } }

        if perms.length == 0 && !object.read_restricted
          perms << {
            permission_type: ::CategoryGroup.permission_types[:full],
            group_name: ::Group[:everyone]&.name.presence || :everyone,
          }
        end

        perms
      end
    end
  end
end
