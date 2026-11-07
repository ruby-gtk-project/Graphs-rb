# frozen_string_literal: true

require "adwaita"
require_relative "../color_button"
require_relative "../utilities"

module Graphs
  module StyleEditor
    # Ported from upstream's graphs/style_editor/item_color_row.vala and
    # data/ui/style-editor/item-color-row.blp: one colour of a colour group,
    # with a colour button, a delete button and — in place of upstream's
    # drag handle, which the Ruby GTK4 bindings cannot reproduce reliably —
    # move-up and move-down buttons.
    class ItemColorRow
      def initialize(index:, color:, can_move_up:, can_move_down:, on_color_changed:, on_move:, on_remove:)
        @index = index
        @color = color
        @can_move_up = can_move_up
        @can_move_down = can_move_down
        @on_color_changed = on_color_changed
        @on_move = on_move
        @on_remove = on_remove
      end

      def build
        row.tap do |widget|
          widget.add_suffix(move_up_button)
          widget.add_suffix(move_down_button)
          widget.add_suffix(color_button.build)
          widget.add_suffix(delete_button)

          move_up_button.signal_connect("clicked") { @on_move.call(@index, @index - 1) }
          move_down_button.signal_connect("clicked") { @on_move.call(@index, @index + 1) }
          delete_button.signal_connect("clicked") { @on_remove.call(@index) }

          color_button.build.tap do
            color_button.color = Tools.hex_to_rgba(@color)
          end
        end
      end

      def widget = row

      def row
        @row ||= Adwaita::ActionRow.new.tap do |widget|
          widget.title = "Color #{@index + 1}"
          widget.title_lines = 1
        end
      end

      def move_up_button
        @move_up_button ||= Gtk::Button.new.tap do |button|
          button.icon_name = "go-up-symbolic"
          button.tooltip_text = "Move Up"
          button.valign = :center
          button.sensitive = @can_move_up
          button.add_css_class("flat")
        end
      end

      def move_down_button
        @move_down_button ||= Gtk::Button.new.tap do |button|
          button.icon_name = "go-down-symbolic"
          button.tooltip_text = "Move Down"
          button.valign = :center
          button.sensitive = @can_move_down
          button.add_css_class("flat")
        end
      end

      def color_button
        @color_button ||= ColorButton.new do |rgba|
          @on_color_changed.call(@index, Tools.rgba_to_hex(rgba).delete_prefix("#"))
        end
      end

      def delete_button
        @delete_button ||= Gtk::Button.new.tap do |button|
          button.tooltip_text = "Remove"
          button.valign = :center
          button.add_css_class("flat")
          button.icon_name = "edit-delete-symbolic"
        end
      end
    end
  end
end
