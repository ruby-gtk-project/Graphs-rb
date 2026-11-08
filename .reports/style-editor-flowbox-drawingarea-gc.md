# Binding gap: Gtk::FlowBox#remove_all + Gtk::DrawingArea#set_draw_func + GC

## Status: mitigated in the port, root cause still unfixed upstream

`lib/style_editor/window.rb#reload_grid` no longer destroys and recreates
`StylePreview` tiles on every rebuild. Each tile (and its
`Gtk::DrawingArea`) is now built exactly once and kept in a
`@style_previews` hash keyed by style name, reused in place across every
later reload; `reload_grid` only removes a tile whose style has actually
disappeared (deleted by the user), and only ever adds genuinely new
tiles. Nothing with a `set_draw_func` closure is ever destroyed-then-
GC'd as part of an ordinary rebuild any more, which was the exact
mechanism below.

This was verified by driving `reload_grid` far beyond the two calls the
previous version of this script limited itself to: `test/drive_style_editor.rb`
now forces `GC.start`, allocates pressure garbage, and calls `reload_grid`
five more times in a row after the real close-style rebuild, and asserts
the grid still has the right tile count afterward. It survives — the
whole script reaches `DRIVE OK`. This is evidence the specific crash
pattern reproduced below (destroy-and-recreate a batch of
`Gtk::DrawingArea`-backed widgets, then let GC run) no longer occurs in
this codebase, because that code path (destroying a live, already-
realized `Gtk::DrawingArea` that has a registered draw closure) is no
longer exercised. It is not a fix to `gobject-introspection` itself: a
future call site that still destroys-and-recreates `set_draw_func`
widgets (anywhere in this codebase or elsewhere) would still be at risk,
and the underlying binding gap below is unresolved and worth filing
against `ruby-gnome/gobject-introspection` upstream — this report
documents it for that purpose, but no issue has been filed from this

**Addendum, added during this round's parity audit, not by the original
author of this report:** that "future call site" risk is not only
hypothetical or only elsewhere — `reload_grid`'s own new body still
contains one. The sentence above, "only removes a tile whose style has
actually disappeared," is accurate, and that removal
(`flow_box.remove(previews.delete(name).widget)`, reached when a user
deletes a style) destroys exactly the kind of `Gtk::DrawingArea`-backed
widget this report's repro shows is at risk, and does so inside the same
method this report credits with fixing the bug. `test/drive_style_editor.rb`
never calls `confirm_delete`/`on_delete_response`, with or without GC
pressure, so this path has no evidence either way. Read generously, the
status line above ("mitigated in the port") is true for the *rebuild*
path it was written about and tested against; read adversarially, a
reader could take it to mean the whole method, which it does not cover.
Recorded here so the next reader of this file sees it, not only in
`accountability-ensurance.md`.

session.

## Original summary

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
