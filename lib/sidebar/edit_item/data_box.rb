# frozen_string_literal: true

require "adwaita"

module Graphs
  module EditItem
    # Ported from upstream's graphs/sidebar/edit_item/data_box.vala and
    # data/ui/sidebar/edit-item/data.ui: a dataset's line and marker style,
    # and, past the downsample threshold, the toggle to draw it reduced.
    class DataBox
      LINESTYLES = ["None", "Solid", "Dotted", "Dashed", "Dashdot"].freeze
      MARKERSTYLES = [
        "None", "Point", "Pixel", "Circle", "Triangle Down", "Triangle Up",
        "Triangle Left", "Triangle Right", "Octagon", "Square", "Pentagon",
        "Star", "Hexagon 1", "Hexagon 2", "Plus", "X", "Diamond",
        "Thin Diamond", "Vertical Line", "Horizontal Line", "Filled Plus",
        "Filled X"
      ].freeze

      def initialize(item:)
        @item = item
      end

      def build
        box.tap do |widget|
          widget.append(line_group)
          widget.append(downsample_group)
        end
      end

      def widget = box

      def box = @box ||= Gtk::Box.new(:vertical, 20)

      def line_group
        @line_group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
          preferences.title = "Line and Markers"
          preferences.add(linestyle_row)
          preferences.add(linewidth_row)
          preferences.add(markerstyle_row)
          preferences.add(markersize_row)

          linestyle_row.tap do |row|
            row.selected = @item.linestyle
            row.signal_connect("notify::selected") do
              @item.linestyle = row.selected
              linewidth_scale.sensitive = row.selected != 0
            end
            linewidth_scale.sensitive = row.selected != 0
          end

          linewidth_scale.adjustment.tap do |adjustment|
            adjustment.value = @item.linewidth
            adjustment.signal_connect("value-changed") { @item.linewidth = adjustment.value }
          end

          markerstyle_row.tap do |row|
            row.selected = @item.markerstyle
            row.signal_connect("notify::selected") do
              @item.markerstyle = row.selected
              markersize_scale.sensitive = row.selected != 0
            end
            markersize_scale.sensitive = row.selected != 0
          end

          markersize_scale.adjustment.tap do |adjustment|
            adjustment.value = @item.markersize
            adjustment.signal_connect("value-changed") { @item.markersize = adjustment.value }
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
          row.child = linewidth_scale
        end
      end

      def linewidth_scale
        @linewidth_scale ||= Gtk::Scale.new(
          :horizontal,
          Gtk::Adjustment.new(3.0, 0.0, 10.0, 0.1, 1.0, 0.0),
        ).tap do |scale|
          scale.draw_value = true
          scale.width_request = 200
        end
      end

      def markerstyle_row
        @markerstyle_row ||= Adwaita::ComboRow.new.tap do |row|
          row.title = "Markers"
          row.model = Gtk::StringList.new(MARKERSTYLES)
        end
      end

      def markersize_row
        @markersize_row ||= Adwaita::ActionRow.new.tap do |row|
          row.title = "Marker Size"
          row.child = markersize_scale
        end
      end

      def markersize_scale
        @markersize_scale ||= Gtk::Scale.new(
          :horizontal,
          Gtk::Adjustment.new(7.0, 0.0, 20.0, 0.1, 1.0, 0.0),
        ).tap do |scale|
          scale.draw_value = true
          scale.width_request = 200
        end
      end

      def downsample_group
        @downsample_group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
          if @item.exceeds_downsample_threshold?
            preferences.visible = true
            preferences.add(downsample_row)

            downsample_row.tap do |row|
              row.active = @item.downsample
              row.signal_connect("notify::active") { @item.downsample = row.active? }
            end
          end
        end
      end

      def downsample_row
        @downsample_row ||= Adwaita::SwitchRow.new.tap do |row|
          row.title = "Reduce Detail"
          row.subtitle = "Draw fewer data points to improve performance"
        end
      end
    end
  end
end
