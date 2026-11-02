# frozen_string_literal: true

require "adwaita"

module Graphs
  # Ported from upstream's graphs/color_swatch.vala: a 20×20 circle filled
  # with a colour.
  #
  # Upstream subclasses Gtk.Widget and overrides `snapshot`; the Ruby bindings
  # cannot override a widget's snapshot, so the same circle is drawn with the
  # draw function of a Gtk.DrawingArea.
  class ColorSwatch
    SIZE = 20

    def initialize(color: nil)
      @color = color || Gdk::RGBA.new(
        1.0,
        0.0,
        0.0,
        1.0,
      )
    end

    def build
      widget.tap do |area|
        area.set_draw_func { |_, context, width, height| draw(context, width, height) }
      end
    end

    attr_reader :color

    def color=(rgba)
      @color = rgba
      widget.queue_draw
      rgba
    end

    def widget
      @widget ||= Gtk::DrawingArea.new.tap do |area|
        area.set_size_request(SIZE, SIZE)
        area.valign = :center
        area.halign = :center
      end
    end

    private

      def draw(context, width, height)
        context.set_source_rgba(
          @color.red,
          @color.green,
          @color.blue,
          @color.alpha,
        )
        context.arc(
          width / 2.0,
          height / 2.0,
          [width, height].min / 2.0,
          0,
          2 * Math::PI,
        )
        context.fill
      end
  end
end
