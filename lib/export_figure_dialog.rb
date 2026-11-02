# frozen_string_literal: true

require "adwaita"
require "tmpdir"
require_relative "settings"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/export_figure.vala and
  # data/ui/export-figure.blp: writes the figure to a file at a size of the
  # user's choosing, optionally without a background.
  #
  # Upstream hands the work to matplotlib's `savefig`; here the canvas draws
  # itself into a Cairo surface of the requested kind. The formats are the ones
  # upstream offers minus WebP, which neither Cairo nor the GdkPixbuf loaders
  # shipped with the bindings can write.
  class ExportFigureDialog
    FORMATS = {
      "eps"  => "Encapsulated PostScript",
      "jpeg" => "JPEG",
      "pdf"  => "PDF",
      "png"  => "PNG",
      "ps"   => "PostScript",
      "svg"  => "SVG",
    }.freeze

    def initialize(window:, settings: Settings.default)
      @window = window
      @settings = settings.child("export-figure")
    end

    def build
      dialog.tap do |widget|
        widget.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = clamp
        end

        header_bar.tap do |bar|
          bar.pack_start(cancel_button)
          bar.pack_end(confirm_button)

          cancel_button.signal_connect("clicked") { dialog.close }
          confirm_button.signal_connect("clicked") { on_accept }
        end

        clamp.tap do |widget_clamp|
          widget_clamp.child = content_box

          content_box.tap do |box|
            box.append(settings_group)
            box.append(size_group)

            settings_group.tap do |group|
              group.add(format_row)
              group.add(transparent_row)
            end

            size_group.tap do |group|
              group.add(width_row)
              group.add(height_row)
              group.add(window_size_row)

              window_size_row.signal_connect("activated") { on_use_window_size }
            end
          end
        end

        load_values
      end
    end

    def present
      build
      dialog.present(@window.window)
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |widget|
        widget.title = "Export Figure"
        widget.content_width = 450
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
      end
    end

    def cancel_button = @cancel_button ||= Gtk::Button.new(label: "Cancel")

    def confirm_button
      @confirm_button ||= Gtk::Button.new(label: "Export").tap do |button|
        button.add_css_class("suggested-action")
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |widget|
        widget.maximum_size = 800
        widget.margin_start = 12
        widget.margin_end = 12
        widget.margin_top = 12
        widget.margin_bottom = 12
      end
    end

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 10)

    def settings_group
      @settings_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Export Settings"
      end
    end

    def size_group
      @size_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Export Size"
      end
    end

    def format_row
      @format_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = "File Format"
        row.model = Gtk::StringList.new(FORMATS.values)
      end
    end

    def transparent_row
      @transparent_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = "Transparent Background"
      end
    end

    def width_row
      @width_row ||= Adwaita::SpinRow.new(size_adjustment(7680.0), 1, 0).tap do |row|
        row.title = "Width (pixels)"
      end
    end

    def height_row
      @height_row ||= Adwaita::SpinRow.new(size_adjustment(4320.0), 1, 0).tap do |row|
        row.title = "Height (pixels)"
      end
    end

    def window_size_row
      @window_size_row ||= Adwaita::ButtonRow.new.tap do |row|
        row.title = "Use Same Size as App"
      end
    end

    def size_adjustment(upper)
      Gtk::Adjustment.new(
        800.0,
        100.0,
        upper,
        10.0,
        100.0,
        0.0,
      )
    end

    private

      def load_values
        format_row.selected = FORMATS.keys.index(@settings["file-format"]) || 0
        transparent_row.active = @settings["transparent"]
        width_row.value = @settings["width"].to_f
        height_row.value = @settings["height"].to_f
      end

      def on_use_window_size
        width_row.value = @window.canvas.widget.allocated_width.to_f
        height_row.value = @window.canvas.widget.allocated_height.to_f
      end

      def suffix = FORMATS.keys[format_row.selected]

      def on_accept
        Gtk::FileDialog.new.tap do |file_dialog|
          file_dialog.initial_name = "Exported Figure.#{suffix}"
          file_dialog.accept_label = "Export"
          file_dialog.filters = Tools.create_file_filters(
            false,
            Tools.create_file_filter(FORMATS.fetch(suffix), suffix),
          )
          file_dialog.save(@window.window) do |_source, result|
            file_dialog.save_finish(result).then { |file| export(file) }
          rescue GLib::Error
            nil
          end
        end
      end

      def export(file)
        store_settings
        write_figure(file.path)
        @window.add_toast_string_with_file("Exported Figure", file)
        dialog.close
      end

      def store_settings
        @settings["file-format"] = suffix
        @settings["transparent"] = transparent_row.active?
        @settings["width"] = width_row.value.to_i
        @settings["height"] = height_row.value.to_i
      end

      def write_figure(path)
        width = width_row.value.to_i
        height = height_row.value.to_i
        case suffix
        when "png" then write_png(path, width, height)
        when "jpeg" then write_jpeg(path, width, height)
        else write_vector(path, width, height)
        end
      end

      def write_png(path, width, height)
        image_surface(width, height).tap do |surface|
          surface.write_to_png(path)
          surface.finish
        end
      end

      # GdkPixbuf writes the JPEG, so the figure goes through a PNG the loader
      # can read.
      def write_jpeg(path, width, height)
        Dir.mktmpdir do |directory|
          File.join(directory, "figure.png").then do |intermediate|
            write_png(intermediate, width, height)
            GdkPixbuf::Pixbuf.new(file: intermediate).save(path, "jpeg")
          end
        end
      end

      def image_surface(width, height)
        Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, width, height).tap do |surface|
          draw_figure(surface, width, height)
        end
      end

      def write_vector(path, width, height)
        vector_surface(path, width, height).tap do |surface|
          draw_figure(surface, width, height)
          surface.finish
        end
      end

      def vector_surface(path, width, height)
        case suffix
        when "svg" then Cairo::SVGSurface.new(path, width, height)
        when "pdf" then Cairo::PDFSurface.new(path, width, height)
        else postscript_surface(path, width, height)
        end
      end

      def postscript_surface(path, width, height)
        Cairo::PSSurface.new(path, width, height).tap do |surface|
          surface.eps = suffix == "eps"
        end
      end

      def draw_figure(surface, width, height)
        Cairo::Context.new(surface).tap do |context|
          @window.canvas.draw_to(
            context,
            width,
            height,
            transparent_row.active?,
          )
        end
      end
  end
end
