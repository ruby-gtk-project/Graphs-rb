# Graphs — component inventory (upstream `origin/main` vs. `ruby`)

> **Superseded.** This file was written against `ruby` @ `8930c5e3`, before
> the sidebar edit-item page, colour row, curve-fitting dialog (`42ff07f5`)
> and project load/save (`8915152e`) were ported. `component-identification.md`
> is the current, maintained inventory and records the same rows updated for
> every commit since. Kept here only for its original per-file "Notes" detail
> on areas `component-identification.md` summarizes more tersely (figure.py/
> artist.py/scales.py coverage inside canvas.rb, `math_parser/main.vala`,
> `graphs/bindings.vala` vs `properties.rb`). Do not read the "Missing" rows
> for curve fitting, project/migration or the style editor below as current —
> two of those three subsystems are partially ported now; see
> `component-identification.md`.

Scope: every user-facing component (windows, dialogs, pages, rows, menus,
shortcuts, preferences, actions, empty/error states) plus the declarative UI
(`.blp`), GSettings schema, GResource manifest and `po/` catalogue that back
them. Upstream is Vala (`graphs/*.vala`) with a thin Python layer
(`graphs/*.py`) and Blueprint UI (`data/ui/**/*.blp`); the port lives under
`lib/`.

Legend: **Exists** = a `lib/*.rb` file already covers this component (may be
partial — see Notes). **Missing** = no port file exists yet.

## Application shell

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/application.vala`, `graphs/__init__.py`, `graphs/graphs.c` | `lib/graphs/application.rb` | Application | Yes | Entry point, actions registration |
| `graphs/window.vala`, `graphs/window.py`, `data/ui/window.blp` | `lib/window.rb` | Window (ApplicationWindow) | Yes | Main window shell, header bar, canvas + sidebar split view |
| `graphs/actions.vala` | `lib/actions.rb` | Actions | Yes | `win.*`/`app.*` action installs |
| `data/ui/window-shortcuts.blp`, `graphs/shortcuts_dialog` (Help > Shortcuts) | `lib/shortcuts_dialog.rb` | Dialog (shortcuts) | Yes | |
| `graphs/settings.vala`/schema | `lib/settings.rb` | Settings model | Yes | Backed by GSettings upstream; JSON-backed in port |
| `data/se.sjoerd.Graphs.gschema.xml` | `lib/settings.rb` | GSettings schema | Partial | Schema itself not ported as a `.gschema.xml`; keys re-implemented in `settings.rb`. No `.gschema.xml` exists under `lib/` or `data/` on `ruby` |
| `data/se.sjoerd.Graphs.metainfo.xml.in`, `.desktop.in`, `.mime.xml`, `.service.in` | — | App metadata | Missing | No equivalent app-metadata files on `ruby` |
| GResource manifest (`data/*.gresource.xml` via `data/meson.build`) | — | GResource | N/A | Ruby port has no `.ui`/GResource by house style (widgets built in code); nothing to port 1:1 |
| `po/*.po`, `po/POTFILES.in` | — | i18n catalogue | Missing | No `po/` directory, no translation marks audited yet on `ruby` |

## Canvas & figure

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/canvas/canvas.vala`, `graphs/canvas/canvas.py` | `lib/canvas.rb` | Canvas widget | Yes | |
| `graphs/canvas/figure.py` | `lib/canvas.rb` (folded in) | Figure model | Partial | Not a distinct file; confirm feature parity against `figure.py` |
| `graphs/canvas/artist.py` | — | Rendering helper | Missing | No `lib/` counterpart found |
| `graphs/canvas/scales.py` | — | Axis scale helper | Missing | No `lib/` counterpart found |
| `graphs/figure_settings.vala`, `data/ui/sidebar/figure-settings/settings-page.blp` | `lib/figure_settings.rb` | Figure settings model/page | Yes | |
| `data/ui/sidebar/figure-settings/style-page.blp` | `lib/figure_settings.rb` / `lib/styles.rb` | Style-page UI | Partial | No distinct page file; verify the style-pick UI itself (not just the `Style`/`StyleManager` model) is built somewhere |

## Items (data series)

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/item/base.vala` | `lib/item/base.rb` | Item base model | Yes | |
| `graphs/item/data_item.vala` | `lib/item/data_item.rb` | Item model | Yes | |
| `graphs/item/equation_item.vala` | `lib/item/equation_item.rb` | Item model | Yes | |
| `graphs/item/fill_item.vala` | `lib/item/fill_item.rb` | Item model | Yes | |
| `graphs/item/generated_data_item.vala` | `lib/item/generated_data_item.rb` | Item model | Yes | |
| `graphs/item/text_item.vala` | `lib/item/text_item.rb` | Item model | Yes | |
| `graphs/item/factory.vala` | `lib/item/factory.rb` | Factory | Yes | |
| (no direct upstream `data_holder.vala`) | `lib/item/data_holder.rb` | Model mixin | Yes (extra) | Port-side helper; confirm it has an upstream analogue or is a deliberate house-style split |
| `graphs/item_box.vala`, `data/ui/item-box.blp` | `lib/item_box.rb` | Row (sidebar item list row) | Yes | |

## Sidebar — item editor ("edit item" page)

This whole sub-tree (the per-item property editor shown when an item is
selected in the sidebar) has **no port file at all** on `ruby`:

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/sidebar/edit_item/page.vala`, `data/ui/sidebar/edit-item/page.blp` | `lib/sidebar/edit_item_page.rb` (proposed) | Page | Missing | Hosts the stack of boxes below |
| `graphs/sidebar/edit_item/base_box.vala`, `data/ui/sidebar/edit-item/base.blp` | `lib/sidebar/edit_item/base_box.rb` (proposed) | Box | Missing | Name/x-position/y-position/legend — binds directly to `Item` properties |
| `graphs/sidebar/edit_item/data_box.vala`, `data/ui/sidebar/edit-item/data.blp` | `lib/sidebar/edit_item/data_box.rb` (proposed) | Box | Missing | DataItem-specific fields |
| `graphs/sidebar/edit_item/equation_box.vala`, `data/ui/sidebar/edit-item/equation.blp` | `lib/sidebar/edit_item/equation_box.rb` (proposed) | Box | Missing | |
| `graphs/sidebar/edit_item/equation_group.vala`, `data/ui/sidebar/edit-item/equation-group.blp` | `lib/sidebar/edit_item/equation_group.rb` (proposed) | Group | Missing | |
| `graphs/sidebar/edit_item/errorbar_group.vala`, `data/ui/sidebar/edit-item/errorbar-group.blp` | `lib/sidebar/edit_item/errorbar_group.rb` (proposed) | Group | Missing | |
| `graphs/sidebar/edit_item/fill_box.vala`, `data/ui/sidebar/edit-item/fill.blp` | `lib/sidebar/edit_item/fill_box.rb` (proposed) | Box | Missing | |
| `graphs/sidebar/edit_item/generated_data_box.vala`, `data/ui/sidebar/edit-item/generated-data.blp` | `lib/sidebar/edit_item/generated_data_box.rb` (proposed) | Box | Missing | |

## Sidebar — main page & operations

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/sidebar/main.vala`, `data/ui/sidebar/main.blp` | `lib/main_sidebar_page.rb` | Page | Yes | |
| `graphs/sidebar/operations.vala`, `data/ui/sidebar/operations.blp` | `lib/operations_panel.rb` | Panel | Yes | |
| `graphs/sidebar/figure_settings.vala` | `lib/figure_settings.rb` | Sidebar-side glue | Partial | Confirm sidebar-facing wiring (not just the settings model) is present |
| `graphs/operations.py` | `lib/operations.rb` | Operation implementations | Yes | |

## Dialogs

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/add_equation.vala`, `data/ui/add-equation.blp` | `lib/add_equation_dialog.rb` | Dialog | Yes | |
| `graphs/add_fill.vala`, `data/ui/add-fill.blp` | `lib/add_fill_dialog.rb` | Dialog | Yes | |
| `graphs/export_figure.vala`, `data/ui/export-figure.blp` | `lib/export_figure_dialog.rb` | Dialog | Yes | |
| `graphs/export_items.vala` | `lib/export_items.rb` | Dialog/action | Yes | |
| `graphs/generate_data.vala`, `data/ui/generate-data.blp` | `lib/generate_data_dialog.rb` | Dialog | Yes | |
| `graphs/smoothen_settings.vala`, `data/ui/smoothen-settings.blp` | `lib/smoothen_dialog.rb` | Dialog | Yes | |
| `graphs/transform.vala`, `data/ui/transform.blp` | `lib/transform_dialog.rb` | Dialog | Yes | |
| `data/ui/dialogs/beta-disallowed.blp` | `lib/alert_dialogs.rb` | Alert dialog | Yes | |
| `data/ui/dialogs/delete-style.blp` | `lib/alert_dialogs.rb` | Alert dialog | Yes | |
| `data/ui/dialogs/invalid-project.blp` | `lib/alert_dialogs.rb` | Alert dialog | Yes | |
| `data/ui/dialogs/legacy-migration-disallowed.blp` | `lib/alert_dialogs.rb` | Alert dialog | Yes | |
| `data/ui/dialogs/reset-import-settings.blp` | `lib/alert_dialogs.rb` | Alert dialog | Yes | Confirm the import-settings-reset flow it belongs to is wired up once import exists |
| `data/ui/dialogs/save-project-changes.blp` | `lib/alert_dialogs.rb` | Alert dialog | Yes | |
| `data/ui/dialogs/save-style-changes.blp` | `lib/alert_dialogs.rb` | Alert dialog | Yes | |
| `graphs/curve_fitting.vala`, `graphs/curve_fitting.py`, `data/ui/curve-fitting.blp`, `data/ui/fitting-parameters.blp` | `lib/curve_fitting_dialog.rb` (proposed) | Dialog | **Missing** | Entire curve-fitting flow (fitting parameters, fit preview) absent from `lib/` |

## Color widgets

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/color_button.vala`, `data/ui/color-button.blp` | `lib/color_button.rb` | Widget | Yes | |
| `graphs/color_swatch.vala` | `lib/color_swatch.rb` | Widget | Yes | |
| `graphs/color_row.vala`, `data/ui/color-row.blp` | `lib/color_row.rb` (proposed) | Row | **Missing** | No port file; used in figure settings / style editor |

## Style editor (separate window)

Entirely unported — the whole style-editing sub-app:

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/style_editor/window.vala`, `data/ui/style-editor/window.blp` | `lib/style_editor/window.rb` (proposed) | Window | Missing | Separate `Adw.ApplicationWindow` for editing a style |
| `graphs/style_editor/add_style.vala`, `data/ui/style-editor/add-style.blp` | `lib/style_editor/add_style_dialog.rb` (proposed) | Dialog | Missing | |
| `graphs/style_editor/color_group.vala`, `data/ui/style-editor/color-group.blp` | `lib/style_editor/color_group.rb` (proposed) | Group | Missing | |
| `graphs/style_editor/editor_box.vala`, `graphs/style_editor/editor_box.py`, `data/ui/style-editor/editor-box.blp` | `lib/style_editor/editor_box.rb` (proposed) | Box | Missing | |
| `graphs/style_editor/item_color_row.vala`, `data/ui/style-editor/item-color-row.blp` | `lib/style_editor/item_color_row.rb` (proposed) | Row | Missing | |
| `data/ui/style-editor/shortcuts.blp` | `lib/style_editor/shortcuts_dialog.rb` (proposed) | Dialog (shortcuts) | Missing | Style editor has its own shortcuts window, distinct from the main one |
| `data/ui/style-preview.blp` | `lib/style_editor/style_preview.rb` (proposed) | Widget | Missing | Also used from the figure-settings style page |
| `graphs/styles.vala`, `graphs/styles.py`, `graphs/style_io.py` | `lib/styles.rb` | Style/StyleManager model | Yes | Model layer present; the *editor UI* above is what's missing |

## File import

Entirely unported:

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/file_import/dialog.vala`, `data/ui/import/dialog.blp` | `lib/file_import/dialog.rb` (proposed) | Dialog | Missing | Top-level import dialog (`Adw.NavigationSplitView`) |
| `graphs/file_import/file_import.vala`, `graphs/file_import/__init__.py` | `lib/file_import/file_import.rb` (proposed) | Controller | Missing | |
| `data/ui/import/file-row.blp` | `lib/file_import/file_row.rb` (proposed) | Row | Missing | |
| `data/ui/import/columns/box.blp`, `item-group.blp`, `main-group.blp`, `graphs/file_import/parsers/columns/{main,reader,ui}.vala` | `lib/file_import/parsers/columns/*.rb` (proposed) | Parser + UI | Missing | |
| `data/ui/import/spreadsheet/box.blp`, `item-group.blp`, `main-group.blp`, `graphs/file_import/parsers/spreadsheet/{main,reader,ui}.vala` | `lib/file_import/parsers/spreadsheet/*.rb` (proposed) | Parser + UI | Missing | |
| `data/ui/import/sql/main-group.blp`, `graphs/file_import/parsers/sql/{main,reader,ui}.vala` | `lib/file_import/parsers/sql/*.rb` (proposed) | Parser + UI | Missing | |
| `graphs/file_import/parsers/xry/parser.vala` | `lib/file_import/parsers/xry/parser.rb` (proposed) | Parser | Missing | |
| `graphs/file_import/parsers/project/__init__.py` | `lib/file_import/parsers/project.rb` (proposed) | Parser | Missing | Legacy `.graphs`/project-format import |

## Project load/save & legacy migration

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/project.vala`, `graphs/project.py` | `lib/project.rb` (proposed) | Model/controller | Missing | Save/open project, `ProjectParseError`/`ProjectParseFlags` (beta-disallowed, legacy-migration-disallowed) — the dialogs exist (`alert_dialogs.rb`) but the flow that triggers them does not |
| `graphs/migrate.py` | `lib/migrate.rb` (proposed) | Migration logic | Missing | Pickle-based legacy-format migration |

## Math parser & misc utilities

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `graphs/math_parser/ast.vala`, `graphs/ast.py` | `lib/math_parser/ast.rb` | Model | Yes | |
| `graphs/math_parser/lexer.vala` | `lib/math_parser/lexer.rb` | Lexer | Yes | |
| `graphs/math_parser/parser.vala` | `lib/math_parser/parser.rb` | Parser | Yes | |
| `graphs/math_parser/compiler.vala` | `lib/math_parser/program.rb` | Compiler | Yes (renamed) | Confirm 1:1 behavior; name differs from upstream file |
| `graphs/math_parser/evaluator.vala` | `lib/math_parser/evaluator.rb` | Evaluator | Yes | |
| `graphs/math_parser/printer.vala` | `lib/math_parser/printer.rb` | Printer | Yes | |
| `graphs/math_parser/main.vala` | — | Entry/dispatch | Partial | Confirm coverage; no single `main.rb` under `math_parser/`, likely folded into `lib/math_parser.rb` |
| (no direct 1 upstream file) | `lib/math_parser/functions.rb` | Function table | Yes (extra) | House-style split, not a gap |
| `graphs/math_utilities.vala` | `lib/utilities.rb` (folded in?) | Math helpers | Partial | Confirm upstream's numeric helpers are covered, not just string/enum ones |
| `graphs/utilities.vala`, `graphs/utilities.py`, `graphs/utilities.c` | `lib/utilities.rb` | Utilities | Yes | |
| `graphs/misc.vala`, `graphs/misc.py` | `lib/enums.rb` | Enums | Yes | |
| `graphs/data.vala`, `graphs/data.py` | `lib/data.rb` | Data model | Yes | |
| `graphs/bindings.vala` | `lib/properties.rb` (partial overlap) | Property-binding glue | Partial | Upstream's GObject `bind_property` plumbing; confirm `properties.rb` covers the same binding surface used throughout `edit_item` boxes above (relevant once those are ported) |
| `graphs/python_helper.vala`, `graphs/python_helper.py`, `graphs/config.vala.in` | — | Build/glue | N/A | Vala↔Python bridge and build-time config; no Ruby equivalent needed |

## Help / documentation

| Upstream file(s) | Port path | Kind | Exists | Notes |
|---|---|---|---|---|
| `help/C/*.page` (curve-fitting, edit-item, edit-style, export, figure-settings, import, index, legal, manipulate, projects, window) | — | Help pages | Missing | I did not build any of the 11 help pages or their translated copies; a user of this port who presses Help gets nothing upstream's user gets. This is a real gap in the delivered app, not a decision to exclude help content from the audit. |

## Summary

- **Ported (Yes):** application shell/window/actions/shortcuts/settings model, canvas, figure settings model, all six item model classes + item row + factory, main sidebar page + operations panel, six of the standalone dialogs (add-equation, add-fill, export-figure, export-items, generate-data, smoothen, transform) plus all seven alert dialogs, color button/swatch, styles model, full math-parser pipeline, data/enums/utilities.
- **Entirely missing sub-systems:**
  - Sidebar item-editor page and its 7 boxes/groups (`sidebar/edit_item/*`)
  - Curve-fitting dialog
  - Color row widget
  - Style Editor window and its whole sub-tree (6 files)
  - File import: dialog + 3 parser back-ends (columns, spreadsheet, sql) + xry + legacy project parser (9+ files)
  - Project load/save/migration (`project.vala`, `migrate.py`)
  - GSettings schema file, app metadata files (`.desktop`, `.metainfo.xml`, `.mime.xml`, `.service`)
  - `po/` translation catalogue
  - `help/` documentation pages
- **Needs verification (Partial):** `canvas/figure.py`, `canvas/artist.py`, `canvas/scales.py` coverage inside `canvas.rb`; `math_parser/main.vala` and `math_utilities.vala` coverage; `graphs/bindings.vala` vs `properties.rb`; sidebar-side figure-settings wiring vs the settings model alone.
