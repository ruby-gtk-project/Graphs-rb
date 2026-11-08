# Test parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `3a3d19c7` |
| Upstream tests | **43** |
| Ported (named rspec or behaviourally bijective) | **30** (18 math-eval, 12 operations — see below) |
| Partially covered | **~2 of 6** (`item_instantiation_spec.rb`, unchanged) |
| Gaps | **11 of 43** clean gaps (migration, 7; item-instantiation, 4), plus the unnamed-coverage caveat on the 12 operations tests |
| Runtime gate rerun this session | rspec: **29 examples, 0 failures**; 5 drive scripts: **DRIVE OK ×5, 0 failures** — see §3 on the exact count |

This report supersedes the prior round's, written against `ce0ff04e`. One
thing changed in the port since then: `3a3d19c7` fixed the
`reload_grid`/`Gtk::DrawingArea` GC crash that `test/drive_style_editor.rb`
was previously scoped around (see §3), and widened that same drive script
from 36 to 39 `check()` sites in doing so. No new test files, upstream or
port, appeared between `ce0ff04e` and `3a3d19c7`.

## 1. Upstream census (unchanged)

```
tests/test_math_evaluation.vala   18 tests
tests/test_item_instantiation.py   6 tests
tests/test_migration.py            7 tests
tests/test_operations.py          12 tests
-----------------------------------------
Total                             43 tests
```

## 2. The bijection: upstream test → named/behavioural port test

| Upstream suite | Count | Port file | Count | State |
|---|---:|---|---:|---|
| `test_math_evaluation.vala` | 18 | `spec/math_evaluation_spec.rb` | 18 | **Full bijection**, unchanged from last pass. Re-ran this session: 18/18 pass (part of the 29-example rspec total below). |
| `test_item_instantiation.py` | 6 | `spec/item_instantiation_spec.rb` | 6 `it` blocks | **Partial, unchanged**: 2 of 6 covered behaviourally (unnamed), 4 clean gaps (`test_new_from_dict_text_item`, `test_new_from_dict_fill_item`, `test_new_from_dict_unknown_type_raises`, `test_data_item_default_data`/`_err`) — see prior report's line-by-line reading, re-verified by re-reading `spec/item_instantiation_spec.rb` this session; unchanged since the file was not touched. |
| `test_migration.py` | 7 | — | 0 | **Gap, still untestable** — `graphs/migrate.py` has no port file, `tests/project_v1.graphs` was never copied into `test/`. Unchanged. |
| `test_operations.py` | 12 | `test/drive_operations.rb` (lines ~495-589) | 12 named `check()` sections | **Covered, with a caveat, unchanged this pass.** `71decf49` added one `check()` block per upstream `def test_*`, using the exact same `XDATA`/`YDATA` fixture values (`[0,1,4,5,7,8,12,3]` / `[5,2,7,1,31,5,123,156]`), with the same property being asserted (normalize's max, translate's offset, multiply's scale, center-at-maximum/middle, derivative/integral against a second, independently-chosen fixture matching upstream's own test bodies, cut returning nil, fft/inverse_fft preserving length). Verified by reading both files side by side this session — the mapping is real, not a relabelling. **The caveat**: this lives in a plain Ruby script using a hand-rolled `check()`, not an rspec `it` block in `spec/`. It runs under `ruby test/drive_operations.rb`, not `bundle exec rspec`, so it is not discoverable the way `spec/math_evaluation_spec.rb` is, and a reviewer running only `bundle exec rspec spec` (one of the two "documented test commands") will see 29 examples and never encounter these 12 checks at all. Counted here as ported-by-behaviour, not rounded up to "in the spec suite." |

## 3. The runtime gate, rechecked this session

```
nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
  → 29 examples, 0 failures   (18 math-eval + 6 item-instantiation + 5 project)

nix develop --command xvfb-run -a ruby test/drive_window.rb        → 20 ok lines, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_canvas.rb        → 28 ok lines, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_sidebar.rb       → 47 ok lines, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_operations.rb    → 117 ok lines, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_style_editor.rb  → 38 ok lines, DRIVE OK
```

Total this session: 29 rspec examples + 20 + 28 + 47 + 117 + 38 = **279**
individual pass/fail assertions across 8 files (5 drive scripts + 3 spec
files), all real (confirmed by reading each script for non-trivial
`FAILURES`/`exit 1` gating), 0 failures anywhere.

**The task's stated gate this round is `248 checks passed, 0 failed,
covering 8 components`.** The "8" reproduces exactly if "components" means
test files (5 drive scripts + 3 spec files = 8). The "248" does **not**
reproduce to the digit by any counting method tried this session: 279 by
counting every printed `ok`/passing-example line, 233 by counting literal
`check(` call sites in the drive scripts plus rspec's own 29-example count.
Neither equals 248. I am not rounding either number to match the task's
figure, and not assuming the task's figure is simply wrong either —
recorded here as an unreconciled discrepancy, because the task's own
framing says to "treat a failed or narrow drive run as a parity gap in its
own right," and a gate number that cannot be reproduced by any plausible
counting method is itself worth flagging rather than silently accepting.
**What does reproduce, and matters more than the exact digit:** `drive_ok`
is genuinely `true`, failures are genuinely `0`, and the suite that exists
genuinely covers all 8 files with no `FAILURES`/non-zero exit anywhere.

**The crash finding from the prior pass is resolved in-port, re-verified
this session — this is the real change since `ce0ff04e`.**
`.reports/style-editor-flowbox-drawingarea-gc.md` previously documented
`test/drive_style_editor.rb` as deliberately scoped to call `reload_grid`
only twice and avoid allocation-heavy work afterward, "the one ordering
confirmed *not* to crash" — and said plainly that this did not establish
safety under heavier real use. `3a3d19c7` changed `reload_grid` itself (it
now reuses live tiles instead of destroying and recreating
`Gtk::DrawingArea`-backed widgets) and widened the drive script to force
`GC.start`, allocate pressure garbage, and call `reload_grid` five
*additional* times beyond the real rebuild — specifically probing past the
old two-call ceiling. Re-ran it this session: still `DRIVE OK`, 38/38.
**This is a genuine widening of what the gate proves**, not a relabelling
of the same narrow run. The honest caveat, carried forward and sharpened
this pass: this proves the specific destroy-then-GC mechanism no longer
triggers through a *rebuild* call to `reload_grid`, not that the
underlying `ruby-gnome`/`gobject-introspection` binding gap (root cause)
is fixed, **and not that every path through `reload_grid` is covered** —
deleting a style still destroys one tile's `Gtk::DrawingArea` widget
(`previews.delete(name)` then `flow_box.remove`), and
`grep -n 'delete\|confirm_delete\|on_delete' test/drive_style_editor.rb`
returns nothing: that path is never driven, with or without GC pressure.
See `accountability-ensurance.md` Finding 1 — this is the round's most
serious finding.

## 4. Verdict

Test parity is **30/43 ported (18 clean bijection + 12 behaviourally
covered outside `spec/`), 2/43 behaviourally-covered-but-unnamed inside
`spec/`, 11/43 clean gap (4 item-instantiation + 7 migration)** — unchanged
in count from the prior pass, because no test file changed between
`ce0ff04e` and `3a3d19c7`; what changed is that the style-editor drive
script's own gate widened and the crash it was previously scoped around is
now mitigated (§3). This round's gate figure (`248`/`8` as stated by the
task) does not reproduce to the digit (§3), but `drive_ok=true` and `0
failures` both do reproduce, honestly, across all 8 files. Not full parity:
`test_migration.py` (7 tests) remains completely untestable because
`graphs/migrate.py` has no port file, and the task's framing — "a
component no check exercises is unverified, not done" — applies squarely
to it.

## Extra (unchanged)

- `spec/project_spec.rb` — 5 examples, extra coverage, no upstream
  counterpart.
- The four pre-existing drive scripts — 212 `check()` calls (window 20 +
  canvas 28 + sidebar 47 + operations 117), all gating correctly, none named
  after an upstream test (operations' 12 property checks are the exception,
  counted above under §2).
- `test/drive_style_editor.rb` — widened from 36 to 38-39 `check()`/`ok`
  sites this round (count depends on method, §3), gating correctly and now
  covering the crash-mitigation cycles — see §3.

## Behaviour still owed

- `test_new_from_dict_text_item`, `test_new_from_dict_fill_item`,
  `test_new_from_dict_unknown_type_raises`, `test_data_item_default_data`,
  `test_data_item_default_err` — unchanged, still owed.
- All 7 of `test_migration.py` — unchanged, blocked on `graphs/migrate.py`.
- Moving the 12 operations checks (or equivalents) into `spec/` so
  `bundle exec rspec spec` alone surfaces them, rather than requiring a
  second, separately-remembered command.
- An upstream-filed `ruby-gnome`/`gobject-introspection` issue for the
  underlying GC-rooting gap — the port's own exposure is now mitigated
  (`3a3d19c7`, re-verified §3), but the binding-level root cause is still
  undocumented anywhere outside this repo's own `.reports/` directory, and
  no issue has been filed from any session so far.
- A minimal regression test for the fixed mechanism itself, so a future
  revert of `reload_grid`'s tile-reuse approach would be caught by the
  suite rather than only by re-reading the report.
- Driving the style-delete path (`confirm_delete`/`on_delete_response`)
  under the same `GC.start`-plus-allocation-pressure conditions
  `drive_style_editor.rb` now applies to rebuilds — it still destroys one
  tile's `Gtk::DrawingArea` widget and is currently untested against the
  exact mechanism this round's fix addresses elsewhere.
