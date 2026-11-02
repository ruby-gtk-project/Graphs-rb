# frozen_string_literal: true

require "adwaita"
require_relative "color_swatch"

module Graphs
  # Ported from upstream's graphs/color_button.vala and
  # data/ui/color-button.blp: a flat button showing a colour swatch, which
  # opens the colour chooser and reports the chosen colour.
  class ColorButton
    def initialize(color: nil, &on_color_chosen)
      @on_color_chosen = on_color_chosen
      @swatch = ColorSwatch.new(color: color)
    end

    def build
      button.tap do |widget|
        widget.child = @swatch.build
        widget.signal_connect("clicked") { choose_color }
      end
    end

    def widget = button

    def color = @swatch.color

    def color=(rgba)
      @swatch.color = rgba
    end

    def button
      @button ||= Gtk::Button.new.tap do |widget|
        widget.tooltip_text = "Change Color"
        widget.add_css_class("flat")
        widget.vexpand = false
        widget.valign = :center
      end
    end

    private

      def choose_color
        Gtk::ColorDialog.new.tap do |dialog|
          dialog.with_alpha = true
          dialog.choose_rgba(button.root, color) do |_, result|
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
