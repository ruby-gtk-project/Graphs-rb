# frozen_string_literal: true

module Graphs
  # Ported from upstream's graphs/misc.vala.
  #
  # Upstream's enums are GLib enums, whose "friendly string" is the GLib nick
  # ("upper-right" for UPPER_RIGHT). Here each enum is a module holding an
  # ordered list of symbols; the symbol *is* the nick, the index is the integer
  # value the project files and settings store.
  DOWNSAMPLE_THRESHOLD = 5000

  # Mixin for the enum modules below: the list of members is the single source
  # of truth and everything else is derived from it.
  module Enumeration
    def members = self::MEMBERS

    def value(member) = members.index(member)
    def member(value) = members[value]
    def friendly_string(member) = member.to_s
    def from_string(string) = members.fetch(members.index(string.to_s.downcase.to_sym) || 0)
    def include?(member) = members.include?(member)
  end

  # The axis an item's x data belongs to.
  module XPosition
    MEMBERS = %i[bottom top].freeze
    extend Enumeration
  end

  # The axis an item's y data belongs to.
  module YPosition
    MEMBERS = %i[left right].freeze
    extend Enumeration
  end

  # Axis scales. `radians` is linear with relabelled ticks; `log`, `log2`,
  # `squareroot` and `inverse` transform the axis.
  module Scale
    MEMBERS = %i[linear log log2 radians squareroot inverse].freeze
    extend Enumeration

    def self.logarithmic?(scale) = scale == :log || scale == :log2
    def self.nonzero?(scale) = logarithmic?(scale) || scale == :squareroot
  end

  # Where the legend sits inside the axes.
  module LegendPosition
    MEMBERS = %i[
      best
      upper-right
      upper-left
      lower-left
      lower-right
      center-left
      center-right
      lower-center
      upper-center
      center
    ].freeze
    extend Enumeration
  end

  # The kinds of change the undo history records.
  module ChangeType
    MEMBERS = %i[
      item-property-changed
      item-added
      item-removed
      items-swapped
      figure-settings-changed
    ].freeze
    extend Enumeration
  end

  # What dragging on the canvas does.
  module Mode
    MEMBERS = %i[pan zoom select].freeze
    extend Enumeration
  end

  def self.scale_to_string(scale) = Scale.friendly_string(scale)
  def self.legend_position_to_string(position) = LegendPosition.friendly_string(position)
end
