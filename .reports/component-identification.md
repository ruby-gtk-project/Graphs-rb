# Component identification — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `8930c5e3` |
| Method | `.claude/skills/component-identification` applied by hand (file-level scan of both trees; `gir-symbols.sh`/`component-scan.sh` not run — see caveat below) |

Caveat up front: this pass did not run `component-scan.sh` with a built
`symbols.tsv` (that needs the fork's `nix develop` gir dump, which was spent on
the runtime-gate recheck instead — see `test-parity.md`). What follows is a
file-existence inventory, which is Step 1 of the skill (find the declarative
UI / unit list) carried all the way to "does a port file exist at all", not
the widget/CSS/signal/action table the skill asks for per surviving unit.
**That table has not been built for a single ported file in this pass.**
Treat every row below marked "Yes" as *a file exists*, not as *parity* —
`component-parity.md` is where the four axes are actually checked, and it
checks only three files in any depth.

This supersedes `.reports/component-inventory.md` (written two commits ago,
before the edit-item page, colour row and style manager landed) where they
disagree. The old file also violates `accountability-ensurance` — see that
report.

## Application shell

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/application.vala`, `graphs/__init__.py` | `lib/graphs/application.rb` | Yes |
| `graphs/window.vala`, `data/ui/window.blp` | `lib/window.rb` | Yes |
| `graphs/actions.vala` | `lib/actions.rb` | Yes |
| `data/ui/window-shortcuts.blp` | `lib/shortcuts_dialog.rb` | Yes |
| `graphs/settings.vala` + `data/se.sjoerd.Graphs.gschema.xml` | `lib/settings.rb` | **Partial** — no `.gschema.xml` on `ruby` at all; keys hand-re-implemented |
| `data/se.sjoerd.Graphs.metainfo.xml.in`, `.desktop.in`, `.mime.xml`, `.service.in` | — | **Missing** |
| `po/` (28 `.po` files, `POTFILES.in` listing 135 files) | — | **Missing** — see `translation-parity.md` |
| `help/C/*.page` (11 help pages) + `help/<lang>/*.po` (translated help, dozens of languages) | — | **Missing** |

## Canvas & figure

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/canvas/canvas.vala`, `graphs/canvas/canvas.py` | `lib/canvas.rb` | Yes |
| `graphs/canvas/figure.py`, `artist.py`, `scales.py` | folded into `lib/canvas.rb` | Partial — not verified line-for-line |
| `graphs/figure_settings.vala` + `data/ui/sidebar/figure-settings/settings-page.blp` | `lib/figure_settings.rb` | Yes |
| `data/ui/sidebar/figure-settings/style-page.blp` | `lib/figure_settings.rb` / `lib/styles.rb` | Partial |

## Items (data series)

All six item model files and the factory and base box are present and
unchanged in shape since the last inventory: `lib/item/{base,data_item,
equation_item,fill_item,generated_data_item,text_item,factory,data_holder}.rb`,
`lib/item_box.rb`. **Yes** across the board.

## Sidebar — item editor (`sidebar/edit_item/*`)

**Now ported** (was entirely missing in the prior inventory):

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/sidebar/edit_item/page.vala` | `lib/sidebar/edit_item/page.rb` | Yes |
| `graphs/sidebar/edit_item/base_box.vala` | `lib/sidebar/edit_item/base_box.rb` | Yes |
| `graphs/sidebar/edit_item/data_box.vala` | `lib/sidebar/edit_item/data_box.rb` | Yes |
| `graphs/sidebar/edit_item/equation_box.vala` | `lib/sidebar/edit_item/equation_box.rb` | Yes |
| `graphs/sidebar/edit_item/equation_group.vala` | `lib/sidebar/edit_item/equation_group.rb` | Yes |
| `graphs/sidebar/edit_item/errorbar_group.vala` | `lib/sidebar/edit_item/errorbar_group.rb` | Yes |
| `graphs/sidebar/edit_item/fill_box.vala` | `lib/sidebar/edit_item/fill_box.rb` | Yes |
| `graphs/sidebar/edit_item/generated_data_box.vala` | `lib/sidebar/edit_item/generated_data_box.rb` | Yes |

File existence only — no widget/CSS/signal table has been built for any of
these eight files in this pass. `component-parity.md`'s driven check covers
only the page title and "not empty", not the per-field bindings.

## Sidebar — main page & operations

`lib/main_sidebar_page.rb`, `lib/operations_panel.rb`, `lib/operations.rb` —
Yes, as before.

## Dialogs

All seven standalone dialogs (add-equation, add-fill, export-figure,
export-items, generate-data, smoothen, transform) and all seven alert dialogs
— Yes, as before.

**Still entirely missing:**

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/curve_fitting.vala`, `graphs/curve_fitting.py`, `data/ui/curve-fitting.blp`, `data/ui/fitting-parameters.blp` | — | **Missing** |

## Colour widgets

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/color_button.vala` | `lib/color_button.rb` | Yes |
| `graphs/color_swatch.vala` | `lib/color_swatch.rb` | Yes |
| `graphs/color_row.vala`, `data/ui/color-row.blp` | `lib/color_row.rb` | **Now Yes** (was missing) |

## Style editor (separate window)

**Still entirely unported**, except the model layer:

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/style_editor/window.vala` | — | **Missing** |
| `graphs/style_editor/add_style.vala` | — | **Missing** |
| `graphs/style_editor/color_group.vala` | — | **Missing** |
| `graphs/style_editor/editor_box.vala`/`.py` | — | **Missing** |
| `graphs/style_editor/item_color_row.vala` | — | **Missing** |
| `data/ui/style-editor/shortcuts.blp` | — | **Missing** |
| `data/ui/style-preview.blp` | — | **Missing** |
| `graphs/styles.vala`, `.py`, `style_io.py` | `lib/styles.rb` | Yes (model only) |

The "style manager" driven in `drive_sidebar.rb` is `lib/styles.rb`'s
`StyleManager` — the model. There is no window a user can open to add, edit
or delete a style. This is a whole top-level window with no port file,
reachable from the app's header-bar menu upstream.

## File import

**Still entirely unported** — dialog, controller, parsers (columns,
spreadsheet, sql, xry, legacy project format), all ~9+ files. No `lib/
file_import/` directory exists.

## Project load/save & legacy migration

**Still entirely unported**:

| Upstream file(s) | Port path | Exists |
|---|---|---|
| `graphs/project.vala`, `graphs/project.py` | — | **Missing** |
| `graphs/migrate.py` | — | **Missing** |

The alert dialogs this flow triggers (`beta-disallowed`, `legacy-migration-
disallowed`, `invalid-project`) exist in `lib/alert_dialogs.rb`, but nothing
in `lib/` ever raises them — there is no save, no open, no "recent projects",
no migration path for a `.graphs` v1 file. `tests/test_migration.py` upstream
(7 tests) pins exactly this code, and none of it exists in the port.

## Math parser & misc utilities

Unchanged from the prior inventory: full pipeline ported
(`lib/math_parser/{ast,lexer,parser,program,evaluator,printer,functions}.rb`),
`lib/{utilities,enums,data,properties}.rb` present. "Partial — needs
verification" on `math_parser/main.vala` coverage and `graphs/bindings.vala`
vs `properties.rb`, unchanged.

## Help / documentation

No `help/` tree on `ruby`. Upstream ships 11 English help pages plus
translated copies in dozens of languages via `help/<lang>/*.po`.

## Summary of what changed since the last inventory

- **Closed:** sidebar edit-item page + 7 boxes/groups, colour row widget,
  and (per the git log) the style manager is now driven by a test.
- **Still wide open, verified by file-existence, each a whole subsystem with
  zero port files:** style editor window (6 files), file import (9+ files),
  project load/save/migration (2 files + the flow that calls them), curve
  fitting dialog (1 file + its fitting-parameters sub-UI), GSettings schema,
  app metadata (`.desktop`/`.metainfo`/`.mime`/`.service`), `po/` (28
  languages), `help/` (11 pages + translations).
- **Not attempted in this pass:** the widget/CSS/signal/action table for any
  single file, upstream or port. `component-parity.md` below does this for
  the three files the `ruby-gtk-testing` driver actually exercises and stops
  there — the remaining ~20 ported files have never had their axes compared.
