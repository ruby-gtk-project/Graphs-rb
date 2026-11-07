# Graphs-rb component inventory

Survey of upstream `se.sjoerd.Graphs` (`origin/main`) against the Ruby port on
`ruby`. One row per user-facing component (window, dialog, page, row, menu,
shortcuts, actions, empty/error state). "Exists" means the `lib/*.rb` file is
present and its header/class comment names the matching upstream file(s); it
does not by itself certify full widget/signal parity (see `component-parity`
for that pass).

Upstream is Vala + Blueprint (`data/ui/*.blp`) with a small amount of Python
(curve fitting math, project/style IO, migration) and C (fast array/utility
helpers). The Ruby house style collapses a class's `.vala` + `.blp` pair into
one `lib/*.rb` file.

## Application shell

| Upstream file(s) | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `graphs/application.vala` | `lib/graphs/application.rb` | application class (actions, accelerators, About) | Yes |
| `graphs/actions.vala` | `lib/actions.rb` | action definitions/handlers | Yes |
| `graphs/window.vala`, `data/ui/window.blp` | `lib/window.rb` | main window | Yes |
| `data/ui/window-shortcuts.blp` | `lib/shortcuts_dialog.rb` | keyboard shortcuts dialog | Yes |
| `graphs/graphs.c`, `graphs/__init__.py` | — | entry point / bootstrap | N/A (no widget) |

## Canvas & data model

| Upstream file(s) | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `graphs/canvas/canvas.vala`, `canvas.py`, `artist.py`, `figure.py`, `scales.py` | `lib/canvas.rb` | plotting canvas widget | Yes |
| `graphs/data.vala`, `data.py` | `lib/data.rb` | dataset/item collection model | Yes |
| `graphs/project.vala`, `project.py` | `lib/project.rb` | project load/save model | Yes |
| `graphs/misc.vala`, `misc.py` | `lib/enums.rb` (+ `lib/properties.rb`) | enums/misc helpers | Yes (split) |
| `graphs/utilities.vala`, `.c`/`.h`, `utilities.py` | `lib/utilities.rb` | utility functions | Yes |
| `graphs/managed_array.vala` | — | native array wrapper | Not found in lib (no dedicated file) |
| `graphs/bindings.vala` | — | GObject property bindings helper | Not found in lib (likely folded into `properties.rb`) |
| `graphs/math_utilities.vala` | — | math helpers | Not found in lib as a standalone file |

## Items (`graphs/item/*`)

| Upstream file | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `item/base.vala` | `lib/item/base.rb` | item base class | Yes |
| `item/data_item.vala` | `lib/item/data_item.rb`, `lib/item/data_holder.rb` | plotted-data item | Yes |
| `item/equation_item.vala` | `lib/item/equation_item.rb` | equation-defined item | Yes |
| `item/fill_item.vala` | `lib/item/fill_item.rb` | fill-between item | Yes |
| `item/generated_data_item.vala` | `lib/item/generated_data_item.rb` | generated-data item | Yes |
| `item/text_item.vala` | `lib/item/text_item.rb` | text annotation item | Yes |
| `item/factory.vala` | `lib/item/factory.rb` | item factory | Yes |
| `data/ui/item-box.blp`, `graphs/item_box.vala` | `lib/item_box.rb` | item row in the items list | Yes |

## Sidebar — main & edit-item pages

| Upstream file | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `data/ui/sidebar/main.blp`, `graphs/sidebar/main.vala` | `lib/main_sidebar_page.rb` | sidebar container/switcher | Yes |
| `data/ui/sidebar/operations.blp`, `graphs/sidebar/operations.vala` | `lib/operations_panel.rb`, `lib/operations.rb` | operations panel + ops logic | Yes |
| `data/ui/sidebar/edit-item/page.blp`, `graphs/sidebar/edit_item/page.vala` | `lib/sidebar/edit_item/page.rb` | edit-item page | Yes |
| `data/ui/sidebar/edit-item/base.blp`, `edit_item/base_box.vala` | `lib/sidebar/edit_item/base_box.rb` | shared edit-item fields | Yes |
| `data/ui/sidebar/edit-item/data.blp`, `edit_item/data_box.vala` | `lib/sidebar/edit_item/data_box.rb` | data-item edit box | Yes |
| `data/ui/sidebar/edit-item/equation.blp`, `edit_item/equation_box.vala` | `lib/sidebar/edit_item/equation_box.rb` | equation-item edit box | Yes |
| `data/ui/sidebar/edit-item/equation-group.blp`, `edit_item/equation_group.vala` | `lib/sidebar/edit_item/equation_group.rb` | equation parameter group | Yes |
| `data/ui/sidebar/edit-item/errorbar-group.blp`, `edit_item/errorbar_group.vala` | `lib/sidebar/edit_item/errorbar_group.rb` | error-bar settings group | Yes |
| `data/ui/sidebar/edit-item/fill.blp`, `edit_item/fill_box.vala` | `lib/sidebar/edit_item/fill_box.rb` | fill-item edit box | Yes |
| `data/ui/sidebar/edit-item/generated-data.blp`, `edit_item/generated_data_box.vala` | `lib/sidebar/edit_item/generated_data_box.rb` | generated-data edit box | Yes |

## Figure settings & styling

| Upstream file | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `data/ui/sidebar/figure-settings/settings-page.blp`, `graphs/figure_settings.vala` | `lib/figure_settings.rb` | figure settings page | Yes |
| `graphs/styles.vala`, `styles.py`, `style_io.py` | `lib/styles.rb` | style model/IO | Yes |
| `data/ui/sidebar/figure-settings/style-page.blp` | — | style tab inside figure-settings sidebar page | **Missing** — no page/tab for this in `lib/figure_settings.rb` |
| `data/ui/style-preview.blp` | — | small style-preview plot widget | **Missing** |
| `data/ui/style-editor/window.blp`, `graphs/style_editor/window.vala` | — | standalone style-editor window | **Missing — whole window absent from `lib/`** |
| `data/ui/style-editor/editor-box.blp`, `style_editor/editor_box.vala`/`.py` | — | style-editor main box | **Missing** |
| `data/ui/style-editor/add-style.blp`, `style_editor/add_style.vala` | — | "add style" dialog | **Missing** |
| `data/ui/style-editor/color-group.blp`, `style_editor/color_group.vala` | — | style color-group editor | **Missing** |
| `data/ui/style-editor/item-color-row.blp`, `style_editor/item_color_row.vala` | — | per-item color row in style editor | **Missing** |
| `data/ui/style-editor/shortcuts.blp` | — | style-editor's own shortcuts dialog | **Missing** |
| `graphs/color_button.vala`, `data/ui/color-button.blp` | `lib/color_button.rb` | color picker button | Yes |
| `graphs/color_row.vala`, `data/ui/color-row.blp` | `lib/color_row.rb` | color row widget | Yes |
| `graphs/color_swatch.vala` | `lib/color_swatch.rb` | color swatch widget | Yes |

## Math / curve fitting / transforms

| Upstream file | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `graphs/curve_fitting.py`/`.vala`, `data/ui/curve-fitting.blp`, `data/ui/fitting-parameters.blp` | `lib/curve_fitting.rb`, `lib/curve_fitting_dialog.rb` | curve-fitting dialog + fitting-parameter rows | Yes |
| `graphs/transform.vala`, `data/ui/transform.blp` | `lib/transform_dialog.rb` | custom-transform dialog | Yes |
| `graphs/generate_data.vala`, `data/ui/generate-data.blp` | `lib/generate_data_dialog.rb` | generate-data dialog | Yes |
| `graphs/add_equation.vala`, `data/ui/add-equation.blp` | `lib/add_equation_dialog.rb` | add-equation dialog | Yes |
| `graphs/add_fill.vala`, `data/ui/add-fill.blp` | `lib/add_fill_dialog.rb` | add-fill dialog | Yes |
| `graphs/math_parser/*.vala` | `lib/math_parser/*.rb` | expression lexer/parser/AST/evaluator/printer | Yes |

## Smoothing, export, project import/export

| Upstream file | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| (smoothen settings; file not independently listed under `graphs/`, UI only) `data/ui/smoothen-settings.blp` | `lib/smoothen_dialog.rb` | smoothen-settings dialog | Yes |
| `graphs/export_figure.vala`, `data/ui/export-figure.blp` | `lib/export_figure_dialog.rb` | export-figure dialog | Yes |
| `graphs/export_items.vala` | `lib/export_items.rb` | export-items (data) action | Yes |
| `graphs/migrate.py` | — | legacy-project migration | **Missing** (legacy-migration-disallowed alert exists, but no migration logic file) |

## Alert / confirmation dialogs

| Upstream file | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `data/ui/dialogs/beta-disallowed.blp` | `lib/alert_dialogs.rb` (`:beta_disallowed`) | alert dialog | Yes |
| `data/ui/dialogs/delete-style.blp` | `lib/alert_dialogs.rb` (`:delete_style`) | alert dialog | Yes |
| `data/ui/dialogs/invalid-project.blp` | `lib/alert_dialogs.rb` (`:invalid_project`) | alert dialog | Yes |
| `data/ui/dialogs/legacy-migration-disallowed.blp` | `lib/alert_dialogs.rb` (`:legacy_migration_disallowed`) | alert dialog | Yes |
| `data/ui/dialogs/reset-import-settings.blp` | `lib/alert_dialogs.rb` (`:reset_import_settings`) | alert dialog | Yes |
| `data/ui/dialogs/save-project-changes.blp` | `lib/alert_dialogs.rb` (`:save_project_changes`) | alert dialog | Yes |
| `data/ui/dialogs/save-style-changes.blp` | `lib/alert_dialogs.rb` (`:save_style_changes`) | alert dialog | Yes |

## File import — **entirely missing from `lib/`**

No `lib/file_import*` or `lib/import/*` tree exists on `ruby` at all. This is
the largest gap in the port: importing any external data file (columns,
spreadsheet, SQL, XRY) is unimplemented.

| Upstream file | → lib/*.rb (proposed) | Kind | Exists |
|---|---|---|---|
| `graphs/file_import/dialog.vala`, `data/ui/import/dialog.blp` | `lib/file_import/dialog.rb` | import dialog (file picker + settings) | **Missing** |
| `graphs/file_import/file_import.vala` | `lib/file_import/file_import.rb` | import orchestration/dispatch | **Missing** |
| `data/ui/import/file-row.blp` | `lib/file_import/file_row.rb` | one file row in the import dialog | **Missing** |
| `data/ui/import/columns/box.blp` | `lib/file_import/parsers/columns/box.rb` | columns-parser settings box | **Missing** |
| `data/ui/import/columns/item-group.blp` | `lib/file_import/parsers/columns/item_group.rb` | per-item column mapping group | **Missing** |
| `data/ui/import/columns/main-group.blp` | `lib/file_import/parsers/columns/main_group.rb` | columns main settings group | **Missing** |
| `graphs/file_import/parsers/columns/main.vala`, `reader.vala`, `ui.vala` | `lib/file_import/parsers/columns/{main,reader,ui}.rb` | columns parser (delimited text) | **Missing** |
| `data/ui/import/spreadsheet/box.blp`, `item-group.blp`, `main-group.blp` | `lib/file_import/parsers/spreadsheet/*.rb` | spreadsheet-parser settings UI | **Missing** |
| `graphs/file_import/parsers/spreadsheet/main.vala`, `reader.vala`, `ui.vala` | `lib/file_import/parsers/spreadsheet/{main,reader,ui}.rb` | spreadsheet parser | **Missing** |
| `data/ui/import/sql/main-group.blp` | `lib/file_import/parsers/sql/main_group.rb` | SQL-parser settings UI | **Missing** |
| `graphs/file_import/parsers/sql/main.vala`, `reader.vala`, `ui.vala` | `lib/file_import/parsers/sql/{main,reader,ui}.rb` | SQL parser | **Missing** |
| `graphs/file_import/parsers/xry/parser.vala` | `lib/file_import/parsers/xry/parser.rb` | XRY parser (no dedicated UI) | **Missing** |
| `graphs/file_import/parsers/project/__init__.py` | `lib/file_import/parsers/project.rb` | native `.graphs` project import | **Missing** |
| `graphs/file_import/parsers/xrdml/__init__.py` | `lib/file_import/parsers/xrdml.rb` | XRDML parser | **Missing** |

## Style editor window — **entirely missing from `lib/`**

Covered above under "Figure settings & styling"; summarized again here
because it is a second full top-level window with no port counterpart:
`window.blp`/`.vala`, `editor-box.blp`, `add-style.blp`, `color-group.blp`,
`item-color-row.blp`, `shortcuts.blp`, `style-preview.blp`, plus
`graphs/style_editor/editor_box.py`.

## Non-widget data/config (GSettings, GResource, metadata)

| Upstream file | Port equivalent | Exists |
|---|---|---|
| `data/se.sjoerd.Graphs.gschema.xml` | `lib/settings.rb` | Settings wrapper exists; confirm schema keys have 1:1 coverage during a parity pass |
| `data/se.sjoerd.Graphs.metainfo.xml.in`, `.desktop.in`, `.service.in`, `.mime.xml` | — | Not a widget; app packaging metadata, out of scope for this inventory |
| `data/generate_gresource.py`, `data/meson.build` | — | build-time only, N/A for Ruby port |
| `data/style.css` | `lib/style.css` | Yes (present; byte-for-byte parity not checked here) |
| `data/styles/*.mplstyle` | — | Not found under `lib/` or `data/` on `ruby`; matplotlib style presets used by the style editor/canvas — **Missing** (depends on style-editor + canvas style-loading support) |

## Help / documentation

| Upstream | Port | Exists |
|---|---|---|
| `help/C/*.page` (curve-fitting, edit-item, edit-style, export, figure-settings, import, manipulate, projects, window, index) | — | **Missing** — no in-app help pages ported; not a widget component per se but is user-facing documentation content |

## Translations

| Upstream | Port | Exists |
|---|---|---|
| `po/*.po` (30 locale catalogues + `LINGUAS`, `POTFILES.in`) | — | No `po/` directory found on `ruby`. Translation parity is tracked separately (see `translation-parity` skill); flagged here only as a gap, not scored. |

## Summary

- **Fully ported, by file-name correspondence:** application shell, window,
  shortcuts dialog, canvas, item model (all 5 item kinds + factory + item
  box), full edit-item sidebar box set, main sidebar + operations panel,
  figure-settings page, color button/row/swatch, curve fitting (+ dialog),
  transform/generate-data/add-equation/add-fill/smoothen dialogs, export
  figure/items, all 7 alert/confirmation dialogs, math parser pipeline.
- **Two whole subsystems are unported:**
  1. **File import** (`graphs/file_import/**`, `data/ui/import/**`) — no
     `lib/file_import` tree exists; columns/spreadsheet/SQL/XRY/XRDML/project
     parsers and their settings UI are all absent.
  2. **Style editor window** (`graphs/style_editor/**`,
     `data/ui/style-editor/**`, `data/ui/style-preview.blp`, and the
     style-page tab of figure-settings) — no standalone style-editor window,
     add-style dialog, color-group/item-color-row widgets, or style preview
     exist in `lib/`.
- Smaller gaps: `migrate.py` (legacy project migration logic), the
  `.mplstyle` preset files, help pages, and `po/` translations.
