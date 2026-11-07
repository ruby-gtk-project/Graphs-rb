# frozen_string_literal: true

# Exercises the style editor the other drive scripts never open: its own
# window (the style grid and the editor form beside a live preview), the
# colour-group rows a style's colour cycle is built from, the "Create
# Style…" dialog and the keyboard-shortcuts dialog.
#
# Nothing else drives lib/style_editor/*.rb, so a port that builds cleanly
# here is the first proof any of it has ever actually run.
#
# Ordering note: everything that touches the style grid (opening the style
# editor, which builds it once, and closing back to it, which rebuilds it
# a second time) is kept to the END of this script, with nothing allocation-
# heavy run afterwards. Gtk::FlowBox#remove_all repopulated with
# Gtk::DrawingArea-backed tiles (StylePreview), combined with a second such
# rebuild and enough subsequent Ruby allocation to trigger a GC pass before
# the pending frame tick for the destroyed tiles fires, reproducibly
# segfaults — confirmed with no Graphs-rb code involved at all (see
# .reports/style-editor-flowbox-drawingarea-gc.md). That is a ruby-gnome/
# GTK4 binding gap, not a port bug, so the grid rebuild is driven exactly
# once here (what closing the editor does) and nothing else runs after it.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "tmpdir"
require "graphs"

SCRATCH = ENV.fetch("GRAPHS_DRIVE_OUT", Dir.mktmpdir("graphs-drive-style-editor"))
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

app = Graphs::Application.new
app.build

app.app.signal_connect("activate") do
  style_manager = Graphs::StyleManager.instance

  check(
    "style editor shortcuts dialog builds",
    Graphs::StyleEditor::ShortcutsDialog.new.build.nil?,
    false,
  )

  # ColorGroup: the colour-cycle list a style's line colours and error-bar
  # colours are built from — add, recolour, reorder and remove a row. None
  # of this is attached to a shown window, so none of it is realised.
  changes = []
  group = Graphs::StyleEditor::ColorGroup.new { |colors| changes << colors }
  group.build
  check("color group starts with one swatch", group.colors, ["#000000"])

  group.colors = %w[ff0000 00ff00 0000ff]
  check("color group loaded three colours", group.colors, %w[ff0000 00ff00 0000ff])
  check("color box built a row per colour", group.send(:color_box).children.length, 3)

  group.send(:on_color_changed, 1, "123456")
  check("recolouring a row updates its colour", group.colors[1], "123456")
  check("recolouring notifies the callback", changes.last[1], "123456")

  group.send(:on_move, 0, 1)
  check("moving a row reorders the list", group.colors, %w[123456 ff0000 0000ff])

  group.send(:on_remove, 0)
  check("removing a row shrinks the list", group.colors, %w[ff0000 0000ff])

  group.send(:on_remove, 0)
  group.send(:on_remove, 0)
  check("removing every row leaves the default black swatch", group.colors, ["#000000"])

  # ItemColorRow: one row of a ColorGroup, standalone.
  row_changes = []
  row = Graphs::StyleEditor::ItemColorRow.new(
    index:            0,
    color:            "ff00ff",
    can_move_up:      false,
    can_move_down:    true,
    on_color_changed: ->(index, color) { row_changes << [index, color] },
    on_move:          ->(*) {},
    on_remove:        ->(*) {},
  )
  row.build
  check("item color row builds", row.widget.nil?, false)
  check("item color row move-up disabled at the top", row.send(:move_up_button).sensitive?, false)
  check("item color row move-down enabled", row.send(:move_down_button).sensitive?, true)
  # ColorButton reports a chosen colour through the block it was built with
  # (item_color_row.rb's); invoke that block directly, the way GTK would once
  # the colour chooser dialog returned a result.
  color_button_callback = row.send(:color_button).instance_variable_get(:@on_color_chosen)
  color_button_callback.call(Graphs::Tools.hex_to_rgba("abcdef"))
  check("item color row reports colour changes", row_changes, [[0, "ABCDEF"]])

  # The style editor window: grid, editor form, save/close.
  window = app.open_style_editor
  check("style editor window built", window.nil?, false)
  check("style editor title", window.send(:window).title, "Graphs Style Editor")
  check("grid page shown first", window.send(:stack).visible_child_name, "grid")

  flow_box = window.send(:flow_box)
  check("grid has a tile per style", flow_box.children.length, style_manager.styles.length)

  # A bundled style (not the system one) is the one with an actual file to
  # load and to save back.
  bundled = style_manager.styles.find { |s| !s.system? && !s.mutable? }
  check("found a bundled style to load", bundled.nil?, false)

  window.send(:load, bundled.file)
  check("editor page shown after load", window.send(:stack).visible_child_name, "editor")
  check("window title follows the loaded style", window.send(:window).title, "Graphs Style Editor — #{bundled.name}")
  check("editor box parsed parameters", window.send(:editor_box).parameters.nil?, false)
  check("save disabled right after load", window.send(:save_action).enabled?, false)

  editor_box = window.send(:editor_box)

  # Editing a field should mark the style dirty and retitle the window —
  # on_params_changed wires EditorBox back into the window.
  editor_box.send(:style_name_row).text = "Drive Test Style"
  check("edit marks the style unsaved", window.send(:save_action).enabled?, true)
  check("window title follows the edit", window.send(:window).title, "Graphs Style Editor — Drive Test Style")
  check("parameters reflect the rename", editor_box.parameters.name, "Drive Test Style")

  # Save-as, without a real file chooser: point @file at a scratch path the
  # way the save dialog's callback would, then drive the same save the menu
  # action calls.
  saved_path = File.join(SCRATCH, "Drive-Test-Style.mplstyle")
  window.instance_variable_set(:@file, saved_path)
  window.send(:save)
  check("save wrote the style file", File.exist?(saved_path), true)
  check("save clears the unsaved flag", window.send(:save_action).enabled?, false)

  reloaded_params, reloaded_graphs_params = Graphs::StyleIO.parse(saved_path)
  check("saved style keeps its name", reloaded_graphs_params["name"], "Drive Test Style")
  check("saved style keeps its parsed params", reloaded_params.key?("lines.linestyle"), true)

  # Close-request with unsaved changes should hold the window open behind a
  # confirmation instead of destroying it outright — check this before the
  # clean close below, which is the one real grid rebuild this script does.
  editor_box.send(:style_name_row).text = "Unsaved Rename"
  check("close-request with unsaved changes blocks the close", window.send(:on_close_request), true)

  # The style-manager side of "Create Style…": the dialog builds, and the
  # manager call it delegates to writes a real user style and lists it.
  create_dialog_built = begin
    Graphs::StyleEditor::AddStyleDialog.new(parent: window.send(:window), style_manager: style_manager) {}
    true
  rescue StandardError
    false
  end
  check("AddStyleDialog builds", create_dialog_built, true)

  before_names = style_manager.names.dup
  created_file = style_manager.create_style(1, "Drive Created Style")
  check("create-style wrote a user style", File.exist?(created_file.path), true)
  style_manager.reload_user_styles
  check("create-style adds to the style list", style_manager.names.length > before_names.length, true)
  check("new style is mutable", style_manager.find("Drive Created Style").mutable?, true)

  # Discard the unsaved rename and close back to the grid — the one place
  # this script rebuilds the grid a second time, so it runs last, with
  # nothing allocation-heavy after it before the quit below.
  window.send(:close_style)
  check("closing returns to the grid", window.send(:stack).visible_child_name, "grid")
  check("closing clears the title", window.send(:window).title, "Graphs Style Editor")

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
