# frozen_string_literal: true

module DiscourseForwardTrust
  module SerializerFamily
    # Adds `name` to `base` and to every serializer that inherits from it.
    # add_to_serializer already walks all loaded descendants of `base`, and it
    # overwrites `name` and `include_<name>?` on every one of them. That would
    # clobber a class that defines `name` itself (e.g.
    # CategorySerializer#group_permissions) and its subclasses (e.g.
    # WebHookCategorySerializer), which inherit those rules. So this puts
    # those classes back: a descendant that defines `name` itself keeps its
    # own methods, and a subclass of such a class goes back to inheriting.
    def self.add(plugin, base, name, &block)
      include_name = :"include_#{name}?"
      owners = base.descendants.select { |klass| klass.instance_methods(false).include?(name) }
      saved =
        owners.to_h do |klass|
          own = klass.instance_methods(false)
          [klass, [klass.instance_method(name), own.include?(include_name) && klass.instance_method(include_name)]]
        end

      # add_to_serializer appends "Serializer" to what it is given, so pass
      # the class name without that suffix.
      plugin.add_to_serializer(base.name.delete_suffix("Serializer"), name, &block)

      base.descendants.each do |klass|
        next if owners.none? { |owner| klass <= owner }
        [name, include_name].each do |m|
          klass.send(:remove_method, m) if klass.instance_methods(false).include?(m)
        end
      end
      saved.each do |klass, (name_method, include_method)|
        klass.send(:define_method, name, name_method)
        klass.send(:define_method, include_name, include_method) if include_method
      end
    end
  end
end
