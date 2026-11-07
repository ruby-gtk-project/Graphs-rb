# frozen_string_literal: true

require "adwaita"
require_relative "styles"
require_relative "utilities"

module Graphs
  # Ported from data/ui/style-preview.blp: one tile of a style grid, showing
  # a small sketch of the style's look, its name, whether it is the one
  # currently selected, and — for a mutable style — a menu to open, open
  # with another app or delete it.
  #
  # Upstream renders the preview by rendering the style with matplotlib into
  # a thumbnail; this port draws the same shape (two coloured lines over the
  # style's background and outline) directly with Cairo.
  class StylePreview
    WIDTH = 155
    HEIGHT = 93

    def initialize(selected: false, on_open: nil, on_open_with: nil, on_delete: nil)
      @style = nil
      @selected = selected
      @on_open = on_open
      @on_open_with = on_open_with
      @on_delete = on_delete
    end

    def build
      bin.tap do |widget|
        widget.child = frame

        frame.tap do |aspect|
          aspect.child = box

          box.tap do |content|
            content.append(overlay)
            content.append(label)

            overlay.tap do |ov|
              ov.child = picture
              ov.add_overlay(indicator)
              ov.add_overlay(menu_button)

              menu_button.tap do |button|
                button.menu_model = style_menu
                button.insert_action_group("style", style_actions)
              end
            end
          end
        end
      end
    end

    def widget = bin

    attr_reader :style

    def style=(new_style)
      @style = new_style
      label.label = new_style.name
      indicator.visible = @selected
      menu_button.visible = new_style.mutable?
      picture.queue_draw
      new_style
    end

    def selected=(value)
      @selected = value
      indicator.visible = value
      value
    end

    def bin = @bin ||= Adwaita::Bin.new

    def frame
      @frame ||= Gtk::AspectFrame.new(0.5, 0.5, WIDTH.to_f / HEIGHT, false)
    end

    def box = @box ||= Gtk::Box.new(:vertical, 0)

    def overlay
      @overlay ||= Gtk::Overlay.new.tap do |ov|
        ov.set_size_request(WIDTH, HEIGHT)
      end
    end

    def picture
      @picture ||= Gtk::DrawingArea.new.tap do |area|
        area.set_draw_func { |_, context, width, height| draw(context, width, height) }
      end
    end

    def indicator
      @indicator ||= Gtk::Image.new.tap do |image|
        image.icon_name = "check-round-outline-whole-symbolic"
        image.halign = :end
        image.valign = :end
        image.margin_end = 6
        image.margin_bottom = 6
        image.visible = @selected
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "view-more-symbolic"
        button.halign = :end
        button.valign = :start
        button.margin_end = 4
        button.margin_top = 4
        button.visible = false
        button.add_css_class("flat")
      end
    end

    def label
      @label ||= Gtk::Label.new.tap do |widget|
        widget.margin_top = 8
        widget.ellipsize = :end
      end
    end

    private

      def style_menu
        @style_menu ||= Gio::Menu.new.tap do |menu|
          menu.append("Open", "style.open")
          menu.append("Open With…", "style.open_with")
          menu.append("Delete…", "style.delete")
        end
      end

      def style_actions
        @style_actions ||= Gio::SimpleActionGroup.new.tap do |group|
          group.add_action(simple_action("open") { @on_open&.call(@style) })
          group.add_action(simple_action("open_with") { @on_open_with&.call(@style) })
          group.add_action(simple_action("delete") { @on_delete&.call(@style) })
        end
      end

      def simple_action(name, &block)
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect("activate") { block.call }
        end
      end

      def draw(context, width, height)
        unless @style.nil?
          background = Tools.hex_to_rgba(background_color)
          outline = Tools.hex_to_rgba(outline_color)
          context.set_source_rgba(background.red, background.green, background.blue, 1.0)
          context.rectangle(0, 0, width, height)
          context.fill
          context.set_source_rgba(outline.red, outline.green, outline.blue, 1.0)
          context.set_line_width(2)
          context.rectangle(1, 1, width - 2, height - 2)
          context.stroke
          draw_lines(context, width, height)
        end
      end

      def draw_lines(context, width, height)
        colors.each_with_index do |color, index|
          rgba = Tools.hex_to_rgba(color)
          context.set_source_rgba(rgba.red, rgba.green, rgba.blue, 1.0)
          context.set_line_width(2)
          y_at = ->(fraction) { height - 10 - (fraction * (height - 20)) }
          context.move_to(10, y_at.call(index.zero? ? 0.2 : 0.8))
          context.curve_to(
            width * 0.4, y_at.call(index.zero? ? 0.8 : 0.2),
            width * 0.6, y_at.call(index.zero? ? 0.2 : 0.8),
            width - 10, y_at.call(index.zero? ? 0.9 : 0.1)
          )
          context.stroke
        end
      end

      def colors
        params.color_cycle.first(2)
      end

      def background_color = params.background_color
      def outline_color = params.outline_color

      def params
        @params_cache ||= {}
        @params_cache[@style.name] ||= StyleManager.instance.params_for(@style)
      end
  end
end
