# frozen_string_literal: true

require "adwaita"
require_relative "math_parser"

module Graphs
  # Ported from upstream's graphs/sidebar/operations.vala and
  # data/ui/sidebar/operations.blp: the bottom half of the sidebar, with the
  # operations grouped into Adjust, Transform and Modify pages.
  #
  # Every button activates the window's `perform-operation` action with its own
  # name, which is how upstream derives the operation from the button id. The
  # four Modify entries are evaluated as they are typed: an entry that is not a
  # number marks itself and blocks its button.
  class OperationsPanel
    # The buttons of the Adjust page: name, icon, label, tooltip and the cell
    # of the grid they sit in as column, row and column span.
    ADJUST_BUTTONS = [
      ["combine", "edit-paste-symbolic", "Combine", "Combine all selected data", [0, 0, 1]],
      ["cut", "edit-cut-symbolic", "Cut", "Cut selected data", [1, 0, 1]],
      [
        "shift",
        "shift-symbolic",
        "Shift",
        "Shift all data vertically with respect to each other",
        [0, 1, 1],
      ],
      ["normalize", "normalize-symbolic", "Normalize", "Normalize data", [1, 1, 1]],
    ].freeze

    TRANSFORM_BUTTONS = [
      [
        "derivative",
        "derivative2-symbolic",
        "Derivative",
        "Get the derivative of the data",
        [0, 0, 1],
      ],
      [
        "integral",
        "integral-symbolic",
        "Integral",
        "Get the indefinite integral of the data",
        [1, 0, 1],
      ],
      [
        "fft",
        "fast-fourier-transform-symbolic",
        "FFT",
        "Get the Fast Fourier Transform of the data",
        [0, 1, 2],
      ],
      [
        "inverse_fft",
        "inverse-fast-fourier-transform-symbolic",
        "Inverse FFT",
        "Get the Inverse Fast Fourier Transform of the data",
        [0, 2, 2],
      ],
      [
        "custom_transformation",
        "transform-symbolic",
        "Custom Transformation",
        "Perform custom transformations on the data",
        [0, 3, 2],
      ],
    ].freeze

    # The Modify page's entries: name, icon, label and row.
    MODIFY_ROWS = [
      ["translate_x", "horizontal-arrows-symbolic", "Translate X", 0],
      ["translate_y", "vertical-arrows-symbolic", "Translate Y", 1],
      ["multiply_x", "horizontal-arrows-symbolic", "Multiply X", 2],
      ["multiply_y", "vertical-arrows-symbolic", "Multiply Y", 3],
    ].freeze

    # The icon and label of every button, by operation name.
    LABELS = (
      ADJUST_BUTTONS.map { |name, icon, label, _tooltip, _cell| [name, [icon, label]] } +
      TRANSFORM_BUTTONS.map { |name, icon, label, _tooltip, _cell| [name, [icon, label]] } +
      MODIFY_ROWS.map { |name, icon, label, _row| [name, [icon, label]] }
    ).to_h.freeze

    # The tooltip of every button that has one.
    TOOLTIPS = (
      ADJUST_BUTTONS.map { |name, _icon, _label, tooltip, _cell| [name, tooltip] } +
      TRANSFORM_BUTTONS.map { |name, _icon, _label, tooltip, _cell| [name, tooltip] }
    ).to_h.freeze

    def initialize(window:)
      @window = window
      @entries_sensitive = false
      @cut_sensitive = false
    end

    def build
      container.tap do |box|
        box.append(view_switcher)
        box.append(stack)

        stack.tap do |pages|
          pages.add_titled(adjust_group, "adjust", "Adjust")
          pages.add_titled(transform_group, "transform", "Transform")
          pages.add_titled(modify_group, "modify", "Modify")

          adjust_group.tap do |group|
            group.add(adjust_grid)

            adjust_grid.tap do |grid|
              ADJUST_BUTTONS.each { |definition| attach_button(grid, definition) }
              attach(
                grid,
                smoothen_button,
                [0, 2, 2],
              )
              attach(
                grid,
                center_button,
                [0, 3, 2],
              )
            end
          end

          transform_group.tap do |group|
            group.add(transform_grid)

            transform_grid.tap do |grid|
              TRANSFORM_BUTTONS.each { |definition| attach_button(grid, definition) }
            end
          end

          modify_group.tap do |group|
            group.add(modify_grid)

            modify_grid.tap do |grid|
              MODIFY_ROWS.each { |definition| attach_modify_row(grid, definition) }
            end
          end
        end

        on_mode_change
        MODIFY_ROWS.each { |name, _icon, _label, _row| validate_entry(name) }
      end
    end

    def widget = container

    # The two buttons the window switches on its own, as upstream's window
    # does through the panel's properties.
    def shift_button = button("shift")
    def smoothen_button = @smoothen_button ||= split_button("smoothen", "Smoothen", smoothen_menu)

    def center_button
      @center_button ||= split_button("center", "Center", center_menu)
    end

    # Upstream binds combine's and normalize's sensitivity to shift's, so all
    # three follow the same selection.
    def set_entry_sensitivity(sensitive)
      @entries_sensitive = sensitive
      MODIFY_ROWS.each { |name, _icon, _label, _row| validate_entry(name) }
    end

    def set_cut_sensitivity(sensitive)
      @cut_sensitive = sensitive
      on_mode_change
    end

    def set_items_sensitivity(items_selected)
      shift_button.sensitive = items_selected
      button("combine").sensitive = items_selected
      button("normalize").sensitive = items_selected
      TRANSFORM_BUTTONS.each do |name, _icon, _label, _tooltip, _cell|
        button(name).sensitive = items_selected
      end
    end

    def set_data_items_sensitivity(data_items_selected)
      smoothen_button.sensitive = data_items_selected
    end

    # A cut only means anything over a selection.
    def on_mode_change
      button("cut").sensitive = @cut_sensitive && @window.mode == :select
    end

    # The text of one of the Modify entries, which is the value the operation
    # is performed with.
    def entry_text(name) = entry(name).text

    def container
      @container ||= Gtk::Box.new(:vertical, 18).tap do |box|
        box.hexpand = false
        box.margin_start = 12
        box.margin_end = 12
        box.margin_top = 12
        box.margin_bottom = 12
      end
    end

    def view_switcher
      @view_switcher ||= Adwaita::InlineViewSwitcher.new.tap do |switcher|
        switcher.stack = stack
        switcher.homogeneous = true
      end
    end

    def stack = @stack ||= Adwaita::ViewStack.new

    def adjust_group = @adjust_group ||= Adwaita::PreferencesGroup.new
    def transform_group = @transform_group ||= Adwaita::PreferencesGroup.new
    def modify_group = @modify_group ||= Adwaita::PreferencesGroup.new

    def adjust_grid = @adjust_grid ||= operation_grid(10)
    def transform_grid = @transform_grid ||= operation_grid(12)

    def modify_grid
      @modify_grid ||= Gtk::Grid.new.tap do |grid|
        grid.column_spacing = 10
        grid.row_spacing = 10
      end
    end

    def button(name)
      buttons[name] ||= Gtk::Button.new.tap do |widget|
        widget.child = button_content(name)
        widget.signal_connect("clicked") { perform(name) }
      end
    end

    def entry(name)
      entries[name] ||= Gtk::Entry.new.tap do |widget|
        widget.max_width_chars = 6
        widget.hexpand = true
        widget.text = "10"
        widget.signal_connect("notify::text") { validate_entry(name) }
      end
    end

    def smoothen_menu
      @smoothen_menu ||= Gio::Menu.new.tap do |menu|
        Gio::Menu.new.tap do |section|
          section.append("Savitzky–Golay Filter", "win.smoothen::savgol")
          section.append("Moving Average", "win.smoothen::moving-average")
          menu.append_section(nil, section)
        end
        Gio::Menu.new.tap do |section|
          section.append("Advanced Settings", "win.smoothen-settings")
          menu.append_section(nil, section)
        end
      end
    end

    def center_menu
      @center_menu ||= Gio::Menu.new.tap do |menu|
        menu.append("At Maximum Y Value", "win.center::max-y")
        menu.append("At Middle X Value", "win.center::middle-x")
      end
    end

    private

      def buttons = @buttons ||= {}
      def entries = @entries ||= {}

      def operation_grid(spacing)
        Gtk::Grid.new.tap do |grid|
          grid.column_homogeneous = true
          grid.column_spacing = spacing
          grid.row_spacing = spacing
        end
      end

      def button_content(name)
        Adwaita::ButtonContent.new.tap do |content|
          LABELS.fetch(name).then do |icon, label|
            content.icon_name = icon
            content.label = label
          end
          content.halign = :center
          content.can_shrink = true
        end
      end

      def split_button(name, label, menu)
        Adwaita::SplitButton.new.tap do |widget|
          widget.can_shrink = true
          widget.tooltip_text = "#{label} data"
          widget.menu_model = menu
          widget.child = Adwaita::ButtonContent.new.tap do |content|
            content.icon_name = "#{name}-symbolic"
            content.label = label
            content.halign = :center
            content.can_shrink = true
          end
          widget.signal_connect("clicked") { perform(name) }
        end
      end

      def attach_button(grid, definition)
        name, _icon, _label, tooltip, cell = definition
        button(name).tooltip_text = tooltip
        attach(grid, button(name), cell)
      end

      def attach_modify_row(grid, definition)
        name, _icon, _label, row = definition
        attach(grid, entry(name), [0, row, 1])
        button(name).tap do |widget|
          widget.valign = :center
          widget.set_size_request(120, -1)
          attach(grid, widget, [1, row, 1])
        end
      end

      def attach(grid, widget, cell)
        column, row, span = cell
        grid.attach(
          widget,
          column,
          row,
          span,
          1,
        )
      end

      # An entry holding something other than a number marks itself and takes
      # its button with it.
      def validate_entry(name)
        if Graphs.try_evaluate_string(entry(name).text)
          entry(name).remove_css_class("error")
          button(name).sensitive = @entries_sensitive
        else
          entry(name).add_css_class("error")
          button(name).sensitive = false
        end
      end

      def perform(name)
        @window.window.lookup_action("perform-operation").then do |action|
          unless action.nil?
            action.activate(name)
          end
        end
      end
  end
end
