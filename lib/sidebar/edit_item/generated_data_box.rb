# frozen_string_literal: true

require "adwaita"
require_relative "../../enums"
require_relative "../../math_parser"
require_relative "../../utilities"
require_relative "equation_group"

module Graphs
  module EditItem
    # Ported from upstream's graphs/sidebar/edit_item/generated_data_box.vala
    # and data/ui/sidebar/edit-item/generated-data.ui: the equation, range and
    # sampling that a generated dataset is drawn from.
    class GeneratedDataBox
      SCALE_LABELS = [
        "Linear",
        "Logarithmic (Base 10)",
        "Logarithmic (Base 2)",
        "Radians",
        "Square Root",
        "Inverse",
      ].freeze

      def initialize(item:)
        @item = item
        @equation_group = EquationGroup.new(item: item)
      end

      def build
        box.tap do |widget|
          widget.append(@equation_group.build)
          widget.append(range_group)
          widget.append(sampling_group)
        end
      end

      def widget = box

      def box = @box ||= Gtk::Box.new(:vertical, 12)

      def range_group
        @range_group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
          preferences.add(range_row)
          range_row.child = range_box

          range_box.tap do |box_range|
            box_range.append(xstart_group)
            box_range.append(xstop_group)

            xstart_group.add(xstart_row)
            xstop_group.add(xstop_row)

            xstart_row.tap do |row|
              row.text = @item.xstart
              row.signal_connect("notify::text") { on_entry_change(row) }
              row.signal_connect("apply") { @item.xstart = row.text }
            end

            xstop_row.tap do |row|
              row.text = @item.xstop
              row.signal_connect("notify::text") { on_entry_change(row) }
              row.signal_connect("apply") { @item.xstop = row.text }
            end
          end
        end
      end

      def range_row
        @range_row ||= Adwaita::PreferencesRow.new.tap do |row|
          row.activatable = false
        end
      end

      def range_box
        @range_box ||= Gtk::Box.new(:horizontal, 12).tap do |box_range|
          box_range.homogeneous = true
        end
      end

      def xstart_group = @xstart_group ||= Adwaita::PreferencesGroup.new
      def xstop_group = @xstop_group ||= Adwaita::PreferencesGroup.new

      def xstart_row = @xstart_row ||= Adwaita::EntryRow.new.tap { |row| row.title = "X Start" }
      def xstop_row = @xstop_row ||= Adwaita::EntryRow.new.tap { |row| row.title = "X Stop" }

      def sampling_group
        @sampling_group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
          preferences.add(steps_row)
          preferences.add(scale_row)

          steps_row.value = @item.steps.to_f
          steps_row.signal_connect("notify::value") { @item.steps = steps_row.value.to_i }

          scale_row.selected = Scale.value(@item.scale) || 0
          scale_row.signal_connect("notify::selected") do
            @item.scale = Scale.member(scale_row.selected)
          end
        end
      end

      def steps_row
        @steps_row ||= Adwaita::SpinRow.new(steps_adjustment, 1, 0).tap do |row|
          row.title = "Steps"
        end
      end

      def steps_adjustment
        Gtk::Adjustment.new(
          100.0,
          2.0,
          1_000_000_000.0,
          1.0,
          100.0,
          0.0,
        )
      end

      def scale_row
        @scale_row ||= Adwaita::ComboRow.new.tap do |row|
          row.title = "Scale"
          row.subtitle = "How points are spaced"
          row.model = Gtk::StringList.new(SCALE_LABELS)
        end
      end

      private

        # A range entry that is not a number marks itself, as upstream's
        # `on_entry_change` does; a valid one gets an apply button.
        def on_entry_change(row)
          valid, = Graphs.try_evaluate_string(row.text)
          if valid
            row.remove_css_class("error")
            row.show_apply_button = true
          else
            row.add_css_class("error")
            row.show_apply_button = false
          end
        end
    end
  end
end
