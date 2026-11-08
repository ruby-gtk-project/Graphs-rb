# Component parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `ce0ff04e` |
| Units with full four-axis parity proven | **0 / ~38 ported files** |
| Units with a widget/CSS/signal/action table built in this pass | **3** (`color_row.rb`, `sidebar/edit_item/page.rb` carried over unchanged; `style_editor/window.rb` new this pass) |

## Headline finding

`component-identification.md` now lists roughly 38 port files with a
plausible upstream counterpart (up from ~32 — the style editor's six files
and the app-metadata files were ported since the last pass). This pass adds
one new tabled unit on top of the two carried forward. **Three units have a
full four-axis table; all three have a confirmed gap.** Zero are clean. The
runtime gate this round (`36 checks / 6 components`, see `test-parity.md`)
reproduces exactly and is real — but it is scoped to one new subsystem
(the style editor) and, within that subsystem, deliberately avoids the one
sequence (`reload_grid` called twice with GC running in between) that is
known to crash the process. A green gate is not evidence against a known
crash the gate was written around.

## Unit: colour row — unchanged from the prior pass

Carried forward verbatim: tooltip-text gap (`Change Color`, bare literal,
`lib/color_row.rb:33`). See prior report text; re-confirmed present this
pass (`grep -n 'tooltip_text = "Change Color"' lib/color_row.rb` still
matches).

## Unit: edit-item page — unchanged from the prior pass

Carried forward verbatim: title text gap (`Edit Item`, bare literal,
`lib/sidebar/edit_item/page.rb:45`) and the unresolved `Gtk.Viewport`
wrapper question. Re-confirmed present this pass.

## Unit: style editor window — `graphs/style_editor/window.vala` + `data/ui/style-editor/window.blp` → `lib/style_editor/window.rb` (new this pass)

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `close-request` → unsaved-changes guard (driven, `drive_style_editor.rb`) | — | parity on signal shape |
| `Adw.MultiLayoutView` (adaptive side-by-side / bottom-sheet) | 1 | 0 | — | — | — | **gap, disclosed in-code** (`lib/style_editor/window.rb:21-23`): the port always lays out side-by-side, upstream switches to a bottom sheet on a narrow window. A user who resizes the port's style editor to phone width gets a layout upstream never ships; this is a real, user-visible behavioural difference, not a cosmetic one. |
| `Adw.WindowTitle` | 2 (main view + narrow view) | 2 (both code paths build one, lines 273 & 388) | — | — | ✗ | **gap**: `"Graphs Style Editor"` / `"Graphs Style Editor — #{name}"` are bare literals (lines 45, 160, 214, 223, 273, 388), same untranslated-text class as every other file in this port. |
| `Gtk.Button` (open-menu) | 1 | 2 (one per layout branch, lines 281 & 396) | — | — | ✗ | tooltip `"Open Application Menu"` bare literal |
| `Gtk.Button` (Import File…) | 1 | 1 | — | — | ✗ | label `"Import File…"` bare literal — and note: this button's label promises a file-import feature that, per `component-identification.md`, has zero port files behind it anywhere in `lib/`. Whether this button is wired to anything live or is a dead end was **not checked in this pass**; it is flagged here as a thing to verify, not asserted either way. |
| `Gtk.Button` (Create Style…) | 1 | 1 | — | ✓ drives `AddStyleDialog` (driven, `drive_style_editor.rb`: "AddStyleDialog builds", "create-style wrote a user style") | ✗ | label bare literal; behaviour is driven and passes |

- **The crash is the real finding here, not a text gap.** `reload_grid`
  (called once at window build, and again by `close_style` and by a
  successful "Create Style…") is documented in
  `.reports/style-editor-flowbox-drawingarea-gc.md` as reproducibly
  segfaulting or corrupting the process on its **second** invocation once
  the garbage collector runs before the pending frame callback fires — with
  **no Graphs-rb-specific code** in the minimal repro, confirmed by the
  report's author as a `ruby-gnome`/`gobject-introspection` binding gap, not
  a port logic bug. `test/drive_style_editor.rb` passes 36/36 — and, per its
  own documentation, passes specifically *because* it was written to call
  `reload_grid` only twice total and to avoid allocation-heavy work
  afterward, the one ordering confirmed safe. A user who opens the style
  editor, closes one style, then opens and closes a second in the same
  session is already past what the drive script proves safe. **This is
  filed against the component here; it is filed again in
  `accountability-ensurance.md` as the round's most serious finding**,
  because "36 checks passed, 0 failed" is true and is also not evidence the
  component doesn't crash in ordinary use.

## What was not checked at all

Unchanged in kind from the prior pass: `window.rb`, `canvas.rb`,
`figure_settings.rb`, `styles.rb`, all item classes, all standalone and
alert dialogs, `color_button.rb`, `color_swatch.rb`, `main_sidebar_page.rb`,
`operations_panel.rb`, `operations.rb`, `actions.rb`, `shortcuts_dialog.rb`,
`curve_fitting_dialog.rb`, `project.rb` — plus, new this pass,
`style_editor/{add_style,color_group,editor_box,item_color_row,
shortcuts_dialog}.rb`, none of which has had a four-axis table built. The
drive script's 36 checks assert widget *state* after an action for these
files (title follows a rename, save clears the unsaved flag, the new style
is mutable), never CSS classes or the text axis.

## Stylesheet (Step 4)

Unchanged — not diffed in this pass either. **Unverified.**

## Whole units with no port file at all

Unchanged except the style editor is removed from this list (now tabled,
with gaps, above): file import (9+ files) and legacy-project migration
(`graphs/migrate.py`) remain `upstream N, port 0` for every widget.

## Rules check

- No app-wide total is reported as a pass.
- All three gaps found this pass are named with file:line on the port side.
- The style-editor crash is named as a crash, not rounded down to a
  "text gap" or folded into the generic translation finding — it is a
  distinct, more serious class of finding and is treated as one here and in
  `accountability-ensurance.md`.
