# frozen_string_literal: true

# Exercises the operations, the fill item and the dialogs that were added
# alongside them: the array maths against values worked out by hand, the
# symbolic rewrites through the printer, every operation on a dataset and on an
# equation, a fill following a dataset, the data and figure exports, and the
# construction of each new widget inside a built window.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "tmpdir"
require "graphs"

SCRATCH = ENV.fetch("GRAPHS_DRIVE_OUT", Dir.mktmpdir("graphs-drive"))
ENV["XDG_CONFIG_HOME"] = File.join(SCRATCH, "config")

FAILURES = []

def check(label, actual, expected)
  if actual == expected
    puts "ok   #{label}: #{actual.inspect}"
  else
    FAILURES << label
    puts "FAIL #{label}: #{actual.inspect} != #{expected.inspect}"
  end
end

def close_enough(label, actual, expected, tolerance = 1e-6)
  check(label, (actual - expected).abs < tolerance, true)
end

# Numerics
include Graphs

check("mean", Numerics.mean([1.0, 2.0, 3.0]), 2.0)
check("median even", Numerics.median([1.0, 2.0, 3.0, 4.0]), 2.5)
close_enough("standard deviation", Numerics.standard_deviation([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]), 2.0)
check(
  "gradient of a line",
  Numerics.gradient([0.0, 2.0, 4.0, 6.0], [0.0, 1.0, 2.0, 3.0]),
  [2.0, 2.0, 2.0, 2.0],
)
check(
  "cumulative trapezoid",
  Numerics.cumulative_trapezoid([1.0, 1.0, 1.0], [0.0, 1.0, 2.0]),
  [0.0, 1.0, 2.0],
)
check(
  "moving average of a constant",
  Numerics.moving_average([2.0, 2.0, 2.0, 2.0, 2.0], 3).map { |value| value.round(6) }[1..3],
  [2.0, 2.0, 2.0],
)
# A Savitzky-Golay filter of a polynomial of the same degree returns it
# unchanged, which is the property scipy's filter has.
LINE = (0..20).map { |index| (3.0 * index) + 1 }
check(
  "savgol keeps a line",
  Numerics.savgol_filter(LINE, 5, 2).map { |value| value.round(6) },
  LINE.map { |value| value.round(6) },
)
check(
  "fourier transform of a constant",
  Numerics.fourier_transform([1.0, 1.0, 1.0, 1.0], false).map { |value| value.real.round(6) },
  [4.0, 0.0, 0.0, 0.0],
)
check(
  "transform of an impulse",
  Numerics.fourier_transform([1.0, 0.0, 0.0, 0.0], false).map { |value| value.real.round(6) },
  [1.0, 1.0, 1.0, 1.0],
)
check(
  "inverse transform of a constant",
  Numerics.fourier_transform([1.0, 1.0, 1.0, 1.0], true).map { |value| value.real.round(6) },
  [1.0, 0.0, 0.0, 0.0],
)
# Six splits into sub-transforms, five does not; both have to agree with the
# definition of the transform.
[5, 6].each do |length|
  values = (0...length).map { |index| (index + 1).to_f }
  expected = (0...length).map do |frequency|
    (0...length).sum do |index|
      values[index] * Complex.polar(1, -2 * Math::PI * frequency * index / length)
    end
  end
  check(
    "transform of #{length} values",
    Numerics.fourier_transform(values, false).map { |value| value.real.round(6) },
    expected.map { |value| value.real.round(6) },
  )
end
check("fftfreq", Numerics.fftfreq(4, 1.0), [0.0, 0.25, -0.5, -0.25])

# Symbolic
def printed(root) = Graphs.ast_to_expression(MathParser::Ast.new(root))

check(
  "substitute x",
  printed(Symbolic.substitute(Graphs.expression_to_ast("x^2").root, "x", Graphs.expression_to_ast("x+1").root)),
  "(x + 1)^2",
)
check(
  "derivative of x squared",
  Graphs.ast_to_program(
    MathParser::Ast.new(Symbolic.differentiate(Graphs.expression_to_ast("x^2").root, "x")),
  ).eval([3.0]).map { |value| value.round(6) },
  [6.0],
)
check(
  "derivative of sin",
  Graphs.ast_to_program(
    MathParser::Ast.new(Symbolic.differentiate(Graphs.expression_to_ast("sin(x)").root, "x")),
  ).eval([0.0]).map { |value| value.round(6) },
  [1.0],
)
check(
  "derivative of sind in degrees",
  Graphs.ast_to_program(
    MathParser::Ast.new(Symbolic.differentiate(Graphs.expression_to_ast("sind(x)").root, "x")),
  ).eval([0.0]).map { |value| value.round(8) },
  [0.01745329],
)
check(
  "two variable evaluation",
  Symbolic.evaluate(Graphs.expression_to_ast("x*y").root, { "x" => 3.0, "y" => 4.0 }),
  12.0,
)

# Operations on a dataset
def dataset(data)
  Graphs::ItemFactory.new_data_item(
    data.selected_style_params,
    (0..10).map { |index| index.to_f },
    (0..10).map { |index| index.to_f * 2 },
  )
end

data = Graphs::Data.new
item = dataset(data)
data.add_items([item])

check(
  "translate x",
  Graphs::DataOperations.execute(
    item,
    "translate_x",
    data.figure_settings,
    :pan,
    5.0,
  ).first,
  true,
)
check("translated xdata", item.xdata.first, 5.0)
check(
  "multiply y",
  Graphs::DataOperations.execute(
    item,
    "multiply_y",
    data.figure_settings,
    :pan,
    2.0,
  ).first,
  true,
)
check("multiplied ydata", item.ydata.last, 40.0)
check(
  "normalize",
  Graphs::DataOperations.execute(
    item,
    "normalize",
    data.figure_settings,
    :pan,
  ).first,
  true,
)
check("normalized maximum", item.ydata.max, 1.0)
check(
  "derivative",
  Graphs::DataOperations.execute(
    item,
    "derivative",
    data.figure_settings,
    :pan,
  ).first,
  true,
)
check(
  "integral",
  Graphs::DataOperations.execute(
    item,
    "integral",
    data.figure_settings,
    :pan,
  ).first,
  true,
)
check(
  "smoothen",
  Graphs::DataOperations.execute(
    item,
    "smoothen",
    data.figure_settings,
    :pan,
    0,
    Graphs::Settings.default.child("smoothen"),
  ).first,
  true,
)
check(
  "fft",
  Graphs::DataOperations.execute(
    item,
    "fft",
    data.figure_settings,
    :pan,
  ).first,
  true,
)
check(
  "centered",
  Graphs::DataOperations.execute(
    item,
    "center",
    data.figure_settings,
    :pan,
    1,
  ).first,
  true,
)
check(
  "custom transformation",
  Graphs::DataOperations.execute(
    item,
    "transform",
    data.figure_settings,
    :pan,
    "x",
    "y*2",
    false,
  ).first,
  true,
)
check(
  "unknown operation refused",
  Graphs::DataOperations.execute(
    item,
    "nonsense",
    data.figure_settings,
    :pan,
  ),
  [false, Graphs::DataOperations::UNSUPPORTED_MESSAGE],
)

# A cut keeps what lies outside the selection.
cut_data = Graphs::Data.new
cut_item = dataset(cut_data)
cut_data.add_items([cut_item])
cut_data.figure_settings.set_limits([0.0, 10.0, 0.0, 20.0, 0.0, 1.0, 0.0, 10.0])
cut_data.figure_settings.set_selection_range(0.0, 0.5)
check(
  "cut inside a selection",
  Graphs::DataOperations.execute(
    cut_item,
    "cut",
    cut_data.figure_settings,
    :select,
  ).first,
  true,
)
check("cut kept the tail", cut_item.xdata.first, 6.0)

# Operations on an equation
equation_data = Graphs::Data.new
equation_item = Graphs::ItemFactory.new_equation_item(
  equation_data.selected_style_params,
  Graphs.expression_to_ast("x^2"),
)
equation_data.add_items([equation_item])

check(
  "equation translate y",
  Graphs::EquationOperations.execute(
    equation_item,
    "translate_y",
    equation_data.figure_settings,
    :pan,
    3.0,
  ).first,
  true,
)
check("equation translated", equation_item.equation_string, "x^2 + 3")
check(
  "equation derivative",
  Graphs::EquationOperations.execute(
    equation_item,
    "derivative",
    equation_data.figure_settings,
    :pan,
  ).first,
  true,
)
check(
  "equation integral is refused",
  Graphs::EquationOperations.execute(
    equation_item,
    "integral",
    equation_data.figure_settings,
    :pan,
  ),
  [false, Graphs::EquationOperations::UNSUPPORTED_MESSAGE],
)

# Fill item
fill_data = Graphs::Data.new
source = dataset(fill_data)
source.name = "Source"
fill_data.add_items([source])
fill = Graphs::ItemFactory.new_fill_item(fill_data.selected_style_params)
fill.set_upper_source(source)
fill.set_lower_equation(Graphs.expression_to_ast("0"))
fill_data.add_items([fill])

check("fill follows the source", fill.data.xdata, source.xdata)
check("fill upper equals the source", fill.data.upper, source.ydata)
check("fill lower is zero", fill.data.lower.uniq, [0.0])
check("fill is not view based", fill.view_based?, false)
check("fill typename", fill.typename, "Fill")
check("fill alpha", fill.alpha, 0.4)
check("source has a dependent", source.get_dependents.length, 1)

view_fill = Graphs::ItemFactory.new_fill_item(fill_data.selected_style_params)
view_fill.set_upper_equation(Graphs.expression_to_ast("inf"))
view_fill.set_lower_equation(Graphs.expression_to_ast("x"))
check("equation fill is view based", view_fill.view_based?, true)
check(
  "view fill bounds",
  view_fill.evaluate_bounds([1.0, 2.0]),
  [[1.0, 2.0], [Float::INFINITY, Float::INFINITY]],
)

check(
  "fill bound model",
  Graphs::FillBounds.create_model(Graphs::FillBounds.get_source_items(fill_data)).n_items,
  4,
)
check(
  "fill bound selection",
  Graphs::FillBounds.get_selection(
    :equation,
    nil,
    Graphs.expression_to_ast("-inf"),
    [],
  ),
  Graphs::FillBoundSelection::NEG_INF,
)

serialized = Graphs::ItemFactory.to_dict(fill)
check("fill serializes its type", serialized[:type], "FillItem")
check("fill serializes its lower bound", serialized[:lower_equation], "0")
restored = Graphs::ItemFactory.new_from_dict(serialized)
check("fill round trips", restored.data.lower.uniq, [0.0])
linked = Graphs::ItemFactory.link_dependencies(fill, serialized.dup, [source, fill])
check("fill links its source", linked[:upper_source], 0)
Graphs::ItemFactory.resolve_dependencies(restored, linked, [source, restored])
check("fill resolves its source", restored.get_upper_source.equal?(source), true)

# Deleting the source deletes the fill with it.
fill_data.delete_items([source])
check("deleting the source removed the fill", fill_data.n_items, 0)

# Exports
export_data = Graphs::Data.new
export_item = dataset(export_data)
export_item.xlabel = "X"
export_item.ylabel = "Y"
export_data.add_items([export_item])
columns = Graphs::Export.columns(export_item, export_item.data)
check("export header", columns.lines.first.strip.split("\t"), %w[X Y])
check("export rows", columns.lines.length, 12)

# Widgets, inside a real window
class DriveApplication < Graphs::Application
  def run_checks(&block)
    app.signal_connect("activate") do
      block.call(create_main_window)
      app.quit
    end
    app.run([])
  end
end

DriveApplication.new.run_checks do |window|
  # create_main_window already calls window.build; building it again here
  # double-appended every child widget and tripped GTK/Adwaita's
  # "parent == NULL" assertions on every run.
  window.present

  check("window has an operations panel", window.main_page.operations.widget.is_a?(Gtk::Box), true)
  check("operations stack pages", window.main_page.operations.stack.pages.n_items, 3)
  check(
    "perform-operation action",
    window.window.lookup_action("perform-operation").nil?,
    false,
  )
  check("center action state", window.window.lookup_action("center").state, "middle-x")
  window.window.lookup_action("center").activate("max-y")
  check("center action remembers", Graphs::Settings.default.child("actions")["center"], "max-y")
  check("cut starts insensitive", window.main_page.operations.button("cut").sensitive?, false)

  window.data.add_items([dataset(window.data)])
  check("shift is sensitive with a selection", window.main_page.operations.shift_button.sensitive?, true)
  check("entry value", window.operation_value("translate_x"), 10.0)

  # A full operation through the action, as the button triggers it.
  window.window.lookup_action("perform-operation").activate("translate_x")
  check("operation through the action", window.data.get_item(0).xdata.first, 10.0)

  [
    Graphs::TransformDialog.new(window: window),
    Graphs::SmoothenDialog.new(window: window),
    Graphs::GenerateDataDialog.new(window: window),
    Graphs::AddFillDialog.new(window: window),
    Graphs::ExportFigureDialog.new(window: window),
  ].each do |dialog|
    dialog.build
    check("#{dialog.class.name.split('::').last} builds", dialog.dialog.is_a?(Adwaita::Dialog), true)
  end

  Graphs::AlertDialogs::DIALOGS.each_key do |name|
    check("#{name} alert builds", Graphs::AlertDialogs.build(name).is_a?(Adwaita::AlertDialog), true)
  end

  # Curve fitting: fit the default linear preset against a y = 2x dataset,
  # then confirm it and check the fitted curve and its confidence band both
  # landed in the figure.
  fit_item = dataset(window.data)
  window.data.add_items([fit_item])
  before_count = window.data.n_items
  curve_dialog = Graphs::CurveFittingDialog.new(window: window, item: fit_item)
  curve_dialog.build
  check("curve fitting dialog builds", curve_dialog.dialog.is_a?(Adwaita::Dialog), true)
  curve_dialog.fit_button.signal_emit("clicked")
  check("curve fit confirm enabled", curve_dialog.confirm_button.sensitive?, true)
  close_enough("curve fit slope", curve_dialog.fit_result.parameters[0], 2.0)
  close_enough("curve fit intercept", curve_dialog.fit_result.parameters[1], 0.0)
  curve_dialog.confirm_button.signal_emit("clicked")
  check("curve fit added two items", window.data.n_items, before_count + 2)
  check(
    "curve fit item is an equation",
    window.data.get_item(before_count).is_a?(Graphs::EquationItem),
    true,
  )
  check(
    "confidence band item is a fill",
    window.data.get_item(before_count + 1).is_a?(Graphs::FillItem),
    true,
  )
  # Leaves the item count as later checks expect it.
  window.data.delete_items(window.data.items[before_count - 1..])

  # A fill of each kind in the figure, so the canvas draws both paths as the
  # figure is exported.
  Graphs::ItemFactory.new_fill_item(window.data.selected_style_params).tap do |following|
    following.set_upper_source(window.data.get_item(0))
    following.set_lower_equation(Graphs.expression_to_ast("0"))
    window.data.add_items([following])
  end
  Graphs::ItemFactory.new_fill_item(window.data.selected_style_params).tap do |sampled|
    sampled.set_upper_equation(Graphs.expression_to_ast("inf"))
    sampled.set_lower_equation(Graphs.expression_to_ast("x"))
    sampled.legend = true
    window.data.add_items([sampled])
  end
  check("figure holds both fills", window.data.n_items, 3)

  # The figure written to every format the export dialog offers.
  exporter = Graphs::ExportFigureDialog.new(window: window)
  exporter.build
  Graphs::ExportFigureDialog::FORMATS.each_key do |suffix|
    exporter.format_row.selected = Graphs::ExportFigureDialog::FORMATS.keys.index(suffix)
    File.join(SCRATCH, "figure.#{suffix}").then do |path|
      exporter.send(:write_figure, path)
      check("exported #{suffix}", File.size(path).positive?, true)
    end
  end

  # The data export, written without the file dialog.
  File.join(SCRATCH, "export.txt").then do |path|
    Graphs::Export.save_item_as_columns(
      window.data.get_item(0),
      Gio::File.new_for_path(path),
      window.data.figure_settings,
    )
    check("exported data", File.read(path).lines.length.positive?, true)
  end
end

# Ported from upstream's tests/test_operations.py: the same fixed XDATA/YDATA
# arrays, run through DataOperations.callback (which stands in for upstream's
# per-operation static methods, since this port dispatches by name rather
# than exposing one method per operation) and checked against the same
# properties the upstream tests assert.
PROP_XDATA = [0.0, 1.0, 4.0, 5.0, 7.0, 8.0, 12.0, 3.0].freeze
PROP_YDATA = [5.0, 2.0, 7.0, 1.0, 31.0, 5.0, 123.0, 156.0].freeze

def op(name, xdata, ydata, *args)
  Graphs::DataOperations.callback(nil, name, xdata, ydata, args)
end

# test_normalize: normalize scales ydata to a maximum value of 1.
_, normalized_y, = op("normalize", PROP_XDATA, PROP_YDATA)
check("normalize scales to a maximum of 1", normalized_y.max, 1.0)

# test_translate_x: translate_x shifts all x values by the given offset.
translated_x, = op("translate_x", PROP_XDATA, PROP_YDATA, 15.0)
check(
  "translate_x shifts every x value by the offset",
  translated_x,
  PROP_XDATA.map { |x| x + 15.0 },
)

# test_translate_y: translate_y shifts all y values by the given offset.
_, translated_y, = op("translate_y", PROP_XDATA, PROP_YDATA, 15.0)
check(
  "translate_y shifts every y value by the offset",
  translated_y,
  PROP_YDATA.map { |y| y + 15.0 },
)

# test_multiply_x: multiply_x scales all x values by the given multiplier.
multiplied_x, = op("multiply_x", PROP_XDATA, PROP_YDATA, 15.0)
check(
  "multiply_x scales every x value by the multiplier",
  multiplied_x,
  PROP_XDATA.map { |x| x * 15.0 },
)

# test_multiply_y: multiply_y scales all y values by the given multiplier.
_, multiplied_y, = op("multiply_y", PROP_XDATA, PROP_YDATA, 15.0)
check(
  "multiply_y scales every y value by the multiplier",
  multiplied_y,
  PROP_YDATA.map { |y| y * 15.0 },
)

# test_center_at_maximum: center mode 0 places the x of the maximum y at zero.
centered_on_max_x, = op("center", PROP_XDATA, PROP_YDATA, 0)
max_y_index = PROP_YDATA.each_index.max_by { |index| PROP_YDATA[index] }
check("center at maximum puts that x at zero", centered_on_max_x[max_y_index], 0.0)

# test_center_at_middle: center mode 1 places the midpoint of the x range at zero.
centered_on_middle_x, = op("center", PROP_XDATA, PROP_YDATA, 1)
middle_value = (PROP_XDATA.min + PROP_XDATA.max) / 2.0
check(
  "center at middle shifts every x by the midpoint",
  centered_on_middle_x,
  PROP_XDATA.map { |x| x - middle_value },
)

# test_derivative: derivative returns the correct gradient at each point.
derivative_x = [1.0, 2.0, 3.0, 4.0, 5.0]
derivative_y = [5.0, 10.0, 15.0, 10.0, 5.0]
_, derivative_result, = op("derivative", derivative_x, derivative_y)
check("derivative keeps the input length", derivative_result.length, derivative_x.length)
derivative_result.zip([5.0, 5.0, 0.0, -5.0, -5.0]).each_with_index do |(actual, expected), index|
  close_enough("derivative value at index #{index}", actual, expected)
end

# test_integral: integral returns the correct cumulative area at each point.
integral_x = [1.0, 2.0, 3.0, 4.0, 5.0]
integral_y = [5.0, 10.0, 15.0, 10.0, 5.0]
_, integral_result, = op("integral", integral_x, integral_y)
check("integral keeps the input length", integral_result.length, integral_x.length)
integral_result.zip([0.0, 7.5, 20.0, 32.5, 40.0]).each_with_index do |(actual, expected), index|
  close_enough("integral value at index #{index}", actual, expected)
end

# test_cut_returns_none: cut hands back no x and y lists.
cut_x, cut_y, = op("cut", PROP_XDATA, PROP_YDATA)
check("cut returns no xdata", cut_x, nil)
check("cut returns no ydata", cut_y, nil)

# test_fft_output_length / test_inverse_fft_output_length: both transforms
# return arrays of the same length as the input.
fft_x = (0...8).map(&:to_f)
fft_y = [0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0, -1.0]
fft_new_x, fft_new_y, = op("fft", fft_x, fft_y)
check("fft keeps the x length", fft_new_x.length, fft_x.length)
check("fft keeps the y length", fft_new_y.length, fft_y.length)
inverse_new_x, inverse_new_y, = op("inverse_fft", fft_x, fft_y)
check("inverse_fft keeps the x length", inverse_new_x.length, fft_x.length)
check("inverse_fft keeps the y length", inverse_new_y.length, fft_y.length)

puts(FAILURES.empty? ? "DRIVE OK" : "DRIVE FAILED: #{FAILURES.join(', ')}")
exit(FAILURES.empty? ? 0 : 1)
