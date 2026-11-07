# frozen_string_literal: true

require "adwaita"
require_relative "../item/base"
require_relative "../styles"
require_relative "../utilities"
require_relative "color_group"

module Graphs
  module StyleEditor
    # Ported from upstream's graphs/style_editor/editor_box.py and
    # data/ui/style-editor/editor-box.blp: the form of every parameter a
    # style carries, bound straight onto the parsed `params`/`graphs_params`
    # hashes `StyleIO` reads and writes.
    #
    # Each entry of `STYLE_DICT` is a parameter key paired with the one or
    # more matplotlib/Graphs keys it sets; `VALUE_DICT` holds the string
    # choices a combo row picks between.
    class EditorBox
      STYLE_DICT = {
        linestyle:          ["lines.linestyle"],
        linewidth:          ["lines.linewidth"],
        markers:            ["lines.marker"],
        markersize:         ["lines.markersize"],
        draw_frame:         %w[axes.spines.bottom axes.spines.left axes.spines.top axes.spines.right],
        axis_width:         ["axes.linewidth"],
        tick_direction:     %w[xtick.direction ytick.direction],
        minor_ticks:        %w[xtick.minor.visible ytick.minor.visible],
        major_tick_width:   %w[xtick.major.width ytick.major.width],
        minor_tick_width:   %w[xtick.minor.width ytick.minor.width],
        major_tick_length:  %w[xtick.major.size ytick.major.size],
        minor_tick_length:  %w[xtick.minor.size ytick.minor.size],
        tick_bottom:        ["xtick.bottom"],
        tick_left:          ["ytick.left"],
        tick_top:           ["xtick.top"],
        tick_right:         ["ytick.right"],
        tick_labels:        ["ticklabels"],
        show_grid:          ["axes.grid"],
        grid_linewidth:     ["grid.linewidth"],
        grid_opacity:       ["grid.alpha"],
        text_color:         %w[text.color axes.labelcolor xtick.labelcolor ytick.labelcolor],
        tick_color:         %w[xtick.color ytick.color],
        axis_color:         ["axes.edgecolor"],
        grid_color:         ["grid.color"],
        background_color:   ["axes.facecolor"],
        outline_color:      %w[figure.facecolor figure.edgecolor],
        errorbar_capsize:   ["errorbar.capsize"],
        errorbar_capthick:  ["errorbar.capthick"],
        errorbar_linewidth: ["errorbar.linewidth"],
        errorbar_barsabove: ["errorbar.barsabove"],
      }.freeze

      GRAPHS_PARAMS = %w[ticklabels errorbar.capsize errorbar.capthick errorbar.linewidth errorbar.barsabove].freeze

      VALUE_DICT = {
        linestyle:      Item::LINESTYLES,
        markers:        Item::MARKERSTYLES,
        tick_direction: %w[in out],
      }.freeze

      attr_reader :parameters

      def initialize(&on_params_changed)
        @params = nil
        @graphs_params = nil
        @parameters = nil
        @on_params_changed = on_params_changed
        @loading = false
      end

      def build
        box.tap do |widget|
          widget.append(name_group)
          widget.append(lines_group)
          widget.append(frame_group)
          widget.append(ticks_group)
          widget.append(grid_group)
          widget.append(colors_group)
          widget.append(errorbar_group)
          widget.append(font_group)
          widget.append(line_colors.widget)
          widget.append(errorbar_colors.widget)

          connect_rows
        end
      end

      def widget = box

      # Loads a style file's parameters and populates every widget from them.
      def load(file)
        @loading = true
        params, graphs_params = StyleIO.parse(Tools.file_path(file))
        @params = params
        @graphs_params = graphs_params
        style_name_row.text = graphs_params.fetch("name", "")
        STYLE_DICT.each_key { |key| load_widget_value(key) }
        load_font
        line_colors.colors = color_cycle_list(@params.fetch("axes.prop_cycle", ""))
        errorbar_colors.colors = color_cycle_list(@graphs_params.fetch("errorbar.color_cycle", ""), ["000000"])
        @loading = false
        update_parameters
      end

      def save(file) = StyleIO.write(Tools.file_path(file), @params, @graphs_params)

      private

        def connect_rows
          style_name_row.signal_connect("changed") { on_name_change }
          font_button.signal_connect("notify::font-desc") { on_font_change }
          titlesize_row.signal_connect("value-changed") { on_titlesize_change }
          labelsize_row.signal_connect("value-changed") { on_labelsize_change }

          STYLE_DICT.each_key do |key|
            widget = widget_for(key)
            unless widget.nil?
              connect_widget(key, widget)
            end
          end
        end

        def connect_widget(key, widget)
          case widget
          when Adwaita::ComboRow
            widget.signal_connect("notify::selected") { apply_value(key, decode_value(key, widget.selected)) }
          when Gtk::Scale
            widget.signal_connect("value-changed") { apply_value(key, widget.adjustment.value) }
          when Adwaita::SwitchRow
            widget.signal_connect("notify::active") { apply_value(key, widget.active?) }
          end
        end

        # Colour rows are driven through the `ColorButton` wrapper's own
        # callback, set up in `color_row_for`, not through `connect_widget`.
        def color_row_for(key)
          ColorButton.new(color: Tools.hex_to_rgba(color_param(key))) do |rgba|
            apply_value(key, Tools.rgba_to_hex(rgba).delete_prefix("#"))
          end
        end

        def color_param(key)
          if @params.nil?
            "000000"
          else
            STYLE_DICT.fetch(key).first.then { |param| graphs_or_style_param(param) }
          end
        end

        def graphs_or_style_param(param)
          if GRAPHS_PARAMS.include?(param)
            @graphs_params.fetch(param, "000000")
          else
            @params.fetch(param, "000000")
          end
        end

        def widget_for(key)
          case key
          when :linestyle then linestyle_row
          when :linewidth then linewidth_row
          when :markers then markers_row
          when :markersize then markersize_row
          when :draw_frame then draw_frame_row
          when :axis_width then axis_width_row
          when :tick_direction then tick_direction_row
          when :minor_ticks then minor_ticks_row
          when :major_tick_width then major_tick_width_row
          when :minor_tick_width then minor_tick_width_row
          when :major_tick_length then major_tick_length_row
          when :minor_tick_length then minor_tick_length_row
          when :tick_bottom then tick_bottom_row
          when :tick_left then tick_left_row
          when :tick_top then tick_top_row
          when :tick_right then tick_right_row
          when :tick_labels then tick_labels_row
          when :show_grid then show_grid_row
          when :grid_linewidth then grid_linewidth_row
          when :grid_opacity then grid_opacity_row
          when :errorbar_capsize then errorbar_capsize_row
          when :errorbar_capthick then errorbar_capthick_row
          when :errorbar_linewidth then errorbar_linewidth_row
          when :errorbar_barsabove then errorbar_barsabove_row
          end
        end

        def load_widget_value(key)
          widget = widget_for(key)
          if widget.nil?
            load_color_row(key)
          else
            load_value_widget(key, widget)
          end
        end

        def load_color_row(key)
          color_button_for(key).color = Tools.hex_to_rgba(color_param(key))
        end

        def load_value_widget(key, widget)
          value = decode_loaded_value(key, graphs_or_style_param(STYLE_DICT.fetch(key).first))
          case widget
          when Adwaita::ComboRow then widget.selected = value
          when Gtk::Scale then widget.adjustment.value = value.to_f
          when Adwaita::SwitchRow then widget.active = truthy?(value)
          end
        end

        def decode_loaded_value(key, value)
          choices = VALUE_DICT[key]
          if choices.nil?
            value
          else
            choices.index(value.to_s) || 0
          end
        end

        def decode_value(key, selected)
          choices = VALUE_DICT[key]
          if choices.nil?
            selected
          else
            choices[selected]
          end
        end

        def truthy?(value) = %w[true 1 yes on].include?(value.to_s.downcase)

        def apply_value(key, value)
          unless @loading || @params.nil?
            STYLE_DICT.fetch(key).each do |param|
              if GRAPHS_PARAMS.include?(param)
                @graphs_params[param] = value
              else
                @params[param] = value
              end
            end
            update_parameters
          end
        end

        def on_name_change
          unless @loading || @graphs_params.nil?
            @graphs_params["name"] = style_name_row.text
            update_parameters
          end
        end

        def on_font_change
          unless @loading || @params.nil?
            description = font_button.font_desc
            @font_size = description.size / Pango::SCALE.to_f
            @params["font.sans-serif"] = [description.family]
            %w[font.size xtick.labelsize ytick.labelsize legend.fontsize figure.labelsize].each do |key|
              @params[key] = @font_size
            end
            @params["font.weight"] = description.weight.nick
            @params["font.style"] = description.style.nick
            @params["font.variant"] = description.variant.nick
            update_parameters
          end
        end

        def on_titlesize_change
          unless @loading || @params.nil?
            @params["figure.titlesize"] = (titlesize_row.adjustment.value / 2.0 * font_size).round(1)
            @params["axes.titlesize"] = @params["figure.titlesize"]
            update_parameters
          end
        end

        def on_labelsize_change
          unless @loading || @params.nil?
            @params["axes.labelsize"] = (labelsize_row.adjustment.value / 2.0 * font_size).round(1)
            update_parameters
          end
        end

        def font_size = @font_size ||= 12.0

        def load_font
          description = Pango::FontDescription.new
          @font_size = @params.fetch("font.size", "12").to_f
          description.size = (@font_size * Pango::SCALE).to_i
          description.family = Array(@params["font.sans-serif"]).first || "Sans"
          font_button.font_desc = description
          titlesize_row.adjustment.value = (
            @params.fetch("figure.titlesize", "12").to_f * 2 / @font_size
          ).round(1)
          labelsize_row.adjustment.value = (@params.fetch("axes.labelsize", "12").to_f * 2 / @font_size).round(1)
        end

        def color_cycle_list(raw, fallback = ["1A5FB4"])
          list = raw[/\[([^\]]*)\]/, 1] || raw
          colors = list.scan(/['"]([^'"]+)['"]/).flatten
          if colors.empty?
            colors = raw.to_s.split(",").map(&:strip).reject(&:empty?)
          end
          if colors.empty?
            fallback
          else
            colors
          end
        end

        def on_line_colors_changed(colors)
          unless @loading || @params.nil?
            @params["axes.prop_cycle"] = "cycler('color', #{colors.inspect})"
            @params["patch.facecolor"] = colors.first
            update_parameters
          end
        end

        def on_errorbar_colors_changed(colors)
          unless @loading || @graphs_params.nil?
            @graphs_params["errorbar.color_cycle"] = "cycler('color', #{colors.inspect})"
            update_parameters
          end
        end

        def update_parameters
          unless @params.nil?
            @parameters = StyleParameters.new(@params, @graphs_params)
            @on_params_changed&.call(@parameters)
          end
        end

        def color_button_for(key)
          @color_buttons ||= {}
          @color_buttons[key] ||= color_row_for(key)
        end

        def box = @box ||= Gtk::Box.new(:vertical, 16)

        def name_group
          @name_group ||= Adwaita::PreferencesGroup.new.tap do |group|
            group.title = "Name"
            group.add(style_name_row)
          end
        end

        def style_name_row
          @style_name_row ||= Adwaita::EntryRow.new.tap { |row| row.title = "Style Name" }
        end

        def lines_group
          @lines_group ||= Adwaita::PreferencesGroup.new.tap do |group|
            group.title = "Lines and Markers"
            group.add(linestyle_row)
            group.add(scale_row(linewidth_row, "Line Width"))
            group.add(markers_row)
            group.add(scale_row(markersize_row, "Marker Size"))
          end
        end

        def linestyle_row
          @linestyle_row ||= combo_row("Line Style", Item::LINESTYLES)
        end

        def linewidth_row
          @linewidth_row ||= scale(0.5, 10.0, 0.1)
        end

        def markers_row
          @markers_row ||= combo_row("Markers", Item::MARKERSTYLES)
        end

        def markersize_row
          @markersize_row ||= scale(0.0, 20.0, 0.5)
        end

        def frame_group
          @frame_group ||= Adwaita::PreferencesGroup.new.tap do |group|
            group.title = "Frame"
            group.add(draw_frame_row)
            group.add(scale_row(axis_width_row, "Axis Width"))
          end
        end

        def draw_frame_row
          @draw_frame_row ||= switch_row("Draw Frame")
        end

        def axis_width_row
          @axis_width_row ||= scale(0.1, 5.0, 0.1)
        end

        def ticks_group
          @ticks_group ||= Adwaita::PreferencesGroup.new.tap do |group|
            group.title = "Ticks"
            [
              tick_direction_row,
              minor_ticks_row,
              scale_row(major_tick_width_row, "Major Tick Width"),
              scale_row(minor_tick_width_row, "Minor Tick Width"),
              scale_row(major_tick_length_row, "Major Tick Length"),
              scale_row(minor_tick_length_row, "Minor Tick Length"),
              tick_bottom_row,
              tick_left_row,
              tick_top_row,
              tick_right_row,
              tick_labels_row,
            ].each { |row| group.add(row) }
          end
        end

        def tick_direction_row = @tick_direction_row ||= combo_row("Tick Direction", %w[in out])
        def minor_ticks_row = @minor_ticks_row ||= switch_row("Minor Ticks")
        def major_tick_width_row = @major_tick_width_row ||= scale(0.1, 5.0, 0.1)
        def minor_tick_width_row = @minor_tick_width_row ||= scale(0.1, 5.0, 0.1)
        def major_tick_length_row = @major_tick_length_row ||= scale(0.0, 20.0, 0.5)
        def minor_tick_length_row = @minor_tick_length_row ||= scale(0.0, 20.0, 0.5)
        def tick_bottom_row = @tick_bottom_row ||= switch_row("Tick Bottom")
        def tick_left_row = @tick_left_row ||= switch_row("Tick Left")
        def tick_top_row = @tick_top_row ||= switch_row("Tick Top")
        def tick_right_row = @tick_right_row ||= switch_row("Tick Right")
        def tick_labels_row = @tick_labels_row ||= switch_row("Tick Labels")

        def grid_group
          @grid_group ||= Adwaita::PreferencesGroup.new.tap do |group|
            group.title = "Grid"
            group.add(show_grid_row)
            group.add(scale_row(grid_linewidth_row, "Grid Line Width"))
            group.add(scale_row(grid_opacity_row, "Grid Opacity"))
          end
        end

        def show_grid_row = @show_grid_row ||= switch_row("Show Grid")
        def grid_linewidth_row = @grid_linewidth_row ||= scale(0.1, 5.0, 0.1)
        def grid_opacity_row = @grid_opacity_row ||= scale(0.0, 1.0, 0.05)

        def colors_group
          @colors_group ||= Adwaita::PreferencesGroup.new.tap do |group|
            group.title = "Colors"
            [:text_color, :tick_color, :axis_color, :grid_color, :background_color, :outline_color].each do |key|
              group.add(color_row(key, key.to_s.split("_").map(&:capitalize).join(" ")))
            end
          end
        end

        def color_row(key, title)
          Adwaita::ActionRow.new.tap do |row|
            row.title = title
            row.add_suffix(color_button_for(key).build)
          end
        end

        def errorbar_group
          @errorbar_group ||= Adwaita::PreferencesGroup.new.tap do |group|
            group.title = "Error Bars"
            group.add(scale_row(errorbar_capsize_row, "Cap Size"))
            group.add(scale_row(errorbar_capthick_row, "Cap Thickness"))
            group.add(scale_row(errorbar_linewidth_row, "Line Width"))
            group.add(errorbar_barsabove_row)
          end
        end

        def errorbar_capsize_row = @errorbar_capsize_row ||= scale(0.0, 20.0, 0.5)
        def errorbar_capthick_row = @errorbar_capthick_row ||= scale(0.1, 5.0, 0.1)
        def errorbar_linewidth_row = @errorbar_linewidth_row ||= scale(0.1, 5.0, 0.1)
        def errorbar_barsabove_row = @errorbar_barsabove_row ||= switch_row("Bars Above")

        def font_group
          @font_group ||= Adwaita::PreferencesGroup.new.tap do |group|
            group.title = "Font"
            group.add(font_row)
            group.add(scale_row(titlesize_row, "Title Size"))
            group.add(scale_row(labelsize_row, "Label Size"))
          end
        end

        def font_row
          @font_row ||= Adwaita::ActionRow.new.tap do |row|
            row.title = "Font"
            row.add_suffix(font_button)
          end
        end

        def font_button = @font_button ||= Gtk::FontDialogButton.new(Gtk::FontDialog.new)
        def titlesize_row = @titlesize_row ||= scale(0.5, 4.0, 0.1)
        def labelsize_row = @labelsize_row ||= scale(0.5, 4.0, 0.1)

        def line_colors
          @line_colors ||= ColorGroup.new { |colors| on_line_colors_changed(colors) }.tap do |group|
            group.build
            group.widget.title = "Line Colors"
          end
        end

        def errorbar_colors
          @errorbar_colors ||= ColorGroup.new { |colors| on_errorbar_colors_changed(colors) }.tap do |group|
            group.build
            group.widget.title = "Error Bar Colors"
          end
        end

        def scale(lower, upper, step)
          Gtk::Scale.new(
            :horizontal,
            Gtk::Adjustment.new(lower, lower, upper, step, step, 0.0),
          ).tap do |widget|
            widget.hexpand = true
            widget.digits = 2
            widget.value_pos = :right
          end
        end

        def scale_row(scale_widget, title)
          Adwaita::ActionRow.new.tap do |row|
            row.title = title
            scale_widget.width_request = 160
            row.add_suffix(scale_widget)
          end
        end

        def switch_row(title) = Adwaita::SwitchRow.new.tap { |row| row.title = title }

        def combo_row(title, choices)
          Adwaita::ComboRow.new.tap do |row|
            row.title = title
            row.model = Gtk::StringList.new(choices)
          end
        end
    end
  end
end
