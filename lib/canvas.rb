# frozen_string_literal: true

require "adwaita"
require_relative "enums"
require_relative "item/factory"
require_relative "item/fill_item"
require_relative "properties"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/canvas/canvas.vala, canvas.py, figure.py,
  # artist.py and scales.py.
  #
  # Upstream draws the figure with matplotlib embedded in a GTK widget; this
  # port draws it with Cairo on a Gtk.DrawingArea. What is drawn, and how the
  # three mouse modes behave, follows upstream: the four axes with their own
  # limits and scales, the grid, the items, the legend, the selection
  # highlight, and pan, zoom and select on drag.
  class Canvas
    include Signals

    AXIS_FONT_RATIO = 1.0
    TICK_LENGTH = 4.0
    LEGEND_PADDING = 8.0

    # Where each mode's drag leaves the figure.
    SCROLL_FACTOR = 1.1

    # The order upstream's used-positions array uses: the two x axes, then
    # the two y axes.
    DIRECTIONS = %w[bottom top left right].freeze

    # Pixels reserved around the axes for labels and ticks.
    MARGIN = {
      left:   70.0,
      right:  70.0,
      top:    40.0,
      bottom: 55.0,
    }.freeze

    attr_reader :data, :mode

    def initialize(data:)
      @data = data
      @mode = :pan
      @drag = nil
    end

    # Builds the drawing area and its controllers; the result is the widget to
    # put in the window.
    def build
      drawing_area.tap do |area|
        area.set_draw_func { |_, context, width, height| draw(context, width, height) }

        drag_gesture.tap do |gesture|
          gesture.signal_connect("drag-begin") { |_, x, y| on_drag_begin(x, y) }
          gesture.signal_connect("drag-update") { |_, x, y| on_drag_update(x, y) }
          gesture.signal_connect("drag-end") { |_, x, y| on_drag_end(x, y) }
        end
        area.add_controller(drag_gesture)

        scroll_controller.tap do |controller|
          controller.signal_connect("scroll") { |_, _dx, dy| on_scroll(dy) }
        end
        area.add_controller(scroll_controller)

        click_gesture.tap do |gesture|
          gesture.signal_connect("pressed") { |_, n_press, x, y| on_click(n_press, x, y) }
        end
        area.add_controller(click_gesture)

        motion_controller.tap do |controller|
          controller.signal_connect("motion") { |_, x, y| on_motion(x, y) }
        end
        area.add_controller(motion_controller)
      end
    end

    def widget = drawing_area

    def mode=(value)
      @mode = value
      emit_signal(:mode_changed, value)
      drawing_area.queue_draw
    end

    def queue_draw = drawing_area.queue_draw

    # The zoom the keyboard shortcuts trigger, centred on the axes.
    def zoom_in = zoom(1 / SCROLL_FACTOR)
    def zoom_out = zoom(SCROLL_FACTOR)

    # Nothing has been drawn before the first frame, so there is no area to
    # zoom around yet.
    def zoom(factor)
      unless @width.nil?
        zoom_at(@pointer, factor)
        emit_signal(:view_changed)
        drawing_area.queue_draw
      end
    end

    # Draws the figure into any Cairo context at a size of its own, which is
    # how the figure is written to a file. The on-screen size is put back
    # afterwards, so the pointer maths keeps working while the export runs.
    def draw_to(context, width, height, transparent = false)
      [@width, @height].then do |size|
        draw(
          context,
          width,
          height,
          transparent,
        )
        @width, @height = size
      end
    end

    def figure_settings = @data.figure_settings

    def style_params = @data.selected_style_params

    def drawing_area
      @drawing_area ||= Gtk::DrawingArea.new.tap do |area|
        area.hexpand = true
        area.vexpand = true
        area.focusable = true
        area.add_css_class("canvas-view")
      end
    end

    def drag_gesture = @drag_gesture ||= Gtk::GestureDrag.new
    def click_gesture = @click_gesture ||= Gtk::GestureClick.new
    def scroll_controller = @scroll_controller ||= Gtk::EventControllerScroll.new(:vertical)
    def motion_controller = @motion_controller ||= Gtk::EventControllerMotion.new

    private

      # Section drawing

      def draw(context, width, height, transparent = false)
        @width = width.to_f
        @height = height.to_f
        unless transparent
          fill(
            context,
            0,
            0,
            @width,
            @height,
            style_params.outline_color,
          )
        end
        plot_area.then do |left, top, right, bottom|
          fill(
            context,
            left,
            top,
            right - left,
            bottom - top,
            style_params.background_color,
          )
        end
        draw_grid_and_ticks(context)
        draw_axis_labels(context)
        draw_title(context)
        draw_items(context)
        draw_selection(context)
        draw_frame(context)
        draw_legend(context)
        draw_band(context)
      end

      # The rectangle the data is drawn in: left, top, right, bottom in pixels.
      def plot_area
        [
          MARGIN[:left],
          MARGIN[:top],
          @width - MARGIN[:right],
          @height - MARGIN[:bottom],
        ]
      end

      def fill(context, x, y, width, height, color)
        set_color(context, color, 1.0)
        context.rectangle(
          x,
          y,
          width,
          height,
        )
        context.fill
      end

      def set_color(context, color, alpha)
        Tools.hex_to_rgba(color).then do |rgba|
          context.set_source_rgba(
            rgba.red,
            rgba.green,
            rgba.blue,
            alpha,
          )
        end
      end

      def draw_frame(context)
        left, top, right, bottom = plot_area
        set_color(context, style_params.tick_color, 1.0)
        context.set_line_width(1.0)
        context.rectangle(
          left,
          top,
          right - left,
          bottom - top,
        )
        context.stroke
      end

      # Section axes

      # Which of the four axes are in use, so an unused one costs no ticks.
      def used_positions = @data.used_positions

      def axis_used?(direction) = used_positions[DIRECTIONS.index(direction)]

      def limits_for(direction)
        [
          figure_settings["min-#{direction}"],
          figure_settings["max-#{direction}"],
        ]
      end

      def scale_for(direction) = figure_settings["#{direction}-scale"]

      def x_pixel(value, direction)
        left, _top, right, _bottom = plot_area
        minimum, maximum = limits_for(direction)
        fraction = Graphs.get_fraction_at_value(
          value,
          minimum,
          maximum,
          scale_for(direction),
        )
        left + (fraction * (right - left))
      end

      def y_pixel(value, direction)
        _left, top, _right, bottom = plot_area
        minimum, maximum = limits_for(direction)
        fraction = Graphs.get_fraction_at_value(
          value,
          minimum,
          maximum,
          scale_for(direction),
        )
        bottom - (fraction * (bottom - top))
      end

      def x_value(pixel, direction)
        left, _top, right, _bottom = plot_area
        minimum, maximum = limits_for(direction)
        Graphs.get_value_at_fraction(
          (pixel - left) / (right - left),
          minimum,
          maximum,
          scale_for(direction),
        )
      end

      def y_value(pixel, direction)
        _left, top, _right, bottom = plot_area
        minimum, maximum = limits_for(direction)
        Graphs.get_value_at_fraction(
          (bottom - pixel) / (bottom - top),
          minimum,
          maximum,
          scale_for(direction),
        )
      end

      # Section ticks

      # The tick values of one axis: whole decades on a logarithmic axis,
      # multiples of pi on a radians axis, and a 1/2/5 step elsewhere.
      def ticks_for(direction)
        minimum, maximum = limits_for(direction)
        scale = scale_for(direction)
        case scale
        when :log then decade_ticks(minimum, maximum, 10.0)
        when :log2 then decade_ticks(minimum, maximum, 2.0)
        when :radians then radian_ticks(minimum, maximum)
        when :linear then nice_ticks(minimum, maximum)
        else fraction_ticks(minimum, maximum, scale)
        end
      end

      def nice_ticks(minimum, maximum)
        span = maximum - minimum
        if span <= 0 || !span.finite?
          []
        else
          step = tick_step(span)
          first = (minimum / step).ceil * step
          values = []
          value = first
          while value <= maximum + (step / 1000)
            values << value
            value += step
          end
          values
        end
      end

      # A step of 1, 2 or 5 times a power of ten, aiming for five ticks.
      def tick_step(span)
        rough = span / 5.0
        magnitude = 10.0**Math.log10(rough).floor
        normalized = rough / magnitude
        if normalized < 1.5
          magnitude
        elsif normalized < 3.0
          2.0 * magnitude
        elsif normalized < 7.0
          5.0 * magnitude
        else
          10.0 * magnitude
        end
      end

      def decade_ticks(minimum, maximum, base)
        if minimum <= 0 || maximum <= 0
          []
        else
          first = Math.log(minimum, base).ceil
          last = Math.log(maximum, base).floor
          (first..last).map { |exponent| base**exponent }
        end
      end

      def radian_ticks(minimum, maximum)
        step = Math::PI / 2
        first = (minimum / step).ceil
        last = (maximum / step).floor
        (first..last).map { |multiple| multiple * step }
      end

      # Scales without a natural tick spacing get ticks at even fractions of
      # the axis, which is how upstream's custom scales place theirs.
      def fraction_ticks(minimum, maximum, scale)
        (0..5).map do |step|
          Graphs.get_value_at_fraction(
            step / 5.0,
            minimum,
            maximum,
            scale,
          )
        end
      end

      def tick_label(value, scale)
        if scale == :radians
          MathTools.prettyprint_double(value)
        else
          format_number(value)
        end
      end

      # Short enough to fit under a tick: plain digits in the middle range,
      # exponent notation outside it.
      def format_number(value)
        if value.zero?
          "0"
        elsif value.abs >= 1e5 || value.abs < 1e-4
          format("%.1e", value)
        else
          format("%g", MathTools.sig_fig_round(value, 4))
        end
      end

      def draw_grid_and_ticks(context)
        left, top, right, bottom = plot_area
        context.set_line_width(style_params.grid_linewidth)

        %w[bottom top].each do |direction|
          if axis_used?(direction)
            draw_vertical_ticks(
              context,
              direction,
              left,
              right,
              top,
              bottom,
            )
          end
        end

        %w[left right].each do |direction|
          if axis_used?(direction)
            draw_horizontal_ticks(
              context,
              direction,
              left,
              right,
              top,
              bottom,
            )
          end
        end
      end

      def draw_vertical_ticks(context, direction, left, right, top, bottom)
        primary = direction == "bottom"
        ticks_for(direction).each do |value|
          pixel = x_pixel(value, direction)
          unless pixel >= left - 0.5 && pixel <= right + 0.5
            next
          end

          if primary && style_params.grid?
            draw_grid_line(
              context,
              pixel,
              top,
              pixel,
              bottom,
            )
          end
          draw_tick_mark(context, direction, pixel)
          draw_tick_label(
            context,
            direction,
            value,
            pixel,
          )
        end
      end

      def draw_horizontal_ticks(context, direction, left, right, top, bottom)
        primary = direction == "left"
        ticks_for(direction).each do |value|
          pixel = y_pixel(value, direction)
          unless pixel >= top - 0.5 && pixel <= bottom + 0.5
            next
          end

          if primary && style_params.grid?
            draw_grid_line(
              context,
              left,
              pixel,
              right,
              pixel,
            )
          end
          draw_tick_mark(context, direction, pixel)
          draw_tick_label(
            context,
            direction,
            value,
            pixel,
          )
        end
      end

      def draw_grid_line(context, x1, y1, x2, y2)
        set_color(context, style_params.grid_color, style_params.grid_alpha)
        context.set_line_width(style_params.grid_linewidth)
        context.move_to(x1, y1)
        context.line_to(x2, y2)
        context.stroke
      end

      def draw_tick_mark(context, direction, pixel)
        left, top, right, bottom = plot_area
        set_color(context, style_params.tick_color, 1.0)
        context.set_line_width(1.0)
        case direction
        when "bottom" then tick_segment(
          context,
          pixel,
          bottom,
          pixel,
          bottom - TICK_LENGTH,
        )
        when "top" then tick_segment(
          context,
          pixel,
          top,
          pixel,
          top + TICK_LENGTH,
        )
        when "left" then tick_segment(
          context,
          left,
          pixel,
          left + TICK_LENGTH,
          pixel,
        )
        when "right" then tick_segment(
          context,
          right,
          pixel,
          right - TICK_LENGTH,
          pixel,
        )
        end
      end

      def tick_segment(context, x1, y1, x2, y2)
        context.move_to(x1, y1)
        context.line_to(x2, y2)
        context.stroke
      end

      def draw_tick_label(context, direction, value, pixel)
        left, top, right, bottom = plot_area
        text = tick_label(value, scale_for(direction))
        set_font(context)
        set_color(context, style_params.label_color, 1.0)
        extents = context.text_extents(text)
        case direction
        when "bottom"
          show_text_at(
            context,
            text,
            pixel - (extents.width / 2),
            bottom + 18,
          )
        when "top"
          show_text_at(
            context,
            text,
            pixel - (extents.width / 2),
            top - 8,
          )
        when "left"
          show_text_at(
            context,
            text,
            left - extents.width - 8,
            pixel + (extents.height / 2),
          )
        when "right"
          show_text_at(
            context,
            text,
            right + 8,
            pixel + (extents.height / 2),
          )
        end
      end

      def set_font(context)
        context.select_font_face("sans-serif", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
        context.set_font_size(style_params.font_size * AXIS_FONT_RATIO)
      end

      def show_text_at(context, text, x, y)
        context.move_to(x, y)
        context.show_text(text)
      end

      def draw_axis_labels(context)
        left, top, right, bottom = plot_area
        set_font(context)
        set_color(context, style_params.label_color, 1.0)

        # An axis nothing is drawn against carries no label, as upstream hides
        # the whole axis then.
        if axis_used?("bottom")
          draw_centered(
            context,
            figure_settings.bottom_label,
            (left + right) / 2,
            @height - 12,
          )
        end
        if axis_used?("top")
          draw_centered(
            context,
            figure_settings.top_label,
            (left + right) / 2,
            top - 24,
          )
        end
        if axis_used?("left")
          draw_rotated(
            context,
            figure_settings.left_label,
            20,
            (top + bottom) / 2,
          )
        end
        if axis_used?("right")
          draw_rotated(
            context,
            figure_settings.right_label,
            @width - 8,
            (top + bottom) / 2,
          )
        end
      end

      def draw_title(context)
        left, _top, right, _bottom = plot_area
        set_font(context)
        set_color(context, style_params.text_color, 1.0)
        context.set_font_size(style_params.font_size * 1.2)
        draw_centered(
          context,
          figure_settings.title,
          (left + right) / 2,
          24,
        )
      end

      def draw_centered(context, text, x, y)
        unless text.to_s.empty?
          extents = context.text_extents(text)
          show_text_at(
            context,
            text,
            x - (extents.width / 2),
            y,
          )
        end
      end

      def draw_rotated(context, text, x, y)
        unless text.to_s.empty?
          extents = context.text_extents(text)
          context.save
          context.translate(x, y + (extents.width / 2))
          context.rotate(-Math::PI / 2)
          context.move_to(0, 0)
          context.show_text(text)
          context.restore
        end
      end

      # Section items

      def draw_items(context)
        left, top, right, bottom = plot_area
        context.save
        context.rectangle(
          left,
          top,
          right - left,
          bottom - top,
        )
        context.clip
        @data.each do |item|
          if item.visible
            draw_item(context, item)
          end
        end
        context.restore
      end

      def draw_item(context, item)
        if item.is_a?(FillItem)
          draw_fill_item(context, item)
        elsif item.is_a?(DataItem)
          draw_data_item(context, item)
        elsif item.is_a?(EquationItem)
          draw_equation_item(context, item)
        elsif item.is_a?(TextItem)
          draw_text_item(context, item)
        end
      end

      def draw_data_item(context, item)
        points = item_points(item)
        unless points.empty?
          draw_errorbars(context, item, points)
          draw_line(
            context,
            points,
            item.color,
            item.alpha,
            item.linestyle,
            item.linewidth,
          )
          draw_markers(context, points, item)
        end
      end

      # Points past the downsample threshold are thinned out, which is what
      # the window's toast tells the user about.
      def item_points(item)
        xdata = item.xdata
        ydata = item.ydata
        count = [xdata.length, ydata.length].min
        step = 1
        if item.downsample && count >= DOWNSAMPLE_THRESHOLD
          step = (count / DOWNSAMPLE_THRESHOLD.to_f).ceil
        end
        (0...count).step(step).filter_map do |index|
          data_point(xdata[index], ydata[index], item)
        end
      end

      def data_point(x, y, item)
        if x.finite? && y.finite?
          pixel_x = x_pixel(x, item.xposition)
          pixel_y = y_pixel(y, item.yposition)
          if pixel_x.finite? && pixel_y.finite?
            [pixel_x, pixel_y]
          end
        end
      end

      def draw_equation_item(context, item)
        left, _top, right, _bottom = plot_area
        direction = item.xposition
        count = [(right - left).to_i, 2].max
        xdata = Array.new(count) { |step| x_value(left + step, direction) }
        ydata = item.get_program.eval(xdata)
        points = xdata.each_index.filter_map do |index|
          data_point(xdata[index], ydata[index], item)
        end
        draw_line(
          context,
          points,
          item.color,
          item.alpha,
          line_style_index(item),
          item.linewidth,
        )
      end

      # The area between a fill's two bounds. A fill that follows no dataset
      # has no x values of its own, so it is sampled across the visible range,
      # as upstream's artist does on every view change.
      def draw_fill_item(context, item)
        fill_values(item).then do |values|
          fill_polygon(item, values).then do |points|
            unless points.length < 3
              set_color(context, item.color, item.alpha)
              context.move_to(*points.first)
              points.drop(1).each { |point| context.line_to(*point) }
              context.close_path
              context.fill
            end
          end
        end
      end

      def fill_values(item)
        if item.view_based?
          sampled_fill(item)
        else
          [item.data.xdata, item.data.lower, item.data.upper]
        end
      end

      def sampled_fill(item)
        left, _top, right, _bottom = plot_area
        count = [(right - left).to_i, 2].max
        Array.new(count) { |step| x_value(left + step, item.xposition) }.then do |xdata|
          item.evaluate_bounds(xdata).then do |lower, upper|
            [xdata, lower, upper]
          end
        end
      end

      # The outline of the filled area: along the lower bound and back along
      # the upper one. A point whose bounds are undefined is left out.
      def fill_polygon(item, values)
        xdata, lower, upper = values
        clamped_lower = clamp_fill(lower, item.yposition)
        clamped_upper = clamp_fill(upper, item.yposition)
        kept = xdata.each_index.select do |index|
          usable_fill_point?(xdata[index], clamped_lower[index], clamped_upper[index])
        end
        kept.filter_map { |index| data_point(xdata[index], clamped_lower[index], item) } +
          kept.reverse.filter_map { |index| data_point(xdata[index], clamped_upper[index], item) }
      end

      def usable_fill_point?(x, lower, upper)
        !x.nil? && !lower.nil? && !upper.nil? &&
          x.finite? && !lower.nan? && !upper.nan?
      end

      # An infinite bound is resolved to one figure height beyond the visible
      # area, which is what upstream's clamp does.
      def clamp_fill(values, direction)
        limits_for(direction).then do |minimum, maximum|
          (maximum - minimum).then do |span|
            values.map { |value| clamped_bound(value, minimum - span, maximum + span) }
          end
        end
      end

      def clamped_bound(value, low, high)
        if value.nan? || value.finite?
          value
        elsif value.positive?
          high
        else
          low
        end
      end

      def draw_text_item(context, item)
        set_font(context)
        context.set_font_size(item.size)
        set_color(context, item.color, item.alpha)
        context.save
        context.translate(
          x_pixel(item.xanchor, item.xposition),
          y_pixel(item.yanchor, item.yposition),
        )
        context.rotate(-item.rotation * Math::PI / 180)
        context.move_to(0, 0)
        context.show_text(item.text)
        context.restore
      end

      # Section strokes

      def draw_line(context, points, color, alpha, linestyle, linewidth)
        style = Item::LINESTYLES[linestyle]
        unless points.length < 2 || style == "none" || style.nil?
          set_color(context, color, alpha)
          context.set_line_width(linewidth)
          context.set_dash(dash_pattern(style, linewidth), 0)
          context.move_to(*points.first)
          points.drop(1).each { |point| context.line_to(*point) }
          context.stroke
          context.set_dash([], 0)
        end
      end

      # The dash patterns of upstream's bundled styles, scaled with the line.
      def dash_pattern(style, linewidth)
        scale = [linewidth, 1.0].max
        case style
        when "dotted" then [scale, 3 * scale]
        when "dashed" then [6 * scale, 6 * scale]
        when "dashdot" then [3 * scale, 5 * scale, scale, 5 * scale]
        else []
        end
      end

      def draw_markers(context, points, item)
        style = Item::MARKERSTYLES[item.markerstyle]
        unless style.nil? || style == "none"
          set_color(context, item.color, item.alpha)
          radius = item.markersize / 2
          points.each { |point| draw_marker(
            context,
            style,
            point,
            radius,
          ) }
        end
      end

      # The marker shapes are drawn as the closest Cairo primitive: a round,
      # square, triangular or cross-shaped mark.
      def draw_marker(context, style, point, radius)
        x, y = point
        case style
        when ",", ".", "o", "8", "p", "h", "H", "*"
          context.arc(
            x,
            y,
            radius,
            0,
            2 * Math::PI,
          )
          context.fill
        when "s", "D", "d", "P", "X"
          context.rectangle(
            x - radius,
            y - radius,
            radius * 2,
            radius * 2,
          )
          context.fill
        when "v", "^", "<", ">"
          draw_triangle(
            context,
            style,
            x,
            y,
            radius,
          )
        else draw_cross(
          context,
          style,
          x,
          y,
          radius,
        )
        end
      end

      def draw_triangle(context, style, x, y, radius)
        case style
        when "v" then triangle_path(
          context,
          [x - radius, y - radius],
          [x + radius, y - radius],
          [x, y + radius],
        )
        when "^" then triangle_path(
          context,
          [x - radius, y + radius],
          [x + radius, y + radius],
          [x, y - radius],
        )
        when "<" then triangle_path(
          context,
          [x + radius, y - radius],
          [x + radius, y + radius],
          [x - radius, y],
        )
        else triangle_path(
          context,
          [x - radius, y - radius],
          [x - radius, y + radius],
          [x + radius, y],
        )
        end
      end

      def triangle_path(context, first, second, third)
        context.move_to(*first)
        context.line_to(*second)
        context.line_to(*third)
        context.close_path
        context.fill
      end

      def draw_cross(context, style, x, y, radius)
        context.set_line_width(1.5)
        case style
        when "|" then tick_segment(
          context,
          x,
          y - radius,
          x,
          y + radius,
        )
        when "_" then tick_segment(
          context,
          x - radius,
          y,
          x + radius,
          y,
        )
        when "x"
          tick_segment(
            context,
            x - radius,
            y - radius,
            x + radius,
            y + radius,
          )
          tick_segment(
            context,
            x - radius,
            y + radius,
            x + radius,
            y - radius,
          )
        else
          tick_segment(
            context,
            x - radius,
            y,
            x + radius,
            y,
          )
          tick_segment(
            context,
            x,
            y - radius,
            x,
            y + radius,
          )
        end
      end

      def draw_errorbars(context, item, _points)
        if item.has_xerr? || item.has_yerr?
          set_color(context, item.errcolor, item.alpha)
          context.set_line_width(item.errlinewidth)
          item.xdata.each_index do |index|
            draw_errorbar(context, item, index)
          end
        end
      end

      def draw_errorbar(context, item, index)
        x = item.xdata[index]
        y = item.ydata[index]
        unless x.nil? || y.nil?
          center = data_point(x, y, item)
          unless center.nil?
            if item.showxerr && item.has_xerr?
              horizontal_errorbar(
                context,
                item,
                index,
                y,
              )
            end
            if item.showyerr && item.has_yerr?
              vertical_errorbar(
                context,
                item,
                index,
                x,
              )
            end
          end
        end
      end

      def horizontal_errorbar(context, item, index, y)
        error = item.xerr[index].to_f
        pixel_y = y_pixel(y, item.yposition)
        low = x_pixel(item.xdata[index] - error, item.xposition)
        high = x_pixel(item.xdata[index] + error, item.xposition)
        tick_segment(
          context,
          low,
          pixel_y,
          high,
          pixel_y,
        )
        item.errcapsize.then do |cap|
          if cap.positive?
            tick_segment(
              context,
              low,
              pixel_y - cap,
              low,
              pixel_y + cap,
            )
            tick_segment(
              context,
              high,
              pixel_y - cap,
              high,
              pixel_y + cap,
            )
          end
        end
      end

      def vertical_errorbar(context, item, index, x)
        error = item.yerr[index].to_f
        pixel_x = x_pixel(x, item.xposition)
        low = y_pixel(item.ydata[index] - error, item.yposition)
        high = y_pixel(item.ydata[index] + error, item.yposition)
        tick_segment(
          context,
          pixel_x,
          low,
          pixel_x,
          high,
        )
        item.errcapsize.then do |cap|
          if cap.positive?
            tick_segment(
              context,
              pixel_x - cap,
              low,
              pixel_x + cap,
              low,
            )
            tick_segment(
              context,
              pixel_x - cap,
              high,
              pixel_x + cap,
              high,
            )
          end
        end
      end

      # Section legend

      def draw_legend(context)
        entries = legend_entries
        if figure_settings.legend && !entries.empty?
          set_font(context)
          layout_legend(context, entries).then do |x, y, width, height|
            draw_legend_frame(
              context,
              x,
              y,
              width,
              height,
            )
            entries.each_with_index do |item, index|
              draw_legend_entry(
                context,
                item,
                x,
                y + (index * legend_line_height(context)),
              )
            end
          end
        end
      end

      def legend_entries
        @data.select { |item| item.visible && item.legendable? && item.legend }
      end

      def legend_line_height(context) = context.font_extents.height + 4

      def layout_legend(context, entries)
        left, top, right, bottom = plot_area
        width = entries.map { |item| context.text_extents(item.name).width }.max + 48
        height = (entries.length * legend_line_height(context)) + LEGEND_PADDING
        position = figure_settings.legend_position
        if %i[upper-left lower-left center-left].include?(position)
          x = left + LEGEND_PADDING
        elsif %i[upper-center lower-center center].include?(position)
          x = ((left + right) / 2) - (width / 2)
        else
          x = right - width - LEGEND_PADDING
        end
        if %i[lower-left lower-right lower-center].include?(position)
          y = bottom - height - LEGEND_PADDING
        elsif %i[center-left center-right center].include?(position)
          y = ((top + bottom) / 2) - (height / 2)
        else
          y = top + LEGEND_PADDING
        end
        [x, y, width, height]
      end

      def draw_legend_frame(context, x, y, width, height)
        if style_params.legend_frame?
          set_color(context, style_params.background_color, 0.8)
          context.rectangle(
            x,
            y,
            width,
            height,
          )
          context.fill
          set_color(context, style_params.tick_color, 1.0)
          context.set_line_width(1.0)
          context.rectangle(
            x,
            y,
            width,
            height,
          )
          context.stroke
        end
      end

      def draw_legend_entry(context, item, x, y)
        baseline = y + legend_line_height(context) - 4
        draw_legend_sample(context, item, [x, baseline])
        set_color(context, style_params.text_color, 1.0)
        show_text_at(
          context,
          item.name,
          x + 40,
          baseline,
        )
      end

      # A fill has no line, so it is shown as a patch of its own colour.
      def draw_legend_sample(context, item, position)
        x, baseline = position
        if item.is_a?(FillItem)
          set_color(context, item.color, item.alpha)
          context.rectangle(
            x + 6,
            baseline - 12,
            28,
            12,
          )
          context.fill
        else
          draw_line(
            context,
            [[x + 6, baseline - 4], [x + 34, baseline - 4]],
            item.color,
            item.alpha,
            line_style_index(item),
            legend_linewidth(item),
          )
        end
      end

      # An equation item has no "none" line style, so its index counts from
      # the second entry of the list.
      def line_style_index(item)
        if item.is_a?(EquationItem)
          item.linestyle + 1
        else
          item.linestyle
        end
      end

      def legend_linewidth(item) = [item.linewidth, 1.0].max

      # Section selection highlight

      # The range the select mode has marked, as the operations act on.
      def draw_selection(context)
        minimum = figure_settings.min_selected
        maximum = figure_settings.max_selected
        unless minimum == maximum
          left, top, right, bottom = plot_area
          start = left + (minimum * (right - left))
          stop = left + (maximum * (right - left))
          set_color(context, style_params.text_color, 0.15)
          context.rectangle(
            start,
            top,
            stop - start,
            bottom - top,
          )
          context.fill
        end
      end

      # The rubber band of an in-progress zoom or select drag.
      def draw_band(context)
        unless @drag.nil? || @mode == :pan
          left, top, right, bottom = plot_area
          start_x, start_y = @drag[:start]
          current_x, current_y = @drag[:current]
          if @mode == :select
            start_y = top
            current_y = bottom
          end
          set_color(context, style_params.text_color, 0.2)
          context.rectangle(
            [start_x, current_x].min.clamp(left, right),
            [start_y, current_y].min.clamp(top, bottom),
            (current_x - start_x).abs,
            (current_y - start_y).abs,
          )
          context.fill
        end
      end

      # Section interaction

      def on_drag_begin(x, y)
        @drag = {
          start:   [x, y],
          current: [x, y],
          limits:  figure_settings.limits,
        }
        drawing_area.grab_focus
        drawing_area.queue_draw
      end

      def on_drag_update(offset_x, offset_y)
        unless @drag.nil?
          @drag[:current] = [@drag[:start][0] + offset_x, @drag[:start][1] + offset_y]
          if @mode == :pan
            pan_by(offset_x, offset_y)
          end
          drawing_area.queue_draw
        end
      end

      def on_drag_end(offset_x, offset_y)
        unless @drag.nil?
          @drag[:current] = [@drag[:start][0] + offset_x, @drag[:start][1] + offset_y]
          case @mode
          when :zoom then finish_zoom
          when :select then finish_select
          end
          @drag = nil
          emit_signal(:view_changed)
          drawing_area.queue_draw
        end
      end

      # Panning moves every used axis by the dragged fraction of its length.
      def pan_by(offset_x, offset_y)
        left, top, right, bottom = plot_area
        x_fraction = -offset_x / (right - left)
        y_fraction = offset_y / (bottom - top)
        @drag[:limits].then do |limits|
          figure_settings.set_limits(limits)
        end
        %w[bottom top].each { |direction| shift_axis(direction, x_fraction) }
        %w[left right].each { |direction| shift_axis(direction, y_fraction) }
      end

      def shift_axis(direction, fraction)
        minimum, maximum = limits_for(direction)
        scale = scale_for(direction)
        new_min = Graphs.get_value_at_fraction(
          fraction,
          minimum,
          maximum,
          scale,
        )
        new_max = Graphs.get_value_at_fraction(
          1 + fraction,
          minimum,
          maximum,
          scale,
        )
        if new_min.finite? && new_max.finite? && new_min < new_max
          figure_settings["min-#{direction}"] = new_min
          figure_settings["max-#{direction}"] = new_max
        end
      end

      def finish_zoom
        left, top, right, bottom = plot_area
        start_x, start_y = @drag[:start]
        current_x, current_y = @drag[:current]
        if (current_x - start_x).abs > 5 && (current_y - start_y).abs > 5
          zoom_axes(
            [[start_x, current_x].min, [start_x, current_x].max],
            [[start_y, current_y].min, [start_y, current_y].max],
            [left, right, top, bottom],
          )
        end
      end

      def zoom_axes(x_range, y_range, bounds)
        left, right, top, bottom = bounds
        %w[bottom top].each do |direction|
          set_axis_range(
            direction,
            x_value(x_range[0].clamp(left, right), direction),
            x_value(x_range[1].clamp(left, right), direction),
          )
        end
        %w[left right].each do |direction|
          set_axis_range(
            direction,
            y_value(y_range[1].clamp(top, bottom), direction),
            y_value(y_range[0].clamp(top, bottom), direction),
          )
        end
      end

      def set_axis_range(direction, minimum, maximum)
        if minimum.finite? && maximum.finite? && minimum < maximum
          figure_settings["min-#{direction}"] = minimum
          figure_settings["max-#{direction}"] = maximum
        end
      end

      # A select drag marks a fraction of the bottom axis.
      def finish_select
        left, _top, right, _bottom = plot_area
        start_x = @drag[:start][0].clamp(left, right)
        current_x = @drag[:current][0].clamp(left, right)
        width = right - left
        figure_settings.set_selection_range(
          ([start_x, current_x].min - left) / width,
          ([start_x, current_x].max - left) / width,
        )
      end

      # Scrolling zooms both axes around the pointer.
      def on_scroll(direction)
        if direction.negative?
          zoom_at(@pointer, 1 / SCROLL_FACTOR)
        else
          zoom_at(@pointer, SCROLL_FACTOR)
        end
        emit_signal(:view_changed)
        drawing_area.queue_draw
        true
      end

      def zoom_at(pointer, factor)
        left, top, right, bottom = plot_area
        x, y = pointer || [(left + right) / 2, (top + bottom) / 2]
        x_anchor = ((x - left) / (right - left)).clamp(0.0, 1.0)
        y_anchor = ((bottom - y) / (bottom - top)).clamp(0.0, 1.0)
        %w[bottom top].each { |direction| zoom_axis(direction, factor, x_anchor) }
        %w[left right].each { |direction| zoom_axis(direction, factor, y_anchor) }
      end

      def zoom_axis(direction, factor, anchor)
        minimum, maximum = limits_for(direction)
        scale = scale_for(direction)
        new_min = Graphs.get_value_at_fraction(
          anchor - (anchor * factor),
          minimum,
          maximum,
          scale,
        )
        new_max = Graphs.get_value_at_fraction(
          anchor + ((1 - anchor) * factor),
          minimum,
          maximum,
          scale,
        )
        set_axis_range(direction, new_min, new_max)
      end

      def on_motion(x, y)
        @pointer = [x, y]
      end

      # A click on an axis label or the title opens the figure settings at it.
      def on_click(n_press, x, y)
        if n_press >= 2
          label_at(x, y).then do |label|
            unless label.nil?
              emit_signal(:edit_request, label)
            end
          end
        end
        drawing_area.grab_focus
      end

      def label_at(x, y)
        left, top, right, bottom = plot_area
        if y < top && y > 12
          "title"
        elsif y > bottom
          "bottom-label"
        elsif x < left
          "left-label"
        elsif x > right
          "right-label"
        end
      end
  end
end
