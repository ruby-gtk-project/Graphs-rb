# frozen_string_literal: true

require_relative "ast"
require_relative "functions"

module Graphs
  module MathParser
    # Ported from upstream's graphs/math_parser/evaluator.vala: evaluates an
    # expression that contains no variables to a single number. A variable
    # evaluates to NaN, which `eval_ast` then reports as an error.
    class Evaluator
      def self.instance = @instance ||= new

      def eval_ast(ast)
        evaluate(ast.root).tap do |result|
          if result.nan?
            raise MathError.new("expression is not a number", kind: :invalid)
          end
        end
      end

      def evaluate(expression)
        case expression.kind
        when :number, :constant then expression.value
        when :variable then Float::NAN
        when :unary then Functions.unary(expression.op, evaluate(expression.right))
        when :binary then binary(expression)
        when :postfix then Functions.postfix(expression.op, evaluate(expression.left))
        when :function then Functions.apply(expression.ident, evaluate(expression.right))
        end
      end

      private

        def binary(expression)
          Functions.binary(
            expression.op,
            evaluate(expression.left),
            evaluate(expression.right),
          )
        end
    end
  end
end
