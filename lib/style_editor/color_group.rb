# frozen_string_literal: true

require "adwaita"
require_relative "../utilities"
require_relative "item_color_row"

module Graphs
  module StyleEditor
    # Ported from upstream's graphs/style_editor/color_group.vala and
    # data/ui/style-editor/color-group.blp: a preferences group listing a
    # style's colour cycle (the line colours or the error bar colours), with
    # a button to add a colour and, on each row, a way to move, recolour or
    # remove it.
    class ColorGroup
      def initialize(&on_colors_changed)
        @colors = ["#000000"]
        @on_colors_changed = on_colors_changed
      end

      def build
        group.tap do |widget|
          widget.header_suffix = add_button
          widget.add(color_box)

          add_button.signal_connect("clicked") { add_color }
        end
      end

      def widget = group

      def colors = @colors.dup

      def colors=(new_colors)
        if new_colors.empty?
          @colors = ["#000000"]
        else
          @colors = new_colors.dup
        end
        reload_rows
        new_colors
      end

      def group = @group ||= Adwaita::PreferencesGroup.new

      def add_button
        @add_button ||= Gtk::Button.new.tap do |button|
          button.add_css_class("flat")
          button.child = Adwaita::ButtonContent.new.tap do |content|
            content.halign = :center
            content.icon_name = "list-add-symbolic"
            content.label = "Add Color"
          end
        end
      end

      def color_box
        @color_box ||= Gtk::ListBox.new.tap do |box|
          box.vexpand = false
          box.valign = :start
          box.hexpand = true
          box.selection_mode = :none
          box.add_css_class("boxed-list")
        end
      end

      private

        def add_color
          Gtk::ColorDialog.new.tap do |dialog|
            dialog.with_alpha = false
            dialog.choose_rgba(group.root, nil) do |_, result|
              on_color_chosen(dialog, result)
            end
          end
        end

        def on_color_chosen(dialog, result)
          chosen = dialog.choose_rgba_finish(result)
          unless chosen.nil?
            @colors << Tools.rgba_to_hex(chosen).delete_prefix("#")
            reload_rows
            @on_colors_changed&.call(colors)
          end
        rescue StandardError
          nil
        end

        def reload_rows
          color_box.tap do |box|
            box.remove_all
            @colors.each_with_index { |color, index| box.append(row_for(index, color)) }
          end
        end

        def row_for(index, color)
          ItemColorRow.new(
            index:            index,
            color:            color,
            can_move_up:      index.positive?,
            can_move_down:    index + 1 < @colors.length,
            on_color_changed: method(:on_color_changed),
            on_move:          method(:on_move),
            on_remove:        method(:on_remove),
          ).build
        end

        def on_color_changed(index, color)
          @colors[index] = color
          @on_colors_changed&.call(colors)
        end

        def on_move(from, to)
          if to >= 0 && to < @colors.length
            @colors.insert(to, @colors.delete_at(from))
            reload_rows
            @on_colors_changed&.call(colors)
          end
        end

        def on_remove(index)
          @colors.delete_at(index)
          if @colors.empty?
            @colors << "#000000"
          end
          reload_rows
          @on_colors_changed&.call(colors)
        end
    end
  end
end
