# frozen_string_literal: true

require_relative "base"
require_relative "data_holder"
require_relative "data_item"
require_relative "equation_item"
require_relative "fill_item"
require_relative "generated_data_item"
require_relative "text_item"
require_relative "../math_parser"

module Graphs
  # Ported from upstream's graphs/item/factory.vala and the ItemFactory class
  # of graphs/item/__init__.py.
  #
  # Creates items with the current style's parameters applied, converts them
  # to and from the plain hashes the undo history and project files store, and
  # moves items onto a new style's parameters when the style changes.
  module ItemFactory
    # Which item property each style parameter feeds, and how the parameter's
    # value is converted. An equation item has no markers, so its line style
    # index is one lower than a dataset's.
    STYLE_PROPERTIES = {
      "DataItem"     => {
        errbarsabove: ["errorbar.barsabove", :boolean],
        errcapsize:   ["errorbar.capsize", :float],
        errcapthick:  ["errorbar.capthick", :float],
        errlinewidth: ["errorbar.linewidth", :float],
        linestyle:    ["lines.linestyle", :linestyle],
        linewidth:    ["lines.linewidth", :float],
        markerstyle:  ["lines.marker", :markerstyle],
        markersize:   ["lines.markersize", :float],
      },
      "EquationItem" => {
        linestyle: ["lines.linestyle", :equation_linestyle],
        linewidth: ["lines.linewidth", :float],
      },
      "TextItem"     => {
        size:  ["font.size", :float],
        color: ["text.color", :string],
      },
    }.freeze

    TYPES = {
      "DataItem"          => DataItem,
      "GeneratedDataItem" => GeneratedDataItem,
      "EquationItem"      => EquationItem,
      "TextItem"          => TextItem,
      "FillItem"          => FillItem,
    }.freeze

    module_function

    def new_data_item(parameters, xdata, ydata, xerr = nil, yerr = nil)
      DataItem.new(
        data: DataHolder.new(
          xdata,
          ydata,
          xerr,
          yerr,
        ),
      ).tap do |item|
        override_item(item, parameters)
      end
    end

    def new_generated_data_item(parameters, equation, xstart, xstop, steps, scale)
      GeneratedDataItem.new(
        equation: equation,
        xstart:   xstart,
        xstop:    xstop,
        steps:    steps,
        scale:    scale,
      ).tap do |item|
        override_item(item, parameters)
      end
    end

    def new_equation_item(parameters, equation)
      EquationItem.new(equation: equation).tap do |item|
        item.name = "Y = #{Graphs.ast_to_expression(equation)}"
        override_item(item, parameters)
      end
    end

    # A fill starts out empty: its values follow from the bounds the dialog
    # sets on it.
    def new_fill_item(parameters, xdata = [], lower = [], upper = [])
      FillItem.new(
        data: FillHolder.new(
          xdata,
          lower,
          upper,
        ),
      ).tap do |item|
        override_item(item, parameters)
      end
    end

    def new_text_item(parameters, xanchor, yanchor, text)
      TextItem.new(
        xanchor: xanchor,
        yanchor: yanchor,
        text:    text,
        name:    text,
      ).tap do |item|
        override_item(item, parameters)
      end
    end

    # Applies a style's parameters to an item, overwriting what it had.
    def override_item(item, parameters)
      style_properties(item).each do |property, (key, conversion)|
        item[property] = convert(style_value(parameters, key), conversion)
      end
    end

    # Moves an item onto a new style, but only for the properties it still
    # holds the old style's value for.
    def reset_item(item, old_parameters, new_parameters)
      style_properties(item).each do |property, (key, conversion)|
        old_value = convert(style_value(old_parameters, key), conversion)
        new_value = convert(style_value(new_parameters, key), conversion)
        if item[property] == old_value
          item[property] = new_value
        end
      end
    end

    def style_properties(item)
      if item.is_a?(DataItem)
        STYLE_PROPERTIES.fetch("DataItem")
      elsif item.is_a?(EquationItem)
        STYLE_PROPERTIES.fetch("EquationItem")
      elsif item.is_a?(TextItem)
        STYLE_PROPERTIES.fetch("TextItem")
      else
        {}
      end
    end

    # Graphs' own parameters and the matplotlib ones are one namespace here,
    # as they are upstream.
    def style_value(parameters, key)
      parameters.params.fetch(key) { parameters.graphs_params[key] }
    end

    def convert(value, conversion)
      case conversion
      when :float then value.to_f
      when :string then value.to_s
      when :boolean then %w[true 1 yes on].include?(value.to_s.downcase)
      when :linestyle then linestyle_index(value)
      when :equation_linestyle then [linestyle_index(value) - 1, 0].max
      when :markerstyle then [Item::MARKERSTYLES.index(value.to_s), 0].compact.max
      end
    end

    def linestyle_index(value) = Item::LINESTYLES.index(value.to_s) || 1

    def type_name(item) = TYPES.key(item.class)

    # Serializes an item the way the undo history and project files store it.
    def to_dict(item)
      item.to_h.keys.to_h do |property|
        [property, serialize_property(item, property)]
      end.tap do |dictionary|
        dictionary.delete(:visible)
        dictionary[:type] = type_name(item)
        if item.equation_based?
          dictionary[:equation] = item.equation_string
        end
        if item.is_a?(FillItem)
          dictionary[:upper_equation] = expression_or_nil(item.get_upper_equation)
          dictionary[:lower_equation] = expression_or_nil(item.get_lower_equation)
        end
      end
    end

    def expression_or_nil(equation)
      unless equation.nil?
        Graphs.ast_to_expression(equation)
      end
    end

    # A bound that follows another item is stored as that item's position, so
    # the reference survives a round trip through a project file or the undo
    # history.
    def link_dependencies(item, dictionary, items)
      dictionary.tap do |linked|
        if item.is_a?(FillItem)
          linked[:upper_source] = items.index(item.get_upper_source)
          linked[:lower_source] = items.index(item.get_lower_source)
        end
      end
    end

    def resolve_dependencies(item, dictionary, items)
      item.tap do |resolved|
        if resolved.is_a?(FillItem)
          bind_source(
            resolved,
            dictionary[:upper_source],
            items,
            true,
          )
          bind_source(
            resolved,
            dictionary[:lower_source],
            items,
            false,
          )
        end
      end
    end

    def bind_source(fill, position, items, upper)
      unless position.nil? || position >= items.length
        if upper
          fill.set_upper_source(items[position])
        else
          fill.set_lower_source(items[position])
        end
      end
    end

    def serialize_property(item, property)
      case Properties.normalize(property)
      when :data then serialize_holder(item)
      when :equation then item.equation_string
      else item[property]
      end
    end

    def serialize_holder(item)
      if item.is_a?(FillItem)
        [Array(item.data.xdata), Array(item.data.lower), Array(item.data.upper)]
      else
        serialize_data(item.data)
      end
    end

    def serialize_data(holder)
      [
        Array(holder.xdata),
        Array(holder.ydata),
        holder.xerr,
        holder.yerr,
      ]
    end

    def deserialize_property(item, property, value)
      case Properties.normalize(property)
      when :data then item.data = holder_from(item, value)
      when :equation then item.equation = Graphs.expression_to_ast(value)
      when :xposition then item.xposition = XPosition.from_string(value.to_s)
      when :yposition then item.yposition = YPosition.from_string(value.to_s)
      else item[property] = value
      end
    end

    def holder_from(item, value)
      if item.is_a?(FillItem)
        FillHolder.new(*value)
      else
        DataHolder.new(*value)
      end
    end

    def new_from_dict(dictionary)
      properties = dictionary.transform_keys { |key| Properties.normalize(key) }
      type = TYPES.fetch(properties.delete(:type).to_s)
      equation = properties.delete(:equation)
      data = properties.delete(:data)
      bounds = [properties.delete(:upper_equation), properties.delete(:lower_equation)]
      properties.delete(:upper_source)
      properties.delete(:lower_source)
      type.new.tap do |item|
        item.set_properties(properties)
        unless properties[:xposition].nil?
          item.xposition = XPosition.from_string(properties[:xposition].to_s)
        end
        unless properties[:yposition].nil?
          item.yposition = YPosition.from_string(properties[:yposition].to_s)
        end
        unless data.nil?
          item.data = holder_from(item, data)
        end
        unless equation.nil?
          item.equation = Graphs.expression_to_ast(equation)
        end
        if item.is_a?(FillItem)
          restore_bounds(item, bounds)
        end
      end
    end

    def restore_bounds(item, bounds)
      upper, lower = bounds
      unless upper.nil?
        item.set_upper_equation(Graphs.expression_to_ast(upper))
      end
      unless lower.nil?
        item.set_lower_equation(Graphs.expression_to_ast(lower))
      end
    end
  end
end
