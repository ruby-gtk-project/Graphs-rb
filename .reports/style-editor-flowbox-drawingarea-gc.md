# Binding gap: Gtk::FlowBox#remove_all + Gtk::DrawingArea#set_draw_func + GC

## Summary

Rebuilding a `Gtk::FlowBox` twice — `remove_all` followed by re-`append`ing
children that are (or contain) `Gtk::DrawingArea` widgets using
`set_draw_func` — reproducibly corrupts memory once Ruby's garbage collector
runs and GTK's main loop later invokes a pending draw/frame callback. The
observed symptoms are either a hard segfault inside
`gobject-introspection`'s FFI closure dispatch, or (with slightly different
timing) a live Ruby object being replaced by garbage so that a stored
callback is some unrelated object (`undefined method 'call' for an instance
of Array`).

This reproduces with **no Graphs-rb code at all** — see the minimal
reproduction below — so it is a ruby-gnome / GTK4 binding gap, not a port
bug. `lib/style_editor/window.rb`'s `reload_grid` (called once at build
time, and again every time the style editor's grid page needs refreshing —
by `close_style`, and by "Create Style…") is the exact shape that triggers
it, because every tile is a `StylePreview`, which backs its thumbnail with a
`Gtk::DrawingArea#set_draw_func`.

## Where this was found

Writing `test/drive_style_editor.rb` (this round's new drive script,
exercising `lib/style_editor/*.rb`, which no earlier drive script touched)
to open the style editor, load a style, create a new one and close back to
the grid. Calling `window.send(:reload_grid)` a second time — the real
behaviour of "Create Style…" refreshing the grid, or of closing the editor
twice — crashed the whole process, deterministically, once enough other
Ruby allocation happened afterward to give the GC a reason to run before the
pending frame tick for the destroyed tiles fired.

## Minimal reproduction (no Graphs-rb code)

```ruby
require "gtk4"

class Widget
  def build
    Gtk::DrawingArea.new.tap do |area|
      area.set_content_width(50)
      area.set_content_height(50)
      area.set_draw_func { |_, context, width, height| draw(context, width, height) }
    end
  end

  def draw(context, width, height)
    context.set_source_rgb(1, 0, 0)
    context.rectangle(0, 0, width, height)
    context.fill
  end
end

flow = Gtk::FlowBox.new

def reload(flow)
  flow.remove_all
  20.times { flow.append(Widget.new.build) }
end

app = Gtk::Application.new("org.test.repro", :default_flags)
app.signal_connect("activate") do
  w = Gtk::ApplicationWindow.new(app)
  scroll = Gtk::ScrolledWindow.new
  scroll.child = flow
  w.child = scroll
  w.present
  reload(flow)
  GC.start
  reload(flow)   # the second remove_all + repopulate is what matters
  GC.start
  GLib::Timeout.add(300) { app.quit; false }
end
app.run([])
puts "did not reach this line"
```

Run under `xvfb-run ruby repro.rb`. First `reload` + `GC.start` is safe by
itself (confirmed separately); it is specifically the **second** cycle,
with GC given a chance to run, that corrupts state. The crash fires later,
inside `Gio::Application#run`'s own event loop — not at the `GC.start` call
site — which is why it looks unrelated to whatever code ran most recently.

Removing the `set_draw_func` call (plain colour-filled widgets, no draw
callback) makes the same remove/repopulate/GC loop safe, which points at the
draw-function closure specifically, not `Gtk::FlowBox#remove_all` alone.

Even keeping a strong Ruby reference to every `Widget` instance for the
whole process lifetime (an array that is never cleared) does **not** avoid
the crash, which rules out "the Ruby wrapper object was prematurely
collected" as the mechanism — this looks like the FFI closure object the
`gobject-introspection` gem allocates to bridge `set_draw_func` is not
properly rooted against GC independent of the Ruby-level callable staying
alive.

## Environment

- `ruby-gnome` / `gobject-introspection` gem 4.3.9 (Nix:
  `ruby3.4-gobject-introspection-4.3.9`)
- `gtk4` 4.22.4 (Nix: `gtk4-4.22.4`)
- Ruby 3.4.9, this fork's dev shell (`xvfb-run` under Xvfb, no GPU)

## What this means for the port

`lib/style_editor/window.rb`'s `reload_grid` is the one place in Graphs-rb
that destroys and recreates a batch of `Gtk::DrawingArea`-backed widgets
more than once in a running process. In real use this is reachable by:
closing the style editor back to the grid after editing more than one
style in a session, or by "Create Style…" refreshing the grid after the
first style is created. Either can crash the app if the garbage collector
happens to run at the wrong moment afterward — this is **not** limited to
the test harness.

No port-level change avoids this (keeping strong references does not help,
per the repro above); it needs a fix in `gobject-introspection` or a
different draw-callback registration strategy than `set_draw_func` with a
Ruby closure. Filed here rather than worked around.

## What the drive script does instead

`test/drive_style_editor.rb` exercises `reload_grid` exactly twice (the
unavoidable build-time call, plus one `close_style` call, which is the real
behaviour it is proving), and deliberately runs nothing allocation-heavy
after that second call before the process quits — the same ordering that
is safe in isolation. This keeps the script's own run inside the safe
window demonstrated above; it does not establish that the *app*, run
interactively for longer with more such cycles, is safe — the opposite is
true, and is the point of this report.
