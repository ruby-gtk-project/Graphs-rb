# Translation parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `42ff07f5` (rechecked this pass — `grep -rn '_(' lib/ \| wc -l` is still `0`, including in the curve-fitting dialog and project files ported since the last pass; see "Rechecked" note below) |
| Domain | `se.sjoerd.Graphs` (`meson.build` project id — unconfirmed against an installed `.mo`, since none exists) |
| Upstream messages | **~374** distinct `msgid`s (counted from `po/nl.po`'s `^msgid "` lines minus the header; the full `msgid-census.sh`/`catalogue.rb` pipeline from the skill was not run in this pass — see caveat) |
| Upstream languages | **28** `.po` files under `po/` |
| Port messages | **0** |
| Port languages | **0** |
| Ported | **0** |
| Gaps | **~374** (every upstream message) |
| Extra | **0** confirmed as genuinely marked (see below — the port has zero gettext call sites of any kind) |

**Caveat on the message count.** This number comes from one `.po` file's
`msgid` line count, not from running `scripts/catalogue.rb` against both
trees with the proper quote-normalisation and `.pot`/`.po` cross-check the
skill specifies. It is good enough to establish the headline (the gap is in
the hundreds, not a handful) but is not the generated, regeneratable
artifact the skill requires before closing this ledger. Running the real
pipeline is unfinished work, not a number to trust to the digit.

## 1. Does the port mark any string at all?

```
$ grep -rn '_(' lib/ | wc -l
0
$ grep -rln "require ['\"]gettext" lib/ exe/
(no output)
```

**Zero.** There is no `_()`, `n_()`, `N_()`, `C_()` call anywhere in `lib/`,
and no `require "gettext"` (or any Ruby gettext gem) anywhere in `lib/` or
`exe/`. Every user-visible string in the port — every dialog title, every
button label, every tooltip, every toast — is a bare Ruby string literal.
This is not "translation deferred"; it is translation absent as a mechanism,
not merely as content.

**Rechecked this pass against the two subsystems ported since the last
report** (`lib/curve_fitting_dialog.rb`, `lib/curve_fitting.rb`,
`lib/project.rb` — `component-identification.md`): none of the three
contains `_(`, `n_(`, `N_(` or `C_(`, confirming the gap is unchanged by new
code, not shrinking. `lib/curve_fitting_dialog.rb` alone adds at least 13
more untranslated literals (`"Curve Fitting"`, `"Cancel"`, `"Add Fit"`,
`"Equation"`, `"Y ="`, `"Fitting Parameters"`, `"Fit"`, `"Confidence Band"`,
`"Fit Curve"`, `"No fit yet"` ×2, `""` subtitle ×2) to the pile counted in
§1 — the port is adding user-facing text faster than it is adding any
translation mechanism to carry it.

## 2. Does the port ship a catalogue?

```
$ find . -path ./.git -prune -o -iname 'po' -print -o -iname '*.pot' -print -o -iname 'LINGUAS' -print -o -iname 'POTFILES*' -print
(no output, excluding .git)
```

No `po/` directory, no `.pot`, no `LINGUAS`, no `POTFILES.in` on `ruby`.
Upstream's `po/` carries **28 languages** (`bg ca de el en_GB eo es eu fa fi
fr he hi hu it ka kk nb nl pt_BR ro ru sl sr sv tr uk zh_CN`) and a
`POTFILES.in` naming **135** source files. None of it was copied.
`help/<lang>/*.po` (translated help pages, a separate catalogue domain) is
also absent, matching `component-identification.md`'s finding that `help/`
itself does not exist on `ruby`.

## 3. Concrete msgid-level gaps found while doing the component-parity pass

Two messages were confirmed byte-for-byte against upstream source while
building `component-parity.md`, both already gaps by §1 but worth recording
individually with sites, per the skill's rule that a text-axis gap is
recorded in both ledgers:

| msgid | Upstream site | Port site | State |
|---|---|---|---|
| `Change Color` | `data/ui/color-row.blp:5` `tooltip-text: _("Change Color");` | `lib/color_row.rb:33` `widget.tooltip_text = "Change Color"` | **gap** — present as a literal, never marked |
| `Edit Item` | `data/ui/sidebar/edit-item/page.blp:5` `title: _("Edit Item");` | `lib/sidebar/edit_item/page.rb:45` `Adwaita::NavigationPage.new(toolbar_view, "Edit Item")` | **gap** — present as a literal, never marked, and actively pinned as English by `test/drive_sidebar.rb`'s `check("... edit page shows its name", ..., "Edit Item")`, three times (once per item kind) |

Both are byte-identical to upstream's English *today*, which is exactly the
trap the skill describes: an English screenshot of either looks perfect, and
a static read of the port's code shows no bug. They are gaps because the
only mechanism that would let a `de.po`, `fr.po` or any of the other 26
catalogues produce anything but this exact English for these two strings is
absent.

These two are not special — they are two data points sampled from a port
with zero gettext call sites. Every other string in every other file is in
the identical state by construction (§1).

## 4. What this means for the inherited asset

Upstream's 28 `.po` files are real, ongoing, human-contributed translations
(`msgfmt`-valid `.po` files tracked in the fork's `main` branch). None of
that work reaches a Graphs-rb user in any language. This is not a feature
the port has not reached yet — the 28 languages exist today, in the same
repository, on `origin/main`, and the port ships none of them.

## 5. Verdict

Parity is **0/~374 messages, 0/28 languages**, and it is not close: this is
not "most strings ported, a few gaps," it is the gnome-contacts-rb worked
example's end state exactly — a port built entirely in untranslatable
literals. No `summary.parity` document was regenerated because the
catalogue pipeline was not run to produce one; stating `parity: false` by
hand is sufficient given the inputs (0 gettext call sites, 0 `po/` directory)
leave no plausible path to `true`.

## Checks not run (say so plainly, per the skill's own rule)

- `scripts/msgid-census.sh` / `scripts/catalogue.rb` against both trees —
  not run. The ~374 figure is a hand count of one `.po` file, not a
  generated catalogue.
- `msgfmt -c` / `rmsgfmt` validation — not run (and moot: there is nothing to
  compile).
- A non-English locale smoke test (`LANGUAGE=de ... <port binary>`) — not
  run (and moot: no `.mo`, no `bindtextdomain` call exists in `lib/` or
  `exe/` to bind one if it did).

## Rules check

- No reworded string was proposed as a fix. Both gap rows above carry the
  byte-identical upstream English in `Text still owed`-equivalent form,
  copied from source, not retyped.
- `#{}`-interpolated strings were specifically grepped for as a secondary
  check (`grep -rn '"[^"]*#{' lib/ | grep -v '_('`) and several exist (e.g.
  toast messages in `window.rb`/`export_items.rb` built with string
  interpolation); since none of them is marked with any gettext call in the
  first place (§1), they are already counted in the 0-markers finding above
  rather than double-counted as a separate "interpolation" category — but
  they are worth naming explicitly as the thing that will make this harder
  to close than "wrap it in `_()`": each interpolated toast needs
  restructuring to `format(n_(...) || _(...), ...)` against upstream's
  msgid, not a mechanical wrap.
