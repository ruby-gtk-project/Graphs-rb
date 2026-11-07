# Specs

Plain RSpec, no extra harness. `spec/spec_helper.rb` requires `lib/graphs.rb`,
and loading it initializes GTK, so the suite needs a display: run it with

```
xvfb-run -a bundle exec rspec
```

(or the dev shell's advertised one-liner, also prefixed with `xvfb-run -a`).
Running `rspec` under a plain terminal with no display fails at `require
"graphs"` with `Gtk::InitError`, not inside a spec — that is expected.
