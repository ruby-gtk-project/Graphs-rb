# frozen_string_literal: true

require "spec_helper"

# Ported from the shape of upstream's tests/test_item_instantiation.py: each
# item type can be built through ItemFactory and serialized back out.
RSpec.describe Graphs::ItemFactory do
  let(:params) { Graphs::Data.new.selected_style_params }

  it "builds a data item with its data and style properties" do
    item = Graphs::ItemFactory.new_data_item(params, [1.0, 2.0], [3.0, 4.0])
    expect(item).to be_a(Graphs::DataItem)
    expect(item.data.xdata).to eq([1.0, 2.0])
    expect(item.data.ydata).to eq([3.0, 4.0])
    expect(item.linestyle).to be_a(Integer)
  end

  it "builds an equation item named after its equation" do
    item = Graphs::ItemFactory.new_equation_item(params, Graphs.expression_to_ast("x^2"))
    expect(item).to be_a(Graphs::EquationItem)
    expect(item.name).to eq("Y = x^2")
    expect(item.equation_based?).to be(true)
  end

  it "builds a text item anchored at a point" do
    item = Graphs::ItemFactory.new_text_item(
      params,
      1.0,
      2.0,
      "Peak",
    )
    expect(item).to be_a(Graphs::TextItem)
    expect(item.xanchor).to eq(1.0)
    expect(item.yanchor).to eq(2.0)
    expect(item.text).to eq("Peak")
  end

  it "builds a generated data item from its equation and range" do
    item = Graphs::ItemFactory.new_generated_data_item(
      params,
      Graphs.expression_to_ast("x"),
      "0",
      "10",
      5,
      :linear,
    )
    expect(item).to be_a(Graphs::GeneratedDataItem)
    expect(item.xstart).to eq("0")
    expect(item.xstop).to eq("10")
    expect(item.data.xdata.length).to eq(5)
  end

  it "round-trips a data item through to_dict/new_from_dict" do
    item = Graphs::ItemFactory.new_data_item(params, [1.0, 2.0], [3.0, 4.0])
    item.name = "Measured"
    dictionary = Graphs::ItemFactory.to_dict(item)
    rebuilt = Graphs::ItemFactory.new_from_dict(dictionary)
    expect(rebuilt.name).to eq("Measured")
    expect(rebuilt.data.xdata).to eq(item.data.xdata)
    expect(rebuilt.data.ydata).to eq(item.data.ydata)
  end

  it "round-trips an equation item through to_dict/new_from_dict" do
    item = Graphs::ItemFactory.new_equation_item(params, Graphs.expression_to_ast("sin(x)"))
    dictionary = Graphs::ItemFactory.to_dict(item)
    rebuilt = Graphs::ItemFactory.new_from_dict(dictionary)
    expect(Graphs.ast_to_expression(rebuilt.equation)).to eq("sin(x)")
  end
end
