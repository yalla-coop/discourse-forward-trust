# frozen_string_literal: true

module DiscourseForwardTrust
  module SerializerFamily
    # Adds `name` to `base` and to every serializer that inherits from it.
    # A subclass created before the plugin loads keeps its own copy of the
    # attribute list, so adding to `base` alone would miss it. A class that
    # defines `name` itself (e.g. CategorySerializer#group_permissions) is
    # skipped so its own rules keep working.
    def self.add(plugin, base, name, &block)
      ([base] + base.descendants).each do |klass|
        next if klass != base && klass.instance_methods(false).include?(name)
        plugin.add_to_serializer(klass, name, &block)
      end
    end
  end
end
