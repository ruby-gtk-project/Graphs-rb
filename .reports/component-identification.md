# Component identification — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `ce0ff04e` (this pass updates the rows for the style editor, the test_operations.py checks, and the app-metadata files — ported since `42ff07f5` — the rest of this file carries forward unchanged) |
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

Caveat 2 — **an unresolved binding-level crash reachable through this
window**, documented in `.reports/style-editor-flowbox-drawingarea-gc.md`:
rebuilding the style grid (`reload_grid`) a second time, with GC running at
the wrong moment afterward, reproducibly segfaults or corrupts the
process — not a Graphs-rb logic bug, a `ruby-gnome`/`gobject-introspection`
binding gap around `Gtk::FlowBox#remove_all` + `Gtk::DrawingArea#set_draw_func`.
`reload_grid` is called at build time and again on every `close_style` and
every successful "Create Style…" — i.e., on the two most ordinary ways a
user interacts with this window more than once per session. This is carried
in detail in `test-parity.md` and `accountability-ensurance.md` because of
what it implies about the drive script's green result, not re-derived here.

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

- **Closed this pass:** the whole style editor window subsystem (6 files),
  app metadata (gschema/desktop/mime/service/metainfo), and the
  `data/styles/*.mplstyle` preset files (all 17, name-complete).
- **Opened this pass (new finding, not previously listed):** the style
  editor's adaptive layout is disclosed-but-missing (side-by-side only), and
  a real, reproducible, unresolved GTK-binding crash is reachable through
  the window's ordinary "close and reopen a different style" / "create a
  new style" flows.
- **Still wide open, zero port files:** file import (9+ files), legacy
  project migration (`graphs/migrate.py`), `help/` (11 pages + translations),
  `po/` (28 languages).
- **Not attempted in this pass, still:** the widget/CSS/signal/action table
  for most ported files — `component-parity.md` tables a handful and says so.
