# frozen_string_literal: true

require "adwaita"
require_relative "enums"
require_relative "math_parser"
require_relative "item/data_holder"

module Graphs
  # Ported from upstream's graphs/utilities.vala and graphs/math_utilities.vala
  # (whose numeric helpers live in Graphs::MathTools below).

  module_function

  # The value an axis takes at the given fraction of its length, honouring the
  # axis scale.
  def get_value_at_fraction(fraction, start, stop, scale)
    case scale
    when :linear, :radians then start + (fraction * (stop - start))
    when :log then logarithmic_value(
      fraction,
      start,
      stop,
      10.0,
    )
    when :log2 then logarithmic_value(
      fraction,
      start,
      stop,
      2.0,
    )
    when :squareroot then square_root_value(fraction, start, stop)
    when :inverse then inverse_value(fraction, start, stop)
    end
  end

  # The fraction of an axis' length at which the given value sits.
  def get_fraction_at_value(value, start, stop, scale)
    case scale
    when :linear, :radians then (value - start) / (stop - start)
    when :log then logarithmic_fraction(
      value,
      start,
      stop,
      10.0,
    )
    when :log2 then logarithmic_fraction(
      value,
      start,
      stop,
      2.0,
    )
    when :squareroot then square_root_fraction(value, start, stop)
    when :inverse then inverse_fraction(value, start, stop)
    end
  end

  def logarithmic_value(fraction, start, stop, base)
    log_start = Math.log(start, base)
    log_stop = Math.log(stop, base)
    base**(log_start + ((log_stop - log_start) * fraction))
  end

  def logarithmic_fraction(value, start, stop, base)
    log_start = Math.log(start, base)
    log_stop = Math.log(stop, base)
    (Math.log(value, base) - log_start) / (log_stop - log_start)
  end

  # A square root axis has no meaningful negative side, so the fraction is
  # clamped at zero.
  def square_root_value(fraction, start, stop)
    sqrt_start = [0.0, Math.sqrt([start, 0.0].max)].max
    sqrt_stop = Math.sqrt([stop, 0.0].max)
    value = sqrt_start + ((sqrt_stop - sqrt_start) * [0.0, fraction].max)
    value * value
  end

  def square_root_fraction(value, start, stop)
    sqrt_start = Math.sqrt([0.0, start].max)
    sqrt_stop = Math.sqrt([0.0, stop].max)
    (Math.sqrt([0.0, value].max) - sqrt_start) / (sqrt_stop - sqrt_start)
  end

  def inverse_value(fraction, start, stop)
    adjusted_start = inverse_start(start, stop)
    scaled_range = (1.0 / adjusted_start) - (1.0 / stop)
    1.0 / ((1.0 / stop) + (fraction * scaled_range))
  end

  def inverse_fraction(value, start, stop)
    adjusted_start = inverse_start(start, stop)
    scaled_range = (1.0 / adjusted_start) - (1.0 / stop)
    ((1.0 / value) - (1.0 / stop)) / scaled_range
  end

  # An inverse axis cannot reach zero; a range that starts at or below it is
  # pulled up to a tenth of the upper limit.
  def inverse_start(start, stop)
    if start <= 0.0 && stop > 0.0
      stop / 10.0
    else
      start
    end
  end

  # Ported from the Tools namespace of upstream's graphs/utilities.vala.
  module Tools
    module_function

    # Style files write colours as bare six-digit hex ("1A5FB4"), which
    # Gdk.RGBA.parse rejects, so the digits are read here and the alpha
    # channel of an eight-digit colour is honoured.
    def hex_to_rgba(hex)
      digits = hex.to_s.delete_prefix("#")
      channels = digits.scan(/\h\h/).map { |pair| pair.to_i(16) / 255.0 }
      if channels.length < 3
        Gdk::RGBA.new(
          0.0,
          0.0,
          0.0,
          1.0,
        )
      else
        Gdk::RGBA.new(
          channels[0],
          channels[1],
          channels[2],
          channels.fetch(3, 1.0),
        )
      end
    end

    def rgba_to_hex(rgba)
      format(
        "#%02X%02X%02X",
        (rgba.red * 255).to_i,
        (rgba.green * 255).to_i,
        (rgba.blue * 255).to_i,
      )
    end

    def get_luminance_from_hex(hex) = get_luminance_from_rgba(hex_to_rgba(hex))

    def get_luminance_from_rgba(rgba)
      (0.2126 * srgb(rgba.red)) + (0.7152 * srgb(rgba.green)) + (0.0722 * srgb(rgba.blue))
    end

    def srgb(color)
      if color <= 0.03928
        color / 12.92
      else
        ((color + 0.055) / 1.055)**2.4
      end
    end

    def get_contrast(background, foreground)
      [get_luminance_from_rgba(background), get_luminance_from_rgba(foreground)].then do |pair|
        (pair.max + 0.05) / (pair.min + 0.05)
      end
    end

    # "Name" becomes "Name (1)" when taken, and an already numbered name gets
    # the next free number rather than a second suffix.
    def get_duplicate_string(original, used)
      if used.include?(original)
        base = original
        original.match(/\A(?<string>.+) \(\d+\)\z/).then do |info|
          unless info.nil?
            base = info[:string]
          end
        end
        number = 1
        candidate = "#{base} (#{number})"
        while used.include?(candidate)
          number += 1
          candidate = "#{base} (#{number})"
        end
        candidate
      else
        original
      end
    end

    def config_directory
      File.join(
        ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
        "graphs",
      )
    end

    # `file` is usually a Gio::File from a FileDialog result; a plain path
    # string works too, which is what the drive scripts pass.
    def file_path(file) = file.respond_to?(:path) ? file.path : file.to_s

    def get_filename(file) = File.basename(file_path(file))

    # The directory a file lives in, with the home directory abbreviated, as
    # shown under the window title.
    def get_friendly_path(file)
      path = File.dirname(File.expand_path(file_path(file)))
      home = Dir.home
      if path == home
        "~/"
      elsif path.start_with?("#{home}/")
        "~#{path[home.length..]}"
      else
        path
      end
    end

    def open_file_location(file)
      Gtk::FileLauncher.new(Gio::File.new_for_path(file.to_s)).tap do |launcher|
        launcher.open_containing_folder
      end
    end

    def create_file_filter(name, *suffixes)
      Gtk::FileFilter.new.tap do |filter|
        filter.name = name
        suffixes.each { |suffix| filter.add_suffix(suffix) }
      end
    end

    def create_all_filter
      Gtk::FileFilter.new.tap do |filter|
        filter.name = "All Files"
        filter.add_pattern("*")
      end
    end

    def create_file_filters(add_all, *filters)
      Gio::ListStore.new(Gtk::FileFilter.gtype).tap do |store|
        filters.each { |filter| store.append(filter) }
        if add_all
          store.append(create_all_filter)
        end
      end
    end

    # 0 -> A, 26 -> AA, as spreadsheet columns are labelled.
    def int_to_alpha(index)
      result = ""
      number = index + 1
      while number.positive?
        remainder = (number - 1) % 26
        result = ((0x41 + remainder).chr + result)
        number = (number - 1) / 26
      end
      result
    end

    # AA -> 26; -1 for anything that is not alphabetic.
    def alpha_to_int(label)
      index = 0
      invalid = false
      label.each_char do |char|
        unless char.match?(/\A[[:alpha:]]\z/)
          invalid = true
        end
        index = (index * 26) + (char.downcase.ord - 0x61 + 1)
      end
      if invalid
        -1
      else
        index - 1
      end
    end
  end

  # Ported from upstream's graphs/math_utilities.vala, plus the array helpers
  # its C companion (graphs/math_parser/array_evaluator.c and the CUtilities
  # bindings) provides.
  module MathTools
    REL_TOL = 1e-9
    ABS_TOL = 1e-4

    PI_THRESHOLD = 0.00010000314159265359
    E_THRESHOLD = 0.00010000271828182846

    VALIDATION_XDATA = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(&:to_f).freeze

    module_function

    def close?(first, second)
      (first - second).abs <= [REL_TOL * [first.abs, second.abs].max, ABS_TOL].max
    end

    def all_close?(first, second)
      first.length == second.length && first.each_with_index.all? do |value, index|
        close?(value, second[index])
      end
    end

    # A number as the user should read it, recognising whole multiples of pi
    # and e.
    def prettyprint_double(value)
      if value.zero?
        "0"
      else
        sign = ""
        magnitude = value
        if value.negative?
          sign = "-"
          magnitude = -value
        end
        "#{sign}#{prettyprint_magnitude(magnitude)}"
      end
    end

    def prettyprint_magnitude(value)
      pretty_multiple(
        value,
        Math::PI,
        PI_THRESHOLD,
        "pi",
      ) ||
        pretty_multiple(
          value,
          Math::E,
          E_THRESHOLD,
          "e",
        ) ||
        format("%.15g", value)
    end

    def pretty_multiple(value, constant, threshold, name)
      remainder = value.remainder(constant)
      if remainder <= threshold || remainder >= constant - threshold
        factor = ((value / constant) + 0.5).floor
        unless factor.zero?
          if factor == 1
            name
          else
            format("%.15g%s", factor, name)
          end
        end
      end
    end

    def sig_fig_round(number, digits)
      if number.zero?
        0.0
      else
        power = Math.log10(number.abs).floor
        factor = 10.0**(digits - power - 1)
        (number * factor).round / factor
      end
    end

    # Every variable in an equation except x, in the order they appear.
    def get_free_variables(equation)
      lexer = MathParser::Lexer.new
      lexer.start_lexing(equation)
      variables = []
      while lexer.current_type != :end
        if lexer.current_type == :ident && lexer.current_ident == :custom
          token = lexer.current_token_as_string
          unless token == "x" || variables.include?(token)
            variables << token
          end
        end
        lexer.next
      end
      variables
    end

    def arange(steps) = Array.new(steps) { |i| i.to_f }

    # `steps` values spread over the range the way the scale spaces them.
    def equidistant_data(start, stop, scale, steps)
      Array.new(steps) do |i|
        if steps == 1
          Graphs.get_value_at_fraction(
            0.0,
            start,
            stop,
            scale,
          )
        else
          Graphs.get_value_at_fraction(
            i.to_f / (steps - 1),
            start,
            stop,
            scale,
          )
        end
      end
    end

    def finite?(values) = values.all? { |value| value.finite? }

    # Drops the points whose x or y value is not finite.
    def filter_nonfinite(xdata, ydata)
      kept = xdata.each_index.select do |index|
        xdata[index].finite? && (ydata[index]&.finite? || false)
      end
      [kept.map { |index| xdata[index] }, kept.map { |index| ydata[index] }]
    end

    # The smallest and largest value in an array, skipping values a
    # logarithmic or square root axis cannot show. Nil when nothing is left.
    def array_minmax(values, nonzero)
      usable = values.select do |value|
        value.finite? && (!nonzero || value.positive?)
      end
      unless usable.empty?
        [usable.min, usable.max]
      end
    end

    def evaluate_expression(ast, length, variable)
      Graphs.ast_to_program(ast, variable).eval(arange(length))
    end

    def program_to_data(program, xstart, xstop, steps = 5000, scale = :linear)
      xdata = equidistant_data(
        xstart,
        xstop,
        scale,
        steps,
      )
      filter_nonfinite(xdata, program.eval(xdata)).then do |filtered_x, filtered_y|
        DataHolder.new(filtered_x, filtered_y)
      end
    end

    def equation_to_data(equation, xstart, xstop, steps = 5000, scale = :linear)
      program_to_data(
        Graphs.ast_to_program(equation),
        xstart,
        xstop,
        steps,
        scale,
      )
    end

    # Linear interpolation of (x, y) at each target, clamped to the data's
    # range at both ends.
    def interpolate(xdata, ydata, targets)
      point_count = [xdata.length, ydata.length].min
      if point_count.zero?
        Array.new(targets.length, 0.0)
      else
        order = (0...point_count).sort_by { |index| xdata[index] }
        targets.map { |target| interpolate_one(
          xdata,
          ydata,
          order,
          target,
        ) }
      end
    end

    def interpolate_one(xdata, ydata, order, target)
      first = order.first
      last = order.last
      if target <= xdata[first]
        ydata[first]
      elsif target >= xdata[last]
        ydata[last]
      else
        between(
          xdata,
          ydata,
          order,
          target,
        )
      end
    end

    def between(xdata, ydata, order, target)
      low = 0
      high = order.length - 1
      while high - low > 1
        mid = (low + high) / 2
        if xdata[order[mid]] <= target
          low = mid
        else
          high = mid
        end
      end
      lower = order[low]
      upper = order[high]
      slope(
        xdata[lower],
        xdata[upper],
        ydata[lower],
        ydata[upper],
        target,
      )
    end

    def slope(x_lower, x_upper, y_lower, y_upper, target)
      dx = x_upper - x_lower
      if dx.zero?
        y_lower
      else
        y_lower + ((target - x_lower) / dx * (y_upper - y_lower))
      end
    end

    # Whether an expression yields finite values over a sample range — the
    # check the dialogs run before accepting an equation.
    def validate_expression(expression)
      finite?(Graphs.ast_to_program(expression).eval(VALIDATION_XDATA))
    rescue MathError
      false
    end

    def validate_equation(equation)
      validate_expression(Graphs.expression_to_ast(equation))
    rescue MathError
      false
    end
  end
end
