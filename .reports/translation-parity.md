# Translation parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `3a3d19c7` (rechecked this pass — `grep -rn '_(' lib/ \| wc -l` is still `0`; the only change between `ce0ff04e` and `3a3d19c7` is the `reload_grid` crash fix in `lib/style_editor/window.rb`, which touches no string literals, so the untranslated-string surface is unchanged in kind and count) |
| Domain | `se.sjoerd.Graphs` upstream; `org.rubygtkproject.Graphs` on the port (confirmed by the new `data/org.rubygtkproject.Graphs.gschema.xml` etc., ported `71decf49`) |
| Upstream messages | **~374** distinct `msgid`s (hand count, see caveat, unchanged from last pass) |
| Upstream languages | **28** `.po` files under `po/` |
| Port messages | **0** |
| Port languages | **0** |
| Ported | **0** |
| Gaps | **~374** (every upstream message) |

Caveat on the message count, unchanged: this is one `.po` file's `msgid`
count, not the skill's full `catalogue.rb` pipeline. Good enough to
establish the headline, not a generated artifact to trust to the digit.

## 1. Does the port mark any string at all?

```
$ grep -rn '_(' lib/ | wc -l
0
$ grep -rln "require ['\"]gettext" lib/ exe/
(no output)
```

**Still zero**, rechecked this pass. No `_()`, `n_()`, `N_()`, `C_()`
anywhere in `lib/`, no gettext require anywhere in `lib/` or `exe/`.

**Rechecked specifically against the six style-editor files ported since
the last report** (`lib/style_editor/{window,add_style,color_group,
editor_box,item_color_row,shortcuts_dialog}.rb`): none contains `_(`, `n_(`,
`N_(` or `C_(`. `lib/style_editor/window.rb` alone adds at least 8 more
untranslated literals confirmed by file:line in `component-parity.md`
(`"Graphs Style Editor"` ×4 sites, `"Graphs Style Editor — #{...}"` ×2,
`"Open Application Menu"` ×2, `"Import File…"`, `"Create Style…"`). The gap
is unchanged in kind and larger in literal count.

The app-metadata files ported this round (`data/org.rubygtkproject.Graphs.
metainfo.xml.in` etc.) were **not** checked for their own translatable
strings (`<summary>`, `<description>`, `<caption>` elements are normally
extracted into the `.pot` alongside `po/` via `appstream-util` or
`itstool`) — this is a gap in this audit, not a claim either way; recorded
under "Checks not run" below rather than silently assumed clean or dirty.

## 2. Does the port ship a catalogue?

```
$ find . -path ./.git -prune -o -iname 'po' -print -o -iname '*.pot' -print -o -iname 'LINGUAS' -print -o -iname 'POTFILES*' -print
(no output, excluding .git)
```

Still nothing. Confirmed again this pass.

## 3. Concrete msgid-level gaps (carried forward + new)

| msgid | Upstream site | Port site | State |
|---|---|---|---|
| `Change Color` | `data/ui/color-row.blp:5` | `lib/color_row.rb:33` | gap, unchanged |
| `Edit Item` | `data/ui/sidebar/edit-item/page.blp:5` | `lib/sidebar/edit_item/page.rb:45` | gap, unchanged |
| `Open Application Menu` | `data/ui/style-editor/window.blp` (tooltip on the menu button) | `lib/style_editor/window.rb:281,396` | **new this pass** — same failure shape, two call sites instead of one (main-layout and narrow-layout menu buttons both carry the bare literal) |

These remain sampled data points, not an exhaustive list — every string in
every file, old or new, is in the identical zero-gettext state by
construction (§1).

## 4. What this means for the inherited asset

Unchanged: upstream's 28 `.po` files are real, ongoing, human-contributed
translations on `origin/main`. None reach a Graphs-rb user in any language.
The style editor — a whole top-level window just ported this round — adds
to the untranslated surface rather than reducing it; porting more of the UI
without porting the translation mechanism widens this gap in absolute
terms even while it closes other gaps.

## 5. Verdict

Parity is **0/~374 messages, 0/28 languages**, unchanged and not trending
toward closing: more files were ported this round, and all of them repeat
the same zero-gettext pattern. `parity: false`, stated by hand given 0
gettext call sites and 0 `po/` directory, same as last round.

## Checks not run (say so plainly)

- `scripts/msgid-census.sh` / `scripts/catalogue.rb` — not run, unchanged.
- `msgfmt -c` — not run, moot.
- A non-English locale smoke test — not run, moot.
- **New this pass**: whether `data/org.rubygtkproject.Graphs.metainfo.xml.in`
  and the other newly-ported app-metadata files carry their own
  translatable AppStream fields, and whether those fields have any upstream
  `.po` coverage at all — not checked. Left open rather than assumed.

## Rules check

- No reworded string proposed as a fix.
- The new `Open Application Menu` gap is filed with both sites, matching
  the skill's register for the two carried-forward gaps.
- The metainfo-translation question is named as unchecked, not folded
  silently into the "0 gettext" headline as though it were already known.
