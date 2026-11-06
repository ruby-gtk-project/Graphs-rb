# frozen_string_literal: true

require "adwaita"
require_relative "actions"
require_relative "canvas"
require_relative "data"
require_relative "item_box"
require_relative "main_sidebar_page"
require_relative "math_parser"
require_relative "sidebar/edit_item/page"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/window.vala and data/ui/window.blp.
  #
  # The sidebar holds the item list, the content side holds the canvas, and
  # the window keeps the two in step with the data: rebuilding the rows when
  # items change, following the window title's unsaved marker, and handing the
  # canvas' view changes to the view history.
  class Window
    def initialize(application:, data: nil)
      @application = application
      @data = data || Data.new
    end

    attr_reader :data

    def build
      window.tap do |widget|
        widget.title = "Graphs"
        widget.child = split_view

        split_view.tap do |view|
          view.sidebar = navigation_view
          view.content = content_view

          navigation_view.tap do |navigation|
            navigation.add(main_page.build)
            navigation.add(edit_item_page.build)
          end

          content_view.tap do |content|
            content.add_top_bar(header_bar)
            content.content = toast_overlay
            content.add_css_class("canvas-view")
          end

          header_bar.tap do |bar|
            bar.title_widget = content_title
            bar.pack_start(sidebar_button)
            bar.pack_start(undo_button)
            bar.pack_start(redo_button)
            bar.pack_end(optimize_limits_button)
            bar.pack_end(view_forward_button)
            bar.pack_end(view_back_button)
          end

          toast_overlay.tap do |overlay|
            overlay.child = canvas.build
          end
        end

        Actions.setup_local(self)
        connect_data
        connect_canvas
        self.mode = :pan
        on_items_changed
        on_unsaved_change
      end
    end

    def present = window.present

    # Section widgets

    def window
      @window ||= Gtk::ApplicationWindow.new(@application.app).tap do |widget|
        widget.set_default_size(1200, 700)
        widget.set_size_request(360, 200)
      end
    end

    def split_view
      @split_view ||= Adwaita::OverlaySplitView.new.tap do |view|
        view.min_sidebar_width = 340
        view.sidebar_width_fraction = 0.3
      end
    end

    def navigation_view = @navigation_view ||= Adwaita::NavigationView.new
    def content_view = @content_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def content_title = @content_title ||= Adwaita::WindowTitle.new("Graphs", "")
    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def main_page = @main_page ||= MainSidebarPage.new(window: self)
    def canvas = @canvas ||= Canvas.new(data: @data)
    def edit_item_page = @edit_item_page ||= EditItem::Page.new(window: self)

    def sidebar_button
      @sidebar_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = "sidebar-show-symbolic"
        button.tooltip_text = "Show Sidebar"
        button.active = true
        button.signal_connect("toggled") do
          split_view.show_sidebar = button.active?
        end
      end
    end

    def undo_button
      @undo_button ||= header_button("edit-undo-symbolic", "Undo", "win.undo")
    end

    def redo_button
      @redo_button ||= header_button("edit-redo-symbolic", "Redo", "win.redo")
    end

    def optimize_limits_button
      @optimize_limits_button ||= header_button(
        "view-reveal-symbolic",
        "Optimize View Limits",
        "win.optimize-limits",
      )
    end

    def view_forward_button
      @view_forward_button ||= header_button("go-next-symbolic", "Next View", "win.view-forward")
    end

    def view_back_button
      @view_back_button ||= header_button(
        "go-previous-symbolic",
        "Previous View",
        "win.view-back",
      )
    end

    # Section state

    def mode = main_page.mode

    def mode=(value)
      main_page.mode = value
      canvas.mode = value
      main_page.operations.on_mode_change
    end

    # The value one of the Modify entries holds, which is what upstream's
    # `get_operation_value` evaluates.
    def operation_value(name) = Graphs.evaluate_string(main_page.operations.entry_text(name))

    # Section toasts

    def add_toast(toast) = toast_overlay.add_toast(toast)

    def add_toast_string(title) = add_toast(Adwaita::Toast.new(title))

    # A toast that offers to open the folder the file was written to, as
    # upstream's `add_toast_string_with_file` does.
    def add_toast_string_with_file(title, file)
      Actions.add_action(window, "open-file-location") { Tools.open_file_location(file) }
      add_toast(
        Adwaita::Toast.new(title).tap do |toast|
          toast.button_label = "Open Location"
          toast.action_name = "win.open-file-location"
        end,
      )
    end

    def add_undo_toast(title)
      add_toast(
        Adwaita::Toast.new(title).tap do |toast|
          toast.button_label = "Undo"
          toast.action_name = "win.undo"
        end,
      )
    end

    # Tells the user which items are drawn with fewer points than they hold.
    def add_downsample_toasts(items)
      items.select do |item|
        item.is_a?(DataItem) && item.exceeds_downsample_threshold?
      end.then do |downsampled|
        if downsampled.length == 1
          add_toast_string(
            "#{downsampled.first.name} is drawn with reduced detail " \
            "using #{DOWNSAMPLE_THRESHOLD} points",
          )
        elsif downsampled.length > 1
          add_toast_string(
            "#{downsampled.length} items are drawn with reduced detail " \
            "using #{DOWNSAMPLE_THRESHOLD} points",
          )
        end
      end
    end

    # Section data

    # Rebuilds the item rows and the sensitivity of everything that acts on
    # items, as upstream's `on_items_changed` does.
    def on_items_changed
      rebuild_item_rows
      if @data.empty?
        main_page.set_show_empty_data_page(true)
        set_action_enabled("optimize-limits", false)
      else
        main_page.set_show_empty_data_page(false)
        set_action_enabled("optimize-limits", true)
      end
      on_selection_changed
      canvas.queue_draw
    end

    # What the operations and the actions on items can act on: whether
    # anything is selected, and whether any of it is a dataset.
    def on_selection_changed
      items_selected = @data.any? { |item| item.selected }
      data_items_selected = @data.any? { |item| item.selected && item.is_a?(DataItem) }
      set_action_enabled("delete-selected", items_selected)
      set_action_enabled("export-data", items_selected)
      main_page.operations.tap do |operations|
        operations.set_items_sensitivity(items_selected)
        operations.set_data_items_sensitivity(data_items_selected)
        operations.set_entry_sensitivity(items_selected)
        operations.set_cut_sensitivity(data_items_selected && mode == :select)
      end
      canvas.queue_draw
    end

    # Upstream rebuilds the canvas on a style change, because a matplotlib
    # figure bakes the style in; this canvas reads the style parameters as it
    # draws, so a redraw is enough.
    def on_style_changed
      canvas.queue_draw
    end

    def add_action(action) = window.add_action(action)

    def set_action_enabled(name, enabled)
      window.lookup_action(name).then do |action|
        unless action.nil?
          action.enabled = enabled
        end
      end
    end

    private

      def header_button(icon_name, tooltip, action_name)
        Gtk::Button.new.tap do |button|
          button.icon_name = icon_name
          button.tooltip_text = tooltip
          button.action_name = action_name
        end
      end

      def rebuild_item_rows
        item_rows.each { |row| main_page.item_list.remove(row.widget) }
        item_rows.clear
        @data.each_with_index do |item, index|
          build_item_row(item, index)
        end
      end

      def build_item_row(item, index)
        ItemBox.new(
          window:      self,
          item:        item,
          index:       index,
          on_activate: ->(selected_item) { open_edit_item_page(selected_item) },
        ).tap do |row|
          main_page.item_list.append(row.build)
          row.setup_interactions
          item_rows << row
        end
      end

      def item_rows = @item_rows ||= []

      def open_edit_item_page(item)
        edit_item_page.load_item(item)
        navigation_view.push(edit_item_page.widget)
      end

      def connect_data
        @data.connect_signal(:items_changed) { on_items_changed }
        @data.connect_signal(:selection_changed) { on_selection_changed }
        @data.connect_signal(:style_changed) { on_style_changed }
        @data.connect_signal(:figure_settings_changed) { canvas.queue_draw }
        @data.connect_notify do |_, property|
          on_data_property_change(property)
        end
      end

      def on_data_property_change(property)
        case property
        when :can_undo then set_action_enabled("undo", @data.can_undo)
        when :can_redo then set_action_enabled("redo", @data.can_redo)
        when :can_view_back then set_action_enabled("view-back", @data.can_view_back)
        when :can_view_forward then set_action_enabled("view-forward", @data.can_view_forward)
        when :unsaved, :file then on_unsaved_change
        end
      end

      def connect_canvas
        canvas.connect_signal(:view_changed) { @data.add_view_history_state }
        canvas.connect_signal(:mode_changed) { |value| main_page.mode = value }
      end

      # The window title carries the project name, a bullet while there are
      # unsaved changes, and the project's directory as its subtitle.
      def on_unsaved_change
        if @data.file.nil?
          title = "Untitled Project"
          path = "Draft"
        else
          title = Tools.get_filename(@data.file)
          path = Tools.get_friendly_path(@data.file)
        end
        window.title = "Graphs — #{title}"
        content_title.subtitle = path
        if @data.unsaved
          content_title.title = "• #{title}"
        else
          content_title.title = title
        end
      end
  end
end
