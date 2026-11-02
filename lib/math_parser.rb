# frozen_string_literal: true

require_relative "math_parser/ast"
require_relative "math_parser/functions"
require_relative "math_parser/lexer"
require_relative "math_parser/parser"
require_relative "math_parser/evaluator"
require_relative "math_parser/printer"
require_relative "math_parser/program"

module Graphs
  # The module-level entry points of upstream's graphs/math_parser/main.vala.
  module_function

  # Evaluates a string to a number, answering whether it could be parsed. The
  # value is the second element of the returned pair, 0 on failure.
  def try_evaluate_string(expression, decimal_separator = ".")
    [true, evaluate_string(expression, decimal_separator)]
  rescue MathError
    [false, 0.0]
  end

  def evaluate_string(expression, decimal_separator = ".")
    MathParser::Evaluator.instance.eval_ast(
      MathParser::Parser.instance.parse(expression, decimal_separator),
    )
  end

  def expression_to_ast(expression) = MathParser::Parser.instance.parse(expression)

  def ast_to_expression(ast) = MathParser::Printer.instance.print(ast)

  # Upstream runs the tree through sympy first, which shortens it without
  # changing what it computes; this port compiles the parsed tree as it is.
  def ast_to_program(ast, variable = "x")
    MathParser::Compiler.instance.compile(ast, variable)
  end
end
