# frozen_string_literal: true

require "adwaita"
require_relative "item/factory"
require_relative "math_parser"
require_relative "settings"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/add_equation.vala and
  # data/ui/add-equation.blp: asks for an equation and an optional name, and
  # adds the resulting item to the figure.
  class AddEquationDialog
    def initialize(window:, settings: Settings.default)
      @window = window
      @settings = settings.child("add-equation")
    end

    def build
      dialog.tap do |widget|
        widget.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = clamp
        end

        header_bar.tap do |bar|
          bar.pack_start(cancel_button)
          bar.pack_end(confirm_button)

          cancel_button.signal_connect("clicked") { dialog.close }
          confirm_button.signal_connect("clicked") { on_accept }
        end

        clamp.tap do |widget_clamp|
          widget_clamp.child = group

          group.tap do |preferences|
            preferences.add(equation_row)
            preferences.add(name_row)

            equation_row.tap do |row|
              row.text = @settings["equation"]
              row.signal_connect("notify::text") { on_equation_change }
            end
          end
        end

        on_equation_change
      end
    end

    def present
      build
      dialog.present(@window.window)
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |widget|
        widget.title = "Add Equation"
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
      @confirm_button ||= Gtk::Button.new(label: "Add").tap do |button|
        button.add_css_class("suggested-action")
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

    def group
      @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
        preferences.description = "Enter a mathematical expression"
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

    private

      def on_accept
        equation = equation_row.text
        @settings["equation"] = equation
        expression = Graphs.expression_to_ast(equation)
        ItemFactory.new_equation_item(
          @window.data.selected_style_params,
          expression,
        ).tap do |item|
          unless name_row.text.empty?
            item.name = name_row.text
          end
          @window.data.add_items([item])
        end
        @window.data.optimize_limits
        dialog.close
      rescue MathError
        on_equation_change
      end

      # An equation that does not evaluate marks the row and blocks the button.
      def on_equation_change
        if MathTools.validate_equation(equation_row.text)
          equation_row.remove_css_class("error")
          confirm_button.sensitive = true
        else
          equation_row.add_css_class("error")
          confirm_button.sensitive = false
        end
      end
  end
end
