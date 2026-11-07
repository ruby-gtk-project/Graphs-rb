# frozen_string_literal: true

# Loading `graphs` initializes GTK (the `gtk4` gem's require calls
# `gtk_init`), so the specs need a display the same way test/drive_*.rb does
# — run them with `xvfb-run -a` as the dev shell's banner says.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "graphs"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
