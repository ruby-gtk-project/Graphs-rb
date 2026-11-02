# frozen_string_literal: true

module Graphs
  # The GObject property machinery the ported models rely on, in the small
  # part this port needs.
  #
  # Upstream's Item and FigureSettings are GObjects: their fields are
  # properties with defaults, settable by name, and every change emits
  # `notify`, which the data model, the canvas and the sidebar all listen to.
  # The Ruby bindings cannot register properties on a Ruby class, so the same
  # three things — declared defaults, access by name, change notification —
  # are provided here.
  module Properties
    def self.included(base)
      base.extend(ClassMethods)
    end

    # `property :linewidth, 3.0` declares a property with its default.
    module ClassMethods
      def properties = @properties ||= superclass_properties.dup

      def superclass_properties
        if superclass.respond_to?(:properties)
          superclass.properties
        else
          {}
        end
      end

      def property(name, default)
        properties[name] = default

        define_method(name) { self[name] }
        define_method(:"#{name}=") { |value| self[name] = value }
        if default == true || default == false
          define_method(:"#{name}?") { self[name] == true }
        end
      end
    end

    # Property names are written with dashes in signals and project files and
    # with underscores in code; both reach the same property.
    def self.normalize(name) = name.to_s.tr("-", "_").to_sym

    def [](name) = values.fetch(Properties.normalize(name))

    def []=(name, value)
      key = Properties.normalize(name)
      unless self.class.properties.key?(key)
        raise ArgumentError, "unknown property #{name}"
      end
      previous = values[key]
      values[key] = value
      unless previous == value
        notify(key)
      end
      value
    end

    # Applies a hash of property values, ignoring keys this object does not
    # have — project files written by other versions carry those.
    def set_properties(hash)
      hash.each do |name, value|
        key = Properties.normalize(name)
        if self.class.properties.key?(key)
          self[key] = value
        end
      end
    end

    def to_h = values.dup

    # Registers a listener called with (object, property name) on every
    # change; `connect_notify(:color) { ... }` listens to one property only.
    def connect_notify(name = nil, &block)
      listeners << [Properties.normalize_or_nil(name), block]
      block
    end

    def disconnect_notify(block)
      listeners.reject! { |_, listener| listener == block }
    end

    def notify(name)
      listeners.each do |watched, listener|
        if watched.nil? || watched == name
          listener.call(self, name)
        end
      end
    end

    def self.normalize_or_nil(name)
      unless name.nil?
        normalize(name)
      end
    end

    private

      def values
        @values ||= self.class.properties.transform_values do |default|
          if default.is_a?(String) || default.is_a?(Array)
            default.dup
          else
            default
          end
        end
      end

      def listeners = @listeners ||= []
  end

  # The signal half of the same machinery: the ported models emit the signals
  # upstream declares (`items-changed`, `selection-changed`, `style-changed`)
  # and the widgets connect to them.
  module Signals
    def connect_signal(name, &block)
      signal_handlers[name] << block
      block
    end

    def disconnect_signal(name, block)
      signal_handlers[name].delete(block)
    end

    def emit_signal(name, *args)
      signal_handlers[name].each { |handler| handler.call(*args) }
    end

    private

      def signal_handlers = @signal_handlers ||= Hash.new { |hash, key| hash[key] = [] }
  end
end
