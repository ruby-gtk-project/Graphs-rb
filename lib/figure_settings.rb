# frozen_string_literal: true

require_relative "enums"
require_relative "properties"

module Graphs
  # Ported from upstream's graphs/figure_settings.vala.
  #
  # Everything about the figure that is not an item: the four axes' labels,
  # scales and limits, the title, the legend, the style and the selection
  # range the select mode writes.
  class FigureSettings
    include Properties

    LIMIT_NAMES = %w[
      min-bottom
      max-bottom
      min-top
      max-top
      min-left
      max-left
      min-right
      max-right
    ].freeze

    property :title, ""
    property :bottom_label, ""
    property :left_label, ""
    property :top_label, ""
    property :right_label, ""

    property :bottom_scale, :linear
    property :left_scale, :linear
    property :top_scale, :linear
    property :right_scale, :linear

    property :legend, true
    property :legend_position, :best
    property :use_custom_style, false
    property :custom_style, "Adwaita"
    property :hide_unselected, false

    property :min_bottom, 0.0
    property :max_bottom, 1.0
    property :min_left, 0.0
    property :max_left, 10.0
    property :min_top, 0.0
    property :max_top, 1.0
    property :min_right, 0.0
    property :max_right, 10.0

    property :min_selected, 0.0
    property :max_selected, 0.0

    # The figure defaults the user configured, as upstream's
    # `FigureSettings (Settings)` constructor reads them.
    def self.from_settings(settings)
      new.tap do |figure_settings|
        settings.keys.each do |key|
          figure_settings[key] = coerce(key, settings[key])
        end
      end
    end

    def self.coerce(key, value)
      if key.end_with?("scale")
        Scale.from_string(value)
      elsif key == "legend-position"
        LegendPosition.from_string(value)
      else
        value
      end
    end

    # The eight axis limits in the order upstream's Limits class holds them.
    def limits = LIMIT_NAMES.map { |name| self[name] }

    def set_limits(limits)
      LIMIT_NAMES.each_with_index do |name, index|
        self[name] = limits[index]
      end
    end

    # The fraction of the bottom axis the select mode has highlighted.
    def set_selection_range(minimum, maximum)
      if minimum.negative? || maximum > 1 || minimum > maximum
        raise ArgumentError, "selection range outside [0, 1]"
      end
      self.min_selected = minimum
      self.max_selected = maximum
    end

    # The label, scale and limit property names of one axis.
    def label_for(direction) = self[:"#{direction}_label"]
    def scale_for(direction) = self[:"#{direction}_scale"]
    def min_for(direction) = self[:"min_#{direction}"]
    def max_for(direction) = self[:"max_#{direction}"]
  end
end
