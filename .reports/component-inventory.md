# Graphs — upstream component inventory

Upstream ref: `origin/main` (Vala + Python + blueprint, GTK4/Libadwaita).
Port branch: `ruby`. Survey only — no app code written in this step.

Upstream splits almost every component across two files: a `.vala` class
carrying `[GtkTemplate (ui = …)]`, `[GtkChild]` fields and callbacks, and a
`data/ui/**.blp` holding the widget tree, CSS classes and `=> $handler`
signal wiring. The component is the pair; each pair becomes one `lib/*.rb`.

Port layout follows the pilot (`gnome-contacts-rb`): flat `lib/<thing>.rb`
with `lib/graphs/application.rb` for the application object and `lib/graphs.rb`
as the entry require.

## Port status on `ruby` (re-checked at survey time)

`lib/` now holds 36 files. The models, the math parser, the canvas and the
first slice of the window chrome are written; everything else below is still
missing. Presence here means *a `lib/*.rb` file exists for that component* —
not that it is at parity.

### UI components — 49 in all, 10 present

| Upstream | → `lib/` | Kind | Present |
|---|---|---|:-:|
| `graphs/application.vala` | `graphs/application.rb` | application | yes |
| `graphs/actions.vala` | `actions.rb` | actions | yes |
| `graphs/window.vala` + `window.blp` | `window.rb` | window | yes |
| `data/ui/window-shortcuts.blp` | `shortcuts_dialog.rb` | shortcuts dialog | yes |
| `graphs/sidebar/main.vala` + `sidebar/main.blp` | `main_sidebar_page.rb` | navigation page | yes |
| `graphs/item_box.vala` + `item-box.blp` | `item_box.rb` | list row | yes |
| `graphs/sidebar/operations.vala` + `sidebar/operations.blp` | `operations_panel.rb` | panel | no |
| `graphs/sidebar/edit_item/page.vala` + `edit-item/page.blp` | `edit_item_page.rb` | navigation page | no |
| `graphs/sidebar/edit_item/base_box.vala` + `base.blp` | `edit_item_base_box.rb` | preferences box | no |
| `graphs/sidebar/edit_item/data_box.vala` + `data.blp` | `edit_item_data_box.rb` | preferences box | no |
| `graphs/sidebar/edit_item/equation_group.vala` + `equation-group.blp` | `edit_item_equation_group.rb` | preferences group | no |
| `graphs/sidebar/edit_item/equation_box.vala` + `equation.blp` | `edit_item_equation_box.rb` | preferences box | no |
| `graphs/sidebar/edit_item/generated_data_box.vala` + `generated-data.blp` | `edit_item_generated_data_box.rb` | preferences box | no |
| `graphs/sidebar/edit_item/fill_box.vala` + `fill.blp` | `edit_item_fill_box.rb` | preferences box | no |
| `graphs/sidebar/edit_item/errorbar_group.vala` + `errorbar-group.blp` | `edit_item_errorbar_group.rb` | preferences group | no |
| `graphs/sidebar/figure_settings.vala` (`FigureSettingsPage`) + `settings-page.blp` | `figure_settings_page.rb` | navigation page | no |
| `graphs/sidebar/figure_settings.vala` (`StylePage`) + `style-page.blp` | `style_page.rb` | navigation page | no |
| `graphs/add_equation.vala` + `add-equation.blp` | `add_equation_dialog.rb` | dialog | yes |
| `graphs/add_fill.vala` + `add-fill.blp` | `add_fill_dialog.rb` | dialog | no |
| `graphs/generate_data.vala` + `generate-data.blp` | `generate_data_dialog.rb` | dialog | no |
| `graphs/transform.vala` + `transform.blp` | `transform_dialog.rb` | dialog | no |
| `graphs/export_figure.vala` + `export-figure.blp` | `export_figure_dialog.rb` | dialog | no |
| `graphs/smoothen_settings.vala` + `smoothen-settings.blp` | `smoothen_dialog.rb` | dialog | no |
| `graphs/curve_fitting.vala` + `curve-fitting.blp` | `curve_fitting_dialog.rb` | dialog | no |
| `graphs/curve_fitting.vala` (`FittingParameterBox`) + `fitting-parameters.blp` | `fitting_parameter_box.rb` | widget | no |
| `graphs/file_import/dialog.vala` (`ImportDialog`) + `import/dialog.blp` | `import_dialog.rb` | dialog | no |
| `graphs/file_import/dialog.vala` (`ImportFileRow`) + `import/file-row.blp` | `import_file_row.rb` | list row | no |
| `file_import/parsers/columns/ui.vala` + `import/columns/box.blp` | `columns_import_box.rb` | widget | no |
| `file_import/parsers/columns/ui.vala` + `import/columns/main-group.blp` | `columns_import_group.rb` | preferences group | no |
| `file_import/parsers/columns/ui.vala` + `import/columns/item-group.blp` | `columns_item_group.rb` | preferences group | no |
| `file_import/parsers/spreadsheet/ui.vala` + `import/spreadsheet/box.blp` | `spreadsheet_import_box.rb` | widget | no |
| `file_import/parsers/spreadsheet/ui.vala` + `import/spreadsheet/main-group.blp` | `spreadsheet_import_group.rb` | preferences group | no |
| `file_import/parsers/spreadsheet/ui.vala` + `import/spreadsheet/item-group.blp` | `spreadsheet_item_group.rb` | preferences group | no |
| `file_import/parsers/sql/ui.vala` + `import/sql/main-group.blp` | `sql_import_group.rb` | preferences group | no |
| `graphs/style_editor/window.vala` + `style-editor/window.blp` | `style_editor_window.rb` | window | no |
| `data/ui/style-editor/shortcuts.blp` | `style_editor_shortcuts_dialog.rb` | shortcuts dialog | no |
| `graphs/style_editor/editor_box.vala` + `editor-box.blp` | `style_editor_box.rb` | preferences box | no |
| `graphs/style_editor/color_group.vala` + `color-group.blp` | `style_color_group.rb` | preferences group | no |
| `graphs/style_editor/item_color_row.vala` + `item-color-row.blp` | `style_item_color_row.rb` | list row | no |
| `graphs/style_editor/add_style.vala` + `add-style.blp` | `add_style_dialog.rb` | dialog | no |
| `graphs/color_button.vala` + `color-button.blp` | `color_button.rb` | widget | yes |
| `graphs/color_row.vala` + `color-row.blp` | `color_row.rb` | list row | no |
| `graphs/color_swatch.vala` (no `.blp`) | `color_swatch.rb` | widget | yes |
| `graphs/styles.vala` (`StylePreview`) + `style-preview.blp` | `style_preview.rb` | widget | no |
| `data/ui/dialogs/beta-disallowed.blp` | `alert_dialogs.rb` | alert dialog | no |
| `data/ui/dialogs/delete-style.blp` | `alert_dialogs.rb` | alert dialog | no |
| `data/ui/dialogs/invalid-project.blp` | `alert_dialogs.rb` | alert dialog | no |
| `data/ui/dialogs/legacy-migration-disallowed.blp` | `alert_dialogs.rb` | alert dialog | no |
| `data/ui/dialogs/reset-import-settings.blp` | `alert_dialogs.rb` | alert dialog | no |
| `data/ui/dialogs/save-project-changes.blp` | `alert_dialogs.rb` | alert dialog | no |
| `data/ui/dialogs/save-style-changes.blp` | `alert_dialogs.rb` | alert dialog | no |
| `graphs/canvas/canvas.vala` + `canvas.py`/`figure.py`/`artist.py`/`scales.py` | `canvas.rb` | widget | yes |

### Non-UI port units

| Upstream | → `lib/` | Present |
|---|---|:-:|
| `graphs/data.vala` + `data.py` | `data.rb` | yes |
| `graphs/figure_settings.vala` | `figure_settings.rb` | yes |
| `graphs/item/*.vala` | `item/*.rb` (`base`, `data_item`, `data_holder`, `equation_item`, `generated_data_item`, `text_item`, `factory`) | yes — `fill_item.vala` has no `lib/item/fill_item.rb` |
| `graphs/styles.vala` + `styles.py` + `style_io.py` | `styles.rb` | yes |
| `graphs/misc.vala` | `enums.rb` | yes |
| `graphs/math_parser/*.vala` + `array_evaluator.c` | `math_parser/*.rb` | yes |
| `graphs/utilities.vala`/`.py`/`.c`, `math_utilities.vala` | `utilities.rb` | yes |
| `data/se.sjoerd.Graphs.gschema.xml` | `settings.rb` | yes |
| `data/style.css` | `style.css` | yes |
| `graphs/operations.py` | `operations.rb` | no |
| `graphs/project.vala` + `project.py` + `migrate.py` | `project.rb` | no |
| `graphs/export_items.vala` | `export_items.rb` | no |
| `graphs/file_import/file_import.vala`, `parsers/*/main.vala`, `parsers/*/reader.vala`, `xry/parser.vala`, `xrdml/__init__.py` | `file_import/*.rb` | no |
| `graphs/curve_fitting.py` (the fitting maths) | `curve_fitting.rb` | no |
| `data/icons/*.svg` (26 custom symbolics + the source SVG) | `data/icons/` | no — only `hicolor/` is present |
| `data/styles/*.mplstyle` (17) | `data/styles/` | yes — all 17 copied |
| `po/` (28 catalogues) | `po/` | no |
| `help/C/*.page` (10 pages) | `help/` | no |
| `graphs/managed_array.vala`, `bindings.vala`, `python_helper.vala`/`.py`, `config.vala.in`, `graphs.c` | — | n/a, Vala↔Python glue |

The port also carries two files with no single upstream counterpart:
`lib/properties.rb` (the GObject property/signal helper the house style uses in
place of Vala's `[GtkChild]`/`notify`) and `lib/math_parser/functions.rb`
(the function table split out of upstream's evaluator).

## Application and global actions

### `graphs/application.vala` + `graphs/actions.vala` → `lib/graphs/application.rb`, `lib/actions.rb`

No widget tree of its own; holds the app-level actions, their accelerators,
the About dialog and the two window factories.

| Action | Accel | Effect |
|---|---|---|
| `app.quit` | `<control>q` | quit, after unsaved-changes prompts |
| `app.about` | — | `Adw.AboutDialog`: name "Graphs", developers, designers, GPL-3.0, release notes loaded from the `whats_new` resource, `translator-credits` |
| `app.help` | `F1` | launches `help:graphs` |
| `app.new-window` | `<control><shift>N` | `create_main_window` + present |
| `app.style-editor` | — | `create_style_editor` + present |

Window actions (installed per `Window` by `Actions.setup_local`, all `win.`):
`toggle-sidebar` (enabled-bound to `overlay_split_view.collapsed`),
`mode-pan` / `mode-zoom` / `mode-select` (generated from the `Mode` enum —
names come from `value_nick`, so they are invisible to any grep),
`center` and `smoothen` (stateful, created from the
`se.sjoerd.Graphs.actions` GSettings child), `perform_operation` (string
target), `optimize-limits`, `smoothen-settings`, `select-all`, `select-none`,
`undo`, `redo`, `view-back`, `view-forward` (enabled-bound to
`data.can_view_back/forward`), `delete-selected` (raises an undo toast
"Deleted %s"), `save-project`, `save-project-as` (both start disabled),
`open-project`, `close-project`, `add-data`, `export-data`, `figure-settings`,
`add-equation`, `generate-data`, `add-fill`, `export-figure`, `zoom-in`,
`zoom-out` (inert stubs the canvas handles), `show-shortcuts`.
Many are `bind_property ("is_main_view", …, "enabled")` — the sensitivity
rules are part of the component.

Style-editor window actions (`win.`): `save-style`, `save-style-as`,
`open-style`, `close-style`, `import-style`, `create-style`, `show-shortcuts`.

Per-style-preview action group `style.`: `open`, `open_with`, `delete`.
Per-item-row action group `item_box.`: `delete`, `curve_fitting`, `move_up`,
`move_down`.

## Main window

### `graphs/window.vala` + `data/ui/window.blp` → `lib/window.rb`

`Adw.ApplicationWindow`, 1200×700. Five `Adw.Breakpoint`s driving the
adaptive layout, a `ShortcutController` with 25 shortcuts, and a drag-and-drop
import overlay.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Overlay` `drag_overlay` | 1 | `drag-overlay` | — | hosts the drop target |
| `Gtk.Revealer` `drag_revealer` | 1 | — | — | crossfade, `can-target: false` |
| `Adw.StatusPage` (drop) | 1 | `drag-overlay-status-page` | — | "Drop Here to Import", `list-add-symbolic` |
| `Adw.OverlaySplitView` `overlay_split_view` | 1 | — | show/hide gestures bound to `collapsed` | |
| `Adw.NavigationView` `sidebar_navigation_view` | 1 | — | — | holds `main_page`, `edit_page` |
| `Adw.ToolbarView` `content_view` | 1 | `canvas-view` | — | |
| `Adw.HeaderBar` | 2 | — | — | top bar + `content_footerbar` (shown only on narrow/short breakpoints) |
| `Adw.WindowTitle` `content_title` | 1 | — | — | project name / unsaved marker |
| `Gtk.ToggleButton` (sidebar) | 1 | — | bidirectional bind to `show-sidebar` | `sidebar-show-symbolic`, visible only when collapsed |
| `Gtk.Button` | 10 | — | `win.undo`, `win.redo`, `win.optimize-limits`, `win.view-forward`, `win.view-back` | five in the header bar, the same five mirrored in the footer bar |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | — | undo toasts, import toasts |
| `Adw.StatusPage` (canvas fallback) | 1 | — | — | "Canvas Failed to Load", `dialog-error-symbolic` |

Shortcuts: `<control>w` close, `<control>question` shortcuts, `<control>comma`
figure settings, `<control>N` add data, `<control><alt>N` add equation,
`<control><shift>N` generate data / new project, `<control>A` select all,
`<control><shift>A` select none, `<control>Z` undo, `<control><shift>Z` redo,
`<control>0`/`<control>KP_0` optimize limits, `<alt>Z` / `<alt><shift>Z` view
back/forward, `<control><shift>E` export data, `<control>E` export figure,
`<control>period` styles, `<control>S` save project, `<control><shift>S` save
as, `<control>O` open project, `Delete` delete selected,
`<control>plus|KP_Add|equal|ZoomIn` zoom in, `<control>minus|KP_Subtract|ZoomOut`
zoom out, `F9` toggle sidebar, `<control>1/2/3` pan/zoom/select mode.

### `data/ui/window-shortcuts.blp` → `lib/shortcuts_dialog.rb`

Standalone `Adw.ShortcutsDialog` (no backing source file; loaded by
`win.show-shortcuts` from the resource). Six `Adw.ShortcutsSection`s —
General (5 items), Mode Switching (3), New Data (6), Save and Export (4),
View (7), Actions (4) — 29 `Adw.ShortcutsItem`s in all.

## Sidebar

### `graphs/sidebar/main.vala` + `data/ui/sidebar/main.blp` → `lib/main_sidebar_page.rb`

`Adw.NavigationPage` titled "Graphs" — the item list, the mode buttons and the
two menus.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.HeaderBar` | 1 | — | — | |
| `Gtk.MenuButton` `add_button` | 1 | — | `add_data_menu` | `list-add-symbolic`, always-show-arrow |
| `Gtk.MenuButton` (primary) | 1 | — | `primary_menu` | `open-menu-symbolic` |
| `Gtk.Button` `figure_settings_button` | 1 | — | `win.figure-settings` | `settings-symbolic` |
| `Gtk.Stack` `itemlist_stack` | 1 | — | — | empty state ↔ list |
| `Adw.StatusPage` (empty) | 1 | `compact` | — | "No Data" / "Add data from a file or manually as an equation", `list-compact` |
| `Gtk.ListBox` `item_list` | 1 | `boxed-list` | — | **repeater**: one `ItemBox` per item in `Data` |
| `Gtk.ToggleButton` | 3 | — | `win.mode-pan`, `win.mode-zoom`, `win.mode-select` | `move-tool-symbolic`, `loupe-symbolic`, `edit-select-all-symbolic`, each with a tooltip |
| `Gtk.Separator` | 2 | — | — | |
| `Adw.Bin` `operations_bin` | 1 | — | — | hosts `Operations` |

`primary_menu`: New Project · Save Project… / Save Project as… / Open
Project… / Close Project · Export Data… / Export Figure… · Style Editor ·
Keyboard Shortcuts / Help / About Graphs (12 items, 5 sections).
`add_data_menu`: Add Data from File… / Add Equation… / Add Fill… / Generate
Data… (4 items).

### `graphs/item_box.vala` + `data/ui/item-box.blp` → `lib/item_box.rb`

One row per data item. `Adw.ActionRow`, activatable, `title-lines: 1`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.CheckButton` `check_button` | 1 | `selection-mode` | `notify::active` → `on_toggle` | prefix |
| `GraphsColorButton` `color_button` | 1 | `flat` | `color-chosen` → `on_color` | composite, see `lib/color_button.rb` |
| `Gtk.MenuButton` | 1 | `flat` | `item_menu` via `Gtk.PopoverMenu` (`has-arrow: false`) | `view-more-symbolic` |

`item_menu`: inline-buttons section "Move Item" with `down-symbolic` /
`up-symbolic` (`item_box.move_down`, `item_box.move_up`), then Curve Fitting
and Remove Item. Move actions are installed only when the item is not at the
list edge — conditional components.

### `graphs/sidebar/operations.vala` + `data/ui/sidebar/operations.blp` → `lib/operations_panel.rb`

`Gtk.Box` with an `Adw.InlineViewSwitcher` over an `Adw.ViewStack` of three
pages. Every button fires `perform_operation`; the handler reads which button.

- **Adjust**: `Gtk.Button` ×4 — Combine (`edit-paste-symbolic`), Cut
  (`edit-cut-symbolic`), Shift (`shift-symbolic`), Normalize
  (`normalize-symbolic`); `Adw.SplitButton` ×2 — Smoothen
  (`smoothen-symbolic`, `smoothen_menu`), Center (`center-symbolic`,
  `center_menu`). Sensitivity of Combine/Normalize/Center is bound to
  `shift_button.sensitive`.
- **Transform**: `Gtk.Button` ×5 — Derivative (`derivative2-symbolic`),
  Integral (`integral-symbolic`), FFT (`fast-fourier-transform-symbolic`),
  Inverse FFT (`inverse-fast-fourier-transform-symbolic`), Custom
  Transformation (`transform-symbolic`).
- **Modify**: `Gtk.Entry` ×4 (default "10") paired with `Gtk.Button` ×4 —
  Translate X / Translate Y / Multiply X / Multiply Y
  (`horizontal-arrows-symbolic`, `vertical-arrows-symbolic`).

`center_menu`: At Maximum Y Value / At Middle X Value (`win.center`, targets
`max-y`, `middle-x`). `smoothen_menu`: Savitzky–Golay Filter / Moving Average
(`win.smoothen`, targets `savgol`, `moving-average`) + Advanced Settings
(`win.smoothen-settings`).

### `graphs/sidebar/edit_item/page.vala` + `data/ui/sidebar/edit-item/page.blp` → `lib/edit_item_page.rb`

`Adw.NavigationPage` "Edit Item": header bar, scrolled viewport, and
`edit_item_box` — a vertical box filled at runtime with the per-kind boxes
below. Which boxes appear depends on the item type: a component boundary, not
a fixed tree.

### `graphs/sidebar/edit_item/base_box.vala` + `base.blp` → `lib/edit_item_base_box.rb`

Group "Name and Position": `Adw.EntryRow` Name, `Adw.SwitchRow` "Show in
Legend" (hidden unless the item is legendable), `Adw.ComboRow` X-Axis Position
(Bottom/Top), `Adw.ComboRow` Y-Axis Position (Left/Right).

### `graphs/sidebar/edit_item/data_box.vala` + `data.blp` → `lib/edit_item_data_box.rb`

Group "Line and Markers": `Adw.ComboRow` Linestyle (5 values, `on_linestyle`),
`Adw.ActionRow` + `Gtk.Scale` Linewidth (0–10, starts insensitive),
`Adw.ComboRow` Markers (22 values, `on_markers`), `Adw.ActionRow` +
`Gtk.Scale` Marker Size (0–20). Group `downsample_group` (hidden by default)
with `Adw.SwitchRow` "Reduce Detail".

### `graphs/sidebar/edit_item/equation_group.vala` + `equation-group.blp` → `lib/edit_item_equation_group.rb`

`Adw.PreferencesGroup` "Equation": `Adw.EntryRow` "Y =" (`notify::text` →
`on_equation_change`, `apply` → `on_equation_apply`) and `Adw.ButtonRow`
Simplify (`on_simplify`). Reused by the equation and generated-data boxes.

### `graphs/sidebar/edit_item/equation_box.vala` + `equation.blp` → `lib/edit_item_equation_box.rb`

`EditItemEquationGroup` + group "Line" with `Adw.ComboRow` Linestyle (4
values — no "None") and a Linewidth scale.

### `graphs/sidebar/edit_item/generated_data_box.vala` + `generated-data.blp` → `lib/edit_item_generated_data_box.rb`

`EditItemEquationGroup` + X Start / X Stop `Adw.EntryRow`s (`on_entry_change`,
`on_entry_apply`), `Adw.SpinRow` Steps (2–1e9, `input` → `on_steps_input`),
`Adw.ComboRow` Scale (6 values).

### `graphs/sidebar/edit_item/fill_box.vala` + `fill.blp` → `lib/edit_item_fill_box.rb`

Group "Fill": `Adw.ComboRow` Upper Bound + `Adw.EntryRow` "Y ="
(`on_upper_change`), the same pair for Lower Bound (`on_lower_change`),
`Adw.ActionRow` + `Gtk.Scale` Opacity (0–1, 2 digits).

### `graphs/sidebar/edit_item/errorbar_group.vala` + `errorbar-group.blp` → `lib/edit_item_errorbar_group.rb`

Group "Error Bars": `Adw.SwitchRow` Show Horizontal / Show Vertical (both
hidden until the item has that error column), `Adw.SwitchRow` Draw Above Data,
`GraphsColorRow` Color, and `Gtk.Scale` rows Cap Length (0–12), Cap Thickness
(0–10), Line Width (0–10).

### `graphs/sidebar/figure_settings.vala` (`FigureSettingsPage`) + `figure-settings/settings-page.blp` → `lib/figure_settings_page.rb`

`Adw.NavigationPage` "Figure Settings". The largest single tree in the app.

- Group "Labels": `Adw.EntryRow` ×5 — Title, plus Bottom/Top X and Left/Right
  Y axis labels, each hidden unless an item uses that axis.
- Group "Axis Limits": four `Gtk.Box`es (`bottom_limits`, `top_limits`,
  `left_limits`, `right_limits`, all hidden by default) each holding two
  `Adw.EntryRow`s — minimum and maximum — all eight on
  `on_limit_entry_change`.
- Group "Scaling": `Adw.ComboRow` ×4 (one per axis, hidden by default), each
  with the 6-value scale model.
- Group "Appearance": `Adw.SwitchRow` Show Legend, `Adw.ComboRow` Legend
  Position (10 values, sensitivity bound to the switch), `Adw.SwitchRow` Hide
  Unselected Items, and an activatable `Adw.ActionRow` "Style" (suffix
  `Gtk.Label` `style_name` + `go-next-symbolic` image) → `open_style_page`.
- `Adw.ButtonRow` "Set as Default" → `set_as_default`.

### `graphs/sidebar/figure_settings.vala` (`StylePage`) + `figure-settings/style-page.blp` → `lib/style_page.rb`

`Adw.NavigationPage` "Style": header-bar `Gtk.Button` "Manage"
(`app.style-editor`) and a `Gtk.GridView` `style_grid` (`style-grid` CSS,
2 columns) whose factory builds `StylePreview` items — a repeater over
`StyleManager.filtered_style_model`.

## Dialogs

### `graphs/add_equation.vala` + `data/ui/add-equation.blp` → `lib/add_equation_dialog.rb`

`Adw.Dialog` "Add Equation", 450 wide. Header bar: Cancel (`window.close`) and
`confirm_button` "Add" (`suggested-action`, `on_accept`). Group with
description "Enter a mathematical expression": `Adw.EntryRow` "Y ="
(`preferencesgroup` CSS, `notify::text` → `on_equation_change` — validates and
toggles the confirm button) and `Adw.EntryRow` "Name (optional)".

### `graphs/add_fill.vala` + `data/ui/add-fill.blp` → `lib/add_fill_dialog.rb`

`Adw.Dialog` "Add Fill". Confirm button "Add" starts insensitive. Two
`Adw.ComboRow` + `Adw.EntryRow` pairs (Upper Bound / Lower Bound,
`on_upper_change` / `on_lower_change`) and a Name row.

### `graphs/generate_data.vala` + `data/ui/generate-data.blp` → `lib/generate_data_dialog.rb`

`Adw.Dialog` "Generate Data". Confirm "Generate". `Adw.EntryRow` "Y ="
(`on_equation_change`), Name, X Start / X Stop (`on_entry_change`),
`Adw.SpinRow` Steps (2–1e9, `on_steps_input`), `Adw.ComboRow` Scale (6
values).

### `graphs/transform.vala` + `data/ui/transform.blp` → `lib/transform_dialog.rb`

`Adw.Dialog` "Transform Data". Confirm "Transform"; header-bar
`Gtk.MenuButton` (`info-symbolic`) with a `Gtk.Popover` documenting the
available variables (markup). Rows: `Adw.EntryRow` "X =",
`Adw.EntryRow` "Y =", `Adw.SwitchRow` "Discard Unselected Data".

### `graphs/export_figure.vala` + `data/ui/export-figure.blp` → `lib/export_figure_dialog.rb`

`Adw.Dialog` "Export Figure". Confirm "Export". Group "Export Settings":
`Adw.ComboRow` File Format (7 values), `Adw.SwitchRow` Transparent Background.
Group "Export Size": `Adw.SpinRow` Width (100–7680, step 10), Height
(100–4320), `Adw.ButtonRow` "Use Same Size as App" → `on_use_window_size`.

### `graphs/smoothen_settings.vala` + `data/ui/smoothen-settings.blp` → `lib/smoothen_dialog.rb`

`Adw.Dialog` "Smoothen Settings", 640×576. Header-bar reset `Gtk.Button`
(`history-undo-symbolic`, `on_reset`). Group "Savitzky–Golay Filter":
`Adw.SpinRow` Span percentage (≤99), Polynomial degree (≤20). Group "Moving
Average": `Adw.SpinRow` Box points (≤9999).

### `graphs/curve_fitting.vala` + `graphs/curve_fitting.py` + `data/ui/curve-fitting.blp` → `lib/curve_fitting_dialog.rb`

`Adw.Dialog` 1000×600 — effectively a second window. `ShortcutController`
with `F9` → `win.toggle_sidebar`; two `Adw.Breakpoint`s (collapse the split
view under 675sp, shrink the residuals pane under 500sp height).

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.OverlaySplitView` `split_view` | 1 | — | gestures bound to `collapsed` | |
| `Adw.HeaderBar` | 2 | — | — | sidebar + canvas side |
| `Adw.WindowTitle` | 1 | — | — | "Curve Fitting" |
| `Gtk.MenuButton` | 1 | — | `fitting_menu` | `view-more-symbolic` |
| `Adw.ComboRow` `equation` | 1 | — | — | 8 regression types incl. Custom |
| `Adw.EntryRow` `custom_equation` | 1 | — | — | hidden unless Custom |
| `Gtk.Box` `fitting_params_box` | 1 | — | — | **repeater**: one `FittingParameterBox` per free parameter |
| `Gtk.TextView` `text_view` | 1 | `card` | — | fit results, read-only |
| `Gtk.Button` `confirm_button` | 1 | `pill`, `suggested-action` | `on_accept` | "Add Fit to Data" |
| `Gtk.ToggleButton` `show_sidebar_button` | 1 | — | bidirectional `show-sidebar` | visible when collapsed |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | — | |
| `Adw.Bin` `canvas_container` | 1 | — | — | holds the canvas; `Adw.StatusPage` "Canvas Failed to Load" fallback |
| `Adw.Bin` `residuals_container` | 1 | — | — | hidden until "Show Residuals" |

`fitting_menu`: Optimization Method — Levenberg-Marquardt / Trust Region
Reflective / Dogbox (`win.optimization`, targets `lm`/`trf`/`dogbox`);
Confidence Bounds — None / 1σ / 2σ / 3σ (`win.confidence`, targets
`none`/`1std`/`2std`/`3std`); Show Residuals (`win.show-residuals`).

### `graphs/curve_fitting.vala` (`FittingParameterBox`) + `data/ui/fitting-parameters.blp` → `lib/fitting_parameter_box.rb`

`Gtk.Box` in a 2-column `Gtk.Grid`: a markup `Gtk.Label`, `Adw.EntryRow`
Initial Guess (default "1"), and Minimum / Maximum `Adw.EntryRow`s (defaults
"-inf" / "inf") whose groups' visibility is bound to the rows.

## Import

### `graphs/file_import/dialog.vala` (`ImportDialog`) + `data/ui/import/dialog.blp` → `lib/import_dialog.rb`

`Adw.Dialog` 900×576 with an `Adw.NavigationSplitView` (collapsing breakpoint
at 500sp).

- Sidebar page "Import Parameters": header-bar `Gtk.Button` "Add File"
  (`list-add-symbolic`, `on_add`), `Gtk.ListBox` `file_list`
  (`navigation-sidebar`, single selection, `row-activated` → `on_row_activated`,
  `row-selected` → `on_row_selected`) — a repeater over the import settings
  list — and `Gtk.Button` "Import" (`suggested-action pill`, `on_accept`).
- Content page: header-bar `Gtk.Button` "Reset to guessed values"
  (`history-undo-symbolic`, `on_reset`), `Adw.ToastOverlay`, `Adw.ComboRow`
  Import Mode (`on_mode`), `file_settings_box` filled with the per-parser box
  below, `Adw.ButtonRow` "Set as Default" (`set_as_default`) and
  `Adw.ButtonRow` "Remove" (`destructive-action`, `remove`).

### `graphs/file_import/dialog.vala` (`ImportFileRow`) + `data/ui/import/file-row.blp` → `lib/import_file_row.rb`

`Gtk.ListBoxRow`, activatable: `Gtk.Label` filename (ellipsized) and
`Gtk.Label` mode with the `import-mode` CSS class.

### `graphs/file_import/parsers/columns/ui.vala` + `import/columns/box.blp`, `main-group.blp`, `item-group.blp` → `lib/columns_import_box.rb`, `lib/columns_import_group.rb`, `lib/columns_item_group.rb`

- `ColumnsBox`: `items_box` (repeater of item groups) + `Adw.ButtonRow`
  "Add Item" → `add`.
- `ColumnsGroup` "Format": `Adw.ComboRow` Delimiter (7 values),
  `Adw.EntryRow` Custom Delimiter (insensitive until Custom) with an
  `info-symbolic` `Gtk.MenuButton` popover explaining regex,
  `Adw.ComboRow` Decimal Separator (2 values), `Adw.SpinRow` Skip Rows
  (0–9999).
- `ColumnsItemGroup`: header-suffix remove `Gtk.Button`
  (`flat destructive-action`, `user-trash-symbolic`, `on_remove`),
  `Adw.SpinRow` X/Y Column (0–100), `Adw.SwitchRow` "Y Values Only",
  `Adw.EntryRow` Equation (default "n") with an `info-symbolic` popover,
  `Adw.SwitchRow` X/Y Error Bars, `Adw.SpinRow` X/Y Error Column — the error
  spin rows' sensitivity bound to the switches.

### `graphs/file_import/parsers/spreadsheet/ui.vala` + `import/spreadsheet/*.blp` → `lib/spreadsheet_import_box.rb`, `lib/spreadsheet_import_group.rb`, `lib/spreadsheet_item_group.rb`

Same shape as the columns parser (column ranges 0–16383, "Single Column"
instead of "Y Values Only") plus `SpreadsheetGroup` "Spreadsheet" with an
`Adw.ComboRow` Sheet selector.

### `graphs/file_import/parsers/sql/ui.vala` + `import/sql/main-group.blp` → `lib/sql_import_group.rb`

`Adw.PreferencesGroup`: `Adw.ComboRow` Database Table (`on_table_changed`),
Column X / Column Y (`on_columns_changed`), `Adw.SwitchRow` X/Y Error Bars
(`on_err_toggled`), `Adw.ComboRow` X/Y Error Column (sensitivity bound to the
switches), and a hidden `Gtk.Label` "This table contains no numeric columns"
— an error state.

## Style editor

### `graphs/style_editor/window.vala` + `data/ui/style-editor/window.blp` → `lib/style_editor_window.rb`

`Adw.ApplicationWindow` "Graphs Style Editor", 1200×700. `ShortcutController`
with `<control>w`, `<control>question`, `<control>S`, `<control><shift>S`,
`<control>O`. Two `Adw.Breakpoint`s switching the `Adw.MultiLayoutView`
between side-by-side and bottom-sheet layouts.

- `Gtk.Stack` page 1 — the empty state: header bar with an `open-menu-symbolic`
  `Gtk.MenuButton` (`empty_menu`); bottom bar with `pill` buttons "Import
  File…" (`win.import-style`), "Create Style…" (`pill suggested-action`,
  `win.create-style`), "Open File…" (`win.open-style`), and a
  `style_menu_button` `Gtk.MenuButton` (`pill`, `list-add-symbolic`, visible
  only on the narrow breakpoint) over `style_menu`; content is a
  `Gtk.GridView` `style_grid` (`style-grid`, max 3 columns) of style previews.
- Page 2 — the editor: `Adw.MultiLayoutView` with `Adw.Layout`
  `side_by_side_layout` and `bottom_sheet_layout`, `Adw.LayoutSlot`s
  `editor` and `canvas`, an `Adw.BottomSheet` whose bottom bar is a
  `Gtk.CenterBox` label "Open Preview", `editor_headerbar` with an
  `Adw.WindowTitle` and a primary `Gtk.MenuButton` (`primary_menu`),
  `editor_bin` holding the editor box, `content_view` (`canvas-view`) with a
  `preview-headerbar`, and `canvas_bin` whose fallback is an
  `Adw.StatusPage` "Canvas Failed to Load".

`primary_menu`: Open Style… / Save Style… / Save Style as… / Close Style… ·
New Window · Keyboard Shortcuts / Help / About Graphs. `empty_menu`: New
Window · Keyboard Shortcuts / Help / About Graphs. `style_menu`: Create
Style… / Import File… / Open File….

### `data/ui/style-editor/shortcuts.blp` → `lib/style_editor_shortcuts_dialog.rb`

Standalone `Adw.ShortcutsDialog`, two sections: General (Show Shortcuts, Open
Help, Close Application, Close Application Window `<control>w`) and Save (Save
Style `<control>S`, Save Style As `<control><shift>S`, Open Style
`<control>O`).

### `graphs/style_editor/editor_box.vala` + `editor_box.py` + `data/ui/style-editor/editor-box.blp` → `lib/style_editor_box.rb`

`Gtk.Box` of nine `Adw.PreferencesGroup`s — the whole mplstyle surface:

| Group | Contents |
|---|---|
| (unnamed) | `Adw.EntryRow` Style Name; `Adw.ActionRow` Font with a `Gtk.FontDialogButton`; Title Size and Label Size `Gtk.Scale` rows |
| Lines | `Adw.ComboRow` Linestyle (5, `on_linestyle`), Line width scale, `Adw.ComboRow` Markers (22, `on_markers`), Marker Size scale |
| Error Bars | Cap Length / Cap Thickness / Line Width scales, `Adw.SwitchRow` Draw Above Data |
| Axes | Axis Width scale, `Adw.SwitchRow` Draw Frame |
| Ticks | `Adw.ComboRow` Tick Directions (Inwards/Outwards), `Adw.SwitchRow` Minor Ticks, four tick width/length scales (minor ones sensitivity-bound to Minor Ticks), `Adw.SwitchRow` ×5 — tick labels on all axes, bottom, left, right, top |
| Grid | `Adw.SwitchRow` Show Grid, Grid Width and Grid Opacity scales bound to it |
| Padding | Value / Label / Title Padding scales with subtitles |
| Colors | header-suffix `Gtk.Box` `poor_contrast_warning` (`warning flat`, `dialog-warning-symbolic` + "Poor Contrast" — an error state), then a 2×3 `Gtk.Grid` of `GraphsColorRow`s: Text, Tick, Axis, Grid, Background, Outline |
| Line Colors / Error Bar Colors | two `GraphsStyleColorGroup` instances |

### `graphs/style_editor/color_group.vala` + `color-group.blp` → `lib/style_color_group.rb`

`Adw.PreferencesGroup` with a header-suffix `flat` `Gtk.Button`
(`Adw.ButtonContent`, `list-add-symbolic`, "Add Color", `add_color`) over a
`Gtk.ListBox` `color_box` (`boxed-list`) — a repeater of color rows.

### `graphs/style_editor/item_color_row.vala` + `item-color-row.blp` → `lib/style_item_color_row.rb`

`Adw.ActionRow`: prefix `Gtk.Image` `list-drag-handle-symbolic`
(`drag-handle`, drag-and-drop reordering), suffix `GraphsColorButton`
(`flat`, `color_chosen` → `on_color_chosen`), suffix `flat` `Gtk.Button`
with an `edit-delete-symbolic` image → `on_delete`.

### `graphs/style_editor/add_style.vala` + `add-style.blp` → `lib/add_style_dialog.rb`

`Adw.Dialog` "Add New Style": Cancel / "Add" (`suggested-action`,
`on_accept`), `Adw.ComboRow` Template (searchable,
`on_template_changed`), `Adw.EntryRow` Name.

## Shared widgets

### `graphs/color_button.vala` + `data/ui/color-button.blp` → `lib/color_button.rb`

`Gtk.Button`, tooltip "Change Color", `clicked` → `choose_color` (a
`Gtk.ColorDialog`), child `GraphsColorSwatch`; emits `color-chosen`.

### `graphs/color_row.vala` + `data/ui/color-row.blp` → `lib/color_row.rb`

`Adw.ActionRow`, activatable, tooltip "Change Color", `activated` →
`choose_color`, suffix `GraphsColorSwatch`.

### `graphs/color_swatch.vala` → `lib/color_swatch.rb`

Hand-drawn `Gtk.Widget` subclass (no `.blp`) — the color chip rendered by
`snapshot`. Used by both widgets above.

### `graphs/styles.vala` (`StylePreview`) + `data/ui/style-preview.blp` → `lib/style_preview.rb`

`Adw.Bin` → `Gtk.AspectFrame` → `Gtk.Overlay`: `Gtk.Picture` `picture` (the
rendered preview), overlay `Gtk.Image` `#indicator`
(`check-round-outline-whole-symbolic`, marks the active style), overlay
`flat` `Gtk.MenuButton` `menu_button` (`view-more-symbolic`, hidden for
system styles) over `style_menu` — Open / Open With… / Delete… on the
`style.` action group — and an ellipsized `Gtk.Label` caption.

## Alert dialogs (`data/ui/dialogs/*.blp`, no backing source file)

Loaded by name through `Tools.build_dialog`. Each becomes one
`Adwaita::AlertDialog` factory; they belong together in
`lib/alert_dialogs.rb`.

| File | Heading | Responses |
|---|---|---|
| `beta-disallowed.blp` | Beta Project | Continue / Abort (close default) |
| `delete-style.blp` | Delete Style? | Cancel / Delete (destructive, default) |
| `invalid-project.blp` | Invalid Project | Close |
| `legacy-migration-disallowed.blp` | Legacy Project | Continue (destructive) / Abort |
| `reset-import-settings.blp` | Reset to Defaults? | Cancel / Reset (destructive, default) |
| `save-project-changes.blp` | Save Changes? | Cancel / Discard (destructive, default) / Save (suggested) |
| `save-style-changes.blp` | Save Changes? | Cancel / Discard (destructive, default) / Save (suggested) |

## Canvas

### `graphs/canvas/canvas.vala` + `canvas.py` + `figure.py` + `artist.py` + `scales.py` → `lib/canvas.rb` (+ `lib/canvas_*.rb`)

`Gtk.DrawingArea` subclass. Upstream renders through Matplotlib from Python;
the port has no Matplotlib, so this is the one component that needs a design
decision before it can be ported. The GTK-visible surface is: the drawing
area itself, its `Gtk.GestureClick` / `Gtk.GestureDrag` /
`Gtk.EventControllerScroll` / `Gtk.EventControllerKey` controllers (pan, zoom
rubber-band, select rubber-band), the `mode` property driving
`win.mode-pan/zoom/select`, and the `highlight` rubber band. The
`Adw.StatusPage` "Canvas Failed to Load" in three places is its error state.

## Non-UI upstream files the components depend on

These carry no widgets but no component works without them; they are port
units in their own right.

| Upstream | → | What it is |
|---|---|---|
| `graphs/data.vala` + `data.py` | `lib/data.rb` | the item store: `ListModel` + `Gtk.SelectionModel`, undo/redo history, view history, limit optimization |
| `graphs/figure_settings.vala` | `lib/figure_settings.rb` | figure settings object + `Limits` |
| `graphs/item/base.vala`, `data_item.vala`, `equation_item.vala`, `generated_data_item.vala`, `fill_item.vala`, `text_item.vala`, `factory.vala` | `lib/item/*.rb` | the item hierarchy and its factory |
| `graphs/styles.vala` + `styles.py` + `style_io.py` | `lib/styles.rb` | `Style`, `StyleParameters`, `StyleManager`, the filtered style model, mplstyle IO |
| `graphs/misc.vala` | `lib/enums.rb` | `XPosition`, `YPosition`, `Scale`, `LegendPosition`, `ChangeType`, `Mode` — the enums every ComboRow is bound to |
| `graphs/math_parser/*.vala`, `array_evaluator.c` | `lib/math_parser/*.rb` | lexer, parser, AST, compiler, evaluator, printer for the equation entries |
| `graphs/math_utilities.vala`, `utilities.vala/.py/.c` | `lib/utilities.rb` | shared helpers, incl. `Tools.build_dialog` |
| `graphs/operations.py` | `lib/operations.rb` | the maths behind every operations-panel button |
| `graphs/project.vala` + `project.py` + `migrate.py` | `lib/project.rb` | project save/open/close, migration, validation, the parse-flag errors the alert dialogs report |
| `graphs/export_items.vala` | `lib/export_items.rb` | `win.export-data` |
| `graphs/file_import/file_import.vala`, `parsers/*/main.vala`, `*/reader.vala`, `xry/parser.vala`, `xrdml/__init__.py`, `project/__init__.py` | `lib/file_import/*.rb` | parser registry, import settings, readers |
| `graphs/managed_array.vala` | — | Vala memory plumbing; no Ruby equivalent needed |
| `graphs/bindings.vala`, `python_helper.vala/.py`, `config.vala.in`, `graphs.c` | — | Vala↔Python bridge and build glue; the port has no Python side |
| `data/se.sjoerd.Graphs.gschema.xml` | `lib/settings.rb` | 13 schemas / ~45 keys: figure defaults, add-equation, add-fill, generate-data, export-figure, curve-fitting, actions (center, smoothen, savgol/moving-average), import-params for columns/spreadsheet/sql |
| `data/style.css` | `lib/style.css` (or inline provider) | `.blurred`, `.drag-overlay`, `.drag-overlay-status-page`, `.import-mode`, `.style-grid` |
| `data/generate_gresource.py`, `data/meson.build`, `data/ui/meson.build` | — | GResource assembly; irrelevant to the port |
| `data/icons/*.svg` (20 custom symbolics) | `data/icons/` | `shift-symbolic`, `normalize-symbolic`, `smoothen-symbolic`, `center-symbolic`, `derivative2-symbolic`, `integral-symbolic`, `fast-fourier-transform-symbolic`, `inverse-fast-fourier-transform-symbolic`, `transform-symbolic`, `horizontal-arrows-symbolic`, `vertical-arrows-symbolic`, `move-tool-symbolic`, `loupe-symbolic`, `settings-symbolic`, `list-compact-symbolic`, `history-undo-symbolic`, `info-symbolic`, `up-symbolic`, `down-symbolic`, `left-symbolic`, `right-symbolic`, `check-round-outline-whole-symbolic`, `image-print-symbolic`, `axes-one-quadrant-symbolic`, `function-third-order-symbolic`, `graph-symbolic` — all referenced by the widgets above and none of them stock Adwaita |
| `data/styles/*.mplstyle` (17 files) | `data/styles/` | the bundled style list the style grid shows |
| `po/` (28 catalogues + LINGUAS + POTFILES.in) | `po/` | translations; `POTFILES.in` lists every `.blp` and source file above, so it doubles as the component checklist |
| `help/C/*.page` (10 pages) | `help/` | the user manual `app.help` opens |

## Totals

- 49 blueprint roots: 39 `template` roots (each paired with a `.vala`/`.py`
  class), 7 standalone `Adw.AlertDialog` objects and 2 standalone
  `Adw.ShortcutsDialog` objects. Plus `graphs/color_swatch.vala`, which has no
  `.blp` → **49 UI components** in the table above.
- 2 windows, 12 dialogs, 6 navigation pages, 3 menu-bearing headers,
  9 primary/section menus, 29 + 7 shortcut entries, 5 CSS classes of our own,
  26 custom icons.
- Present on `ruby`: **10 of 49** UI components, and 9 of the 18 non-UI units.
