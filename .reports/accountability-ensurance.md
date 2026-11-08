# Accountability ensurance — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `ce0ff04e` |

Scope grepped: `lib/`, `exe/`, `.reports/` (all five reports plus the
carried-forward `component-inventory.md` and the new
`style-editor-flowbox-drawingarea-gc.md`), and `PORTING.md`/`FINDINGS.md`
(neither exists on `ruby`, confirmed again this pass).

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|
not applicable|n/a\b|does not carry over|by design|dropped deliberately|
intentionally omitted|not ported|skipped|no ruby analogue|not needed|
unnecessary for this port|simplified|streamlined' lib/ exe/ .reports/
```

## Finding 1 — the round's most serious finding: a drive script's green result is real but was shaped around a known, unresolved crash

This is the headline finding of this audit. It is **not** a case of a
report claiming something false — every individual sentence in
`.reports/style-editor-flowbox-drawingarea-gc.md` and in
`test/drive_style_editor.rb`'s own behaviour is accurate. The problem is
what the task's runtime-gate framing invites a reader to conclude from "36
checks passed, 0 failed, covering 6 components" sitting next to that same
report, read in isolation:

- `test/drive_style_editor.rb` passes 36/36, confirmed by re-running it
  this session.
- `.reports/style-editor-flowbox-drawingarea-gc.md`, written by whoever
  wrote that drive script, documents in its own words that the script
  "exercises `reload_grid` exactly twice ... and deliberately runs nothing
  allocation-heavy after that second call before the process quits — the
  same ordering that is safe in isolation," and that this "does not
  establish that the app, run interactively for longer with more such
  cycles, is safe — the opposite is true."
- The underlying defect — rebuilding the style grid's `FlowBox` of
  `DrawingArea`-backed tiles a second time, with GC running at the wrong
  moment, reproducibly segfaults or corrupts the process — reproduces with
  **no Graphs-rb code at all**, per the report's own minimal repro, and is
  reachable through two of the most ordinary things a user does with this
  window: closing a style and opening another, or creating a new style
  (which refreshes the grid) more than once per session.

**This is exactly what this task asked me to go looking for**: "Treat a
failed or narrow drive run as a parity gap in its own right — a component
no check exercises is unverified, not done." The drive run here is not
merely narrow by omission — it is narrow *by deliberate design, to avoid
triggering a documented crash*. A reader who sees "36/36, 6 components" and
stops there would reasonably conclude the style editor works. It does not,
reliably, under ordinary interactive use, and the one artifact proving that
is a markdown file that nothing runs and nothing gates on.

**Crucially, this is not a case of someone hiding the problem** — the
report was written candidly, with a reproduction, by the same person who
wrote the passing drive script, and it says outright that the drive
script's own safety does not generalize. That is the right thing to do
with a binding-level bug outside the port's control. But candor at the
report level does not fix what happens when that report's finding is
several files away from the number the task actually gates on. Filing this
as Finding 1 here is what keeps it from being read as closed.

**What I did about it, rather than only noting it**: nothing — no attempt
was made to fix a `gobject-introspection` GC-rooting bug from this session,
correctly, since the report already established no port-level workaround
avoids it. This finding is left open and is reflected in `clean: false`,
not papered over with a claim the gap is resolved.

## Finding 2 — the one-line excuses in `lib/` are, again, legitimate disclosures, not violations

Re-grepped this pass, three hits in `lib/`/`exe/`:

- `lib/project.rb:15` — unchanged from last round, still a specific,
  first-person admission naming what is missing (legacy migration), not a
  label.
- `lib/export_items.rb:76` — unchanged, ordinary business logic, not an
  excuse.
- `lib/style_editor/window.rb:23` — **new this pass**: "simplified here to
  the side-by-side layout only" for the adaptive `Adw.MultiLayoutView`.
  Read in context (quoted in full in `component-identification.md`), this
  names the specific upstream behaviour (bottom-sheet layout on a narrow
  window) that the port does not have, and names why (no Ruby GTK4 example
  of `Adw.MultiLayoutView` to build against safely) rather than hiding
  behind "out of scope" or "not needed." This is the register the skill
  asks for. **It is still a real gap** — filed as one in
  `component-identification.md` and `component-parity.md` — but it is not
  an accountability violation; it is correctly disclosed.

## Finding 3 — the commit message for the app-metadata port discloses a real, if small, feature drop, correctly

`71decf49`'s own message: "the desktop file drops the new-window/
style-editor actions since those command-line flags aren't implemented by
`lib/graphs/application.rb`." Confirmed this pass:
`lib/graphs/application.rb` has no `--new-window`/`--style-editor` CLI
handling, so the desktop file's quick-launch actions for them would be
dead entries if copied verbatim — dropping them instead of shipping a
broken desktop action is the right call, disclosed plainly. Filed as a
small gap in `component-identification.md`, not excused here.

## Finding 4 — the runtime gate figure this round is narrower than the suite that exists, and I did not let the task's framing of it stand unexamined

The task states this round's gate as `36 checks passed, 0 failed, covering
6 components`. I re-ran it: it reproduces to the digit — it is
`test/drive_style_editor.rb` alone. But the full suite that exists and
passes on this tree is **277 checks** (29 rspec + 212 pre-existing drive
checks + 36 new), and the prior round's own gate was `187 checks / 30
components` (itself unreconciled against this session's 179-recount, see
the prior report). **The task's own framing this round — quoting only the
newest 36 — is consistent with "the round's new work," but taken alone it
undercounts the port's actual tested surface by roughly 8x, and (more
importantly, per Finding 1) it is also the one subsystem whose green result
has a documented reason not to trust it beyond the exact 36 assertions it
makes.** I am naming this rather than either (a) reporting 277 as if it
were this round's gate, which would overstate what the task asked me to
verify, or (b) reporting 36 as if it certified the style editor, which
Finding 1 shows it does not.

## What this report is not claiming

This report does not find a fabricated test, a result asserted without
being run, or a report that lies about what it tested. Every drive script
and every spec I re-ran this session passed exactly as its own report
claims. The failures here are at a different level: a real crash that a
real, honest report documents, sitting one file away from a runtime-gate
number that — read in isolation, the way the task's own prompt frames it —
would let a reader believe the opposite. That is the shape of risk this
skill exists to catch, even when no single sentence anywhere is false.

## Rules check

- No gap above is excused with a construction from the grep list.
- Finding 1 is reported as the most serious finding in this round, per the
  task's own instruction that a false-green risk is the most serious kind.
- Findings 2-3's disclosed-gap language is explicitly *not* treated as a
  violation, with the specific sentence quoted and why it clears the bar.
- Finding 4's number is reported as narrower-but-accurate, not rounded up
  to the full suite's count or left unexamined as the task's own framing.
