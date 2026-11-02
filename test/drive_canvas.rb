# frozen_string_literal: true

# Exercises the model and the canvas without the window: parser round trips,
# datasets with error bars and markers, a log axis, a text item, and the pan,
# zoom and select drags.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "tmpdir"
require "graphs"

SCRATCH = ENV.fetch("GRAPHS_DRIVE_OUT", Dir.tmpdir)

def check(label, actual, expected)
  if actual == expected
    puts "ok   #{label}: #{actual.inspect}"
  else
    puts "FAIL #{label}: #{actual.inspect} != #{expected.inspect}"
  end
end

# Parser
check("evaluate 2+3*4", Graphs.evaluate_string("2+3*4"), 14.0)
check("evaluate 2**3", Graphs.evaluate_string("2**3"), 8.0)
check("evaluate implicit", Graphs.evaluate_string("2(3+4)"), 14.0)
check("evaluate pi", Graphs.evaluate_string("pi").round(6), Math::PI.round(6))
check("evaluate factorial", Graphs.evaluate_string("4!"), 24.0)
check("evaluate superscript", Graphs.evaluate_string("3²"), 9.0)
check("evaluate stacked sign", Graphs.evaluate_string("2--3"), 5.0)
check("evaluate exponent", Graphs.evaluate_string("1.5e2"), 150.0)
check("print round trip", Graphs.ast_to_expression(Graphs.expression_to_ast("2*x+1")), "2 * x + 1")
check("free variables", Graphs::MathTools.get_free_variables("a*x+b"), %w[a b])
check("validate", Graphs::MathTools.validate_equation("sin(x)"), true)
check("validate bad", Graphs::MathTools.validate_equation("sin("), false)
check("program", Graphs.ast_to_program(Graphs.expression_to_ast("x^2")).eval([1.0, 2.0, 3.0]), [1.0, 4.0, 9.0])
check("prettyprint", Graphs::MathTools.prettyprint_double(2 * Math::PI), "2pi")
check("interpolate", Graphs::MathTools.interpolate([0.0, 1.0], [0.0, 10.0], [0.5]), [5.0])

data = Graphs::Data.new
params = data.selected_style_params

dataset = Graphs::ItemFactory.new_data_item(
  params,
  (0..20).map { |i| i.to_f },
  (0..20).map { |i| (i.to_f**1.5) + 1 },
  Array.new(21, 0.2),
  Array.new(21, 1.0),
)
dataset.name = "Measured"
dataset.markerstyle = 3
text = Graphs::ItemFactory.new_text_item(
  params,
  5.0,
  20.0,
  "Peak",
)
equation = Graphs::ItemFactory.new_equation_item(params, Graphs.expression_to_ast("x^2"))
data.add_items([dataset, text, equation])

check("items", data.n_items, 3)
check("colors differ", data.items.first(2).map(&:color).uniq.length, 2)
check("has errors", dataset.has_xerr? && dataset.has_yerr?, true)
check("downsample", dataset.exceeds_downsample_threshold?, false)
puts "limits: #{data.figure_settings.limits.map { |v| v.round(2) }.inspect}"

# Property change recorded and undone
dataset.name = "Renamed"
data.add_history_state
data.undo
check("undo rename", dataset.name, "Measured")
data.redo
check("redo rename", dataset.name, "Renamed")

# Selection
data.unselect_all
check("none selected", data.none? { |item| item.selected }, true)
data.select_all
check("all selected", data.all? { |item| item.selected }, true)

canvas = Graphs::Canvas.new(data: data)
canvas.build
surface = Cairo::ImageSurface.new(:argb32, 900, 650)
context = Cairo::Context.new(surface)
canvas.send(
  :draw,
  context,
  900,
  650,
)
surface.write_to_png(File.join(SCRATCH, "canvas_dataset.png"))
puts "ok   dataset canvas rendered"

# Drag interactions
before = data.figure_settings.limits
canvas.send(:on_drag_begin, 300.0, 300.0)
canvas.send(:on_drag_update, 60.0, 0.0)
canvas.send(:on_drag_end, 60.0, 0.0)
check("pan moved limits", data.figure_settings.limits != before, true)

canvas.mode = :zoom
canvas.send(:on_drag_begin, 200.0, 200.0)
canvas.send(:on_drag_update, 150.0, 120.0)
canvas.send(:on_drag_end, 150.0, 120.0)
check("zoom narrowed", data.figure_settings.max_bottom - data.figure_settings.min_bottom < 25, true)

canvas.mode = :select
canvas.send(:on_drag_begin, 200.0, 200.0)
canvas.send(:on_drag_end, 300.0, 0.0)
puts "selection: #{[data.figure_settings.min_selected.round(3), data.figure_settings.max_selected.round(3)].inspect}"
check("selection set", data.figure_settings.max_selected > data.figure_settings.min_selected, true)

# Log axis
data.figure_settings.left_scale = :log
data.figure_settings.bottom_scale = :log
data.optimize_limits
canvas.send(
  :draw,
  context,
  900,
  650,
)
surface.write_to_png(File.join(SCRATCH, "canvas_log.png"))
puts "ok   log canvas rendered"
puts "DRIVE OK"
