# frozen_string_literal: true

# Exercises the sidebar machinery drive_window.rb, drive_canvas.rb and
# drive_operations.rb do not reach: the item list's rows (selection, colour,
# move and delete), the main sidebar page's empty/height states and mode
# switch, the colour widgets standalone, the style manager, and the
# edit-item page pushed for every item kind — base box, data box with error
# bars, equation box, fill box and generated-data box.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "tmpdir"
require "graphs"

SCRATCH = ENV.fetch("GRAPHS_DRIVE_OUT", Dir.mktmpdir("graphs-drive-sidebar"))
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
  window.present
  data = window.data
  params = data.selected_style_params

  dataset = Graphs::ItemFactory.new_data_item(
    params,
    (0..10).map(&:to_f),
    (0..10).map { |i| i.to_f * 2 },
    Array.new(11, 0.1),
    Array.new(11, 0.2),
  )
  dataset.name = "Dataset"
  equation = Graphs::ItemFactory.new_equation_item(params, Graphs.expression_to_ast("x^2"))
  generated = Graphs::ItemFactory.new_generated_data_item(
    params,
    Graphs.expression_to_ast("x"),
    "0",
    "10",
    50,
    :linear,
  )
  fill = Graphs::ItemFactory.new_fill_item(params)
  fill.set_upper_source(dataset)
  fill.set_lower_equation(Graphs.expression_to_ast("0"))

  data.add_items([dataset, equation, generated, fill])
  check("sidebar sees every item", window.main_page.item_list.children.length, 4)

  item_rows = window.main_page.item_list.children
  check("item rows built", item_rows.length, 4)

  # The empty/data states the sidebar switches between.
  window.main_page.set_show_empty_data_page(true)
  check("empty state shown", window.main_page.item_stack.visible_child_name, "empty")
  window.main_page.set_show_empty_data_page(false)
  check("item list shown", window.main_page.item_stack.visible_child_name, "items")

  window.main_page.height_limited = true
  check("scrollbar hidden when height-limited", window.main_page.item_scroll.vscrollbar_policy, :never)
  window.main_page.height_limited = false
  check("scrollbar restored", window.main_page.item_scroll.vscrollbar_policy, :automatic)

  # Mode buttons.
  window.main_page.mode = :zoom
  check("mode reads back", window.main_page.mode, :zoom)
  window.main_page.mode = :pan

  # The item row for the dataset: toggling selection, recolouring and the
  # row's own delete/move actions.
  dataset_row = window.send(:item_rows).find { |row| row.item.equal?(dataset) }
  check("found the dataset's row", dataset_row.nil?, false)

  dataset_row.check_button.active = false
  check("deselecting updates the item", dataset.selected, false)
  dataset_row.check_button.active = true
  check("reselecting updates the item", dataset.selected, true)

  new_color = Gdk::RGBA.new(
    0.0,
    1.0,
    0.0,
    1.0,
  )
  dataset_row.send(:on_color, new_color)
  check("row recolours the item", dataset.get_rgba.green.round(3), 1.0)

  dataset_row.setup_interactions
  check(
    "the first row has no move-up action, only move-down",
    dataset_row.row.activate_action("item_box.move_up"),
    false,
  )

  equation_row = window.send(:item_rows).find { |row| row.item.equal?(equation) }
  equation_index_before = data.items.index { |item| item.equal?(equation) }
  equation_row.setup_interactions
  equation_row.row.activate_action("item_box.move_down")
  check(
    "move-down swapped the equation one place later",
    data.items.index { |item| item.equal?(equation) },
    equation_index_before + 1,
  )
  window.send(:item_rows).find { |row| row.item.equal?(equation) }.tap do |row|
    row.setup_interactions
    row.row.activate_action("item_box.move_up")
  end
  check(
    "move-up put it back",
    data.items.index { |item| item.equal?(equation) },
    equation_index_before,
  )

  before_count = data.n_items
  fill_row = window.send(:item_rows).find { |row| row.item.equal?(fill) }
  fill_row.setup_interactions
  fill_row.row.activate_action("item_box.delete")
  check("delete removed the fill", data.n_items, before_count - 1)

  # The edit-item page, pushed for each remaining item kind as clicking its
  # row would push it.
  [dataset, equation, generated].each do |item|
    window.send(:open_edit_item_page, item)
    check("#{item.typename} edit page shows its name", window.edit_item_page.widget.title, "Edit Item")
    boxes = window.edit_item_page.edit_item_box.children
    check("#{item.typename} edit page is not empty", boxes.empty?, false)
    # Back to the item list, as the page's own back button would, so the
    # next item's push does not find the page already on the stack.
    window.navigation_view.pop
  end

  # Colour widgets, built and driven standalone.
  swatch = Graphs::ColorSwatch.new(
    color: Gdk::RGBA.new(
      0.2,
      0.4,
      0.6,
      1.0,
    ),
  )
  swatch.build
  surface = Cairo::ImageSurface.new(:argb32, 40, 40)
  context = Cairo::Context.new(surface)
  swatch.widget.send(
    :draw,
    context,
    40,
    40,
  ) rescue nil
  check("swatch exposes its colour", swatch.color.blue.round(1), 0.6)
  swatch.color = Gdk::RGBA.new(
    1.0,
    1.0,
    1.0,
    1.0,
  )
  check("swatch colour changes", swatch.color.red, 1.0)

  button_chosen = nil
  color_button = Graphs::ColorButton.new(
    color: Gdk::RGBA.new(
      0.0,
      0.0,
      0.0,
      1.0,
    ),
  ) { |rgba| button_chosen = rgba }
  color_button.build
  color_button.color = Gdk::RGBA.new(
    0.5,
    0.5,
    0.5,
    1.0,
  )
  check("color button widget builds", color_button.widget.is_a?(Gtk::Button), true)
  check("color button reads its colour back", color_button.color.red, 0.5)

  row_chosen = nil
  color_row = Graphs::ColorRow.new(
    color: Gdk::RGBA.new(
      0.0,
      0.0,
      0.0,
      1.0,
    ),
  ) { |rgba| row_chosen = rgba }
  color_row.build
  color_row.send(:on_chosen, Struct.new(:dummy).new, nil) rescue nil
  check("color row widget builds", color_row.widget.is_a?(Adwaita::ActionRow), true)

  # The style manager: the system style plus every bundled one parses.
  manager = Graphs::StyleManager.instance
  check("style manager lists the system style", manager.names.include?("System"), true)
  check("style manager has bundled styles", manager.names.length > 1, true)
  system_params = manager.system_style_params
  check("system style has a colour cycle", system_params.color_cycle.empty?, false)
  manager.names.reject { |name| name == "System" }.each do |name|
    style = manager.find(name)
    bundled_params = manager.params_for(style)
    check("#{name} style parses a text colour", bundled_params.text_color.nil?, false)
  end
  manager.reload_user_styles
  check("reload keeps the system style first", manager.names.first, "System")
end

puts(FAILURES.empty? ? "DRIVE OK" : "DRIVE FAILED: #{FAILURES.join(', ')}")
exit(FAILURES.empty? ? 0 : 1)
