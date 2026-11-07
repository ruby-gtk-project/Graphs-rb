# Test parity — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `8930c5e3` |
| Upstream tests | **43** |
| Ported (named, bijective) | **0** |
| Gaps | **43** |
| Test command advertised by the dev shell | `ruby -e 'require "rspec/core"; ...' spec` — **does not run** (see below) |
| Drive scripts actually run | `xvfb-run ruby test/drive_{window,canvas,sidebar,operations}.rb` |

## 1. Upstream census

```
tests/test_math_evaluation.vala   18 tests  (g_test, Test.add_func, verified in main())
tests/test_item_instantiation.py   6 tests  (pytest def test_*)
tests/test_migration.py            7 tests  (pytest def test_*)
tests/test_operations.py          12 tests  (pytest def test_*)
-----------------------------------------
Total                             43 tests
```

The Vala file's 18 `Test.add_func` registrations in `main()` were counted by
hand and cross-checked against the 18 `private void test_*` definitions —
they match 1:1, no loop-registered or variable-named cases. `tests/meson.build`
registers one Vala test binary (`test_math_evaluation`) plus a `pytest` run
over the whole `tests/` directory as a second meson `test()` — both are
accounted for above; no third test entry point was found.

## 2. The bijection: upstream test → named port test

| Upstream suite | Upstream count | Port test file | Port count | State |
|---|---:|---|---:|---|
| `/math-parser/eval/*` (18, `test_math_evaluation.vala`) | 18 | none | 0 | **43 gaps total, itemized below** |
| `test_item_instantiation.py` | 6 | none | 0 | gap |
| `test_migration.py` | 7 | none | 0 | gap |
| `test_operations.py` | 12 | none | 0 | gap |

**Zero of the 43 upstream tests has a named Ruby counterpart.** The port has
no `test_*` methods, no `it`/`describe` blocks, and no file structured to
mirror `tests/test_math_evaluation.vala`, `test_item_instantiation.py`,
`test_migration.py` or `test_operations.py`. This is the exact shape the
`test-parity` skill's own worked example (planify-rb) warns about: a
substantial, green, headless suite that was written from scratch against the
port and pins none of what upstream pinned.

In detail:

- **Math evaluation (18 gaps).** The port's `drive_canvas.rb` *does* exercise
  `Graphs.evaluate_string` with 8 expressions (`"2+3*4"`, `"2**3"`, `"2(3+4)"`,
  `"pi"`, `"4!"`, `"3²"`, `"2--3"`, `"1.5e2"`) — real overlap in subject
  matter with upstream's `test_basic_arithmetic`, `test_factorial`,
  `test_implicit_multiplication`, `test_constants`. But none of upstream's
  18 named cases is individually represented: there is no test for operator
  precedence as its own case, none for power associativity, none for
  degree-mode trig, none for the three division-by-zero/invalid-factorial
  error cases, and critically **none for `test_syntax_errors`'s six invalid
  expressions** (`""`, `"1+"`, `"(1+2"`, `"sin()"`, `"*2"`, `"2^^3"`) or for
  `test_operator_associativity`'s ~35 assertions pinning the exact
  precedence of `!` against `^` and unary minus. A parser bug in any of
  those regions has no test in this repository that would catch it.
- **Item instantiation (6 gaps).** Upstream pins `ItemFactory.new_from_dict`
  for `DataItem`, `TextItem`, `FillItem` and the `ValueError` on an unknown
  `type`. `lib/item/factory.rb` exists and the port's drive scripts construct
  items, but never through a dict-deserialization path, and never assert the
  unknown-type error. Grep confirms: no `new_from_dict` and no
  `ItemFactory` call site in `test/` or `lib/` that takes a plain `Hash`.
- **Migration (7 gaps).** `tests/test_migration.py` pins
  `ProjectMigrator`/`ProjectValidator`/`read_project_file` against a real v1
  project fixture (`tests/project_v1.graphs`, carried nowhere into the port).
  `component-identification.md` already finds `graphs/migrate.py` and
  `graphs/project.vala` entirely unported. These 7 tests cannot be ported
  until that code exists — they are not just untested, they are untestable
  in the port's current state. The fixture file itself was never copied into
  the port's `test/`, so even starting this work has no input data yet.
- **Operations (12 gaps).** `lib/operations.rb` exists and
  `test/drive_operations.rb` does exercise several `DataOperations` methods
  (grep shows normalize/translate/multiply/center-type calls), but through
  the drive script's own ad hoc values, not through upstream's fixed
  `XDATA`/`YDATA` arrays and not asserting the same per-operation properties
  (e.g. upstream's `test_normalize` checks `max(ydata) == 1` specifically;
  confirm the port's equivalent check does the same thing rather than a
  nearby one). None of the 12 is named after its upstream counterpart, so
  even where the behaviour might coincidentally be covered, it is not
  **ported** by this skill's definition — a bijection requires a name, and
  there is none.

## 3. The runtime gate does not establish test parity, and partially cannot be trusted

The task's runtime gate states `drive_ok=true, 182 checks passed, 0 failed,
covering 30 components`. Re-running all four drive scripts headless in this
session (`nix develop --command xvfb-run -a ruby test/drive_*.rb`) gives:

| Script | `ok`/`FAIL` lines counted | Tracks failures into exit code? |
|---|---:|---|
| `test/drive_window.rb` | **0** | No `check` helper at all — the script is `puts` statements plus `DRIVE OK` printed unconditionally at the end, regardless of what happened above it |
| `test/drive_canvas.rb` | 28 | **No.** `check` prints `ok`/`FAIL` but never appends to any array, and the script prints `puts "DRIVE OK"` unconditionally on the last line — a `FAIL` line here would be printed to the log and the script would still report success and exit 0 |
| `test/drive_sidebar.rb` | 46 | Yes — `check` pushes to `FAILURES`, the script prints `DRIVE FAILED: ...` and `exit 1` if non-empty |
| `test/drive_operations.rb` | 85 | Yes — same `FAILURES` pattern |
| **Total observed** | **159** | — |

Two findings, not one:

1. **159 ≠ 182.** The gate's own headline number does not reproduce from an
   actual run of the four scripts it names. Either the gate was measured
   against a different revision, a different environment produced a
   different style count (`drive_sidebar.rb` loops over "every bundled style
   but System", so the count is sensitive to how many `.style` files ship —
   worth checking if that's the source of the drift), or the number was
   asserted without being re-run. Whichever it is, it is not reproduced in
   this session and should not be repeated as fact until it is.
2. **Of the 159 checks this session could reproduce, up to 28 (`drive_canvas.rb`)
   cannot actually fail the gate.** A regression in any of those 28
   assertions — including the 8 math-parser overlaps with upstream's suite
   named above — would print `FAIL` to stdout and the script would still
   print `DRIVE OK` and exit 0. Any harness that gates on exit code, or on
   the literal string `"DRIVE OK"`, treats a failing `drive_canvas.rb` as
   passing. **This is the false-green risk the task asked to be found,
   and it sits in the port's own test harness, not in a document's prose.**
   It is filed again in `accountability-ensurance.md` because it is exactly
   the kind of defect that report exists to surface.
3. `test/drive_window.rb` contributes real coverage of zero assertions while
   still reporting `DRIVE OK`. It is not a test; it is a smoke-run with
   `puts` statements. Counting it among "30 components" covered is
   generous — it exercises several widgets but checks nothing about any of
   them.

The dev shell's own banner advertises a third command: `ruby -e 'require
"rspec/core"; exit RSpec::Core::Runner.run([...])' spec`. Running it in this
session:

```
LoadError: cannot load such file -- kettle/test/rspec
0 examples, 0 failures, 2 errors occurred outside of examples
```

`spec/spec_helper.rb` requires a gem (`kettle-soup-cover`, `kettle/test/
rspec`) not present in the dev shell's `Gemfile.lock` resolution used here,
and `spec/` contains no actual example files — it is unmodified `bundle gem`
scaffolding (`spec/spec_helper.rb`, `spec/README.md`), never filled in. The
advertised "run the specs" command fails outright and was not part of either
the 182/0/30 claim or this session's 159-check recount. **A documented test
command that cannot run is itself a gap**, independent of the drive scripts.

## 4. Verdict

Test parity is **0/43**, not met. The port's drive scripts are real,
substantial, and mostly honest about failure (3 of 4 correctly gate on
`FAILURES`) — but they are extra coverage, not ported coverage, per this
skill's definition: none is named after, or asserts the same property as,
any of the 43 upstream tests. They belong under `## Extra` below, outside
the count, same as the skill's own planify-rb example.

## Extra

- `test/drive_window.rb` — boots the app, adds an equation item, renders the
  canvas once. **0 real assertions** despite always reporting success.
- `test/drive_canvas.rb` — 28 checks on the math parser, multi-item canvas
  rendering, undo/redo, pan/zoom/select, log-axis rendering. **Cannot fail
  the gate** due to the bug in §3.
- `test/drive_sidebar.rb` — 46 checks (16 of them a style-list loop) on item
  rows, the edit-item page per item kind, colour widgets, the style manager.
- `test/drive_operations.rb` — 85 checks on array operations, the printer,
  equation/fill/dataset operations, exports, and widget construction.
- `spec/` — present, empty, and broken (`LoadError`). Not run by anything
  that currently passes.

## Behaviour still owed (for the 43 gap rows, grouped)

- The math parser's precedence, associativity and error-reporting edge cases
  pinned by `test_math_evaluation.vala`'s 10 untouched cases (operator
  precedence, power associativity as its own case, implicit multiplication,
  degree-mode trig and inverse trig, nested expressions, decimal-separator
  swap, the three invalid-input error cases, and the six-expression syntax
  error table) are not individually pinned in the port.
- Deserializing a saved item (`DataItem`/`TextItem`/`FillItem`) from a plain
  dict, and raising on an unrecognised `type`, is not pinned.
- Reading, migrating and validating a v1 `.graphs` project file end to end is
  not pinned — and cannot be, until `graphs/project.vala` and
  `graphs/migrate.py`'s behaviour exists in the port at all
  (`component-identification.md`).
- The twelve numeric properties `test_operations.py` pins per-operation
  (normalize's max, each translate/multiply's exact per-element relationship,
  center-at-maximum, etc.) against a fixed fixture array are not pinned
  against that fixture in the port.
