# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "utilities"

module Graphs
  # Ported from upstream's data/se.sjoerd.Graphs.gschema.xml.
  #
  # Upstream reads these through GSettings, which needs a schema compiled into
  # the system's glib-2.0/schemas directory; needing an install step before the
  # app runs from a checkout is worse than the alternative, so the same keys,
  # defaults and child-schema layout are backed by one JSON file under
  # XDG_CONFIG_HOME instead.
  class Settings
    DEFAULTS = {
      "actions"       => {
        "center"   => "middle-x",
        "smoothen" => "savgol",
      },
      "smoothen"      => {
        "savgol-window"      => 10,
        "savgol-polynomial"  => 3,
        "moving-average-box" => 4,
      },
      "figure"        => {
        "title"            => "",
        "bottom-label"     => "X Value",
        "left-label"       => "Y Value",
        "top-label"        => "X Value 2",
        "right-label"      => "Y Value 2",
        "bottom-scale"     => "linear",
        "left-scale"       => "linear",
        "top-scale"        => "linear",
        "right-scale"      => "linear",
        "legend"           => true,
        "legend-position"  => "best",
        "use-custom-style" => false,
        "custom-style"     => "Adwaita",
        "hide-unselected"  => false,
      },
      "add-equation"  => {
        "equation" => "X",
      },
      "add-fill"      => {
        "upper-equation" => "0",
        "lower-equation" => "0",
      },
      "generate-data" => {
        "equation" => "X",
        "xstart"   => "0",
        "xstop"    => "10",
        "steps"    => 100,
        "scale"    => "linear",
      },
      "curve-fitting" => {
        "equation"        => "linear",
        "optimization"    => "trf",
        "confidence"      => "1std",
        "custom-equation" => "a*x+b",
        "show-residuals"  => false,
      },
      "export-figure" => {
        "file-format"     => "png",
        "transparent"     => true,
        "use-window-size" => false,
        "width"           => 800,
        "height"          => 600,
      },
      "window"        => {
        "width"     => 1200,
        "height"    => 700,
        "maximized" => false,
      },
    }.freeze

    def self.default = @default ||= new

    def initialize(path: nil)
      @path = path || File.join(Tools.config_directory, "settings.json")
      @values = read
    end

    def location = @path

    # The settings of one child schema, e.g. `settings.child("figure")`.
    def child(name) = Child.new(self, name)

    def [](child, key) = @values.dig(child, key)

    def []=(child, key, value)
      @values[child][key] = value
      write
      value
    end

    def reset(child, key)
      self[child, key] = DEFAULTS.fetch(child).fetch(key)
    end

    def reset_child(child)
      DEFAULTS.fetch(child).each_key { |key| reset(child, key) }
    end

    private

      def read
        stored = {}
        if File.exist?(@path)
          begin
            stored = JSON.parse(File.read(@path))
          rescue JSON::ParserError
            stored = {}
          end
        end
        DEFAULTS.to_h do |name, defaults|
          [name, defaults.merge(stored[name] || {})]
        end
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, "#{JSON.pretty_generate(@values)}\n")
      end

    # One child schema, so callers read `child["equation"]` the way upstream
    # reads `settings.get_string ("equation")`.
      class Child
        attr_reader :name

        def initialize(settings, name)
          @settings = settings
          @name = name
        end

        def [](key) = @settings[@name, key]

        def []=(key, value)
          @settings[@name, key] = value
        end

        def reset(key) = @settings.reset(@name, key)
        def reset_all = @settings.reset_child(@name)
        def keys = Settings::DEFAULTS.fetch(@name).keys
      end
  end
end
