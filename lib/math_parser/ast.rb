# frozen_string_literal: true

module Graphs
  # Raised for every parse, compile and evaluation failure, mirroring
  # upstream's `MathError` errordomain in graphs/math_parser/main.vala. `kind`
  # is one of :syntax, :unknown_function, :domain or :invalid.
  class MathError < StandardError
    attr_reader :kind

    def initialize(message, kind: :syntax)
      super(message)
      @kind = kind
    end
  end

  # Ported from upstream's graphs/math_parser/main.vala (the Operator, Ident
  # and ExpressionType enums plus the Expression and Ast classes).
  module MathParser
    # Operator precedence; 3 is reserved for unary minus, which the parser
    # handles structurally rather than by precedence.
    PRECEDENCE = {
      add:         1,
      sub:         1,
      mul:         2,
      div:         2,
      pow:         4,
      fact:        5,
      superscript: 5,
    }.freeze

    UNARY_PRECEDENCE = 3

    # Constants an identifier can stand for, and their values.
    CONSTANTS = {
      pi:  Math::PI,
      e:   Math::E,
      inf: Float::INFINITY,
    }.freeze

    # One node of the parsed expression tree. Upstream packs the node kind,
    # the operator or identifier, the numeric value and the variable name into
    # a single compact class; the same fields are kept here, with `kind`
    # saying which of them are meaningful.
    class Expression
      attr_reader :kind, :left, :right, :op, :ident, :name

      def self.number(value) = new(:number, value: value)
      def self.constant(ident) = new(:constant, ident: ident)
      def self.variable(name) = new(:variable, name: name)
      def self.unary(op, expression) = new(:unary, op: op, right: expression)
      def self.postfix(expression, op) = new(:postfix, op: op, left: expression)
      def self.function(ident, argument) = new(:function, ident: ident, right: argument)

      def self.binary(left, op, right)
        new(
          :binary,
          left:  left,
          op:    op,
          right: right,
        )
      end

      def initialize(kind, value: 0.0, ident: nil, name: nil, op: nil, left: nil, right: nil)
        @kind = kind
        @value = value
        @ident = ident
        @name = name
        @op = op
        @left = left
        @right = right
      end

      # The numeric value of a number or constant node.
      def value
        if @kind == :number
          @value
        else
          CONSTANTS.fetch(@ident)
        end
      end

      def precedence
        case @kind
        when :binary, :postfix then PRECEDENCE.fetch(@op)
        when :unary then UNARY_PRECEDENCE
        end
      end
    end

    # A parsed expression, holding its root node. The wrapper exists upstream
    # because the nodes are compact classes; it is kept so the ported code
    # reads the same way.
    class Ast
      attr_reader :root

      def initialize(root)
        @root = root
      end
    end
  end
end
