# frozen_string_literal: true

require_relative "ast"

module Graphs
  module MathParser
    # Ported from upstream's graphs/math_parser/lexer.vala.
    #
    # Upstream recognises identifiers with a hand-written character trie whose
    # states spell out every accepted function name; the accepted language is
    # exactly the set of names below, matched against the whole alphanumeric
    # run, so this port matches that run against a table instead.
    class Lexer
      SUPERSCRIPTS = %w[⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹].freeze

      # `log` is the natural logarithm upstream, matching numpy's naming of
      # the base-10 logarithm as `log10`.
      IDENTS = {
        "pi"    => :pi,
        "π"     => :pi,
        "e"     => :e,
        "inf"   => :inf,

        "sin"   => :sin,
        "cos"   => :cos,
        "tan"   => :tan,
        "cot"   => :cot,
        "sec"   => :sec,
        "csc"   => :csc,
        "sind"  => :sind,
        "cosd"  => :cosd,
        "tand"  => :tand,
        "cotd"  => :cotd,
        "secd"  => :secd,
        "cscd"  => :cscd,

        "asin"  => :asin,
        "acos"  => :acos,
        "atan"  => :atan,
        "acot"  => :acot,
        "asec"  => :asec,
        "acsc"  => :acsc,
        "asind" => :asind,
        "acosd" => :acosd,
        "atand" => :atand,
        "acotd" => :acotd,
        "asecd" => :asecd,
        "acscd" => :acscd,

        "ln"    => :ln,
        "log"   => :ln,
        "log2"  => :log2,
        "log10" => :log10,
        "sqrt"  => :sqrt,
        "exp"   => :exp,
        "abs"   => :abs,
      }.freeze

      attr_reader :current_type, :current_op, :current_ident, :current_val

      def start_lexing(source, decimal_separator = ".")
        @chars = source.each_char.to_a
        @separator = decimal_separator
        @start = 0
        @pos = 0
        self.next
      end

      # Advances to the next token, leaving it in the `current_*` readers.
      def next
        @start = @pos
        char = skip_whitespace
        if char.nil?
          @current_type = :end
        else
          scan(char)
        end
      end

      # The source text of the current token, lowercased — the variable name
      # for a custom identifier.
      def current_token_as_string = @chars[@start...@pos].join.downcase

      private

        def scan(char)
          if digit?(char) || char == @separator
            handle_number(char)
          elsif alpha?(char) || char == "π"
            handle_identifier(char)
          elsif char == "*"
            handle_asterisk
          elsif char == "+" || char == "-"
            handle_sign(char)
          else
            handle_single(char)
          end
        end

        # Skips over whitespace, pulling the token start along with it. Nil
        # means the source is exhausted; an exhausted source that never held a
        # character at all is an error, as it is upstream.
        def skip_whitespace
          char = nil
          while char.nil? && @pos < @chars.length
            candidate = @chars[@pos]
            @pos += 1
            if whitespace?(candidate)
              @start = @pos
            else
              char = candidate
            end
          end
          if char.nil? && @pos.zero?
            raise MathError.new("empty expression", kind: :syntax)
          end
          char
        end

        # A double asterisk is the same operator as a caret.
        def handle_asterisk
          char, after = read(@pos)
          if char.nil?
            raise MathError.new("expected token", kind: :syntax)
          end
          @current_type = :operator
          if char == "*"
            @current_op = :pow
            @pos = after
          else
            @current_op = :mul
          end
        end

        # Stacked unary signs collapse into a single operator, so `2--3` is an
        # addition and `2+-+3` a subtraction.
        def handle_sign(char)
          plus = char == "+"
          index = @pos
          loop do
            seen = nil
            while seen.nil? || whitespace?(seen)
              seen, index = read(index)
              if seen.nil?
                raise MathError.new("expected token", kind: :syntax)
              end
            end
            if seen == "-"
              plus = !plus
            end
            unless seen == "-" || seen == "+"
              break
            end
            @pos = index
          end
          @current_type = :operator
          if plus
            @current_op = :add
          else
            @current_op = :sub
          end
        end

        def handle_single(char)
          case char
          when "/" then operator(:div)
          when "^" then operator(:pow)
          when "!" then operator(:fact)
          when "(" then @current_type = :lparen
          when ")" then @current_type = :rparen
          else handle_superscript(char)
          end
        end

        def handle_superscript(char)
          if SUPERSCRIPTS.include?(char)
            operator(:superscript)
            @current_val = SUPERSCRIPTS.index(char).to_f
          else
            raise MathError.new("invalid token", kind: :syntax)
          end
        end

        def operator(op)
          @current_type = :operator
          @current_op = op
        end

        # Numbers accept thousand separators and embedded spaces, an optional
        # fraction and an optional exponent; a trailing decimal separator is a
        # syntax error.
        def handle_number(first)
          char = first
          index = @pos
          tmp = index
          seen_dot = false
          last_is_dot = false
          seen_exp = false
          int_part = 0
          frac_part = 0
          frac_digits = 0
          exp = 0
          exp_sign = 1

          loop do
            digit = digit_value(char)
            if digit
              if seen_exp
                exp = (exp * 10) + digit
              elsif seen_dot
                frac_part = (frac_part * 10) + digit
                frac_digits += 1
              else
                int_part = (int_part * 10) + digit
              end
              last_is_dot = false
            elsif char == @separator
              if seen_dot || seen_exp
                raise MathError.new("invalid number", kind: :syntax)
              end
              seen_dot = true
              last_is_dot = true
            elsif (char == "e" || char == "E") && !seen_exp
              char, tmp = read(tmp)
              if char.nil?
                break
              end
              if char == "+" || char == "-"
                if char == "-"
                  exp_sign = -1
                end
                char, tmp = read(tmp)
                if char.nil?
                  break
                end
              end
              unless digit?(char)
                break
              end
              seen_exp = true
              last_is_dot = false
              index = tmp
              next
            elsif !(char == "." || char == "," || whitespace?(char))
              break
            end

            index = tmp
            char, tmp = read(tmp)
            if char.nil?
              break
            end
          end

          if last_is_dot
            raise MathError.new("invalid number", kind: :syntax)
          end

          value = int_part.to_f
          if seen_dot
            value += frac_part / (10.0**frac_digits)
          end
          if seen_exp && exp != 0
            value *= 10.0**(exp_sign * exp)
          end

          @current_type = :number
          @current_val = value
          @pos = index
        end

        # Consumes the whole alphanumeric run, then looks it up; `arc`-prefixed
        # inverse functions are accepted as aliases of the `a`-prefixed ones.
        def handle_identifier(first)
          run = first.dup
          scanning = true
          while scanning && @pos < @chars.length
            char = @chars[@pos]
            if identifier_char?(char)
              run << char
              @pos += 1
            else
              scanning = false
            end
          end

          @current_type = :ident
          @current_ident = IDENTS.fetch(canonical_name(run.downcase), :custom)
        end

        def canonical_name(name)
          if name.start_with?("arc")
            "a#{name[3..]}"
          else
            name
          end
        end

        def identifier_char?(char)
          (alpha?(char) || digit?(char) || char == "π") && !SUPERSCRIPTS.include?(char)
        end

        def read(index)
          if index < @chars.length
            [@chars[index], index + 1]
          else
            [nil, index]
          end
        end

        def digit?(char) = char.match?(/\A[0-9]\z/)
        def alpha?(char) = char.match?(/\A[[:alpha:]]\z/)
        def whitespace?(char) = char.match?(/\A\s\z/)

        def digit_value(char)
          if digit?(char)
            char.to_i
          end
        end
    end
  end
end
