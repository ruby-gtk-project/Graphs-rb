# frozen_string_literal: true

require_relative "base"
require_relative "data_item"
require_relative "equation_item"
require_relative "../enums"
require_relative "../math_parser"
require_relative "../utilities"

module Graphs
  # Ported from the FillHolder class of upstream's graphs/item/fill_item.vala:
  # the three arrays a fill is drawn from, held together so a new fill is one
  # property change rather than three.
  class FillHolder
    attr_reader :xdata, :lower, :upper

    def self.empty = new([], [], [])

    def initialize(xdata, lower, upper)
      @xdata = Array(xdata)
      @lower = Array(lower)
      @upper = Array(upper)
    end

    def length = [@xdata.length, @lower.length, @upper.length].min
    def empty? = length.zero?
  end

  # Ported from the FillBoundKind enum of upstream's graphs/item/fill_item.vala:
  # where one side of a fill gets its values from.
  module FillBoundKind
    MEMBERS = %i[data item equation].freeze
    extend Enumeration
  end

  # Ported from the FillBoundSelection enum of upstream's
  # graphs/item/fill_item.vala: the rows of the bound dropdown, with the source
  # items following the three fixed entries.
  module FillBoundSelection
    INF = 0
    NEG_INF = 1
    CUSTOM = 2
    TOP_ITEM = 3
  end

  # Ported from the FillBounds class of upstream's graphs/item/fill_item.vala:
  # the dropdown model a fill's bounds are picked from, and the translation
  # between a dropdown row and the bound it stands for.
  module FillBounds
    FIXED_ENTRIES = ["Positive Infinity", "Negative Infinity", "Custom Equation…"].freeze

    module_function

    # The items a fill can be bound to: the ones that have a y value for every
    # x value.
    def get_source_items(data)
      data.items.select { |item| item.is_a?(DataItem) || item.is_a?(EquationItem) }
    end

    def create_model(source_items)
      Gtk::StringList.new(FIXED_ENTRIES + source_items.map(&:name))
    end

    def get_expression(selected)
      case selected
      when FillBoundSelection::INF then "inf"
      when FillBoundSelection::NEG_INF then "-inf"
      end
    end

    # Which dropdown row a bound the item already holds corresponds to.
    def get_selection(kind, source, equation, source_items)
      if kind == :item
        item_selection(source, source_items)
      elsif equation.nil?
        FillBoundSelection::CUSTOM
      else
        expression_selection(equation)
      end
    end

    def item_selection(source, source_items)
      source_items.index(source).then do |index|
        if index.nil?
          FillBoundSelection::CUSTOM
        else
          FillBoundSelection::TOP_ITEM + index
        end
      end
    end

    def expression_selection(equation)
      case expression_or_nil(equation)
      when "inf" then FillBoundSelection::INF
      when "-inf" then FillBoundSelection::NEG_INF
      else FillBoundSelection::CUSTOM
      end
    end

    def expression_or_nil(equation)
      Graphs.ast_to_expression(equation)
    rescue MathError
      nil
    end
  end

  # Ported from the FillItem class of upstream's graphs/item/fill_item.vala: the
  # area between two bounds, each of which is either another item, a custom
  # equation or a constant.
  #
  # A bound that follows an item is recomputed whenever that item's data
  # changes; a fill whose bounds are both equations has no x values of its own,
  # so it is evaluated across the visible range as the canvas draws it.
  class FillItem < Item
    include Signals

    property :data, nil
    property :legend, false
    property :alpha, 0.4

    def typename = "Fill"
    def legendable? = true

    def initialize(data: nil)
      self.data = data || FillHolder.empty
      @upper = Bound.new
      @lower = Bound.new
    end

    def get_upper_kind = @upper.kind
    def get_upper_source = @upper.item
    def get_upper_equation = @upper.equation
    def get_upper_program = @upper.program

    def get_lower_kind = @lower.kind
    def get_lower_source = @lower.item
    def get_lower_equation = @lower.equation
    def get_lower_program = @lower.program

    def set_upper_source(item) = set_source(@upper, item)
    def set_lower_source(item) = set_source(@lower, item)
    def set_upper_equation(equation) = set_equation(@upper, equation)
    def set_lower_equation(equation) = set_equation(@lower, equation)

    # Whether the fill has no x values of its own, which is the case when
    # neither bound follows a dataset.
    def view_based? = target_x.nil?

    # The two bounds evaluated at every value of `xdata`.
    def evaluate_bounds(xdata)
      [evaluate_bound(@lower, xdata), evaluate_bound(@upper, xdata)]
    end

    # Releases the notifications both bounds hold on their source items; the
    # data model calls this as it deletes the fill.
    def detach
      detach_source(@upper)
      detach_source(@lower)
    end

    private

      # One side of the fill, in the shape upstream's compact FillBound class
      # holds it.
      class Bound
        attr_accessor :kind, :item, :equation, :program, :constant, :handler

        def initialize
          @kind = :data
          @constant = 0.0
        end
      end

      def set_source(bound, item)
        detach_source(bound)
        bound.kind = :item
        bound.item = item
        bound.equation = nil
        bound.program = nil
        bound.handler = connect_source(item)
        item.register_dependent(self)
        if color == ""
          self.color = item.color
        end
        recompute
      end

      def set_equation(bound, equation)
        detach_source(bound)
        bound.kind = :equation
        bound.equation = equation
        bound.program = nil
        if constant?(equation.root)
          bound.constant = evaluate_constant(equation)
        else
          bound.program = Graphs.ast_to_program(equation, "x")
        end
        recompute
      end

      # A constant bound may still be undefined, e.g. 0/0; upstream keeps NaN
      # there rather than refusing the bound.
      def evaluate_constant(equation)
        MathParser::Evaluator.instance.eval_ast(equation)
      rescue MathError
        Float::NAN
      end

      def connect_source(item)
        if item.is_a?(DataItem)
          item.connect_notify(:data) { recompute }
        elsif item.is_a?(EquationItem)
          item.connect_notify(:equation) { recompute }
        end
      end

      def detach_source(bound)
        bound.item.then do |item|
          unless item.nil?
            bound.item = nil
            unless bound.handler.nil?
              item.disconnect_notify(bound.handler)
            end
            bound.handler = nil
            if item != @upper.item && item != @lower.item
              item.unregister_dependent(self)
            end
          end
        end
      end

      # Whether an expression has no variable in it, and so evaluates to a
      # single number.
      def constant?(expression)
        case expression.kind
        when :variable then false
        when :number, :constant then true
        when :unary, :function then constant?(expression.right)
        when :postfix then constant?(expression.left)
        when :binary then constant?(expression.left) && constant?(expression.right)
        end
      end

      # The x values the fill is drawn at, which are those of whichever bound
      # follows a dataset.
      def target_x
        if @upper.kind == :item && @upper.item.is_a?(DataItem)
          @upper.item.xdata
        elsif @lower.kind == :item && @lower.item.is_a?(DataItem)
          @lower.item.xdata
        end
      end

      def evaluate_bound(bound, target)
        if bound.kind == :item
          evaluate_source(bound.item, target)
        elsif bound.program.nil?
          Array.new(target.length, bound.constant)
        else
          bound.program.eval(target)
        end
      end

      def evaluate_source(item, target)
        if item.is_a?(DataItem)
          MathTools.interpolate(item.xdata, item.ydata, target)
        else
          item.get_program.eval(target)
        end
      end

      def recompute
        target_x.then do |target|
          unless target.nil?
            evaluate_bounds(target).then do |lower, upper|
              self.data = FillHolder.new(target.dup, lower, upper)
            end
          end
        end
        emit_signal(:bounds_changed)
      end
  end
end
