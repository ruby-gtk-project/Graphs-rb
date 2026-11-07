# Accountability ensurance — Graphs

| | |
|---|---|
| Upstream | `origin/main` @ `fa994448` |
| Port | `ruby` @ `42ff07f5` |

Scope grepped: `lib/`, `exe/`, `.reports/` (all five of this round's own
reports plus the carried-forward `component-inventory.md`), `PORTING.md`,
`FINDINGS.md`, `README.md`, and commit messages for `8915152e`/`42ff07f5`.
`PORTING.md` and `FINDINGS.md` still do not exist on `ruby`.

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|
not applicable|n/a\b|does not carry over|by design|dropped deliberately|
intentionally omitted|not ported|skipped|no ruby analogue|not needed|
unnecessary for this port|simplified|streamlined' lib/ exe/ .reports/
```

## Finding 1 — `lib/` and `exe/` themselves are clean; two prior findings against the code are now fixed

Grepping `lib/` and `exe/` alone (excluding `.reports/`) turns up exactly
two hits, both legitimate:

- `lib/project.rb:15` — "`the pre-JSON legacy migration migrate.py does are
  not ported this round`" — a first-person, specific admission inside the
  code comment that explains *why* `BETA_DISALLOWED`/
  `LEGACY_MIGRATION_DISALLOWED` have nothing to retry into. This is the
  register the skill asks for (names the behaviour lost, not a label), not
  a violation.
- `lib/export_items.rb:76` — "`an item that holds neither data nor an
  equation is skipped`" — ordinary business logic (what the export loop
  does with an empty item), not a port-gap excuse. Read in context
  (`save_item_as_columns`), it is correct behaviour, not a hedge.

Last round's Finding 2 (`test/drive_canvas.rb` and `test/drive_window.rb`
printing `DRIVE OK` unconditionally regardless of `FAIL` lines) is **fixed**
— verified this session by re-reading both files: both now define `FAILURES
= []`, push onto it from `check`, and `exit 1` when non-empty
(`test-parity.md` §3 has the rerun). This is worth saying plainly rather
than silently dropping the finding, per this skill's own "no asserted
'done' without re-running it" rule — **I re-ran both scripts this session
and confirmed the fix, rather than trusting the commit message that claims
it.**

## Finding 2 — the superseded report carried the exact forbidden-register sentence flagged last round, uncorrected until this pass

Last round's Finding 1 named `.reports/component-inventory.md:165`'s "out
of scope" framing of the missing `help/` tree as the specific violation to
fix. This round's first grep of `.reports/` found that **the sentence was
still there, verbatim**, at the same line (now `:177` after the superseded-
banner was added earlier in this pass):

> `| help/C/*.page (...) | — | Help pages | Missing | No help/ tree on
> ruby; out of scope for widget parity but flagged since the task asked for
> "full parity" |`

Adding the superseded-banner at the top of that file, done earlier in this
same pass before this report was written, pointed readers at
`component-identification.md` as the maintained inventory but did not
rewrite the flagged row itself — a reader who opens
`component-inventory.md` directly (still tracked, still findable, still
linked from the banner) would still have met "out of scope" on the missing
help pages. Rather than file this as open and leave it for the next agent,
**I went back and rewrote the row in first person** (now: "I did not build
any of the 11 help pages or their translated copies; a user of this port
who presses Help gets nothing upstream's user gets. This is a real gap in
the delivered app, not a decision to exclude help content from the audit.")
before finishing this report, so this finding is closed by an edit, not by
a sentence saying someone else should make one.

## Finding 3 — the runtime gate's own number still does not reproduce, and this round's reports say so instead of repeating it

The task's stated gate: `drive_ok=true, 187 checks passed, 0 failed,
covering 30 components`. This session's actual rerun of the rspec suite
plus all four drive scripts (`test-parity.md` §3) counts **179** real
pass/fail assertions (29 rspec + 150 drive-script `check()` calls), all of
which now correctly gate on a non-zero exit (Finding 1 above). **179 ≠
187.** This is a smaller discrepancy than last round's (159 vs. the then-
stated 182 — both numbers in the task prompt moved between rounds, which
is its own data point: the gate figure is not stable across reruns of this
audit, which is more reason not to trust it to the digit either time), and
unlike last round it is no longer explained by a structural bug (both
scripts that previously could not fail now can). The 8-check gap is
unresolved and `test-parity.md` names it as unresolved rather than closing
it with a guess. **Independent of the exact number: "30 components
covered" is 30 of the roughly 32 files that exist in the port, not 30 of
upstream's components** — the style editor, file import and legacy
migration subsystems have zero checks anywhere, gate or otherwise, because
they have zero port files. A reader who takes "187 checks, 0 failed, 30
components" as evidence the port is finished is taking evidence about a
third of the app's surface as evidence about the whole thing.

## Finding 4 — real progress this round, named without inflating it

Two subsystems the prior round correctly flagged as "no port file at all"
now have one: the curve-fitting dialog (`42ff07f5`) and project save/load
(`8915152e`). Both commit messages are in the register this skill asks for
— `8915152e`'s own message says "Version-to-version migration and the
pre-JSON legacy migration (migrate.py) are not covered this round" in
plain first-person-adjacent language, not "out of scope" or "by design".
This is **not** a reason to call the port closer to clean than it is: both
new files repeat the one defect found everywhere else in this port (zero
`_()`/gettext marks — confirmed this round, `translation-parity.md` §1
rechecked), and neither has had the four-axis widget/CSS/signal/action
table built against it (`component-parity.md`). Progress on breadth did not
come with progress on the depth checks this skill and `component-parity`
exist to force.

## What this report is not claiming

This report does **not** find a fabricated test, a result asserted without
being run, or prose that claims a subsystem works when it does not. The
honest-failure fix from last round held up under re-run. The remaining
problems are a stale document not fully retracted (Finding 2) and a gate
number that still doesn't reproduce (Finding 3) — both are accountability
failures by this skill's own definition (a claim that isn't backed, or
isn't retracted when superseded), just smaller and more specific ones than
last round's.

## Rules check

- No gap above is excused with a construction from the grep list; each is
  named with a file:line and what a user loses or what a reader is misled
  into believing.
- Finding 2 explicitly declines to mark itself "fixed" — the banner I added
  earlier in this same pass is named here as insufficient, not as a
  completed remediation.
- Finding 3's number is reported as unreconciled, not rounded to match the
  task's stated figure or silently dropped.
