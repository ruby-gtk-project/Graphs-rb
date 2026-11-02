# frozen_string_literal: true

require "adwaita"

module Graphs
  # Ported from upstream's graphs/transform.vala and data/ui/transform.blp:
  # asks for an expression for x and one for y, and hands them to whoever
  # opened the dialog.
  #
  # The discard switch only means anything over a selection, so it is shown
  # only in select mode, as upstream does.
  class TransformDialog
    VARIABLES = <<~MARKUP.chomp
      <b>Available variables</b>
      General:
       counts - number of data points

      X-Axis:
       x_min, x_max - minimum and maximum values,
       x_mean, x_median - average and median,
       x_std, x_sum — standard deviation and sum

      Y-Axis:
       y_min, y_max - minimum and maximum,
       y_mean, y_median — average and median,
       y_std, y_sum - standard deviation and sum

      Trigonometric functions use radians by default.
      Append d to use degrees, e.g. sind(x) or cosd(x).
    MARKUP

    def initialize(window:)
      @window = window
      @on_accept = nil
    end

    # Registers the block the dialog calls with the two expressions and the
    # discard flag.
    def on_accept(&block)
      @on_accept = block
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
          bar.pack_end(info_button)

          cancel_button.signal_connect("clicked") { dialog.close }
          confirm_button.signal_connect("clicked") { accept }

          info_button.popover = info_popover

          info_popover.child = info_label
        end

        clamp.tap do |widget_clamp|
          widget_clamp.child = group

          group.tap do |preferences|
            preferences.add(transform_x_row)
            preferences.add(transform_y_row)
            preferences.add(discard_row)

            transform_x_row.text = "X"
            transform_y_row.text = "Y"
            discard_row.visible = @window.mode == :select
          end
        end
      end
    end

    def present
      build
      dialog.present(@window.window)
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |widget|
        widget.title = "Transform Data"
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
      @confirm_button ||= Gtk::Button.new(label: "Transform").tap do |button|
        button.add_css_class("suggested-action")
      end
    end

    def info_button
      @info_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "info-symbolic"
        button.tooltip_text = "More info"
        button.halign = :end
      end
    end

    def info_popover
      @info_popover ||= Gtk::Popover.new.tap do |popover|
        popover.position = :bottom
      end
    end

    def info_label
      @info_label ||= Gtk::Label.new(VARIABLES).tap do |label|
        label.use_markup = true
        label.margin_top = 12
        label.margin_bottom = 12
        label.margin_start = 12
        label.margin_end = 12
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |widget|
        widget.margin_start = 12
        widget.margin_end = 12
        widget.margin_top = 12
        widget.margin_bottom = 12
      end
    end

    def group = @group ||= Adwaita::PreferencesGroup.new

    def transform_x_row
      @transform_x_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "X ="
        row.activates_default = true
      end
    end

    def transform_y_row
      @transform_y_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "Y ="
        row.activates_default = true
      end
    end

    def discard_row
      @discard_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = "Discard Unselected Data"
      end
    end

    private

      def accept
        @on_accept&.call(
          transform_x_row.text,
          transform_y_row.text,
          discard_row.active?,
        )
        dialog.close
      end
  end
end
