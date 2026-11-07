# Component parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `42ff07f5` |
| Units with full four-axis parity proven | **0 / ~32 ported files** |
| Units with a widget/CSS/signal/action table built in this pass | **2** (`color_row.rb`, `sidebar/edit_item/page.rb`) — carried over unchanged from the prior pass; `curve_fitting_dialog.rb` and `project.rb`, ported since, were only spot-checked for the text axis (see below), not tabled |

## Headline finding

`component-identification.md` lists roughly 30 port files with a plausible
upstream counterpart. This pass built the four-axis comparison for **two** of
them. Both have a confirmed gap. Zero have been checked and found clean. The
runtime gate (182 checks / 30 components, see `test-parity.md`) exercises
widget *state* after an action, not CSS classes, not the full signal set, and
not the text axis at all — a check like `check("edit page shows its name",
window.edit_item_page.widget.title, "Edit Item")` is written to assert the
*English* string, so it passes whether or not that string is translatable.
That is exactly the failure mode `component-parity.md`'s Step 3 (text axis)
exists to catch, and it is why the gate's green does not mean component
parity. (This round's gate figure is `187 checks / 30 components`; see
`test-parity.md` for the recount.)

## Unit: colour row — `graphs/color_row.vala` + `data/ui/color-row.blp` → `lib/color_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ActionRow` | 1 | 1 | — (none on either side) | ✓ `activated` → `choose_color` | ✗ | **gap**: tooltip text |
| `$GraphsColorSwatch` (suffix) | 1 | 1 | — | — | — | parity |

- **Text gap.** Upstream: `tooltip-text: _("Change Color")` — marked,
  translatable. Port (`lib/color_row.rb:33`): `widget.tooltip_text = "Change
  Color"` — a bare literal, never passed to `_()`. No Ruby `gettext` call
  exists anywhere in `lib/` (confirmed in `translation-parity.md`), so this is
  not a one-off miss, it's the general state of every string in this file and
  every other port file. Recorded here against the component; recorded again
  in `translation-parity.md` against the message `Change Color`.
- Everything else about this widget is correct: same type, same suffix
  child, same signal, same handler shape (`activated` → open a colour
  dialog → report the chosen RGBA). `drive_sidebar.rb` drives it
  (`"color row widget builds"`) and only checks it *exists*, not its tooltip
  or its text.

## Unit: edit-item page — `graphs/sidebar/edit_item/page.vala` + `data/ui/sidebar/edit-item/page.blp` → `lib/sidebar/edit_item/page.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.NavigationPage` | 1 | 1 | — | — | ✗ | **gap**: title |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity (`propagate-natural-height` carried over) |
| `Gtk.Viewport` | 1 | 0 | — | — | — | **gap**: port assigns the box straight to `scrolled_window.child`, dropping the `Viewport` upstream wraps it in. Correspondence or regression — not determined; `Gtk::ScrolledWindow#child=` auto-wraps non-scrollable children in a `Gtk::Viewport` internally in GTK4, so this is *likely* a correspondence, but it has not been verified against the actual widget tree at runtime, so it is left a gap rather than asserted clean. |
| `Gtk.Box` (`edit_item_box`) | 1 | 1 | — | — | — | parity (orientation, spacing, all four margins match) |

- **Text gap.** Upstream: `title: _("Edit Item")` — marked. Port
  (`lib/sidebar/edit_item/page.rb:45`): `Adwaita::NavigationPage.new
  (toolbar_view, "Edit Item")` — bare literal. `drive_sidebar.rb` asserts
  `window.edit_item_page.widget.title == "Edit Item"` for three item kinds —
  the check is written against the untranslated string and will keep passing
  after this gap is "fixed" by marking it, and would keep passing if someone
  retyped it to `"Edit item"` with a lowercase i, which is the exact blind
  spot `component-parity.md`'s text axis exists to name.
- The seven boxes this page assembles (`base_box`, `data_box`, `equation_box`,
  `equation_group`, `errorbar_group`, `fill_box`, `generated_data_box`) are
  **not** individually tabled in this pass — `drive_sidebar.rb` only checks
  that the page "is not empty" for three item kinds, never which fields each
  box builds, their CSS, or their signals. That is seven more unchecked units
  hiding behind one green line.

## Unit: curve fitting dialog — `graphs/curve_fitting.vala`/`.py` + `data/ui/curve-fitting.blp`/`fitting-parameters.blp` → `lib/curve_fitting_dialog.rb`, `lib/curve_fitting.rb` (ported since the last pass, not yet tabled)

No widget/CSS/signal table was built for this unit — it is new since
`8930c5e3` and the four-axis comparison was not run. One text-axis spot
check, same method as the two units above: every title/label/row-title in
`lib/curve_fitting_dialog.rb` is a bare Ruby literal (`"Curve Fitting"`,
`"Cancel"`, `"Add Fit"`, `"Equation"`, `"Y ="`, `"Fitting Parameters"`,
`"Fit"`, `"Confidence Band"`, `"Fit Curve"`, `"No fit yet"` — lines 125, 139,
142, 169, 176, 182, 190, 204, 210, 220, 224, 255), matching upstream's own
strings 1:1 in English but with no `_()`/gettext call anywhere, same gap
class as `Change Color`/`Edit Item` below. This is a **gap**, not a pass —
recorded here and cross-filed in `translation-parity.md`. `test/
drive_operations.rb` drives this dialog (builds it, runs a fit, adds the
resulting items) but, consistent with every other drive check, asserts
widget *state*, never text or CSS.

## Unit: project load/save — `graphs/project.vala`/`.py` → `lib/project.rb` (ported since the last pass, not yet tabled)

This is a model/controller unit, not primarily a widget tree, so the
four-axis table does not apply the same way; it is noted here instead of
skipped silently. `spec/project_spec.rb` (5 examples, all passing — see
`test-parity.md`) exercises round-trip save/load, the unsaved flag, view
history, and `ProjectParseError` for two malformed-file shapes. Not
exercised anywhere: the actual alert-dialog wiring — `lib/alert_dialogs.rb`'s
`invalid_project`/`beta_disallowed`/`legacy_migration_disallowed` builders
are driven standalone (`"X alert builds: true"` in `drive_operations.rb`),
but nothing in `lib/project.rb` or `lib/window.rb` was confirmed in this pass
to actually *call* them on a real parse failure path through the UI, as
opposed to the dialogs simply existing and the spec raising the Ruby
exception directly. That wiring gap is unverified, not confirmed either way.

## What was not checked at all (0 of ~32 files given a table)

Every other ported file — `window.rb`, `canvas.rb`, `figure_settings.rb`,
`styles.rb`, all six item model classes, `item_box.rb`, all seven standalone
dialogs, all seven alert dialogs, `color_button.rb`, `color_swatch.rb`,
`main_sidebar_page.rb`, `operations_panel.rb`, `operations.rb`,
`actions.rb`, `shortcuts_dialog.rb` — has not had this skill's Step 3
(compare axes) or Step 4 (stylesheet diff) run against it in this pass. This
is a scope admission, not a pass: "not checked" is not "parity confirmed",
and every one of them is a candidate for the same two bugs found above
(untranslated literal text, a dropped wrapper widget) until someone actually
tables it.

## Stylesheet (Step 4)

`lib/style.css` exists. A full diff against upstream's `data/style.css` (or
equivalent) was not run in this pass. **Unverified**, not clean.

## Whole units with no port file at all

Per `component-identification.md`: the style editor window and its five
satellite files, the whole file-import sub-tree, and legacy-project
migration (`graphs/migrate.py`). (Project load/save and the curve-fitting
dialog, listed here in the prior pass, now have port files — see the two
units above.) These remaining ones are not "gap" rows in a table — there is
no port widget to put in the "Port ×" column, so the count is `upstream N,
port 0` for every widget in every one of those files. They are listed here
for completeness; the detail lives in `component-identification.md`.

## Rules check

- No app-wide total is reported as a pass. Per-file verdicts above are
  all gaps or unverified; there is no "X% of widgets match" headline number
  because the skill forbids treating that as parity.
- Both gaps found are named with file:line on both sides.
- Neither gap is excused. Both are cross-filed: here against the component,
  and in `translation-parity.md` against the message.
