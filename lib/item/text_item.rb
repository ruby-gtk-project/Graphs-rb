# frozen_string_literal: true

require_relative "base"

module Graphs
  # Ported from upstream's graphs/item/text_item.vala: a text label anchored
  # at a point in data coordinates.
  class TextItem < Item
    property :xanchor, 0.0
    property :yanchor, 0.0
    property :text, ""
    property :size, 12.0
    property :rotation, 0

    def typename = "Label"

    def initialize(**properties)
      set_properties(properties)
    end
  end
end
