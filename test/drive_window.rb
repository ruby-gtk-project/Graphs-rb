# frozen_string_literal: true

# Boots the app headlessly, adds an equation item through the model, and
# checks the window, the sidebar rows, the canvas and the project file
# round trip come up.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "graphs"
require "tmpdir"

SCRATCH = ENV.fetch("GRAPHS_DRIVE_OUT", Dir.tmpdir)
FAILURES = []

def check(label, actual, expected)
  if actual == expected
    puts "ok   #{label}: #{actual.inspect}"
  else
    FAILURES << label
    puts "FAIL #{label}: #{actual.inspect} != #{expected.inspect}"
  end
end

app = Graphs::Application.new
app.build

app.app.signal_connect("activate") do
  window = app.windows.first
  data = window.data

  check("window title", window.window.title, "Graphs — Untitled Project")
  check("style present", data.selected_style_params.name.nil?, false)

  item = Graphs::ItemFactory.new_equation_item(
    data.selected_style_params,
    Graphs.expression_to_ast("sin(x)"),
  )
  data.add_items([item])
  check("items after add", data.n_items, 1)
  check("item name", item.name, "Y = sin(x)")
  check("rows built", window.main_page.item_list.children.length, 1)
  check("can_undo after add", data.can_undo, true)

  data.undo
  check("items after undo", data.n_items, 0)
  check("can_redo after undo", data.can_redo, true)
  data.redo
  check("items after redo", data.n_items, 1)

  # Zoom reads the size the last draw established; nothing has drawn yet in
  # this headless run, so a throwaway draw stands in for the first frame.
  warmup_surface = Cairo::ImageSurface.new(:argb32, 800, 600)
  window.canvas.send(
    :draw,
    Cairo::Context.new(warmup_surface),
    800,
    600,
  )

  before_limits = data.figure_settings.limits
  window.canvas.zoom_in
  check("zoom changed limits", data.figure_settings.limits != before_limits, true)
  check("can_view_back after zoom", data.can_view_back, true)

  Graphs::AddEquationDialog.new(window: window).tap do |dialog|
    dialog.build
    check("add-equation dialog built", dialog.confirm_button.nil?, false)
  end

  check("shortcuts dialog built", Graphs::ShortcutsDialog.new.build.nil?, false)

  # Render the canvas into an image surface to prove the draw path runs.
  surface = Cairo::ImageSurface.new(:argb32, 800, 600)
  context = Cairo::Context.new(surface)
  window.canvas.send(
    :draw,
    context,
    800,
    600,
  )
  surface.write_to_png(File.join(SCRATCH, "window_canvas.png"))
  puts "ok   canvas rendered"

  # Project save/load round trip.
  path = File.join(SCRATCH, "drive_window.graphs")
  data.save(path)
  check("saved project has a file", data.file.nil?, false)
  check("saved project is clean", data.unsaved, false)

  reloaded = Graphs::Data.new
  reloaded.load(path)
  check("reloaded item count", reloaded.n_items, data.n_items)
  check("reloaded item name", reloaded.last.name, item.name)
  check(
    "reloaded limits",
    reloaded.figure_settings.limits.map { |v| v.round(6) },
    data.figure_settings.limits.map { |v| v.round(6) },
  )

  data.undo
  reloaded.undo
  check("reloaded undo matches", reloaded.n_items, data.n_items)

  GLib::Timeout.add(200) do
    app.app.quit
    false
  end
end

app.run([])
if FAILURES.empty?
  puts "DRIVE OK"
else
  puts "DRIVE FAILED: #{FAILURES.inspect}"
  exit 1
end
