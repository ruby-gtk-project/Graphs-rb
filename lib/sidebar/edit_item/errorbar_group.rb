# frozen_string_literal: true

require "adwaita"
require_relative "../../color_row"
require_relative "../../utilities"

module Graphs
  module EditItem
    # Ported from upstream's graphs/sidebar/edit_item/errorbar_group.vala and
    # data/ui/sidebar/edit-item/errorbar-group.ui: a dataset's error bars —
    # which sides are shown, where they draw relative to the data, their
    # colour, and their cap and line sizing.
    class ErrorbarGroup
      def initialize(item:)
        @item = item
      end

      def build
        box.tap do |widget|
          widget.append(group)
        end
      end

      def errcolor_row
        @errcolor_row ||= ColorRow.new(color: Tools.hex_to_rgba(@item.errcolor)) do |rgba|
          @item.errcolor = Tools.rgba_to_hex(rgba)
        end
      end

      def widget = box

      def box = @box ||= Gtk::Box.new(:vertical, 0)

      def group
        @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
          preferences.title = "Error Bars"
          preferences.add(use_xerr_row)
          preferences.add(use_yerr_row)
          preferences.add(errbarsabove_row)
          preferences.add(errcolor_row.build)
          preferences.add(errcapsize_row)
          preferences.add(errcapthick_row)
          preferences.add(errlinewidth_row)

          errcolor_row.widget.title = "Color"

          use_xerr_row.tap do |row|
            if @item.has_xerr?
              row.visible = true
              row.active = @item.showxerr
              row.signal_connect("notify::active") { @item.showxerr = row.active? }
            end
          end

          use_yerr_row.tap do |row|
            if @item.has_yerr?
              row.visible = true
              row.active = @item.showyerr
              row.signal_connect("notify::active") { @item.showyerr = row.active? }
            end
          end

          errbarsabove_row.tap do |row|
            row.active = @item.errbarsabove
            row.signal_connect("notify::active") { @item.errbarsabove = row.active? }
          end

          errcapsize_row.child.adjustment.tap do |adjustment|
            adjustment.value = @item.errcapsize
            adjustment.signal_connect("value-changed") { @item.errcapsize = adjustment.value }
          end

          errcapthick_row.child.adjustment.tap do |adjustment|
            adjustment.value = @item.errcapthick
            adjustment.signal_connect("value-changed") { @item.errcapthick = adjustment.value }
          end

          errlinewidth_row.child.adjustment.tap do |adjustment|
            adjustment.value = @item.errlinewidth
            adjustment.signal_connect("value-changed") { @item.errlinewidth = adjustment.value }
          end
        end
      end

      def use_xerr_row
        @use_xerr_row ||= Adwaita::SwitchRow.new.tap do |row|
          row.title = "Show Horizontal"
          row.visible = false
        end
      end

      def use_yerr_row
        @use_yerr_row ||= Adwaita::SwitchRow.new.tap do |row|
          row.title = "Show Vertical"
          row.visible = false
        end
      end

      def errbarsabove_row
        @errbarsabove_row ||= Adwaita::SwitchRow.new.tap do |row|
          row.title = "Draw Above Data"
        end
      end

      def errcapsize_row
        @errcapsize_row ||= scale_row("Cap Length", 0.0, 12.0)
      end

      def errcapthick_row
        @errcapthick_row ||= scale_row("Cap Thickness", 0.0, 10.0)
      end

      def errlinewidth_row
        @errlinewidth_row ||= scale_row("Line Width", 0.0, 10.0)
      end

      private

        def scale_row(title, lower, upper)
          Adwaita::ActionRow.new.tap do |row|
            row.title = title
            row.child = Gtk::Scale.new(
              :horizontal,
              Gtk::Adjustment.new(lower, lower, upper, 0.1, 1.0, 0.0),
            ).tap do |scale|
              scale.draw_value = true
              scale.width_request = 200
            end
          end
        end
    end
  end
end
