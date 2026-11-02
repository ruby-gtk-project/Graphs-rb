# frozen_string_literal: true

require_relative "ast"
require_relative "functions"

module Graphs
  module MathParser
    # Ported from upstream's graphs/math_parser/compiler.vala plus the Program
    # class in main.vala.
    #
    # Upstream compiles the tree to a flat opcode array so a C loop can walk
    # it once per x value; the opcodes exist for that loop's sake, so here the
    # tree is walked directly. What the compiler decides — that exactly one
    # variable name is allowed, and any other one is an error — is kept.
    class Program
      def initialize(root, variable)
        @root = root
        @variable = variable
      end

      # Evaluates the program for every value in `xdata`.
      def eval(xdata) = xdata.map { |x| evaluate(@root, x) }

      private

        def evaluate(expression, x)
          case expression.kind
          when :number, :constant then expression.value
          when :variable then x
          when :unary then Functions.unary(expression.op, evaluate(expression.right, x))
          when :binary then binary(expression, x)
          when :postfix then Functions.postfix(expression.op, evaluate(expression.left, x))
          when :function then Functions.apply(expression.ident, evaluate(expression.right, x))
          end
        end

        def binary(expression, x)
          Functions.binary(
            expression.op,
            evaluate(expression.left, x),
            evaluate(expression.right, x),
          )
        end
    end

    # Checks the variables in a tree and hands back a Program for it.
    class Compiler
      def self.instance = @instance ||= new

      def compile(ast, variable)
        validate(ast.root, variable)
        Program.new(ast.root, variable)
      end

      private

        def validate(expression, variable)
          if expression.kind == :variable && expression.name != variable
            raise MathError.new(
              "invalid variable: #{expression.name}",
              kind: :unknown_function,
            )
          end
          [expression.left, expression.right].compact.each do |child|
            validate(child, variable)
          end
        end
    end
  end
end
