# Test parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `ce0ff04e` |
| Upstream tests | **43** |
| Ported (named rspec or behaviourally bijective) | **30** (18 math-eval, 12 operations — see below) |
| Partially covered | **~2 of 6** (`item_instantiation_spec.rb`, unchanged) |
| Gaps | **11 of 43** clean gaps (migration, 7; item-instantiation, 4), plus the unnamed-coverage caveat on the 12 operations tests |
| Runtime gate rerun this session | rspec: **29 examples, 0 failures**; 5 drive scripts: **248 `check()` calls, 0 failures, DRIVE OK ×5** |

This report supersedes the prior round's, written against `42ff07f5`. Two
things changed in the port since then: `test_operations.py`'s 12 properties
were added to `test/drive_operations.rb` (`71decf49`), and the style editor
plus its own drive script were added (`400b5f04`, `ce0ff04e`).

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
| `test_operations.py` | 12 | `test/drive_operations.rb` (lines ~495-589) | 12 named `check()` sections | **Now covered, with a caveat.** `71decf49` added one `check()` block per upstream `def test_*`, using the exact same `XDATA`/`YDATA` fixture values (`[0,1,4,5,7,8,12,3]` / `[5,2,7,1,31,5,123,156]`), with the same property being asserted (normalize's max, translate's offset, multiply's scale, center-at-maximum/middle, derivative/integral against a second, independently-chosen fixture matching upstream's own test bodies, cut returning nil, fft/inverse_fft preserving length). Verified by reading both files side by side this session — the mapping is real, not a relabelling. **The caveat**: this lives in a plain Ruby script using a hand-rolled `check()`, not an rspec `it` block in `spec/`. It runs under `ruby test/drive_operations.rb`, not `bundle exec rspec`, so it is not discoverable the way `spec/math_evaluation_spec.rb` is, and a reviewer running only `bundle exec rspec spec` (one of the two "documented test commands") will see 29 examples and never encounter these 12 checks at all. Counted here as ported-by-behaviour, not rounded up to "in the spec suite." |

## 3. The runtime gate, rechecked this session

```
nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
  → 29 examples, 0 failures   (18 math-eval + 6 item-instantiation + 5 project)

nix develop --command xvfb-run -a ruby test/drive_window.rb      → 20 checks, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_canvas.rb      → 28 checks, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_sidebar.rb     → 47 checks, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_operations.rb  → 117 checks, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_style_editor.rb → 36 checks, DRIVE OK
```

Total this session: **29 + 20 + 28 + 47 + 117 + 36 = 277** individual
pass/fail assertions, all real (non-trivial `FAILURES`/`exit 1` gating,
confirmed by reading each script).

**The task's stated gate this round is `36 checks passed, 0 failed,
covering 6 components`.** That figure reproduces exactly — it is
`test/drive_style_editor.rb` alone, not the whole suite (248 drive checks +
29 rspec = 277 total exist and all pass, but the round's own framing names
only the newest 36). Read generously, this is simply "the new work's own
gate." **Read adversarially — the way this task asks to be read — a
36-check/6-component gate is a narrow one, and the task says so explicitly:
"Treat a failed or narrow drive run as a parity gap in its own right."**

**And this round the narrowness is not hypothetical**, because of what
`.reports/style-editor-flowbox-drawingarea-gc.md` documents directly about
*this same drive script*: the script's own author scoped it to call
`reload_grid` only twice and to avoid allocation-heavy work afterward,
because that is the one ordering confirmed *not* to crash. The report says,
in its own words: "this keeps the script's own run inside the safe window
... it does not establish that the app, run interactively for longer with
more such cycles, is safe — the opposite is true, and is the point of this
report." **A drive run that is narrow by design, to dodge a known crash, is
exactly the gap this task's framing asks to be caught, and it is the single
most important finding in this round's audit.** See
`accountability-ensurance.md` for why this is filed as a false-green risk
rather than a plain test gap.

## 4. Verdict

Test parity is **30/43 ported (18 clean bijection + 12 behaviourally
covered outside `spec/`), 2/43 behaviourally-covered-but-unnamed inside
`spec/`, 11/43 clean gap (4 item-instantiation + 7 migration)**. This is
real improvement over the prior round's 18/43 — `test_operations.py` is now
genuinely exercised, with the right fixture and the right properties. It is
not full parity, and the one new runtime-gate number this round cites is
narrower than the suite that actually exists, and narrow in a way that is
directly tied to a known, unresolved crash the gate avoids triggering.

## Extra (unchanged)

- `spec/project_spec.rb` — 5 examples, extra coverage, no upstream
  counterpart.
- The four pre-existing drive scripts — 212 `check()` calls (window 20 +
  canvas 28 + sidebar 47 + operations 117), all gating correctly, none named
  after an upstream test (operations' 12 property checks are the exception,
  counted above under §2).
- `test/drive_style_editor.rb` — 36 `check()` calls, new this round, real
  and gating correctly for what it covers — see §3 for what it is
  deliberately scoped not to cover.

## Behaviour still owed

- `test_new_from_dict_text_item`, `test_new_from_dict_fill_item`,
  `test_new_from_dict_unknown_type_raises`, `test_data_item_default_data`,
  `test_data_item_default_err` — unchanged, still owed.
- All 7 of `test_migration.py` — unchanged, blocked on `graphs/migrate.py`.
- Moving the 12 operations checks (or equivalents) into `spec/` so
  `bundle exec rspec spec` alone surfaces them, rather than requiring a
  second, separately-remembered command.
- A regression test (or an upstream-filed binding-gem issue) for the
  `reload_grid` GC crash — right now the only artifact proving it exists is
  a standalone markdown report with a reproduction script that is not part
  of the suite and does not run in CI.
