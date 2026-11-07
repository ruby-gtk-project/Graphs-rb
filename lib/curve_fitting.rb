# frozen_string_literal: true

require_relative "math_parser"
require_relative "math_parser/functions"

module Graphs
  # Ported from upstream's graphs/curve_fitting.vala and graphs/curve_fitting.py.
  #
  # Upstream hands the nonlinear least squares problem to scipy's
  # `curve_fit`, which runs Levenberg-Marquardt (or trust-region-reflective
  # when bounds are given) in compiled code. This port implements the same
  # algorithm directly: a bounded Levenberg-Marquardt solver with a
  # numerically differentiated Jacobian, run over the tree the math parser
  # already parses equations into.
  module CurveFitting
    # The seven preset equations upstream's dropdown offers, keyed the way
    # upstream's `curve-fitting.equation` setting names them.
    EQUATIONS = {
      "linear"      => "a*x+b",
      "quadratic"   => "a*x^2+b*x+c",
      "exponential" => "a*exp(b*x)",
      "power"       => "a*x^b",
      "logarithmic" => "a*log(x)+b",
      "sigmoid"     => "L/(1+exp(-k*(x-b)))",
      "gaussian"    => "a*exp(-(x-mu)^2/(2*s^2))",
    }.freeze

    # One free parameter of a fit: its starting value and the box it is
    # constrained to, mirroring upstream's FittingParameter class.
    class FittingParameter
      attr_accessor :name, :initial, :lower_bound, :upper_bound

      def initialize(name)
        @name = name
        @initial = 1.0
        @lower_bound = -Float::INFINITY
        @upper_bound = Float::INFINITY
      end
    end

    # The outcome of a successful fit: the fitted parameters, their full
    # covariance matrix (its diagonal's square root is each parameter's
    # standard error), and the two goodness-of-fit statistics upstream
    # reports.
    class FitResult
      attr_reader :parameters, :covariance, :diag_covars, :r2, :rmse

      def initialize(parameters, covariance, r2, rmse)
        @parameters = parameters
        @covariance = covariance
        @diag_covars = covariance.each_index.map { |i| Math.sqrt(covariance[i][i].abs) }
        @r2 = r2
        @rmse = rmse
      end
    end

    # Raised for every failure `fit` can hit; `kind` is one of :value,
    # :bounds, :singular, :convergence, :domain or :equation, mirroring
    # upstream's CurveFittingError enum.
    class FitError < StandardError
      attr_reader :kind

      def initialize(message, kind:)
        super(message)
        @kind = kind
      end
    end

    module_function

    # Fits `expression` (a MathParser::Ast) against `x_data`/`y_data`,
    # varying `free_vars` from the parameters in `parameters` (a name =>
    # FittingParameter map). Returns a FitResult or raises a FitError.
    def fit(expression, free_vars, parameters, x_data, y_data)
      validate_bounds(free_vars, parameters)
      p0 = free_vars.map { |name| parameters.fetch(name).initial }
      lower = free_vars.map { |name| parameters.fetch(name).lower_bound }
      upper = free_vars.map { |name| parameters.fetch(name).upper_bound }
      func = build_function(expression, free_vars)

      params = levenberg_marquardt(func, x_data, y_data, p0, lower, upper)
      residuals = x_data.each_index.map { |i| y_data[i] - func.call(x_data[i], params) }
      covariance = covariance_matrix(func, x_data, params, residuals)

      if covariance.each_index.any? { |i| !covariance[i][i].finite? }
        raise FitError.new("Confidence band error: Covariance matrix is unstable.", kind: :confidence)
      end

      FitResult.new(params, covariance, *goodness_of_fit(residuals, y_data))
    end

    # [r2, rmse] for a fit's residuals against the data they were fit from.
    def goodness_of_fit(residuals, y_data)
      ss_res = residuals.sum { |r| r * r }
      mean_y = y_data.sum / y_data.length
      ss_tot = y_data.sum { |y| (y - mean_y)**2 }

      if ss_tot.zero?
        r2 = 1.0
      else
        r2 = 1 - (ss_res / ss_tot)
      end
      rmse = Math.sqrt(ss_res / y_data.length)
      [r2, rmse]
    end

    # A copy of `expression` with every variable node named in `bindings`
    # replaced by its numeric value; used to turn a fitted equation's free
    # variables into the literal coefficients the fit found.
    def substitute(expression, bindings)
      case expression.kind
      when :number, :constant then expression
      when :variable
        if bindings.key?(expression.name)
          MathParser::Expression.number(bindings.fetch(expression.name))
        else
          expression
        end
      when :unary then MathParser::Expression.unary(expression.op, substitute(expression.right, bindings))
      when :binary
        MathParser::Expression.binary(
          substitute(expression.left, bindings),
          expression.op,
          substitute(expression.right, bindings),
        )
      when :postfix then MathParser::Expression.postfix(substitute(expression.left, bindings), expression.op)
      when :function then MathParser::Expression.function(expression.ident, substitute(expression.right, bindings))
      end
    end

    # The function `x, params -> y`, evaluated by walking the expression tree
    # with `x` and the free variables bound to their current values.
    def build_function(expression, free_vars)
      root = expression.root
      lambda do |x, params|
        bindings = {"x" => x}
        free_vars.each_with_index { |name, index| bindings[name] = params[index] }
        evaluate(root, bindings)
      end
    end

    def evaluate(expression, bindings)
      case expression.kind
      when :number, :constant then expression.value
      when :variable then bindings.fetch(expression.name) { Float::NAN }
      when :unary then MathParser::Functions.unary(expression.op, evaluate(expression.right, bindings))
      when :binary
        MathParser::Functions.binary(
          expression.op,
          evaluate(expression.left, bindings),
          evaluate(expression.right, bindings),
        )
      when :postfix then MathParser::Functions.postfix(expression.op, evaluate(expression.left, bindings))
      when :function then MathParser::Functions.apply(expression.ident, evaluate(expression.right, bindings))
      end
    end

    def validate_bounds(free_vars, parameters)
      free_vars.each do |name|
        param = parameters.fetch(name)
        unless param.lower_bound < param.initial && param.initial < param.upper_bound
          raise FitError.new("Constraint error: ensure Lower < Initial < Upper.", kind: :bounds)
        end
      end
    end

    # A bounded Levenberg-Marquardt solver: each proposed step is clamped
    # into the parameter box, which keeps the search inside the bounds the
    # dialog's rows set without needing a reparameterisation.
    def levenberg_marquardt(func, x_data, y_data, p0, lower, upper, max_iterations: 200, tolerance: 1e-12)
      params = clamp(p0, lower, upper)
      damping = 1e-3
      previous_cost = Float::INFINITY

      max_iterations.times do
        residuals = x_data.each_index.map { |i| y_data[i] - func.call(x_data[i], params) }
        unless finite_values?(residuals)
          raise FitError.new("Domain error: Equation not valid for this data range.", kind: :domain)
        end
        cost = residuals.sum { |r| r * r }
        converged = (previous_cost - cost).abs < tolerance * [1.0, previous_cost].max

        unless converged
          jacobian = numerical_jacobian(func, x_data, params)
          jt = transpose(jacobian)
          jtj = mat_mult(jt, jacobian)
          jtr = mat_vec(jt, residuals)

          step_taken = attempt_step(func, x_data, y_data, params, lower, upper, jtj, jtr, cost, damping)
          unless step_taken
            raise FitError.new(
              "Fit failed: Max iterations reached without converging.",
              kind: :convergence,
            )
          end
          params, damping, improved = step_taken
          previous_cost = cost
          converged = !improved
        end

        if converged
          break
        end
      end

      params
    end

    # One damping search: grows `damping` until a step reduces the cost (or
    # gives up after too many tries), returning the new parameters, the
    # damping to continue with, and whether the cost actually improved, or
    # nil when no step within the damping budget helped.
    def attempt_step(func, x_data, y_data, params, lower, upper, jtj, jtr, cost, damping)
      result = nil
      current_damping = damping

      20.times do
        augmented = augmented_hessian(jtj, current_damping)
        delta = solve_linear(augmented, jtr)

        if delta.nil?
          result = nil
          break
        end

        candidate = clamp(params.each_index.map { |i| params[i] + delta[i] }, lower, upper)
        candidate_residuals = x_data.each_index.map { |i| y_data[i] - func.call(x_data[i], candidate) }

        if finite_values?(candidate_residuals)
          candidate_cost = candidate_residuals.sum { |r| r * r }
          if candidate_cost < cost
            result = [candidate, [current_damping * 0.5, 1e-15].max, true]
            break
          else
            current_damping *= 10
          end
        else
          result = [params, current_damping * 10, false]
          break
        end
      end

      result
    end

    def augmented_hessian(jtj, damping)
      jtj.each_index.map do |i|
        jtj[i].each_index.map do |j|
          if i == j
            jtj[i][j] + (damping * [jtj[i][j].abs, 1e-12].max)
          else
            jtj[i][j]
          end
        end
      end
    end

    # The parameter covariance matrix, approximated the way scipy's
    # `curve_fit` does: the inverse of J'J, scaled by the residual variance.
    def covariance_matrix(func, x_data, params, residuals)
      jacobian = numerical_jacobian(func, x_data, params)
      jt = transpose(jacobian)
      jtj = mat_mult(jt, jacobian)
      dof = [x_data.length - params.length, 1].max
      variance = residuals.sum { |r| r * r } / dof
      inverse = invert(jtj)
      if inverse.nil?
        raise FitError.new("Matrix error: Data is insufficient for this model.", kind: :singular)
      end

      inverse.map { |row| row.map { |value| value * variance } }
    end

    def numerical_jacobian(func, x_data, params)
      x_data.map do |x|
        base = func.call(x, params)
        params.each_index.map do |i|
          step = [params[i].abs * 1e-6, 1e-8].max
          perturbed = params.dup
          perturbed[i] += step
          (func.call(x, perturbed) - base) / step
        end
      end
    end

    def clamp(values, lower, upper)
      values.each_index.map { |i| values[i].clamp(lower[i], upper[i]) }
    end

    def finite_values?(values) = values.all?(&:finite?)

    def transpose(matrix)
      if matrix.empty?
        []
      else
        matrix.first.each_index.map { |col| matrix.map { |row| row[col] } }
      end
    end

    def mat_mult(left, right)
      right_t = transpose(right)
      left.map { |row| right_t.map { |col| dot(row, col) } }
    end

    def mat_vec(matrix, vector)
      matrix.map { |row| dot(row, vector) }
    end

    def dot(first, second)
      first.each_index.sum { |i| first[i] * second[i] }
    end

    # Solves `matrix * x = vector` by Gauss-Jordan elimination with partial
    # pivoting; nil when the matrix is singular to working precision.
    def solve_linear(matrix, vector)
      n = vector.length
      augmented = matrix.each_index.map { |i| matrix[i].dup + [vector[i]] }
      singular = false

      n.times do |col|
        pivot_row = (col...n).max_by { |row| augmented[row][col].abs }
        if augmented[pivot_row][col].abs < 1e-14
          singular = true
        else
          augmented[col], augmented[pivot_row] = augmented[pivot_row], augmented[col]
          pivot = augmented[col][col]
          augmented[col] = augmented[col].map { |value| value / pivot }
          eliminate_column(augmented, col, n)
        end
      end

      if singular
        nil
      else
        augmented.map { |row| row.last }
      end
    end

    def eliminate_column(augmented, col, n)
      n.times do |row|
        if row != col
          factor = augmented[row][col]
          unless factor.zero?
            augmented[row] = augmented[row].each_index.map { |k| augmented[row][k] - (factor * augmented[col][k]) }
          end
        end
      end
    end

    # The inverse of a square matrix via Gauss-Jordan elimination; nil when
    # it is singular.
    def invert(matrix)
      n = matrix.length
      identity = Array.new(n) { |i| Array.new(n) { |j| i == j ? 1.0 : 0.0 } }
      columns = identity.each_index.map { |col| solve_linear(matrix, identity.map { |row| row[col] }) }

      if columns.any?(&:nil?)
        nil
      else
        transpose(columns)
      end
    end
  end
end
