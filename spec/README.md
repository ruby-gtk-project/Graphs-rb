# Specs

Plain RSpec, no extra harness. `spec/spec_helper.rb` requires `lib/graphs.rb`,
and loading it initializes GTK, so the suite needs a display: run it with

```
xvfb-run -a bundle exec rspec
```

(or the dev shell's advertised one-liner, also prefixed with `xvfb-run -a`).
Running `rspec` under a plain terminal with no display fails at `require
"graphs"` with `Gtk::InitError`, not inside a spec — that is expected.

## Harness Helpers

These helpers are available in specs after `spec/spec_helper.rb` loads:

- `stub_env("NAME" => "value")` temporarily sets environment variables and
  restores them after the example.
- `hide_env("NAME")` temporarily removes environment variables and restores
  them after the example.
- `block_is_expected` supports expectation syntax for blocks.
- `:check_output` disables default stream silencing for examples that need to
  assert output.
- `:freeze` and `:travel` metadata integrate with Timecop for example-level
  time control.
- `:skip_global_travel` opts an example out of global time travel.
- `pending_for` marks examples pending for selected runtimes or dependency
  versions.
- `include_context "with rake", "task_name"` is available when `rake` was
  loaded before `kettle/test/rspec`.

Prefer these helpers over ad hoc ENV mutation, direct Timecop setup, or direct
stdout/stderr plumbing. They keep specs isolated across parallel workers and
make local runs match CI behavior.
