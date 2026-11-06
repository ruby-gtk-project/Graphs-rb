# frozen_string_literal: true

require "adwaita"
require_relative "color_swatch"

module Graphs
  # Ported from upstream's graphs/color_row.vala and data/ui/color-row.blp:
  # an activatable Adw.ActionRow whose suffix is a colour swatch; activating
  # the row opens the colour chooser and reports the chosen colour.
  class ColorRow
    def initialize(color: nil, &on_color_chosen)
      @on_color_chosen = on_color_chosen
      @swatch = ColorSwatch.new(color: color)
    end

    def build
      row.tap do |widget|
        widget.add_suffix(@swatch.build)
        widget.signal_connect("activated") { choose_color }
      end
    end

    def widget = row

    def color = @swatch.color

    def color=(rgba)
      @swatch.color = rgba
    end

    def row
      @row ||= Adwaita::ActionRow.new.tap do |widget|
        widget.tooltip_text = "Change Color"
        widget.activatable = true
      end
    end

    private

      def choose_color
        Gtk::ColorDialog.new.tap do |dialog|
          dialog.with_alpha = false
          dialog.choose_rgba(row.root, color) do |_, result|
            on_chosen(dialog, result)
          end
        end
      end

      def on_chosen(dialog, result)
        chosen = dialog.choose_rgba_finish(result)
        unless chosen.nil?
          self.color = chosen
          @on_color_chosen&.call(chosen)
        end
      rescue StandardError
        # The user dismissed the chooser.
        nil
      end
  end
end
