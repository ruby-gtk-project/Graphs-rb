# frozen_string_literal: true

require_relative "base"
require_relative "data_holder"
require_relative "data_item"
require_relative "equation_item"
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
      end
    end

    def serialize_property(item, property)
      case Properties.normalize(property)
      when :data then serialize_data(item.data)
      else item[property]
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
      when :data then item.data = DataHolder.new(*value)
      when :equation then item.equation = Graphs.expression_to_ast(value)
      else item[property] = value
      end
    end

    def new_from_dict(dictionary)
      properties = dictionary.transform_keys { |key| Properties.normalize(key) }
      type = TYPES.fetch(properties.delete(:type).to_s)
      equation = properties.delete(:equation)
      data = properties.delete(:data)
      type.new.tap do |item|
        item.set_properties(properties)
        unless data.nil?
          item.data = DataHolder.new(*data)
        end
        unless equation.nil?
          item.equation = Graphs.expression_to_ast(equation)
        end
      end
    end
  end
end
