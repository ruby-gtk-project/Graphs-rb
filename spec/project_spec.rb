# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

# Covers Data#save/#load — the current-version half of upstream's
# graphs/project.py this round ports (see lib/project.rb for what is not:
# the version-to-version migrations and the pre-JSON legacy migration).
RSpec.describe "project files" do
  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  def build_data
    Graphs::Data.new.tap do |data|
      params = data.selected_style_params
      item = Graphs::ItemFactory.new_data_item(params, [1.0, 2.0, 3.0], [1.0, 4.0, 9.0])
      item.name = "Measured"
      data.add_items([item])
    end
  end

  it "round-trips items, figure settings and undo history" do
    data = build_data
    data.figure_settings.title = "My Figure"
    path = File.join(@dir, "project.graphs")
    data.save(path)

    reloaded = Graphs::Data.new
    reloaded.load(path)

    expect(reloaded.n_items).to eq(1)
    expect(reloaded.last.name).to eq("Measured")
    expect(reloaded.last.data.ydata).to eq([1.0, 4.0, 9.0])
    expect(reloaded.figure_settings.title).to eq("My Figure")
    expect(reloaded.can_undo).to eq(data.can_undo)
  end

  it "clears the unsaved flag and records the file on save" do
    data = build_data
    expect(data.unsaved).to be(true)
    path = File.join(@dir, "project.graphs")
    data.save(path)
    expect(data.unsaved).to be(false)
    expect(data.file).not_to be_nil
  end

  it "preserves view history position across a round trip" do
    data = build_data
    data.optimize_limits
    data.view_back
    position_before = data.can_view_forward
    path = File.join(@dir, "project.graphs")
    data.save(path)

    reloaded = Graphs::Data.new
    reloaded.load(path)
    expect(reloaded.can_view_forward).to eq(position_before)
  end

  it "raises Graphs::ProjectParseError for a project missing required keys" do
    path = File.join(@dir, "broken.graphs")
    File.write(path, JSON.generate({ "version" => 2 }))
    expect { Graphs::Data.new.load(path) }.to raise_error(Graphs::ProjectParseError)
  end

  it "raises Graphs::ProjectParseError for a newer project version" do
    data = build_data
    dict = data.to_project_dict
    dict["version"] = Graphs::Data::CURRENT_PROJECT_VERSION + 1
    path = File.join(@dir, "future.graphs")
    File.write(path, JSON.generate(dict))
    expect { Graphs::Data.new.load(path) }.to raise_error(Graphs::ProjectParseError)
  end
end
