# frozen_string_literal: true

require_relative "ast"

module Graphs
  module MathParser
    # The numeric semantics shared by upstream's evaluator.vala and its C
    # array evaluator (graphs/math_parser/array_evaluator.c): every operator
    # and function, with out-of-domain input yielding NaN rather than an
    # error. C's libm returns NaN there; Ruby's Math raises or returns a
    # Complex, so each one is guarded here.
    module Functions
      DEGREES_TO_RADIANS = 0.017453292519943295
      RADIANS_TO_DEGREES = 57.29577951308232

      NAN = Float::NAN

      module_function

      def unary(op, value)
        case op
        when :sub then -value
        else raise MathError.new("unknown operator", kind: :invalid)
        end
      end

      def binary(op, left, right)
        case op
        when :add then left + right
        when :sub then left - right
        when :mul then left * right
        when :pow then power(left, right)
        when :superscript then integer_power(left, right.to_i)
        when :div then divide(left, right)
        else raise MathError.new("unknown operator", kind: :invalid)
        end
      end

      def postfix(op, value)
        case op
        when :fact then factorial(value)
        else raise MathError.new("unknown operator", kind: :invalid)
        end
      end

      def divide(left, right)
        if right.zero?
          NAN
        else
          left / right
        end
      end

      def power(base, exponent)
        if base.negative? && exponent != exponent.truncate
          NAN
        else
          (base**exponent).to_f
        end
      end

      def integer_power(base, exponent) = (base**exponent).to_f

      def factorial(value)
        if value.negative? || value != value.floor
          NAN
        else
          Math.gamma(value + 1)
        end
      end

      # Every function identifier the lexer knows.
      def apply(ident, value)
        case ident
        when :sin then Math.sin(value)
        when :cos then Math.cos(value)
        when :tan then Math.tan(value)
        when :cot then divide(1.0, Math.tan(value))
        when :sec then divide(1.0, Math.cos(value))
        when :csc then divide(1.0, Math.sin(value))
        else apply_degrees(ident, value)
        end
      end

      def apply_degrees(ident, value)
        case ident
        when :sind then Math.sin(value * DEGREES_TO_RADIANS)
        when :cosd then Math.cos(value * DEGREES_TO_RADIANS)
        when :tand then Math.tan(value * DEGREES_TO_RADIANS)
        when :cotd then divide(1.0, Math.tan(value * DEGREES_TO_RADIANS))
        when :secd then divide(1.0, Math.cos(value * DEGREES_TO_RADIANS))
        when :cscd then divide(1.0, Math.sin(value * DEGREES_TO_RADIANS))
        else apply_inverse(ident, value)
        end
      end

      def apply_inverse(ident, value)
        case ident
        when :asin then arcsin(value)
        when :acos then arccos(value)
        when :atan then Math.atan(value)
        when :acot then Math.atan(divide(1.0, value))
        when :asec then arccos(divide(1.0, value))
        when :acsc then arcsin(divide(1.0, value))
        else apply_inverse_degrees(ident, value)
        end
      end

      def apply_inverse_degrees(ident, value)
        case ident
        when :asind then arcsin(value) * RADIANS_TO_DEGREES
        when :acosd then arccos(value) * RADIANS_TO_DEGREES
        when :atand then Math.atan(value) * RADIANS_TO_DEGREES
        when :acotd then Math.atan(divide(1.0, value)) * RADIANS_TO_DEGREES
        when :asecd then arccos(divide(1.0, value)) * RADIANS_TO_DEGREES
        when :acscd then arcsin(divide(1.0, value)) * RADIANS_TO_DEGREES
        else apply_misc(ident, value)
        end
      end

      def apply_misc(ident, value)
        case ident
        when :ln then logarithm(value) { |v| Math.log(v) }
        when :log2 then logarithm(value) { |v| Math.log2(v) }
        when :log10 then logarithm(value) { |v| Math.log10(v) }
        when :sqrt then square_root(value)
        when :exp then Math.exp(value)
        when :abs then value.abs
        else raise MathError.new("unknown function", kind: :unknown_function)
        end
      end

      def arcsin(value)
        if value.abs > 1
          NAN
        else
          Math.asin(value)
        end
      end

      def arccos(value)
        if value.abs > 1
          NAN
        else
          Math.acos(value)
        end
      end

      def square_root(value)
        if value.negative?
          NAN
        else
          Math.sqrt(value)
        end
      end

      def logarithm(value)
        if value.negative?
          NAN
        elsif value.zero?
          -Float::INFINITY
        else
          yield(value)
        end
      end
    end
  end
end
