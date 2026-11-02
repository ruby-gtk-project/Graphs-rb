# frozen_string_literal: true

require_relative "ast"

module Graphs
  module MathParser
    # Ported from upstream's graphs/math_parser/printer.vala: turns an
    # expression tree back into the string the user sees, parenthesising only
    # where precedence requires it and recognising multiples of pi and e.
    class Printer
      PI_THRESHOLD = 0.00010000314159265359
      E_THRESHOLD = 0.00010000271828182846

      SUPERSCRIPTS = %w[⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹].freeze

      def self.instance = @instance ||= new

      def print(ast) = emit(ast.root)

      private

        def emit(expression)
          case expression.kind
          when :number then number(expression.value)
          when :constant then constant(expression.ident)
          when :variable then expression.name
          when :unary then unary(expression)
          when :binary then binary(expression)
          when :postfix then postfix(expression)
          when :function then function(expression)
          end
        end

        def constant(ident)
          case ident
          when :pi then "pi"
          when :e then "e"
          when :inf then "inf"
          end
        end

        # A number that is (within the tolerance) a whole multiple of pi or e
        # prints as that multiple.
        def number(value)
          multiple(
            value,
            Math::PI,
            PI_THRESHOLD,
            "pi",
          ) ||
            multiple(
              value,
              Math::E,
              E_THRESHOLD,
              "e",
            ) ||
            format("%.15g", value)
        end

        def multiple(value, constant, threshold, name)
          remainder = value.remainder(constant)
          if remainder <= threshold || remainder >= constant - threshold
            factor = (value / constant + 0.5).floor
            unless factor.zero?
              if factor == 1
                name
              else
                format("%.15g%s", factor, name)
              end
            end
          end
        end

        def unary(expression)
          child = expression.right
          text = emit(child)
          if parenthesize?(child, UNARY_PRECEDENCE)
            text = "(#{text})"
          end
          if expression.op == :sub
            text = "-#{text}"
          end
          text
        end

        def parenthesize?(child, precedence)
          child.precedence.then do |child_precedence|
            !child_precedence.nil? && child_precedence < precedence
          end
        end

        def binary(expression)
          left_parens = need_parens?(expression.left, expression, false)
          right_parens = need_parens?(expression.right, expression, true)
          left = wrap(emit(expression.left), left_parens)

          if expression.op == :superscript
            "#{left}#{SUPERSCRIPTS[expression.right.value.to_i]}"
          else
            right = wrap(emit(expression.right), right_parens)
            "#{left}#{infix(expression.op, left_parens && right_parens)}#{right}"
          end
        end

        # Two parenthesised factors read as a product without the asterisk.
        def infix(op, both_parenthesized)
          case op
          when :add then " + "
          when :sub then " - "
          when :div then " / "
          when :pow then "^"
          when :mul then juxtaposition(both_parenthesized)
          end
        end

        def juxtaposition(both_parenthesized)
          if both_parenthesized
            " "
          else
            " * "
          end
        end

        def need_parens?(child, parent, right_child)
          child_precedence = child.precedence
          if child_precedence.nil?
            false
          elsif parent.kind != :binary
            true
          else
            precedence_conflict?(child_precedence, parent, right_child)
          end
        end

        def precedence_conflict?(child_precedence, parent, right_child)
          parent_precedence = parent.precedence
          if child_precedence != parent_precedence
            child_precedence < parent_precedence
          elsif right_child
            parent.op == :sub || parent.op == :div
          else
            parent.op == :pow
          end
        end

        def postfix(expression)
          child = expression.left
          text = wrap(emit(child), parenthesize?(child, expression.precedence))
          case expression.op
          when :fact then "#{text}!"
          end
        end

        def function(expression) = "#{expression.ident}(#{emit(expression.right)})"

        def wrap(text, parenthesized)
          if parenthesized
            "(#{text})"
          else
            text
          end
        end
    end
  end
end
