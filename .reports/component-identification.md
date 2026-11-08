# Component identification — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `3a3d19c7` (this pass re-verifies everything below against the tree as it stands after the `reload_grid` crash-mitigation commit, and adds one finding the prior pass dropped: the figure-settings sidebar's style tab) |
| Method | `.claude/skills/component-identification` applied by hand (file-level scan of both trees; `gir-symbols.sh`/`component-scan.sh` not run — see caveat below) |

Caveat up front, carried forward unchanged: this pass did not run
`component-scan.sh` with a built `symbols.tsv`. What follows is a
file-existence inventory — Step 1 of the skill carried to "does a port file
exist", not the widget/CSS/signal/action table the skill asks for per
surviving unit. **That table is still not built for every ported file** —
`component-parity.md` does it for the files actually tabled and says so.

This supersedes `.reports/component-inventory.md` where they disagree.

## Application shell

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/application.vala`, `graphs/__init__.py` | `lib/graphs/application.rb` | Yes |
| `graphs/window.vala`, `data/ui/window.blp` | `lib/window.rb` | Yes |
| `graphs/actions.vala` | `lib/actions.rb` | Yes |
| `data/ui/window-shortcuts.blp` | `lib/shortcuts_dialog.rb` | Yes |
| `graphs/settings.vala` + `data/se.sjoerd.Graphs.gschema.xml` | `lib/settings.rb` + `data/org.rubygtkproject.Graphs.gschema.xml` | **Now Yes** — the gschema file was ported in `71decf49` (`glib-compile-schemas --strict` claimed, not re-verified in this pass — see "Checks not run" in `accountability-ensurance.md`) |
| `data/se.sjoerd.Graphs.metainfo.xml.in`, `.desktop.in`, `.mime.xml`, `.service.in` | `data/org.rubygtkproject.Graphs.{metainfo.xml.in,desktop.in,mime.xml,service.in}` | **Now Yes, with a disclosed gap** — `71decf49`'s own commit message says the desktop file "drops the new-window/style-editor actions since those command-line flags aren't implemented by `lib/graphs/application.rb`." Confirmed: `lib/graphs/application.rb` has no `--new-window` or `--style-editor` CLI handling. This is a real, if small, behavioural gap (upstream's desktop actions let a user launch straight into the style editor from the app grid's right-click menu; the port's desktop file can't offer that because the app doesn't support it), disclosed in the commit message rather than hidden. |
| `po/` (28 `.po` files, `POTFILES.in` listing 135 files) | — | **Missing** — see `translation-parity.md` |
| `help/C/*.page` (11 help pages) + `help/<lang>/*.po` | — | **Missing** |

## Canvas & figure

Unchanged from the prior pass: `lib/canvas.rb` (folds `canvas.py`,
`artist.py`, `figure.py`, `scales.py`, not verified line-for-line),
`lib/figure_settings.rb`. Both **Yes**, both **Partial** on depth-of-check.

**New finding this pass, not in any prior `component-identification.md`
pass** (it was in the older, superseded `component-inventory.md` and got
dropped when this file replaced it): upstream's
`data/ui/sidebar/figure-settings/style-page.blp` — a dedicated
`Adw.NavigationPage` ("Style") inside the figure-settings sidebar, holding a
`GridView` of style-preview thumbnails plus a header "Manage" button wired
to `action-name: "app.style-editor"` — has **no port file at all**.
`lib/figure_settings.rb` (99 lines) has no `style_page`/`StylePage`
method, class or navigation push, confirmed by `grep -n 'style_page\|StylePage\|style-grid\|style_grid' lib/*.rb` →
only `lib/style.css` matches (a CSS rule, not a widget). The only route
from inside the app to the style editor is the global "Styles…" app-menu
item (`lib/main_sidebar_page.rb:224`, `app.style-editor`) — the quick,
in-context "flip through my project's styles without leaving the sidebar"
page upstream gives the user does not exist in the port at all. This is a
real, user-facing navigation gap, not a cosmetic one: with the style editor
window now ported (see below), this missing page is the one piece that
would have connected it to the sidebar a user is actually looking at.

## Items (data series)

Unchanged: all six item model files + factory + base box + item box. **Yes**
across the board.

## Sidebar — item editor (`sidebar/edit_item/*`)

Unchanged since the last inventory: all eight files present. **Yes**, file
existence only.

## Sidebar — main page & operations

Unchanged: `lib/main_sidebar_page.rb`, `lib/operations_panel.rb`,
`lib/operations.rb` — Yes.

## Dialogs

Unchanged: all seven standalone dialogs and all seven alert dialogs — Yes.
Curve fitting dialog — Yes (ported `42ff07f5`, carried forward).

## Colour widgets

Unchanged: `lib/color_button.rb`, `lib/color_swatch.rb`, `lib/color_row.rb`
— Yes.

## Style editor (separate window) — **now ported, with two caveats**

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/style_editor/window.vala` | `lib/style_editor/window.rb` | **Now Yes** |
| `graphs/style_editor/add_style.vala` | `lib/style_editor/add_style.rb` | **Now Yes** |
| `graphs/style_editor/color_group.vala` | `lib/style_editor/color_group.rb` | **Now Yes** |
| `graphs/style_editor/editor_box.vala`/`.py` | `lib/style_editor/editor_box.rb` | **Now Yes** |
| `graphs/style_editor/item_color_row.vala` | `lib/style_editor/item_color_row.rb` | **Now Yes** |
| `data/ui/style-editor/shortcuts.blp` | `lib/style_editor/shortcuts_dialog.rb` | **Now Yes** |
| `data/ui/style-preview.blp` | `lib/style_preview.rb` | Yes (pre-existing) |
| `graphs/styles.vala`, `.py`, `style_io.py` | `lib/styles.rb` | Yes (model, pre-existing) |

Caveat 1 — **disclosed, real behaviour gap**: `lib/style_editor/window.rb:21-23`
says in its own class comment that upstream's adaptive `Adw.MultiLayoutView`
(side-by-side on a wide window, a bottom sheet on a narrow one) "is
simplified here to the side-by-side layout only." This is a genuine
functional gap — a narrow-window user of the port never gets the
bottom-sheet layout upstream gives them — named plainly in the code, not
hidden behind a label, but still a gap to record here rather than let the
file-existence "Yes" imply full parity.

Caveat 2 — **a binding-level crash reachable through this window, now
mitigated in the port, root cause still open upstream**, documented in
`.reports/style-editor-flowbox-drawingarea-gc.md` and fixed this pass by
`3a3d19c7`: rebuilding the style grid (`reload_grid`) used to destroy every
`StylePreview` tile with `Gtk::FlowBox#remove_all` and rebuild them from
scratch, which — because each tile's `Gtk::DrawingArea#set_draw_func`
closure is not kept rooted independently of the widget by
gobject-introspection — reproducibly segfaulted or corrupted the process
once GC ran before GTK's next frame tick. `reload_grid` now keeps each
tile alive in a `@style_previews` hash keyed by style name and reuses it in
place, only ever removing a tile whose style was actually deleted; nothing
with a live `set_draw_func` closure is destroyed-then-GC'd on an ordinary
rebuild any more. `test/drive_style_editor.rb` was extended to force
`GC.start`, allocate pressure garbage, and call `reload_grid` five more
times after the real rebuild, and the script still reaches `DRIVE OK`
(reverified this pass). **This mitigates the port's own exposure to the
bug; it does not fix `gobject-introspection` itself** — a future call site
anywhere that still destroys-and-recreates `set_draw_func` widgets would
still be at risk, and the report says so in its own words. See
`test-parity.md` and `accountability-ensurance.md` for how this pass reads
that distinction.

## File import — **still entirely unported**

Unchanged: dialog, controller, parsers (columns, spreadsheet, SQL, XRY,
XRDML, legacy project format), all ~9+ files. No `lib/file_import/`
directory exists. Confirmed again this pass (`find lib -iname '*import*'`
returns nothing).

## Project load/save & legacy migration

Unchanged: `lib/project.rb` — Yes (model), `graphs/migrate.py` — **Still
Missing**. Confirmed again this pass (`find lib -iname '*migrat*'` returns
nothing).

## Math parser & misc utilities

Unchanged from the prior inventory — full pipeline ported.

## Non-widget data/config — **largely closed this pass**

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `data/se.sjoerd.Graphs.gschema.xml` | `data/org.rubygtkproject.Graphs.gschema.xml` | **Now Yes** |
| `data/se.sjoerd.Graphs.{metainfo.xml.in,desktop.in,mime.xml,service.in}` | `data/org.rubygtkproject.Graphs.{...}` | **Now Yes** (desktop file gap noted above) |
| `data/styles/*.mplstyle` (17 files) | `data/styles/*.mplstyle` | **Now Yes — all 17 filenames match upstream exactly**, confirmed by diff this pass; byte-for-byte content diff not run |
| `data/style.css` | `lib/style.css` | Yes (present; byte-for-byte parity not checked) |

## Help / documentation

Unchanged. No `help/` tree on `ruby`, confirmed again this pass.

## Translations

Unchanged. No `po/` directory, confirmed again this pass (`find . -iname
'*.po'` → 0 files).

## Summary of what changed since the last inventory

- **Closed in earlier passes, reverified this pass:** the whole style
  editor window subsystem (6 files), app metadata
  (gschema/desktop/mime/service/metainfo), the `data/styles/*.mplstyle`
  preset files (all 17, name-complete).
- **Closed this pass:** the `reload_grid` crash is now mitigated in-port
  (`3a3d19c7`) — see Caveat 2 above. The style editor's adaptive-layout gap
  (side-by-side only, no bottom sheet) is unchanged and still open,
  disclosed in code.
- **New finding this pass** (recovered from the older, superseded
  `component-inventory.md`, which had it and this file had dropped it):
  the figure-settings sidebar's own `style-page.blp` — the in-context style
  grid + "Manage" button — has no port file at all. See "Canvas & figure"
  above.
- **Still wide open, zero port files:** file import (9+ files), legacy
  project migration (`graphs/migrate.py`), `help/` (11 pages + translations),
  `po/` (28 languages), the figure-settings style-page tab (new finding,
  above).
- **Not attempted in this pass, still:** the widget/CSS/signal/action table
  for most ported files — `component-parity.md` tables a handful and says so.
