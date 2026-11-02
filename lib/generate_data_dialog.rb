# frozen_string_literal: true

require "adwaita"
require_relative "enums"
require_relative "item/factory"
require_relative "math_parser"
require_relative "settings"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/generate_data.vala and
  # data/ui/generate-data.blp: generates a dataset from an equation sampled
  # over a range, with the range, the number of points and their spacing all
  # remembered for the next time.
  class GenerateDataDialog
    SCALE_LABELS = [
      "Linear",
      "Logarithmic (Base 10)",
      "Logarithmic (Base 2)",
      "Radians",
      "Square Root",
      "Inverse",
    ].freeze

    def initialize(window:, settings: Settings.default)
      @window = window
      @settings = settings.child("generate-data")
    end

    def build
      dialog.tap do |widget|
        widget.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scrolled_window
        end

        header_bar.tap do |bar|
          bar.pack_start(cancel_button)
          bar.pack_end(confirm_button)

          cancel_button.signal_connect("clicked") { dialog.close }
          confirm_button.signal_connect("clicked") { on_accept }
        end

        scrolled_window.child = clamp

        clamp.tap do |widget_clamp|
          widget_clamp.child = content_box

          content_box.tap do |box|
            box.append(equation_group)
            box.append(range_group)
            box.append(sampling_group)

            equation_group.tap do |group|
              group.add(equation_row)
              group.add(name_row)

              equation_row.tap do |row|
                row.text = @settings["equation"]
                row.signal_connect("notify::text") { on_equation_change }
              end
            end

            range_group.add(range_row)

            range_row.child = range_box

            range_box.tap do |box_range|
              box_range.append(xstart_group)
              box_range.append(xstop_group)

              xstart_group.add(xstart_row)
              xstop_group.add(xstop_row)

              xstart_row.tap do |row|
                row.text = @settings["xstart"]
                row.signal_connect("notify::text") { on_entry_change(row) }
              end

              xstop_row.tap do |row|
                row.text = @settings["xstop"]
                row.signal_connect("notify::text") { on_entry_change(row) }
              end
            end

            sampling_group.tap do |group|
              group.add(steps_row)
              group.add(scale_row)

              steps_row.value = @settings["steps"].to_f
              scale_row.selected = Scale.value(@settings["scale"].to_sym) || 0
            end
          end
        end

        on_equation_change
        on_entry_change(xstart_row)
        on_entry_change(xstop_row)
      end
    end

    def present
      build
      dialog.present(@window.window)
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |widget|
        widget.title = "Generate Data"
        widget.content_width = 450
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
      end
    end

    def cancel_button = @cancel_button ||= Gtk::Button.new(label: "Cancel")

    def confirm_button
      @confirm_button ||= Gtk::Button.new(label: "Generate").tap do |button|
        button.add_css_class("suggested-action")
      end
    end

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scroll|
        scroll.propagate_natural_height = true
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |widget|
        widget.margin_start = 12
        widget.margin_end = 12
        widget.margin_top = 12
        widget.margin_bottom = 12
      end
    end

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 20)

    def equation_group
      @equation_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.description = "Enter a mathematical expression"
        group.separate_rows = true
      end
    end

    def equation_row
      @equation_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "Y ="
        row.max_width_chars = 25
        row.activates_default = true
      end
    end

    def name_row
      @name_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "Name (optional)"
        row.max_width_chars = 25
        row.activates_default = true
      end
    end

    def range_group = @range_group ||= Adwaita::PreferencesGroup.new

    # The two range entries sit side by side, each in a group of its own, as
    # upstream's blueprint nests them.
    def range_row
      @range_row ||= Adwaita::PreferencesRow.new.tap do |row|
        row.activatable = false
      end
    end

    def range_box
      @range_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
        box.homogeneous = true
      end
    end

    def xstart_group = @xstart_group ||= Adwaita::PreferencesGroup.new
    def xstop_group = @xstop_group ||= Adwaita::PreferencesGroup.new

    def xstart_row
      @xstart_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "X Start"
      end
    end

    def xstop_row
      @xstop_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "X Stop"
      end
    end

    def sampling_group = @sampling_group ||= Adwaita::PreferencesGroup.new

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

      def on_accept
        store_settings
        add_item(Graphs.expression_to_ast(equation_row.text))
        @window.data.optimize_limits
        dialog.close
      rescue MathError
        on_equation_change
      end

      def store_settings
        @settings["equation"] = equation_row.text
        @settings["xstart"] = xstart_row.text
        @settings["xstop"] = xstop_row.text
        @settings["steps"] = steps_row.value.to_i
        @settings["scale"] = Scale.member(scale_row.selected).to_s
      end

      def add_item(expression)
        ItemFactory.new_generated_data_item(
          @window.data.selected_style_params,
          expression,
          xstart_row.text,
          xstop_row.text,
          steps_row.value.to_i,
          Scale.member(scale_row.selected),
        ).tap do |item|
          if name_row.text.empty?
            item.name = "Y = #{Graphs.ast_to_expression(expression)}"
          else
            item.name = name_row.text
          end
          @window.data.add_items([item])
          @window.add_downsample_toasts([item])
        end
      end

      # An equation that does not evaluate marks its row; so does a range
      # entry that is not a number.
      def on_equation_change
        if MathTools.validate_equation(equation_row.text)
          equation_row.remove_css_class("error")
        else
          equation_row.add_css_class("error")
        end
        set_confirm_sensitivity
      end

      def on_entry_change(row)
        if Graphs.try_evaluate_string(row.text)
          row.remove_css_class("error")
        else
          row.add_css_class("error")
        end
        set_confirm_sensitivity
      end

      def set_confirm_sensitivity
        confirm_button.sensitive = [equation_row, xstart_row, xstop_row].none? do |row|
          row.has_css_class?("error")
        end
      end
  end
end
