# frozen_string_literal: true

require "adwaita"
require_relative "../../item/fill_item"
require_relative "../../math_parser"
require_relative "../../settings"
require_relative "../../utilities"

module Graphs
  module EditItem
    # Ported from upstream's graphs/sidebar/edit_item/fill_box.vala and
    # data/ui/sidebar/edit-item/fill.ui: a fill's two bounds, each bound
    # either to an item, a constant infinity or a custom equation, and its
    # opacity.
    class FillBox
      def initialize(item:, data:, settings: Settings.default)
        @item = item
        @settings = settings.child("add-fill")
        @source_items = FillBounds.get_source_items(data)
        @ready = false
      end

      def build
        box.tap do |widget|
          widget.append(group)

          group.tap do |preferences|
            preferences.add(upper_bound_row)
            preferences.add(upper_equation_row)
            preferences.add(lower_bound_row)
            preferences.add(lower_equation_row)
            preferences.add(alpha_row)

            upper_bound_row.tap do |row|
              row.model = FillBounds.create_model(@source_items)
              row.selected = FillBounds.get_selection(
                @item.get_upper_kind,
                @item.get_upper_source,
                @item.get_upper_equation,
                @source_items,
              )
              row.signal_connect("notify::selected") { on_upper_change }
            end

            lower_bound_row.tap do |row|
              row.model = FillBounds.create_model(@source_items)
              row.selected = FillBounds.get_selection(
                @item.get_lower_kind,
                @item.get_lower_source,
                @item.get_lower_equation,
                @source_items,
              )
              row.signal_connect("notify::selected") { on_lower_change }
            end

            upper_equation_row.tap do |row|
              row.text = @settings["upper-equation"]
              row.signal_connect("notify::text") { on_upper_change }
            end

            lower_equation_row.tap do |row|
              row.text = @settings["lower-equation"]
              row.signal_connect("notify::text") { on_lower_change }
            end

            alpha_row.child.adjustment.tap do |adjustment|
              adjustment.value = @item.alpha
              adjustment.signal_connect("value-changed") { @item.alpha = adjustment.value }
            end
          end

          @ready = true
          update_state
        end
      end

      def widget = box

      def box = @box ||= Gtk::Box.new(:vertical, 20)

      def group
        @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
          preferences.title = "Fill"
        end
      end

      def upper_bound_row
        @upper_bound_row ||= Adwaita::ComboRow.new.tap { |row| row.title = "Upper Bound" }
      end

      def lower_bound_row
        @lower_bound_row ||= Adwaita::ComboRow.new.tap { |row| row.title = "Lower Bound" }
      end

      def upper_equation_row = @upper_equation_row ||= equation_row
      def lower_equation_row = @lower_equation_row ||= equation_row

      def alpha_row
        @alpha_row ||= Adwaita::ActionRow.new.tap do |row|
          row.title = "Opacity"
          row.child = Gtk::Scale.new(
            :horizontal,
            Gtk::Adjustment.new(0.4, 0.0, 1.0, 0.01, 0.1, 0.0),
          ).tap do |scale|
            scale.draw_value = true
            scale.digits = 2
            scale.width_request = 200
          end
        end
      end

      private

        def equation_row
          Adwaita::EntryRow.new.tap do |row|
            row.title = "Y ="
            row.max_width_chars = 25
          end
        end

        def update_state
          if @ready
            update_bound_row(upper_bound_row, upper_equation_row)
            update_bound_row(lower_bound_row, lower_equation_row)
          end
        end

        def update_bound_row(combo, equation)
          custom = combo.selected == FillBoundSelection::CUSTOM
          equation.sensitive = custom
          if custom && !MathTools.validate_equation(equation.text)
            equation.add_css_class("error")
          else
            equation.remove_css_class("error")
          end
        end

        def on_upper_change
          if @ready
            update_state
            apply_bound(upper_bound_row, upper_equation_row, true)
          end
        end

        def on_lower_change
          if @ready
            update_state
            apply_bound(lower_bound_row, lower_equation_row, false)
          end
        end

        def apply_bound(combo, equation, upper)
          if combo.selected >= FillBoundSelection::TOP_ITEM
            index = combo.selected - FillBoundSelection::TOP_ITEM
            apply_source(@source_items[index], upper)
          else
            expression = FillBounds.get_expression(combo.selected) || equation.text
            apply_expression(expression, upper)
          end
        end

        def apply_source(source, upper)
          if upper
            @item.set_upper_source(source)
          else
            @item.set_lower_source(source)
          end
        end

        def apply_expression(expression, upper)
          if MathTools.validate_equation(expression)
            Graphs.expression_to_ast(expression).then do |ast|
              if upper
                @item.set_upper_equation(ast)
              else
                @item.set_lower_equation(ast)
              end
            end
          end
        end
    end
  end
end
