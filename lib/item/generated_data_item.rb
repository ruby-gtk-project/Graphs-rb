# frozen_string_literal: true

require_relative "data_item"
require_relative "../math_parser"
require_relative "../utilities"

module Graphs
  # Ported from upstream's graphs/item/generated_data_item.vala: a dataset
  # generated from an equation over a range, which is regenerated whenever the
  # equation, the range, the step count or the scale changes.
  class GeneratedDataItem < DataItem
    property :xstart, "0"
    property :xstop, "10"
    property :steps, 100
    property :scale, :linear

    REGENERATE_ON = %i[xstart xstop steps scale].freeze

    def typename = "Generated Dataset"
    def equation_based? = true

    def initialize(equation: nil, **properties)
      super()
      set_properties(properties)
      connect_notify do |_, property|
        if REGENERATE_ON.include?(property)
          regenerate
        end
      end
      unless equation.nil?
        self.equation = equation
      end
    end

    attr_reader :equation

    def equation=(value)
      unless @equation.nil? || name != "Y = #{Graphs.ast_to_expression(@equation)}"
        self.name = "Y = #{Graphs.ast_to_expression(value)}"
      end
      @equation = value
      notify(:equation)
      regenerate
      value
    end

    def equation_string = Graphs.ast_to_expression(@equation)

    def regenerate
      unless @equation.nil?
        self.data = MathTools.equation_to_data(
          @equation,
          Graphs.evaluate_string(xstart),
          Graphs.evaluate_string(xstop),
          steps,
          scale,
        )
      end
    end
  end
end
