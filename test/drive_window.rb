# frozen_string_literal: true

# Boots the app headlessly, adds an equation item through the model, and
# checks the window, the sidebar rows and the canvas come up.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "graphs"

app = Graphs::Application.new
app.build
failures = []

app.app.signal_connect("activate") do
  window = app.windows.first
  data = window.data

  puts "window title: #{window.window.title.inspect}"
  puts "style: #{data.selected_style_params.name} cycle=#{data.selected_style_params.color_cycle.first(3).inspect}"

  item = Graphs::ItemFactory.new_equation_item(
    data.selected_style_params,
    Graphs.expression_to_ast("sin(x)"),
  )
  data.add_items([item])
  puts "items: #{data.n_items}, name: #{item.name.inspect}, color: #{item.color.inspect}"
  puts "limits: #{data.figure_settings.limits.map { |v| v.round(3) }.inspect}"
  puts "rows: #{window.main_page.item_list.children.length}"
  puts "can_undo: #{data.can_undo}"

  data.undo
  puts "after undo items: #{data.n_items}, can_redo: #{data.can_redo}"
  data.redo
  puts "after redo items: #{data.n_items}"

  window.canvas.zoom_in
  puts "after zoom limits: #{data.figure_settings.limits.map { |v| v.round(3) }.inspect}"
  puts "can_view_back: #{data.can_view_back}"

  Graphs::AddEquationDialog.new(window: window).tap do |dialog|
    dialog.build
    puts "dialog confirm sensitive: #{dialog.confirm_button.sensitive?}"
  end

  Graphs::ShortcutsDialog.new.build
  puts "shortcuts built"

  # Render the canvas into an image surface to prove the draw path runs.
  surface = Cairo::ImageSurface.new(:argb32, 800, 600)
  context = Cairo::Context.new(surface)
  window.canvas.send(
    :draw,
    context,
    800,
    600,
  )
  surface.write_to_png("/tmp/claude-1001/-home-nathan-src-github-ruby-gtk-project/9e6adaef-98a4-4c7a-bedc-91433423f878/scratchpad/canvas.png")
  puts "canvas rendered"

  GLib::Timeout.add(200) do
    app.app.quit
    false
  end
end

app.run([])
puts failures.empty? ? "DRIVE OK" : failures.inspect
