# Test parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `42ff07f5` |
| Upstream tests | **43** |
| Ported (named or behaviourally bijective) | **18** (`spec/math_evaluation_spec.rb`, full bijection) |
| Partially covered (file exists, behaviour overlaps, not a clean bijection) | **~2 of 6** (`spec/item_instantiation_spec.rb`) |
| Gaps | **23 of 43** clean gaps, plus 4 partial-coverage gaps inside `item_instantiation_spec.rb` |
| Both documented test commands | `bundle exec rspec spec` (via the dev-shell `rspec/core` one-liner) **runs and passes**; `xvfb-run ruby test/drive_{window,canvas,sidebar,operations}.rb` **runs and passes** |

This report supersedes the prior round's `test-parity.md`, written against
`8930c5e3` when `spec/` was unfilled `bundle gem` scaffolding and the
advertised rspec command raised a `LoadError`. Both of those are now fixed
(`8915152e`, "fix the false-green test harness bugs"); this is a fresh
run against the current tree, not a copy-forward of stale numbers.

## 1. Upstream census

```
tests/test_math_evaluation.vala   18 tests  (g_test, Test.add_func, verified in main())
tests/test_item_instantiation.py   6 tests  (pytest def test_*)
tests/test_migration.py            7 tests  (pytest def test_*)
tests/test_operations.py          12 tests  (pytest def test_*)
-----------------------------------------
Total                             43 tests
```

## 2. The bijection: upstream test → named port test

| Upstream suite | Count | Port file | Count | State |
|---|---:|---|---:|---|
| `test_math_evaluation.vala` | 18 | `spec/math_evaluation_spec.rb` | 18 | **Full bijection** — every one of upstream's 18 named cases (`basic-arithmetic`, `operator-precedence`, `power-associativity`, `unary-operators`, `factorial`, `implicit-multiplication`, `constants`, `trig-radians`, `trig-degrees`, `inverse-trig`, `misc-functions`, `nested-expressions`, `decimal-separator`, `division-by-zero`, `invalid-factorial-negative`, `invalid-factorial-fractional`, `operator-associativity`, `syntax-errors`) has a same-named Ruby `it` block. Ran this session: **18/18 pass.** This is real, named, ported test parity — the first clean one found in this port's history. |
| `test_item_instantiation.py` | 6 | `spec/item_instantiation_spec.rb` | 6 | **Partial.** 6 `it` blocks exist but by different names than upstream's 6, and cover different ground than a 1:1 mapping would suggest (detail below). |
| `test_migration.py` | 7 | — | 0 | **Gap, and untestable as things stand** — `graphs/migrate.py` has no port file (`component-identification.md`), and `tests/project_v1.graphs`, the fixture these 7 tests run against, was never copied into the port's `test/`. |
| `test_operations.py` | 12 | — | 0 | **Gap** — `lib/operations.rb` exists and is exercised ad hoc by `test/drive_operations.rb`, but none of the 12 named upstream properties (`test_normalize`'s `max(ydata) == 1`, `test_derivative`, `test_fft_output_length`, etc.) has a same-named or property-matching Ruby assertion. |

### `item_instantiation_spec.rb` in detail — reading the file, not just counting `it`s

```ruby
it "builds a data item with its data and style properties"      # defaults, not dict-keyed
it "builds an equation item named after its equation"            # constructor, not dict-keyed
it "builds a text item anchored at a point"                      # constructor, not dict-keyed
it "builds a generated data item from its equation and range"    # constructor, not dict-keyed
it "round-trips a data item through to_dict/new_from_dict"        # ~ test_new_from_dict_data_item
it "round-trips an equation item through to_dict/new_from_dict"   # no upstream equivalent (upstream never tests equation-item dict round-trip)
```

Upstream's 6: `test_new_from_dict_data_item`, `test_new_from_dict_text_item`,
`test_new_from_dict_fill_item`, `test_new_from_dict_unknown_type_raises`,
`test_data_item_default_data`, `test_data_item_default_err`.

- **Covered, by behaviour not by name:** `test_new_from_dict_data_item` —
  the port's "round-trips a data item through to_dict/new_from_dict" does
  construct via `new_from_dict` and check the rebuilt fields. Close enough
  to count as covered, but it is not named after its upstream counterpart,
  so a reviewer grepping for `new_from_dict_data_item` finds nothing.
- **Not covered:**
  - `test_new_from_dict_text_item` — the port's text-item test builds via
    the plain constructor (`ItemFactory.new_text_item`), never through
    `to_dict`/`new_from_dict`. **Gap**, not a rename.
  - `test_new_from_dict_fill_item` — no `FillItem` test of any kind in this
    file. **Gap.** (`lib/item/fill_item.rb` exists; it is untested here.)
  - `test_new_from_dict_unknown_type_raises` — no test asserts
    `ItemFactory.new_from_dict` raises on an unrecognised `type` key.
    **Gap**, and a meaningful one: an unhandled bad-type dict is exactly the
    kind of input a corrupted or hand-edited project file would produce.
  - `test_data_item_default_data` / `test_data_item_default_err` — upstream
    pins what a freshly-constructed `DataItem` defaults `xerr`/`yerr`/etc.
    to before any data is set. The port's "builds a data item with its data
    and style properties" test always passes explicit `xdata`/`ydata` and
    never inspects the pre-data defaults. **Gap.**

So of upstream's 6, **2 are behaviourally covered (unnamed), 4 are clean
gaps.** The headline "6/6 `it` blocks" is not the same claim as "6/6 tests
ported" and this report declines to round up.

`spec/project_spec.rb` (5 examples) is real, substantial coverage of
`lib/project.rb` — but it has no upstream counterpart to be bijective with
(upstream has no `test_project.py`; the closest upstream tests are the
migration ones, which pin `graphs/migrate.py`, not `graphs/project.vala`).
It is **extra** coverage, filed under `## Extra` below, same treatment the
skill gives planify-rb's own-written suite.

## 3. The runtime gate, rechecked

Re-running everything the dev shell advertises, headless, this session:

| Command | Result |
|---|---|
| `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` | **29 examples, 0 failures** (18 math-eval + 6 item-instantiation + 5 project) |
| `nix develop --command xvfb-run -a ruby test/drive_window.rb` | **DRIVE OK**, 20 `check()` calls, all passing, failures tracked in a real `FAILURES` array and `exit 1` on non-empty (confirmed fixed — the prior round's "no assertion, unconditional DRIVE OK" bug is gone) |
| `nix develop --command xvfb-run -a ruby test/drive_canvas.rb` | **DRIVE OK**, 27 `check()` calls, same real `FAILURES`/`exit` pattern (confirmed fixed — the prior round's "never fails regardless of a FAIL line" bug is gone) |
| `nix develop --command xvfb-run -a ruby test/drive_sidebar.rb` | **DRIVE OK**, 28 `check()` calls, same pattern |
| `nix develop --command xvfb-run -a ruby test/drive_operations.rb` | **DRIVE OK**, 75 `check()` calls, same pattern |

Total counted this session: **29 + 20 + 27 + 28 + 75 = 179** individual
assertions across rspec + the 4 drive scripts, all using a real
pass/fail/exit-code mechanism. The task's stated gate is `187 checks passed,
0 failed, covering 30 components`. **179 ≠ 187** — close, but still not a
reproduction; the 8-check gap was not tracked down in this pass (candidates:
the `drive_sidebar.rb` style-list loop is sensitive to how many bundled
`.style` files ship, or the gate's 187 was counted at a slightly different
revision). This is recorded rather than smoothed over: **a gate number that
does not reproduce to the digit should not be repeated as fact** until
someone does reconcile it.

**What the gate figure cannot tell you, regardless of whether it is 179 or
187:** both counts are over the files `component-identification.md` lists as
ported. Neither drive script nor any spec touches the style editor, file
import, or legacy migration, because none of that code exists — "30
components covered" is 30 of the ~32 files that exist, not 30 of the
upstream app's components. A component no check exercises, per this task's
own framing, is unverified, not done — and the style editor + file import +
migration subsystems are not in anyone's check count at all, gate or
otherwise.

## 4. Verdict

Test parity is **18/43 clean, 2/43 behaviourally-covered-but-unnamed, 23/43
gap, 7/43 untestable until `migrate.py` exists** (`18 + 2 + 23 + ... ` —
precisely: math-eval 18/18, item-instantiation 2/6 behavioural + 4/6 gap,
migration 0/7 gap (untestable), operations 0/12 gap). This is real, large
improvement over the prior round's 0/43 — the math-parser suite in
particular is now a genuine, named, bijective port of upstream's hardest
test file — but it is not test parity, and the remaining 23 clean gaps plus
4 partial ones are concentrated exactly where the untested code lives
(operations, item dict-deserialization edge cases, migration).

## Extra

- `spec/project_spec.rb` — 5 examples, real coverage of `lib/project.rb`,
  no upstream test file to be bijective with. Extra, not counted toward the
  43.
- `test/drive_window.rb`, `test/drive_canvas.rb`, `test/drive_sidebar.rb`,
  `test/drive_operations.rb` — 150 `check()` calls total, all now gating
  correctly on a real `FAILURES` array and `exit 1`. Real, substantial,
  honest-on-failure coverage of UI state after an action — but none of it is
  named after, or asserts the same named property as, any of the 43 upstream
  tests, so by this skill's definition it is extra coverage, not ported
  coverage.

## Behaviour still owed (for the 23 clean gap + 4 partial rows, grouped)

- `test_new_from_dict_text_item`, `test_new_from_dict_fill_item`,
  `test_new_from_dict_unknown_type_raises`, `test_data_item_default_data`,
  `test_data_item_default_err` — five of upstream's six item-instantiation
  properties, including the one error case (bad `type` on deserialize).
- All 12 of `test_operations.py`'s per-operation numeric properties against
  its fixed `XDATA`/`YDATA` fixture (normalize, translate ×2, multiply ×2,
  center ×2, derivative, integral, cut, fft ×2).
- All 7 of `test_migration.py` — blocked on `graphs/migrate.py` having no
  port file at all, and on `tests/project_v1.graphs` never having been
  copied into `test/`.
- The 8-check discrepancy between this session's 179-check recount and the
  task's stated 187, left open rather than asserted away.
