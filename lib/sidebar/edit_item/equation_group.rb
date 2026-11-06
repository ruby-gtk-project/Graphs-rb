# frozen_string_literal: true

require "adwaita"
require_relative "../../math_parser"
require_relative "../../utilities"

module Graphs
  module EditItem
    # Ported from upstream's graphs/sidebar/edit_item/equation_group.vala and
    # data/ui/sidebar/edit-item/equation-group.ui: the equation entry shared
    # by the equation and generated-data boxes.
    #
    # Upstream's "Simplify" row calls out to a Python symbolic-maths helper
    # this port has no equivalent for, so it is left out; everything else —
    # typing an equation, the error state and applying it — behaves the same.
    class EquationGroup
      def initialize(item:)
        @item = item
      end

      def build
        group.tap do |widget|
          widget.add(equation_row)

          equation_row.tap do |row|
            row.text = Graphs.ast_to_expression(@item.equation)
            row.signal_connect("notify::text") { on_equation_change }
            row.signal_connect("apply") { on_equation_apply }
          end
        end
      end

      def widget = group

      def group
        @group ||= Adwaita::PreferencesGroup.new.tap do |widget|
          widget.title = "Equation"
        end
      end

      def equation_row
        @equation_row ||= Adwaita::EntryRow.new.tap do |row|
          row.title = "Y ="
          row.max_width_chars = 25
        end
      end

      private

        def on_equation_change
          if MathTools.validate_equation(equation_row.text)
            equation_row.remove_css_class("error")
            equation_row.show_apply_button = true
          else
            equation_row.add_css_class("error")
            equation_row.show_apply_button = false
          end
        end

        def on_equation_apply
          Graphs.expression_to_ast(equation_row.text).then do |ast|
            equation_row.text = Graphs.ast_to_expression(ast)
            @item.equation = ast
          end
        rescue MathError
          nil
        end
    end
  end
end
