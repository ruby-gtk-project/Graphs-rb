# frozen_string_literal: true

require "adwaita"
require_relative "settings"

module Graphs
  # Ported from upstream's graphs/smoothen_settings.vala and
  # data/ui/smoothen-settings.blp: the window size of the Savitzky–Golay
  # filter, its polynomial degree, and the box width of the moving average.
  #
  # Upstream binds each row to its GSettings key; here the rows write to the
  # settings file as they change, and the reset button puts the defaults back.
  class SmoothenDialog
    ROWS = {
      "savgol-window"      => [
        "Span percentage",
        "What percentage of the data span to use for the filter window",
        99,
      ],
      "savgol-polynomial"  => ["Polynomial degree", "", 20],
      "moving-average-box" => [
        "Box points",
        "Amount of points to use when calculating a moving average",
        9999,
      ],
    }.freeze

    def initialize(window:, settings: Settings.default)
      @window = window
      @settings = settings.child("smoothen")
    end

    def build
      dialog.tap do |widget|
        widget.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scrolled_window
        end

        header_bar.tap do |bar|
          bar.pack_start(reset_button)

          reset_button.signal_connect("clicked") { on_reset }
        end

        scrolled_window.child = clamp

        clamp.tap do |widget_clamp|
          widget_clamp.child = content_box

          content_box.tap do |box|
            box.append(savgol_group)
            box.append(moving_average_group)

            savgol_group.tap do |group|
              group.add(row("savgol-window"))
              group.add(row("savgol-polynomial"))
            end

            moving_average_group.add(row("moving-average-box"))
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
        widget.title = "Smoothen Settings"
        widget.content_width = 640
        widget.content_height = 576
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def reset_button
      @reset_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "history-undo-symbolic"
        button.tooltip_text = "Reset to Defaults"
      end
    end

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scroll|
        scroll.propagate_natural_height = true
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

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 10)

    def savgol_group
      @savgol_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Savitzky–Golay Filter"
      end
    end

    def moving_average_group
      @moving_average_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Moving Average"
      end
    end

    def row(key)
      rows[key] ||= Adwaita::SpinRow.new(adjustment(key), 1, 0).tap do |spin|
        ROWS.fetch(key).then do |title, subtitle, _upper|
          spin.title = title
          spin.subtitle = subtitle
        end
        spin.signal_connect("notify::value") { @settings[key] = spin.value.to_i }
      end
    end

    def adjustment(key)
      Gtk::Adjustment.new(
        @settings[key].to_f,
        0.0,
        ROWS.fetch(key)[2].to_f,
        1.0,
        10.0,
        0.0,
      )
    end

    private

      def rows = @rows ||= {}

      def load_values
        ROWS.each_key { |key| row(key).value = @settings[key].to_f }
      end

      def on_reset
        @settings.reset_all
        load_values
      end
  end
end
