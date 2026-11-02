# frozen_string_literal: true

require_relative "base"
require_relative "../math_parser"

module Graphs
  # Ported from upstream's graphs/item/equation_item.vala: a curve defined by
  # an equation, evaluated across the visible range every time it is drawn.
  class EquationItem < Item
    property :legend, true
    property :linestyle, 1
    property :linewidth, 3.0

    def typename = "Equation"
    def legendable? = true
    def equation_based? = true

    def initialize(equation: nil)
      unless equation.nil?
        self.equation = equation
      end
    end

    attr_reader :equation

    # Setting a new equation renames the item along with it, as long as the
    # name is still the one derived from the previous equation.
    def equation=(value)
      unless @equation.nil? || name != "Y = #{Graphs.ast_to_expression(@equation)}"
        self.name = "Y = #{Graphs.ast_to_expression(value)}"
      end
      @equation = value
      @program = Graphs.ast_to_program(value)
      notify(:equation)
      value
    end

    def get_program = @program

    def equation_string = Graphs.ast_to_expression(@equation)
  end
end
