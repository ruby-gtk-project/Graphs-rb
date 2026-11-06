# frozen_string_literal: true

require "adwaita"
require_relative "equation_group"

module Graphs
  module EditItem
    # Ported from upstream's graphs/sidebar/edit_item/equation_box.vala and
    # data/ui/sidebar/edit-item/equation.ui: an equation item's equation and
    # its line's style and width.
    class EquationBox
      LINESTYLES = ["Solid", "Dotted", "Dashed", "Dashdot"].freeze

      def initialize(item:)
        @item = item
        @equation_group = EquationGroup.new(item: item)
      end

      def build
        box.tap do |widget|
          widget.append(@equation_group.build)
          widget.append(group)
        end
      end

      def widget = box

      def box = @box ||= Gtk::Box.new(:vertical, 20)

      def group
        @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
          preferences.title = "Line"
          preferences.add(linestyle_row)
          preferences.add(linewidth_row)

          linestyle_row.tap do |row|
            row.selected = @item.linestyle
            row.signal_connect("notify::selected") { @item.linestyle = row.selected }
          end

          linewidth_row.child.adjustment.tap do |adjustment|
            adjustment.value = @item.linewidth
            adjustment.signal_connect("value-changed") { @item.linewidth = adjustment.value }
          end
        end
      end

      def linestyle_row
        @linestyle_row ||= Adwaita::ComboRow.new.tap do |row|
          row.title = "Linestyle"
          row.model = Gtk::StringList.new(LINESTYLES)
        end
      end

      def linewidth_row
        @linewidth_row ||= Adwaita::ActionRow.new.tap do |row|
          row.title = "Linewidth"
          row.child = Gtk::Scale.new(:horizontal, linewidth_adjustment).tap do |scale|
            scale.draw_value = true
            scale.width_request = 200
          end
        end
      end

      def linewidth_adjustment
        Gtk::Adjustment.new(
          3.0,
          0.0,
          10.0,
          0.1,
          1.0,
          0.0,
        )
      end
    end
  end
end
