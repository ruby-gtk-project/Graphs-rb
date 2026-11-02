# frozen_string_literal: true

require "adwaita"
require_relative "item/factory"
require_relative "item/fill_item"
require_relative "math_parser"
require_relative "settings"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/add_fill.vala and data/ui/add-fill.blp: adds
  # the area between two bounds, each of which is positive or negative
  # infinity, a custom equation, or one of the items already in the figure.
  class AddFillDialog
    def initialize(window:, settings: Settings.default)
      @window = window
      @settings = settings.child("add-fill")
      @source_items = FillBounds.get_source_items(window.data)
      @ready = false
    end

    def build
      dialog.tap do |widget|
        widget.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = preferences_page
        end

        header_bar.tap do |bar|
          bar.pack_start(cancel_button)
          bar.pack_end(confirm_button)

          cancel_button.signal_connect("clicked") { dialog.close }
          confirm_button.signal_connect("clicked") { on_accept }
        end

        preferences_page.tap do |page|
          page.add(bounds_group)
          page.add(name_group)

          bounds_group.tap do |group|
            group.add(upper_bound_row)
            group.add(upper_equation_row)
            group.add(lower_bound_row)
            group.add(lower_equation_row)

            upper_bound_row.tap do |row|
              row.model = FillBounds.create_model(@source_items)
              row.signal_connect("notify::selected") { update_state }
            end

            lower_bound_row.tap do |row|
              row.model = FillBounds.create_model(@source_items)
              row.signal_connect("notify::selected") { update_state }
            end

            upper_equation_row.tap do |row|
              row.text = @settings["upper-equation"]
              row.signal_connect("notify::text") { update_state }
            end

            lower_equation_row.tap do |row|
              row.text = @settings["lower-equation"]
              row.signal_connect("notify::text") { update_state }
            end
          end

          name_group.add(name_row)
        end

        select_defaults
        @ready = true
        update_state
      end
    end

    def present
      build
      dialog.present(@window.window)
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |widget|
        widget.title = "Add Fill"
        widget.content_width = 450
        widget.set_size_request(360, 200)
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
        button.sensitive = false
        button.add_css_class("suggested-action")
      end
    end

    def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new
    def bounds_group = @bounds_group ||= Adwaita::PreferencesGroup.new
    def name_group = @name_group ||= Adwaita::PreferencesGroup.new

    def upper_bound_row
      @upper_bound_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = "Upper Bound"
      end
    end

    def lower_bound_row
      @lower_bound_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = "Lower Bound"
      end
    end

    def upper_equation_row = @upper_equation_row ||= equation_row
    def lower_equation_row = @lower_equation_row ||= equation_row

    def name_row
      @name_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "Name (optional)"
        row.max_width_chars = 25
        row.activates_default = true
      end
    end

    private

      def equation_row
        Adwaita::EntryRow.new.tap do |row|
          row.title = "Y ="
          row.max_width_chars = 25
          row.activates_default = true
        end
      end

      # A figure with items starts bound to the first of them above and
      # negative infinity below, which is the fill people reach for.
      def select_defaults
        if @source_items.empty?
          upper_bound_row.selected = FillBoundSelection::CUSTOM
        else
          upper_bound_row.selected = FillBoundSelection::TOP_ITEM
        end
        lower_bound_row.selected = FillBoundSelection::NEG_INF
      end

      def update_state
        if @ready
          update_bound_rows(upper_bound_row, upper_equation_row)
          update_bound_rows(lower_bound_row, lower_equation_row)
          confirm_button.sensitive =
            bound_valid?(upper_bound_row, upper_equation_row) &&
            bound_valid?(lower_bound_row, lower_equation_row)
        end
      end

      # The equation entry is only in play for a custom bound, and only then
      # does an unplottable equation mark it.
      def update_bound_rows(combo, equation)
        custom?(combo).then do |custom|
          equation.sensitive = custom
          if custom && !equation_valid?(equation)
            equation.add_css_class("error")
          else
            equation.remove_css_class("error")
          end
        end
      end

      def custom?(combo) = combo.selected == FillBoundSelection::CUSTOM

      def equation_valid?(equation) = MathTools.validate_equation(equation.text)

      def bound_valid?(combo, equation)
        if custom?(combo)
          equation_valid?(equation)
        else
          true
        end
      end

      def on_accept
        @settings["upper-equation"] = upper_equation_row.text
        @settings["lower-equation"] = lower_equation_row.text
        ItemFactory.new_fill_item(@window.data.selected_style_params).tap do |item|
          apply_bound(
            item,
            upper_bound_row,
            upper_equation_row,
            true,
          )
          apply_bound(
            item,
            lower_bound_row,
            lower_equation_row,
            false,
          )
          if name_row.text.empty?
            item.name = "Fill"
          else
            item.name = name_row.text
          end
          @window.data.add_items([item])
        end
        @window.data.optimize_limits
        dialog.close
      end

      def apply_bound(fill, combo, equation, upper)
        if combo.selected >= FillBoundSelection::TOP_ITEM
          bind_source(
            fill,
            @source_items[combo.selected - FillBoundSelection::TOP_ITEM],
            upper,
          )
        else
          bind_equation(
            fill,
            FillBounds.get_expression(combo.selected) || equation.text,
            upper,
          )
        end
      end

      def bind_source(fill, source, upper)
        if upper
          fill.set_upper_source(source)
        else
          fill.set_lower_source(source)
        end
      end

      def bind_equation(fill, expression, upper)
        Graphs.expression_to_ast(expression).then do |ast|
          if upper
            fill.set_upper_equation(ast)
          else
            fill.set_lower_equation(ast)
          end
        end
      end
  end
end
