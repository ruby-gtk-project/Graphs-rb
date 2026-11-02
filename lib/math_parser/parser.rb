# frozen_string_literal: true

require_relative "ast"
require_relative "lexer"

module Graphs
  module MathParser
    # Ported from upstream's graphs/math_parser/parser.vala.
    #
    # Grammar:
    #   expr    -> term ((+|-) term)*
    #   term    -> unary ((*|/) unary)* | unary expr
    #   unary   -> (- unary) | power
    #   power   -> postfix ((^|**) unary)?
    #   postfix -> primary (!)*
    #   primary -> number | constant | func | '(' expr ')'
    class Parser
      def self.instance = @instance ||= new

      def parse(source, decimal_separator = ".")
        lexer.start_lexing(source, decimal_separator)
        root = expr
        unless lexer.current_type == :end
          raise MathError.new("trailing input", kind: :syntax)
        end
        Ast.new(root)
      end

      private

        def lexer = @lexer ||= Lexer.new

        def expr
          result = term
          while additive?
            op = lexer.current_op
            lexer.next
            result = Expression.binary(result, op, term)
          end
          result
        end

        def additive?
          lexer.current_type == :operator && (lexer.current_op == :add || lexer.current_op == :sub)
        end

        # Juxtaposition multiplies: `2x`, `2(x+1)` and `x sin(x)` are products.
        def term
          result = unary
          looping = true
          while looping
            if implicit_multiplication?
              result = Expression.binary(result, :mul, unary)
            elsif multiplicative?
              op = lexer.current_op
              lexer.next
              result = Expression.binary(result, op, unary)
            else
              looping = false
            end
          end
          result
        end

        def implicit_multiplication?
          %i[number ident lparen].include?(lexer.current_type)
        end

        def multiplicative?
          lexer.current_type == :operator && (lexer.current_op == :mul || lexer.current_op == :div)
        end

        def power
          result = postfix
          if lexer.current_type == :operator && lexer.current_op == :pow
            lexer.next
            result = Expression.binary(result, :pow, unary)
          end
          result
        end

        def unary
          if lexer.current_type == :operator && lexer.current_op == :sub
            lexer.next
            Expression.unary(:sub, unary)
          elsif lexer.current_type == :operator && lexer.current_op == :add
            lexer.next
            unary
          else
            power
          end
        end

        def postfix
          result = primary
          looping = true
          while looping
            if lexer.current_type != :operator
              looping = false
            elsif lexer.current_op == :fact
              result = Expression.postfix(result, :fact)
              lexer.next
            elsif lexer.current_op == :superscript
              exponent = Expression.number(lexer.current_val)
              lexer.next
              result = Expression.binary(result, :superscript, exponent)
            else
              looping = false
            end
          end
          result
        end

        def primary
          case lexer.current_type
          when :number then number
          when :ident then ident
          when :lparen then parenthesized
          else raise MathError.new("unexpected token", kind: :syntax)
          end
        end

        def number
          value = lexer.current_val
          lexer.next
          Expression.number(value)
        end

        def ident
          id = lexer.current_ident
          if id == :custom
            variable
          else
            lexer.next
            named(id)
          end
        end

        def variable
          name = lexer.current_token_as_string
          lexer.next
          Expression.variable(name)
        end

        # A known identifier followed by a parenthesis is a function call;
        # otherwise it has to be one of the constants.
        def named(id)
          if lexer.current_type == :lparen
            lexer.next
            argument = expr
            expect_rparen
            Expression.function(id, argument)
          elsif CONSTANTS.key?(id)
            Expression.constant(id)
          else
            raise MathError.new("missing argument", kind: :syntax)
          end
        end

        def parenthesized
          lexer.next
          result = expr
          expect_rparen
          result
        end

        def expect_rparen
          unless lexer.current_type == :rparen
            raise MathError.new("expected token", kind: :syntax)
          end
          lexer.next
        end
    end
  end
end
