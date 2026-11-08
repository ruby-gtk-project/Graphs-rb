# Accountability ensurance — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `3a3d19c7` |

Scope grepped: `lib/`, `exe/`, `.reports/` (all five reports plus the
carried-forward `component-inventory.md` and
`style-editor-flowbox-drawingarea-gc.md`), and `PORTING.md`/`FINDINGS.md`
(neither exists on `ruby`, confirmed again this pass).

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|
not applicable|n/a\b|does not carry over|by design|dropped deliberately|
intentionally omitted|not ported|skipped|no ruby analogue|not needed|
unnecessary for this port|simplified|streamlined' lib/ exe/ .reports/
```

## Finding 1 — the round's most serious finding: the crash fix's own claim is broader than what it actually covers

The prior pass's Finding 1 was the `reload_grid` crash sitting behind a
green gate. This pass, `3a3d19c7` genuinely fixes the specific mechanism
that pass documented: `reload_grid` no longer destroys-and-recreates every
tile on a rebuild, and re-running `test/drive_style_editor.rb` with five
extra `GC.start`-forced reload cycles (well past the old two-call ceiling)
confirms it, 38/38. That part of the story is real and I am not
discounting it.

**But reading the fix past the part that was tested finds a second,
narrower copy of the same bug class, left unverified.** `reload_grid`'s
new body still does this, for any style that was actually deleted:

```ruby
previews.each_key.to_a.each do |name|
  unless current_names.include?(name)
    flow_box.remove(previews.delete(name).widget)
  end
end
```

`previews.delete(name).widget` is a `StylePreview` whose thumbnail is a
`Gtk::DrawingArea` with a registered `set_draw_func` closure — the exact
object shape `.reports/style-editor-flowbox-drawingarea-gc.md`'s minimal
repro destroys to trigger the crash. `flow_box.remove` destroys it. The
only thing that changed from the original bug is *how many* tiles get
destroyed per call (one, via a user deleting a style, instead of all of
them on every rebuild) — the destroy-then-pending-GC shape is still there.
`confirm_delete`/`on_delete_response` (the only call sites that reach this
line — `grep -n 'delete\|confirm_delete\|on_delete' test/drive_style_editor.rb`
returns **no output at all**) is never driven by the drive script, with or
without GC pressure. Deleting a style and then doing anything else that
allocates — which is any ordinary continued use of the editor — is
untested against exactly the mechanism this round's commit says it fixed.

**This is not a claim that deleting a style crashes.** I did not run that
sequence this session (a GC-triggered native crash is not something to
provoke speculatively against the audit's own process), so I am not
asserting a failure that wasn't observed. The finding is narrower and more
exact than that: the commit message says "nothing with a `set_draw_func`
closure is ever destroyed-then-GC'd as part of an ordinary rebuild any
more" — and deleting a style *is* an ordinary thing a user does with this
window, it does still destroy such a closure, and no check anywhere
exercises it with the GC pressure that is the entire reason the original
bug existed. A reader of the commit message and the green `DRIVE OK` who
concludes the delete path is covered by the same proof would be wrong, and
nothing in the current reports says so plainly until this one. This is
filed as the round's most serious finding because it is exactly the
false-green shape the task asks to be caught: a real, honest fix, whose
own description is wider than its own test coverage, for a bug class
proven to be a live native-process risk.

**What I did about it, rather than only noting it**: nothing — no attempt
was made to extend `test/drive_style_editor.rb` to drive the delete path
under GC pressure, and no attempt was made to trigger the crash directly.
Both would be scope beyond auditing. This finding is left open and is
reflected in `clean: false`.

## Finding 2 — the one-line excuses in `lib/` are, again, legitimate disclosures, not violations

Re-grepped this pass against the current tree; same three hits as last
pass, unchanged by the one commit between rounds (which touched only
`lib/style_editor/window.rb`'s `reload_grid` body and comments, not these
lines):

- `lib/project.rb:15` — still a specific, first-person admission naming
  what is missing (legacy migration), not a label.
- `lib/export_items.rb:76` — ordinary business logic ("an item that holds
  neither data nor an equation is skipped"), not an excuse.
- `lib/style_editor/window.rb:23` — "simplified here to the side-by-side
  layout only" for the adaptive `Adw.MultiLayoutView`, naming the specific
  missing upstream behaviour (bottom-sheet on a narrow window) and why (no
  Ruby GTK4 example to build against safely). Still a real gap, filed in
  `component-identification.md`/`component-parity.md`, not an
  accountability violation.

## Finding 3 — a real gap this pass found that no prior pass's own summary carried: the figure-settings style-page tab

`component-identification.md`'s own "Summary" section, as of the prior
pass, listed what was "still wide open" and did not mention
`data/ui/sidebar/figure-settings/style-page.blp` — even though the
file-level fact (no port file) was sitting, correctly recorded, in the
older `component-inventory.md` the whole time. This is not a case of
anyone writing something false; it is a gap dropping out of the
*summary* of a report while the *detail* elsewhere stayed correct, which
is its own kind of risk — a reader of just the current report's headline
"what changed"/"what's still open" lines would not learn this gap exists
at all. Restored this pass into `component-identification.md` and
`component-parity.md`'s own summaries, with the file:line-equivalent
evidence (the absence of any `style_page`/`StylePage` symbol in
`lib/figure_settings.rb`).

## Finding 4 — the runtime gate figure this round does not reproduce to the digit, and I am not forcing it to

The task states this round's gate as `248 checks passed, 0 failed,
covering 8 components`. Re-running everything this session: `8` matches
cleanly if "components" means test files (5 drive scripts + 3 spec
files). `248` does not reproduce by any counting method tried —
counting every printed `ok`/passing-example line gives 279 (29 rspec + 20
+ 28 + 47 + 117 + 38 drive); counting literal `check(` call sites in the
drive scripts plus rspec's 29 gives 233. Neither is 248, and the two
methods don't even agree with each other, which is itself worth recording
rather than picking whichever is closer and calling it reconciled. What
*does* reproduce exactly and matters more than the digit: `drive_ok=true`
and `0 failures`, confirmed by re-running all 8 files this session with no
`FAILURES`/non-zero-exit anywhere. I am reporting the mismatch rather than
rounding either number to fit the other.

## What this report is not claiming

This report does not find a fabricated test, a result asserted without
being run, or a report that lies about what it tested. Every drive script
and every spec re-run this session passed exactly as claimed, and the
`reload_grid` fix is a real fix for the mechanism it names. Finding 1 is
narrower than "the crash is back" — it is "the fix's own description
covers more ground than its own test does," which is a more exact and, I
think, more useful finding than either overstating the regression or
accepting the green result at face value.

## Rules check

- No gap above is excused with a construction from the grep list.
- Finding 1 is reported as the most serious finding in this round, per the
  task's own instruction that a false-green risk is the most serious kind,
  and is stated precisely (an untested residual case, not an observed
  crash) rather than either downgraded to a style nit or inflated into an
  unverified crash claim.
- Finding 3 names a report-summary accuracy gap distinct from a code gap,
  and fixes it in the two reports it affects rather than only noting it
  here.
- Finding 4's mismatch is reported as a mismatch, not rounded to match the
  task's stated figure or silently dropped.
