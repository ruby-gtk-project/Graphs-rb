# Component parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `3a3d19c7` |
| Units with full four-axis parity proven | **0 / ~38 ported files** |
| Units with a widget/CSS/signal/action table built across all passes | **3** (`color_row.rb`, `sidebar/edit_item/page.rb`, `style_editor/window.rb` — none rebuilt this pass, all re-verified against the current tree) |

## Headline finding

`component-identification.md` lists roughly 38 port files with a plausible
upstream counterpart, plus, new this pass, one upstream component
(`figure-settings/style-page.blp`) that was never ported at all and was
missing from the last pass's own summary — see "New gap this pass" below.
**Three units have a full four-axis table; all three still have a
confirmed gap.** Zero are clean. The `reload_grid` crash that the prior
pass filed as this round's most serious finding is now mitigated in-port
(`3a3d19c7`) — re-verified this pass by re-running `test/drive_style_editor.rb`,
which forces `GC.start` and calls `reload_grid` five more times than the
two-call ceiling the previous script version was limited to, and still
reaches `DRIVE OK`. This is real progress, not a relabelling: the fix
changes `reload_grid` to reuse live tiles instead of destroying and
recreating `Gtk::DrawingArea`-backed widgets, which was the exact
mechanism that corrupted the process. It is **not** a fix to the
underlying `ruby-gnome`/`gobject-introspection` binding gap, which remains
open and would still bite any future call site with the same
destroy-and-recreate shape — see `accountability-ensurance.md` for how
this pass reads that distinction.

## New gap this pass: the figure-settings sidebar's own style page

Upstream's `data/ui/sidebar/figure-settings/style-page.blp` is an
`Adw.NavigationPage` titled "Style", holding a `GridView` of style-preview
thumbnails and a header "Manage" button (`action-name: "app.style-editor"`).
It is the in-context way a user flips through their project's available
styles from inside the figure-settings sidebar they are already looking
at, without leaving to the app menu. `lib/figure_settings.rb` (99 lines, the
file that would own it) has no method, class or navigation-push for it —
confirmed by `grep -n 'style_page\|StylePage\|style-grid\|style_grid'
lib/*.rb`, which matches nothing but an unrelated CSS rule in
`lib/style.css`. **Upstream: 1 `Adw.NavigationPage` + 1 `GridView` + 1
`Gtk.Button`. Port: 0.** The style editor window itself is now fully
ported (see below) — this missing page is the one piece that would have
connected it to the sidebar.

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

- **The crash is now mitigated, re-verified this pass, with the right
  caveat carried forward.** `reload_grid` no longer destroys and recreates
  `StylePreview` tiles; it keeps each tile's widget alive in a
  `@style_previews` hash keyed by style name and reuses it in place,
  removing a tile only when its style is actually deleted. Re-ran
  `test/drive_style_editor.rb` this pass: it now forces `GC.start`,
  allocates pressure garbage, and calls `reload_grid` five more times
  after the real rebuild — specifically to probe past the two-call ceiling
  the earlier version limited itself to — and still reaches `DRIVE OK`.
  This is real evidence the specific destroy-then-GC mechanism documented
  in `.reports/style-editor-flowbox-drawingarea-gc.md` no longer triggers
  through this call site, specifically for a *rebuild* (a style's
  properties changing). **It is not evidence the underlying
  `ruby-gnome`/`gobject-introspection` binding gap is fixed**, and —
  re-reading `reload_grid`'s own new body this pass — the destroy-then-GC
  shape is still reachable through a narrower path the drive script never
  exercises: deleting a style destroys that one tile's `Gtk::DrawingArea`
  widget (`previews.delete(name)` then `flow_box.remove`), and no check
  anywhere drives that path with GC pressure afterward. Filed here as
  mitigated-for-rebuild, unverified-for-delete; see
  `accountability-ensurance.md` Finding 1 for the full reasoning — this is
  the round's most serious finding.

## What was not checked at all

Unchanged in kind from the prior pass: `window.rb`, `canvas.rb`,
`figure_settings.rb`, `styles.rb`, all item classes, all standalone and
alert dialogs, `color_button.rb`, `color_swatch.rb`, `main_sidebar_page.rb`,
`operations_panel.rb`, `operations.rb`, `actions.rb`, `shortcuts_dialog.rb`,
`curve_fitting_dialog.rb`, `project.rb` — plus, new this pass,
`style_editor/{add_style,color_group,editor_box,item_color_row,
shortcuts_dialog}.rb`, none of which has had a four-axis table built, and
the new-this-pass `figure-settings/style-page.blp` gap above (no port file
at all, so no table applies). The drive script's checks assert widget
*state* after an action for these files (title follows a rename, save
clears the unsaved flag, the new style is mutable), never CSS classes or
the text axis.

## Stylesheet (Step 4)

Unchanged — not diffed in this pass either. **Unverified.**

## Whole units with no port file at all

File import (9+ files) and legacy-project migration (`graphs/migrate.py`)
remain `upstream N, port 0` for every widget, unchanged. **New this pass:**
the figure-settings style-page tab (1 `Adw.NavigationPage`, 1 `GridView`,
1 `Gtk.Button`) joins this list.

## Rules check

- No app-wide total is reported as a pass.
- Every gap named this pass is named with file:line (or, for the
  style-page gap, the absence of any file) on the port side.
- The mitigated crash is reported as mitigated, not as fixed or as
  resolved — the binding-level root cause is explicitly carried forward as
  still open, matching `accountability-ensurance.md`.
