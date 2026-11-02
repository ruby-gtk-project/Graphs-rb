# frozen_string_literal: true

require "adwaita"
require_relative "../enums"
require_relative "../properties"
require_relative "../utilities"

module Graphs
  # Ported from upstream's graphs/item/base.vala.
  #
  # The properties every item has, its colour as a Gdk.RGBA, and the
  # dependents an item can have — a fill between two datasets depends on them,
  # and deleting one deletes the fill with it.
  class Item
    include Properties

    LINESTYLES = %w[none solid dotted dashed dashdot].freeze

    MARKERSTYLES = [
      "none", ".", ",", "o", "v", "^", "<", ">", "8", "s", "p",
      "*", "h", "H", "+", "x", "D", "d", "|", "_", "P", "X"
    ].freeze

    property :name, ""
    property :color, ""
    property :alpha, 1.0
    property :selected, true
    property :visible, true
    property :xlabel, ""
    property :ylabel, ""
    property :xposition, :bottom
    property :yposition, :left

    # The kind of item, as the sidebar labels it.
    def typename = "Item"

    def get_rgba
      Tools.hex_to_rgba(color).tap do |rgba|
        rgba.alpha = alpha
      end
    end

    def set_rgba(rgba)
      self.color = Tools.rgba_to_hex(rgba)
      self.alpha = rgba.alpha
    end

    def register_dependent(dependent) = dependents << dependent
    def unregister_dependent(dependent) = dependents.delete(dependent)
    def get_dependents = dependents.dup

    # Whether this item can appear in the legend — a plain label cannot.
    def legendable? = false

    # Whether this item is drawn from an equation the user can edit.
    def equation_based? = false

    private

      def dependents = @dependents ||= []
  end
end
