# frozen_string_literal: true

require_relative "enums"
require_relative "item/factory"
require_relative "math_parser"
require_relative "settings"
require_relative "transform_dialog"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/operations.py.
  #
  # Upstream reaches for numpy, scipy and sympy: numpy for the array
  # arithmetic, scipy for the Savitzky–Golay filter and the cumulative
  # trapezoid, sympy for the symbolic half that operates on equation items.
  # None of the three has a Ruby counterpart, so the array maths lives in
  # `Numerics` below and the symbolic manipulation in `Symbolic`, both written
  # against the same definitions upstream's dependencies use.
  module Operations
    # The order the gschema's `center-values` and `smoothen-types` enums give
    # these, which is the integer upstream's `get_enum` hands the operation.
    CENTER_MODES = %w[max-y middle-x].freeze
    SMOOTHEN_TYPES = %w[savgol moving-average].freeze

    # The operations that act on the whole selection at once rather than on
    # one item at a time.
    COMMON = %w[custom_transformation combine shift].freeze

    module_function

    # Performs a named operation on the selected items, as upstream's
    # `perform_operation` does: a cut outside select mode does nothing, the
    # arguments come from the settings or the panel's entries, and a successful
    # operation records a history state and refits the limits.
    def perform_operation(window, name)
      if name == "cut" && window.mode != :select
        false
      else
        dispatch(window, name).tap do |all_success|
          if all_success
            window.data.add_history_state
            window.data.optimize_limits
          end
        end
      end
    end

    def dispatch(window, name)
      case name
      when "custom_transformation" then CommonOperations.custom_transformation(window)
      when "combine" then CommonOperations.combine(window)
      when "shift" then CommonOperations.shift(window)
      else per_item(window, name)
      end
    end

    # The extra arguments an operation takes beyond the item itself.
    def arguments(window, name)
      actions = Settings.default.child("actions")
      case name
      when "center" then [CENTER_MODES.index(actions["center"]) || 0]
      when "smoothen" then [SMOOTHEN_TYPES.index(actions["smoothen"]) || 0, Settings.default.child("smoothen")]
      when "translate_x", "translate_y", "multiply_x", "multiply_y"
        [window.operation_value(name)]
      else []
      end
    end

    def per_item(window, name)
      all_success = false
      arguments(window, name).then do |args|
        window.data.each do |item|
          if item.selected
            all_success = run_on_item(
              window,
              item,
              name,
              args,
            ) || all_success
          end
        end
      end
      all_success
    end

    def run_on_item(window, item, name, args)
      operations_for(item).then do |operations|
        if operations.nil?
          false
        else
          operations.execute(
            item,
            name,
            window.data.figure_settings,
            window.mode,
            *args,
          ).then do |success, message|
            unless message.to_s.empty?
              window.add_toast_string(message)
            end
            success
          end
        end
      end
    end

    def operations_for(item)
      if item.is_a?(EquationItem)
        EquationOperations
      elsif item.is_a?(DataItem)
        DataOperations
      end
    end

    # The x range an operation acts on: the axis limits, or the highlighted
    # part of them in select mode.
    def get_selected_limits(figure_settings, mode, position)
      minimum = figure_settings.min_for(position)
      maximum = figure_settings.max_for(position)
      scale = figure_settings.scale_for(position)
      if mode == :select
        [
          Graphs.get_value_at_fraction(
            figure_settings.min_selected,
            minimum,
            maximum,
            scale,
          ),
          Graphs.get_value_at_fraction(
            figure_settings.max_selected,
            minimum,
            maximum,
            scale,
          ),
        ]
      else
        [minimum, maximum]
      end
    end
  end

  # The array maths upstream takes from numpy and scipy, in the forms those
  # two define: `gradient` with a coordinate array, `cumulative_trapezoid`
  # with `initial=0`, `savgol_filter` in its default "interp" edge mode,
  # `convolve` in "same" mode, and the unnormalised forward and normalised
  # inverse discrete Fourier transforms with their frequency bins.
  module Numerics
    module_function

    def mean(values) = values.sum / values.length.to_f

    def median(values)
      sorted = values.sort
      middle = sorted.length / 2
      if sorted.length.odd?
        sorted[middle]
      else
        (sorted[middle - 1] + sorted[middle]) / 2.0
      end
    end

    def standard_deviation(values)
      mean(values).then do |average|
        Math.sqrt(values.sum { |value| (value - average)**2 } / values.length.to_f)
      end
    end

    # numpy.gradient over non-uniform coordinates: second-order accurate
    # central differences inside, one-sided differences at the two ends.
    def gradient(ydata, xdata)
      count = [ydata.length, xdata.length].min
      if count < 2
        Array.new(count, 0.0)
      else
        Array.new(count) do |index|
          if index.zero?
            edge_difference(
              ydata,
              xdata,
              0,
              1,
            )
          elsif index == count - 1
            edge_difference(
              ydata,
              xdata,
              count - 2,
              count - 1,
            )
          else
            central_difference(ydata, xdata, index)
          end
        end
      end
    end

    def edge_difference(ydata, xdata, low, high)
      (xdata[high] - xdata[low]).then do |span|
        if span.zero?
          0.0
        else
          (ydata[high] - ydata[low]) / span
        end
      end
    end

    def central_difference(ydata, xdata, index)
      back = xdata[index] - xdata[index - 1]
      forward = xdata[index + 1] - xdata[index]
      divisor = back * forward * (back + forward)
      if divisor.zero?
        0.0
      else
        (
          (forward**2 * ydata[index + 1]) +
          ((back**2 - forward**2) * ydata[index]) -
          (back**2 * ydata[index - 1])
        ) / divisor
      end
    end

    # scipy.integrate.cumulative_trapezoid with initial=0: the running
    # trapezoidal integral, starting at zero so the result keeps its length.
    def cumulative_trapezoid(ydata, xdata)
      total = 0.0
      Array.new([ydata.length, xdata.length].min) do |index|
        unless index.zero?
          total += (xdata[index] - xdata[index - 1]) * (ydata[index] + ydata[index - 1]) / 2.0
        end
        total
      end
    end

    # numpy.convolve(ydata, box, mode="same") with a box of `points` ones
    # divided by `points`, which is upstream's moving average.
    def moving_average(ydata, points)
      width = [points.to_i, 1].max
      offset = (width - 1) / 2
      Array.new(ydata.length) do |index|
        (0...width).sum do |step|
          source = index + step - (width - 1 - offset)
          if source.negative? || source >= ydata.length
            0.0
          else
            ydata[source] / width.to_f
          end
        end
      end
    end

    # scipy.signal.savgol_filter in its default "interp" mode: every interior
    # point is the value of a least squares polynomial fitted to the window
    # centred on it, and the two edges are read off the polynomials fitted to
    # the first and last full window.
    def savgol_filter(ydata, window, polynomial)
      width = [[window.to_i, polynomial.to_i + 1].max, ydata.length].min
      degree = [polynomial.to_i, width - 1].min
      if width < 2 || ydata.length < 2
        ydata.dup
      else
        half = (width - 1) / 2
        Array.new(ydata.length) do |index|
          savgol_value(
            ydata,
            index,
            width,
            degree,
            half,
          )
        end
      end
    end

    def savgol_value(ydata, index, width, degree, half)
      start = [[index - half, 0].max, ydata.length - width].min
      polynomial_value(
        (0...width).map { |step| step.to_f },
        ydata[start, width],
        degree,
        (index - start).to_f,
      )
    end

    # The least squares polynomial of the given degree through (xs, ys),
    # evaluated at `at`.
    def polynomial_value(xs, ys, degree, at)
      polynomial_fit(xs, ys, degree).then do |coefficients|
        coefficients.each_with_index.sum { |value, power| value * (at**power) }
      end
    end

    # The normal equations of the fit, solved for the polynomial's
    # coefficients; a singular system means the window holds too few distinct
    # points, and the mean is the best fit there is.
    def polynomial_fit(xs, ys, degree)
      size = degree + 1
      matrix = Array.new(size) do |row|
        Array.new(size) { |column| xs.sum { |x| x**(row + column) } }
      end
      vector = Array.new(size) do |row|
        xs.each_with_index.sum { |x, index| ys[index] * (x**row) }
      end
      solve(matrix, vector).then do |coefficients|
        if coefficients.nil?
          [mean(ys)]
        else
          coefficients
        end
      end
    end

    # Gaussian elimination with partial pivoting, or nil when the system is
    # singular.
    def solve(matrix, vector)
      size = vector.length
      rows = matrix.each_with_index.map { |row, index| row + [vector[index]] }
      singular = false
      (0...size).each do |column|
        pivot = (column...size).max_by { |row| rows[row][column].abs }
        if rows[pivot][column].abs < 1e-12
          singular = true
        else
          rows[column], rows[pivot] = rows[pivot], rows[column]
          eliminate(rows, column, size)
        end
      end
      unless singular
        back_substitute(rows, size)
      end
    end

    def eliminate(rows, column, size)
      ((column + 1)...size).each do |row|
        (rows[row][column] / rows[column][column]).then do |factor|
          (column..size).each do |index|
            rows[row][index] -= factor * rows[column][index]
          end
        end
      end
    end

    def back_substitute(rows, size)
      Array.new(size, 0.0).tap do |solution|
        (size - 1).downto(0) do |row|
          ((row + 1)...size).sum { |column| rows[row][column] * solution[column] }.then do |known|
            solution[row] = (rows[row][size] - known) / rows[row][row]
          end
        end
      end
    end

    # The discrete Fourier transform, mixed-radix where the length factorises
    # and direct where it does not. numpy's `fft` leaves the forward transform
    # unnormalised and divides the inverse by the length.
    def fourier_transform(values, inverse)
      complex = values.map { |value| Complex(value, 0) }
      transform(complex, inverse).then do |result|
        if inverse
          result.map { |value| value / values.length }
        else
          result
        end
      end
    end

    def transform(values, inverse)
      count = values.length
      factor = smallest_factor(count)
      if count < 2
        values
      elsif factor == count
        direct_transform(values, inverse)
      else
        recursive_transform(values, inverse, factor)
      end
    end

    def smallest_factor(count)
      (2..Integer.sqrt(count)).find { |candidate| (count % candidate).zero? } || count
    end

    # Cooley–Tukey: `factor` interleaved sub-transforms, recombined with the
    # twiddle factors of the full length.
    def recursive_transform(values, inverse, factor)
      count = values.length
      stride = count / factor
      parts = (0...factor).map do |offset|
        transform((0...stride).map { |index| values[(index * factor) + offset] }, inverse)
      end
      if inverse
        sign = 1
      else
        sign = -1
      end
      Array.new(count) do |index|
        (0...factor).sum do |offset|
          parts[offset][index % stride] *
            Complex.polar(1, sign * 2 * Math::PI * offset * index / count)
        end
      end
    end

    def direct_transform(values, inverse)
      count = values.length
      if inverse
        sign = 1
      else
        sign = -1
      end
      Array.new(count) do |frequency|
        (0...count).sum do |index|
          values[index] * Complex.polar(1, sign * 2 * Math::PI * frequency * index / count)
        end
      end
    end

    # numpy.fft.fftfreq: the frequency bins of a transform of `count` samples
    # taken `spacing` apart, with the second half counting down from negative.
    def fftfreq(count, spacing)
      Array.new(count) do |index|
        if index < (count + 1) / 2
          index / (count * spacing)
        else
          (index - count) / (count * spacing)
        end
      end
    end
  end

  # The symbolic manipulation upstream takes from sympy, over this port's own
  # expression trees: substituting one variable for a subtree, and
  # differentiating with respect to x.
  #
  # Upstream also integrates and Fourier-transforms equations symbolically;
  # those two need a full computer algebra system, so an equation item reports
  # them with the same "not supported for equations" toast upstream shows when
  # sympy cannot do them either.
  module Symbolic
    include MathParser

    # Which radian function each degree variant stands for, and back again.
    DEGREE_FUNCTIONS = {
      sind:  :sin,
      cosd:  :cos,
      tand:  :tan,
      cotd:  :cot,
      secd:  :sec,
      cscd:  :csc,
      asind: :asin,
      acosd: :acos,
      atand: :atan,
      acotd: :acot,
      asecd: :asec,
      acscd: :acsc,
    }.freeze

    RADIAN_FUNCTIONS = DEGREE_FUNCTIONS.reject { |key, _| key.to_s.start_with?("a") }.invert.freeze

    INVERSE_DEGREE_FUNCTIONS = DEGREE_FUNCTIONS.keys.select { |key| key.to_s.start_with?("a") }.freeze

    module_function

    def number(value) = Expression.number(value)

    def binary(left, op, right)
      Expression.binary(
        left,
        op,
        right,
      )
    end

    def function(ident, argument) = Expression.function(ident, argument)

    # Replaces every occurrence of the variable `name` with `replacement`.
    def substitute(expression, name, replacement)
      case expression.kind
      when :variable
        if expression.name == name
          replacement
        else
          expression
        end
      when :number, :constant then expression
      when :unary then Expression.unary(expression.op, substitute(expression.right, name, replacement))
      when :postfix then Expression.postfix(substitute(expression.left, name, replacement), expression.op)
      when :function then Expression.function(expression.ident, substitute(expression.right, name, replacement))
      when :binary then substitute_binary(expression, name, replacement)
      end
    end

    def substitute_binary(expression, name, replacement)
      binary(
        substitute(expression.left, name, replacement),
        expression.op,
        substitute(expression.right, name, replacement),
      )
    end

    # Substitutes a whole table of names, which is how the custom
    # transformation gets at the dataset's statistics.
    def substitute_all(expression, bindings)
      bindings.reduce(expression) do |result, (name, value)|
        substitute(result, name, number(value))
      end
    end

    # The derivative with respect to `name`, by the sum, product, quotient,
    # power and chain rules.
    def differentiate(expression, name)
      case expression.kind
      when :number, :constant then number(0.0)
      when :variable then number(expression.name == name ? 1.0 : 0.0)
      when :unary then Expression.unary(expression.op, differentiate(expression.right, name))
      when :postfix then differentiate_postfix(expression, name)
      when :binary then differentiate_binary(expression, name)
      when :function then differentiate_function(expression, name)
      end
    end

    # The only postfix operator is the factorial, which has no derivative over
    # the reals.
    def differentiate_postfix(expression, _name)
      raise MathError.new("cannot differentiate #{expression.op}", kind: :invalid)
    end

    def differentiate_binary(expression, name)
      case expression.op
      when :add, :sub
        binary(
          differentiate(expression.left, name),
          expression.op,
          differentiate(expression.right, name),
        )
      when :mul then differentiate_product(expression, name)
      when :div then differentiate_quotient(expression, name)
      when :pow, :superscript then differentiate_power(expression.left, expression.right, name)
      end
    end

    def differentiate_product(expression, name)
      binary(
        binary(differentiate(expression.left, name), :mul, expression.right),
        :add,
        binary(expression.left, :mul, differentiate(expression.right, name)),
      )
    end

    def differentiate_quotient(expression, name)
      binary(
        binary(
          binary(differentiate(expression.left, name), :mul, expression.right),
          :sub,
          binary(expression.left, :mul, differentiate(expression.right, name)),
        ),
        :div,
        binary(expression.right, :mul, expression.right),
      )
    end

    # A constant exponent takes the power rule and a constant base the
    # exponential rule; only a power with the variable on both sides needs the
    # general form, whose logarithm is undefined wherever the base is not
    # positive.
    def differentiate_power(base, exponent, name)
      if constant?(exponent, name)
        power_rule(base, exponent, name)
      elsif constant?(base, name)
        exponential_rule(base, exponent, name)
      else
        general_power(base, exponent, name)
      end
    end

    # Whether the variable appears nowhere in the expression.
    def constant?(expression, name)
      case expression.kind
      when :variable then expression.name != name
      when :number, :constant then true
      when :unary, :function then constant?(expression.right, name)
      when :postfix then constant?(expression.left, name)
      when :binary then constant?(expression.left, name) && constant?(expression.right, name)
      end
    end

    # g * f^(g - 1) * f'
    def power_rule(base, exponent, name)
      binary(
        binary(exponent, :mul, binary(base, :pow, binary(exponent, :sub, number(1.0)))),
        :mul,
        differentiate(base, name),
      )
    end

    # a^g * ln a * g'
    def exponential_rule(base, exponent, name)
      binary(
        binary(binary(base, :pow, exponent), :mul, function(:ln, base)),
        :mul,
        differentiate(exponent, name),
      )
    end

    # f^g * (g' * ln f + g * f' / f)
    def general_power(base, exponent, name)
      binary(
        binary(base, :pow, exponent),
        :mul,
        binary(
          binary(differentiate(exponent, name), :mul, function(:ln, base)),
          :add,
          binary(
            binary(exponent, :mul, differentiate(base, name)),
            :div,
            base,
          ),
        ),
      )
    end

    # The chain rule over the functions the parser knows.
    def differentiate_function(expression, name)
      binary(
        outer_derivative(expression.ident, expression.right),
        :mul,
        differentiate(expression.right, name),
      )
    end

    # The outer derivative of each function the lexer knows. The degree
    # variants take their argument in degrees, so the chain rule picks up the
    # conversion factor; the inverse degree variants return degrees, so it
    # appears the other way up.
    def outer_derivative(ident, argument)
      trigonometric(ident, argument) ||
        inverse_trigonometric(ident, argument) ||
        logarithmic(ident, argument) ||
        degrees_variant(ident, argument) ||
        raise(MathError.new("cannot differentiate #{ident}", kind: :invalid))
    end

    def trigonometric(ident, argument)
      case ident
      when :sin then function(:cos, argument)
      when :cos then Expression.unary(:sub, function(:sin, argument))
      when :tan then reciprocal(squared(function(:cos, argument)))
      when :cot then Expression.unary(:sub, reciprocal(squared(function(:sin, argument))))
      when :sec then binary(function(:sec, argument), :mul, function(:tan, argument))
      when :csc
        Expression.unary(
          :sub,
          binary(function(:csc, argument), :mul, function(:cot, argument)),
        )
      end
    end

    def inverse_trigonometric(ident, argument)
      case ident
      when :asin then reciprocal(function(:sqrt, one_minus_square(argument)))
      when :acos then Expression.unary(:sub, reciprocal(function(:sqrt, one_minus_square(argument))))
      when :atan then reciprocal(one_plus_square(argument))
      when :acot then Expression.unary(:sub, reciprocal(one_plus_square(argument)))
      when :asec then reciprocal(secant_root(argument))
      when :acsc then Expression.unary(:sub, reciprocal(secant_root(argument)))
      end
    end

    def logarithmic(ident, argument)
      case ident
      when :ln then reciprocal(argument)
      when :log2 then reciprocal(binary(argument, :mul, number(Math.log(2))))
      when :log10 then reciprocal(binary(argument, :mul, number(Math.log(10))))
      when :sqrt then reciprocal(binary(number(2.0), :mul, function(:sqrt, argument)))
      when :exp then function(:exp, argument)
      when :abs then binary(argument, :div, function(:abs, argument))
      end
    end

    # A degree variant is its radian counterpart with the conversion factor
    # folded in: sind(u)' = cosd(u) * pi/180, asind(u)' = asin(u)' * 180/pi.
    def degrees_variant(ident, argument)
      DEGREE_FUNCTIONS[ident].then do |radian_ident|
        unless radian_ident.nil?
          binary(
            degrees_inner(ident, radian_ident, argument),
            :mul,
            number(degrees_factor(ident)),
          )
        end
      end
    end

    def degrees_inner(ident, radian_ident, argument)
      if INVERSE_DEGREE_FUNCTIONS.include?(ident)
        outer_derivative(radian_ident, argument)
      else
        rename_functions(outer_derivative(radian_ident, argument))
      end
    end

    # The derivative of sind is cosd, not cos, so every function the radian
    # derivative names gets its degree name back.
    def rename_functions(expression)
      case expression.kind
      when :function
        Expression.function(
          RADIAN_FUNCTIONS.fetch(expression.ident, expression.ident),
          rename_functions(expression.right),
        )
      when :unary then Expression.unary(expression.op, rename_functions(expression.right))
      when :postfix then Expression.postfix(rename_functions(expression.left), expression.op)
      when :binary
        binary(
          rename_functions(expression.left),
          expression.op,
          rename_functions(expression.right),
        )
      else expression
      end
    end

    def degrees_factor(ident)
      if INVERSE_DEGREE_FUNCTIONS.include?(ident)
        Functions::RADIANS_TO_DEGREES
      else
        Functions::DEGREES_TO_RADIANS
      end
    end

    def reciprocal(expression) = binary(number(1.0), :div, expression)
    def squared(expression) = binary(expression, :pow, number(2.0))

    def one_minus_square(argument)
      binary(number(1.0), :sub, squared(argument))
    end

    def one_plus_square(argument)
      binary(number(1.0), :add, squared(argument))
    end

    def secant_root(argument)
      binary(
        function(:abs, argument),
        :mul,
        function(:sqrt, binary(squared(argument), :sub, number(1.0))),
      )
    end

    # Evaluates an expression with several named values bound at once, which
    # the custom transformation needs for x and y together.
    def evaluate(expression, bindings)
      case expression.kind
      when :number, :constant then expression.value
      when :variable then bindings.fetch(expression.name, Float::NAN)
      when :unary then Functions.unary(expression.op, evaluate(expression.right, bindings))
      when :postfix then Functions.postfix(expression.op, evaluate(expression.left, bindings))
      when :function then Functions.apply(expression.ident, evaluate(expression.right, bindings))
      when :binary
        Functions.binary(
          expression.op,
          evaluate(expression.left, bindings),
          evaluate(expression.right, bindings),
        )
      end
    end
  end

  # Ported from the DataOperations class of upstream's graphs/operations.py:
  # the operations that rewrite a dataset's values.
  module DataOperations
    # The first of the gschema's smoothen types is the Savitzky-Golay filter.
    SMOOTHEN_WITH_WINDOW = 0

    SELECT_MISS_MESSAGE = "No data found within the highlighted area"
    UNSUPPORTED_MESSAGE = "Operation not supported for data items"
    DISCARD_MESSAGE = "Data that was outside of the highlighted area has been discarded"

    module_function

    def execute(item, name, figure_settings, mode, *args)
      select_mask(item, figure_settings, mode).then do |mask|
        if mode == :select && (mask.nil? || mask.empty?)
          [false, SELECT_MISS_MESSAGE]
        else
          apply(
            item,
            name,
            mask,
            args,
          )
        end
      end
    end

    # The indices of the points inside the highlighted area, or nil outside
    # select mode.
    def select_mask(item, figure_settings, mode)
      if mode == :select
        Operations.get_selected_limits(figure_settings, mode, item.xposition).then do |start_x, stop_x|
          item.xdata.each_index.select do |index|
            item.xdata[index] >= start_x && item.xdata[index] <= stop_x
          end
        end
      end
    end

    def apply(item, name, mask, args)
      masked(item, mask).then do |xdata, ydata|
        callback(
          item,
          name,
          xdata,
          ydata,
          args,
        ).then do |result|
          if result.nil?
            [false, UNSUPPORTED_MESSAGE]
          else
            store(item, result, mask)
          end
        end
      end
    rescue MathError, ZeroDivisionError, FloatDomainError, ArgumentError, TypeError => error
      [false, "#{error.class.name.split('::').last}: Error performing the operation"]
    end

    def masked(item, mask)
      if mask.nil?
        [item.xdata, item.ydata]
      else
        [mask.map { |index| item.xdata[index] }, mask.map { |index| item.ydata[index] }]
      end
    end

    # Each operation hands back the new x and y values plus whether the result
    # needs sorting and whether the unselected data is discarded; a cut hands
    # back no values at all, and an unknown name nothing.
    def callback(item, name, xdata, ydata, args)
      case name
      when "translate_x" then [xdata.map { |x| x + args[0] }, ydata, true, false]
      when "translate_y" then [xdata, ydata.map { |y| y + args[0] }, false, false]
      when "multiply_x" then [xdata.map { |x| x * args[0] }, ydata, true, false]
      when "multiply_y" then [xdata, ydata.map { |y| y * args[0] }, false, false]
      when "normalize" then normalize(xdata, ydata)
      when "smoothen" then smoothen(
        xdata,
        ydata,
        args[0],
        args[1],
      )
      when "center" then center(xdata, ydata, args[0])
      when "cut" then [nil, nil, false, false]
      when "derivative" then [xdata, Numerics.gradient(ydata, xdata), false, true]
      when "integral" then [xdata, Numerics.cumulative_trapezoid(ydata, xdata), false, true]
      when "fft" then fourier(xdata, ydata, false)
      when "inverse_fft" then fourier(xdata, ydata, true)
      when "transform" then transform(xdata, ydata, args)
      end
    end

    def normalize(xdata, ydata)
      ydata.max.then do |magnitude|
        [xdata, ydata.map { |y| y / magnitude }, false, false]
      end
    end

    def smoothen(xdata, ydata, smooth_type, settings)
      if SMOOTHEN_WITH_WINDOW == smooth_type
        savgol(xdata, ydata, settings)
      else
        [xdata, Numerics.moving_average(ydata, settings["moving-average-box"]), false, false]
      end
    end

    def savgol(xdata, ydata, settings)
      minimum = settings["savgol-polynomial"] + 1
      window = [minimum, (xdata.length * settings["savgol-window"] / 100.0).to_i].max
      [
        xdata,
        Numerics.savgol_filter(ydata, window, settings["savgol-polynomial"]),
        false,
        false,
      ]
    end

    def center(xdata, ydata, center_maximum)
      middle = 0.0
      if center_maximum.zero?
        middle = xdata[ydata.each_index.max_by { |index| ydata[index] }]
      else
        middle = (xdata.min + xdata.max) / 2.0
      end
      [xdata.map { |x| x - middle }, ydata, true, false]
    end

    def fourier(xdata, ydata, inverse)
      [
        Numerics.fftfreq(xdata.length, xdata[1] - xdata[0]),
        Numerics.fourier_transform(ydata, inverse).map(&:real),
        false,
        true,
      ]
    end

    # The custom transformation: the two expressions are evaluated with x, y
    # and the dataset's statistics in scope.
    def transform(xdata, ydata, args)
      statistics(xdata, ydata).then do |bindings|
        expression_x = Symbolic.substitute_all(Graphs.expression_to_ast(args[0]).root, bindings)
        expression_y = Symbolic.substitute_all(Graphs.expression_to_ast(args[1]).root, bindings)
        [
          evaluate_pairs(expression_x, xdata, ydata),
          evaluate_pairs(expression_y, xdata, ydata),
          true,
          args[2] || false,
        ]
      end
    end

    def evaluate_pairs(expression, xdata, ydata)
      xdata.each_index.map do |index|
        Symbolic.evaluate(expression, { "x" => xdata[index], "y" => ydata[index] })
      end
    end

    def statistics(xdata, ydata)
      {
        "x_min"    => xdata.min,
        "x_max"    => xdata.max,
        "y_min"    => ydata.min,
        "y_max"    => ydata.max,
        "counts"   => xdata.length.to_f,
        "x_mean"   => Numerics.mean(xdata),
        "y_mean"   => Numerics.mean(ydata),
        "x_std"    => Numerics.standard_deviation(xdata),
        "y_std"    => Numerics.standard_deviation(ydata),
        "x_median" => Numerics.median(xdata),
        "y_median" => Numerics.median(ydata),
        "x_sum"    => xdata.sum,
        "y_sum"    => ydata.sum,
      }
    end

    # Writes the result back into the item, splicing it into the unselected
    # data or discarding that data, and sorting when the operation asks.
    def store(item, result, mask)
      new_xdata, new_ydata, sort, discard = result
      message = ""
      xerr = item.data.xerr
      yerr = item.data.yerr
      unless mask.nil?
        if discard
          message = DISCARD_MESSAGE
        elsif new_xdata.nil?
          new_xdata, new_ydata, xerr, yerr = without_mask(item, mask)
        else
          new_xdata, new_ydata = splice(
            item,
            mask,
            new_xdata,
            new_ydata,
          )
        end
      end
      if sort
        new_xdata, new_ydata = sorted(new_xdata, new_ydata)
      end
      item.data = DataHolder.new(
        new_xdata,
        new_ydata,
        xerr,
        yerr,
      )
      [true, message]
    end

    # What a cut leaves behind: everything outside the highlighted area.
    def without_mask(item, mask)
      kept = item.xdata.each_index.reject { |index| mask.include?(index) }
      [
        kept.map { |index| item.xdata[index] },
        kept.map { |index| item.ydata[index] },
        drop_errors(item.data.xerr, kept),
        drop_errors(item.data.yerr, kept),
      ]
    end

    def drop_errors(errors, kept)
      unless errors.nil?
        kept.map { |index| errors[index] }
      end
    end

    def splice(item, mask, new_xdata, new_ydata)
      xdata = item.xdata.dup
      ydata = item.ydata.dup
      mask.each_with_index do |index, position|
        xdata[index] = new_xdata[position]
        ydata[index] = new_ydata[position]
      end
      [xdata, ydata]
    end

    def sorted(xdata, ydata)
      xdata.each_index.sort_by { |index| xdata[index] }.then do |order|
        [order.map { |index| xdata[index] }, order.map { |index| ydata[index] }]
      end
    end
  end

  # Ported from the EquationOperations class of upstream's
  # graphs/operations.py: the same operations, rewriting the equation instead
  # of a list of values.
  module EquationOperations
    UNSUPPORTED_MESSAGE = "Operation not supported for equations."

    module_function

    def execute(item, name, figure_settings, _mode, *args)
      limits(item, figure_settings).then do |low, high|
        rewrite(
          item,
          name,
          [low, high],
          args,
        ).then do |root|
          if root.nil?
            [false, UNSUPPORTED_MESSAGE]
          else
            accept(item, root)
          end
        end
      end
    rescue MathError
      [false, UNSUPPORTED_MESSAGE]
    end

    def limits(item, figure_settings)
      [figure_settings.min_for(item.xposition), figure_settings.max_for(item.xposition)]
    end

    # The new expression tree, or nil when this port cannot produce one.
    def rewrite(item, name, range, args)
      root = item.equation.root
      case name
      when "translate_x" then Symbolic.substitute(root, "x", shifted_x(args[0]))
      when "translate_y" then Symbolic.binary(root, :add, Symbolic.number(args[0]))
      when "multiply_x" then Symbolic.substitute(root, "x", scaled_x(args[0]))
      when "multiply_y" then Symbolic.binary(root, :mul, Symbolic.number(args[0]))
      when "normalize" then normalize(item, root, range)
      when "center" then center(
        item,
        root,
        range,
        args[0],
      )
      when "derivative" then Symbolic.differentiate(root, "x")
      when "transform" then transform(
        item,
        root,
        range,
        args,
      )
      end
    end

    # Upstream substitutes x + offset; the printer parenthesises it where the
    # surrounding precedence needs it.
    def shifted_x(offset)
      Symbolic.binary(
        MathParser::Expression.variable("x"),
        :add,
        Symbolic.number(offset),
      )
    end

    def scaled_x(multiplier)
      Symbolic.binary(
        MathParser::Expression.variable("x"),
        :mul,
        Symbolic.number(multiplier),
      )
    end

    # Upstream asks sympy for the maximum over the range and samples the
    # equation when sympy cannot find one; without a symbolic maximiser the
    # sampled magnitude is all there is.
    def normalize(item, root, range)
      sample(item, range).then do |_xdata, ydata|
        ydata.map(&:abs).max.then do |magnitude|
          if magnitude.nil? || magnitude.zero?
            root
          else
            Symbolic.binary(root, :div, Symbolic.number(magnitude))
          end
        end
      end
    end

    def center(item, root, range, center_maximum)
      middle = 0.0
      if center_maximum.zero?
        middle = maximum_position(item, range)
      else
        middle = (range[0] + range[1]) / 2.0
      end
      Symbolic.substitute(root, "x", shifted_x(middle))
    end

    def maximum_position(item, range)
      sample(item, range).then do |xdata, ydata|
        xdata[ydata.each_index.max_by { |index| ydata[index] }]
      end
    end

    # The custom transformation on an equation: x becomes the x expression and
    # y becomes the equation itself, as upstream's substitutions do.
    def transform(item, root, range, args)
      statistics(item, range).then do |bindings|
        expression_x = Symbolic.substitute_all(Graphs.expression_to_ast(args[0]).root, bindings)
        expression_y = Symbolic.substitute_all(Graphs.expression_to_ast(args[1]).root, bindings)
        Symbolic.substitute(
          expression_y,
          "y",
          Symbolic.substitute(root, "x", expression_x),
        )
      end
    end

    def statistics(item, range)
      sample(item, range).then do |xdata, ydata|
        DataOperations.statistics(xdata, ydata)
      end
    end

    def sample(item, range)
      MathTools.equation_to_data(
        item.equation,
        range[0],
        range[1],
      ).then do |holder|
        [holder.xdata, holder.ydata]
      end
    end

    # An equation the operation turned unplottable is refused, with the name of
    # the item in the message, as upstream does.
    def accept(item, root)
      MathParser::Ast.new(root).then do |ast|
        if MathTools.validate_expression(ast)
          item.equation = ast
          [true, ""]
        else
          [
            false,
            "The operation on #{item.name} did not result in a plottable equation",
          ]
        end
      end
    end
  end

  # Ported from the CommonOperations class of upstream's graphs/operations.py:
  # the operations that look at the whole selection rather than one item.
  module CommonOperations
    NO_DATA_MESSAGE = "No data found in highlighted area"
    MISSING_ERRORS_MESSAGE = "Some items lack error bars; they will be discarded"
    FAIL_MESSAGE = "Unable to perform transformation, make sure the syntax is correct"

    module_function

    # Opens the transform dialog; the operation itself happens when the dialog
    # is accepted, so nothing has changed yet.
    def custom_transformation(window)
      TransformDialog.new(window: window).tap do |dialog|
        dialog.on_accept do |input_x, input_y, discard|
          on_transform(
            window,
            input_x,
            input_y,
            discard,
          )
        end
        dialog.present
      end
      false
    end

    def on_transform(window, input_x, input_y, discard)
      data = window.data
      data.each do |item|
        if item.selected
          transform_item(
            window,
            item,
            [input_x, input_y, discard],
          )
        end
      end
      data.add_history_state
      data.optimize_limits
    end

    def transform_item(window, item, args)
      Operations.operations_for(item).then do |operations|
        unless operations.nil?
          operations.execute(
            item,
            "transform",
            window.data.figure_settings,
            window.mode,
            *args,
          ).then do |success, message|
            unless message.to_s.empty?
              window.add_toast_string(success ? message : FAIL_MESSAGE)
            end
          end
        end
      end
    end

    # Concatenates the selected items into one new dataset, sorted by x.
    def combine(window)
      collect(window).then do |xdata, ydata, xerr, yerr, some_errors|
        if xdata.empty?
          window.add_toast_string(NO_DATA_MESSAGE)
          false
        else
          if some_errors && (xerr.nil? || yerr.nil?)
            window.add_toast_string(MISSING_ERRORS_MESSAGE)
          end
          add_combined(
            window,
            [xdata, ydata],
            [xerr, yerr],
          )
          true
        end
      end
    end

    def collect(window)
      state = {
        xdata:       [],
        ydata:       [],
        xerr:        [],
        yerr:        [],
        some_errors: false,
      }
      window.data.each do |item|
        if item.selected
          collect_item(window, item, state)
        end
      end
      [state[:xdata], state[:ydata], state[:xerr], state[:yerr], state[:some_errors]]
    end

    def collect_item(window, item, state)
      item_values(window, item).then do |xdata, ydata, xerr, yerr|
        unless xdata.nil? || xdata.empty?
          state[:xdata].concat(xdata)
          state[:ydata].concat(ydata)
          collect_errors(state, xerr, yerr)
        end
      end
    end

    # An item without error bars drops them for the whole combination, which
    # is what upstream's toast warns about.
    def collect_errors(state, xerr, yerr)
      if xerr.nil?
        state[:xerr] = nil
      else
        state[:some_errors] = true
        state[:xerr]&.concat(xerr)
      end
      if yerr.nil?
        state[:yerr] = nil
      else
        state[:some_errors] = true
        state[:yerr]&.concat(yerr)
      end
    end

    def item_values(window, item)
      limits = Operations.get_selected_limits(
        window.data.figure_settings,
        window.mode,
        item.xposition,
      )
      if item.is_a?(EquationItem)
        equation_values(item, limits)
      elsif item.is_a?(DataItem)
        data_values(item, limits, window.mode)
      else
        [nil, nil, nil, nil]
      end
    end

    def equation_values(item, limits)
      MathTools.equation_to_data(
        item.equation,
        limits[0],
        limits[1],
      ).then do |holder|
        [holder.xdata, holder.ydata, nil, nil]
      end
    end

    def data_values(item, limits, mode)
      indices = item.xdata.each_index.to_a
      if mode == :select
        indices = indices.select do |index|
          item.xdata[index] >= limits[0] && item.xdata[index] <= limits[1]
        end
      end
      [
        indices.map { |index| item.xdata[index] },
        indices.map { |index| item.ydata[index] },
        slice_errors(item.data.xerr, indices),
        slice_errors(item.data.yerr, indices),
      ]
    end

    def slice_errors(errors, indices)
      unless errors.nil?
        indices.map { |index| errors[index] }
      end
    end

    def add_combined(window, values, errors)
      xdata, ydata = values
      xerr, yerr = errors
      order = xdata.each_index.sort_by { |index| xdata[index] }
      ItemFactory.new_data_item(
        window.data.selected_style_params,
        order.map { |index| xdata[index] },
        order.map { |index| ydata[index] },
        slice_errors(xerr, order),
        slice_errors(yerr, order),
      ).tap do |item|
        item.name = "Combined Data"
        window.data.add_items([item])
      end
    end

    # Shifts every selected item vertically clear of the one below it, by the
    # span of the data already shifted plus a tenth of the axis range.
    def shift(window)
      figure_settings = window.data.figure_settings
      items = window.data.items.select do |item|
        item.selected && (item.is_a?(EquationItem) || item.is_a?(DataItem))
      end
      ranges = [
        figure_settings.max_left - figure_settings.min_left,
        figure_settings.max_right - figure_settings.min_right,
      ]
      items.each_with_index do |item, index|
        shift_item(
          window,
          items,
          index,
          ranges,
        )
      end
      true
    end

    def shift_item(window, items, index, ranges)
      item = items[index]
      figure_settings = window.data.figure_settings
      limits = Operations.get_selected_limits(
        figure_settings,
        window.mode,
        item.xposition,
      )
      scale = figure_settings.scale_for(item.yposition)
      shift_values(
        window,
        items,
        index,
        limits,
      ).then do |xdata, ydata, mask|
        unless xdata.empty? || ydata.empty?
          shift_value = shift_distance(
            items,
            index,
            ranges,
            scale,
            ydata,
          )
          unless shift_value.zero?
            apply_shift(
              item,
              MathTools.sig_fig_round(shift_value, 3),
              scale,
              [xdata, ydata, mask],
            )
          end
        end
      end
    end

    def shift_values(window, items, index, limits)
      item = items[index]
      if item.is_a?(EquationItem)
        equation_values(item, limits).then do |xdata, ydata, _xerr, _yerr|
          [xdata, ydata, nil]
        end
      else
        shift_data_values(item, limits, window.mode)
      end
    end

    def shift_data_values(item, limits, mode)
      indices = item.xdata.each_index.to_a
      if mode == :select
        indices = indices.select do |index|
          item.xdata[index] >= limits[0] && item.xdata[index] <= limits[1]
        end
      end
      [
        indices.map { |index| item.xdata[index] },
        indices.map { |index| item.ydata[index] },
        mode == :select ? indices : nil,
      ]
    end

    # The accumulated distance the item has to move: every item up to and
    # including this one contributes the span of the non-zero values plus a
    # tenth of the range of the axis that item sits on.
    def shift_distance(items, index, ranges, scale, ydata)
      (0..index).sum do |step|
        step_distance(
          ranges[YPosition.value(items[step].yposition)],
          scale,
          ydata,
        )
      end
    end

    # Upstream narrows the item's y values to the x span of the previous item
    # before measuring them, but that mask is the item's own min and max, so it
    # keeps every value; what is left is the span of the non-zero values.
    def step_distance(y_range, scale, ydata)
      ydata.reject(&:zero?).then do |nonzero|
        if nonzero.empty?
          0.0
        else
          scale_span(
            nonzero.min,
            nonzero.max,
            y_range,
            scale,
          )
        end
      end
    end

    def scale_span(minimum, maximum, y_range, scale)
      case scale
      when :log then Math.log10((maximum / minimum).abs) + (0.1 * log_or_zero(y_range, 10))
      when :log2 then Math.log2((maximum / minimum).abs) + (0.1 * log_or_zero(y_range, 2))
      else (maximum - minimum) + (0.1 * y_range)
      end
    end

    def log_or_zero(value, base)
      if value.positive?
        Math.log(value, base)
      else
        0.0
      end
    end

    def apply_shift(item, shift_value, scale, values)
      xdata, ydata, mask = values
      if item.is_a?(EquationItem)
        shift_equation(item, shift_value, scale)
      else
        shift_data(
          item,
          [shift_value, scale],
          [xdata, ydata, mask],
        )
      end
    end

    def shift_equation(item, shift_value, scale)
      case scale
      when :log then multiply_equation(item, 10.0**shift_value)
      when :log2 then multiply_equation(item, 2.0**shift_value)
      else
        item.equation = MathParser::Ast.new(
          Symbolic.binary(item.equation.root, :add, Symbolic.number(shift_value)),
        )
      end
    end

    def multiply_equation(item, factor)
      item.equation = MathParser::Ast.new(
        Symbolic.binary(item.equation.root, :mul, Symbolic.number(factor)),
      )
    end

    def shift_data(item, shift, values)
      shift_value, scale = shift
      _xdata, ydata, mask = values
      shifted = ydata.map { |y| shifted_value(y, shift_value, scale) }
      new_ydata = shifted
      unless mask.nil?
        new_ydata = item.ydata.dup
        mask.each_with_index { |index, position| new_ydata[index] = shifted[position] }
      end
      item.data = DataHolder.new(
        item.xdata,
        new_ydata,
        item.data.xerr,
        item.data.yerr,
      )
    end

    def shifted_value(value, shift_value, scale)
      case scale
      when :log then value * (10.0**shift_value)
      when :log2 then value * (2.0**shift_value)
      else value + shift_value
      end
    end
  end
end
