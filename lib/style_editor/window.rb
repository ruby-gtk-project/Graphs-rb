# frozen_string_literal: true

require "adwaita"
require_relative "../alert_dialogs"
require_relative "../canvas"
require_relative "../data"
require_relative "../item/factory"
require_relative "../style_preview"
require_relative "../styles"
require_relative "../utilities"
require_relative "add_style"
require_relative "editor_box"
require_relative "shortcuts_dialog"

module Graphs
  module StyleEditor
    # Ported from upstream's graphs/style_editor/window.vala and
    # data/ui/style-editor/window.blp: a grid of the available styles, and —
    # once one is opened — the editor form beside a live preview of two
    # sample items drawn under the style being edited.
    #
    # Upstream's adaptive `Adw.MultiLayoutView` (side-by-side on a wide
    # window, a bottom sheet on a narrow one) is simplified here to the
    # side-by-side layout only; the Ruby GTK4 bindings have no example of
    # `Adw.MultiLayoutView` to build the responsive version against safely.
    class Window
      # [0, 10]
      PREVIEW_XDATA = (0..10).map(&:to_f).freeze
      # [0, e^10]
      PREVIEW_YDATA1 = PREVIEW_XDATA.map { |x| Math.exp(x) - 1 }.freeze
      # [1, e^x]
      PREVIEW_YDATA2 = PREVIEW_XDATA.map { |x| Math.exp(x) }.freeze

      def initialize(application:)
        @application = application
        @file = nil
        @unsaved = false
        @style_manager = StyleManager.instance
      end

      attr_reader :application

      def build
        window.tap do |widget|
          widget.title = "Graphs Style Editor"
          widget.set_default_size(1200, 700)
          widget.child = stack
          widget.signal_connect("close-request") { on_close_request }

          stack.tap do |pages|
            pages.add_named(grid_page, "grid")
            pages.add_named(editor_page, "editor")
          end

          setup_actions
          reload_grid
        end
      end

      def present = window.present

      private

        def setup_actions
          add_action("save-style") { save_if_file_present }
          add_action("save-style-as") { save_as }
          add_action("open-style") { import_style }
          add_action("close-style") { request_close_style }
          add_action("import-style") { import_style }
          add_action("create-style") { create_style }
          add_action("show-shortcuts") { ShortcutsDialog.new.build.present(window) }
          save_action.enabled = false
        end

        def add_action(name, &block)
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect("activate") { block.call }
            window.add_action(action)
          end
        end

        def save_action = window.lookup_action("save-style")

        # Section: the grid of available styles

        # Rebuilds the grid without ever destroying a previously-built tile.
        #
        # A `Gtk::DrawingArea` registers its `set_draw_func` callback as an
        # FFI closure that `gobject-introspection` does not keep rooted
        # independently of the widget staying alive; destroying and
        # recreating a batch of `StylePreview` tiles (each backed by one)
        # via `Gtk::FlowBox#remove_all` + re-`append` reproducibly corrupts
        # the process once the GC runs before GTK's next frame tick for the
        # destroyed tiles fires — see
        # .reports/style-editor-flowbox-drawingarea-gc.md, reproduced there
        # with no Graphs-rb code at all. The fix is to never let a tile's
        # underlying widget be destroyed in the first place: each
        # `StylePreview` is built once and kept (and its `Gtk::DrawingArea`
        # with it), reused in place across every later reload, with only
        # tiles for styles that truly no longer exist ever removed.
        def reload_grid
          previews = (@style_previews ||= {})
          current = @style_manager.styles
          current_names = current.map(&:name)
          previews.each_key.to_a.each do |name|
            unless current_names.include?(name)
              flow_box.remove(previews.delete(name).widget)
            end
          end
          current.each do |style|
            preview = previews[style.name]
            if preview
              preview.style = style
            else
              previews[style.name] = build_tile(style)
              flow_box.append(previews[style.name].widget)
            end
          end
        end

        def build_tile(style)
          StylePreview.new(
            on_open:      ->(picked) { load(picked.file) },
            on_open_with: ->(picked) { Tools.open_file_location(picked.file) },
            on_delete:    ->(picked) { confirm_delete(picked) },
          ).tap do |preview|
            preview.build
            preview.style = style
            preview.widget.add_controller(click_gesture_for(preview))
          end
        end

        # Reads `preview.style` lazily, at click time, rather than closing
        # over the `style` object passed to `build_tile` — the tile's
        # widget (and this gesture) is now built once and reused across
        # reloads, but `preview.style` is reassigned on every reload, so a
        # captured style object would go stale.
        def click_gesture_for(preview)
          Gtk::GestureClick.new.tap do |gesture|
            gesture.signal_connect("released") { open_tile(preview.style) }
          end
        end

        def open_tile(style)
          unless style.file.nil?
            load(style.file)
          end
        end

        def confirm_delete(style)
          AlertDialogs.build(:delete_style).tap do |dialog|
            dialog.body = "Are you sure you want to delete #{style.name}?"
            dialog.signal_connect("response") { |_, response| on_delete_response(response, style) }
            dialog.present(window)
          end
        end

        def on_delete_response(response, style)
          if response == "delete"
            Gio::File.new_for_path(style.file).trash
            @style_manager.reload_user_styles
            reload_grid
          end
        end

        def import_style
          Gtk::FileDialog.new.tap do |dialog|
            dialog.filters = Tools.create_file_filters(true, Tools.create_file_filter("Style Files", "mplstyle"))
            dialog.open(window) do |_source, result|
              begin
                load(dialog.open_finish(result))
              rescue GLib::Error
                nil
              end
            end
          end
        end

        def create_style
          AddStyleDialog.new(parent: window, style_manager: @style_manager) do |file|
            load(file)
          end.present
        end

        # Section: the editor page

        def load(file)
          @file = file
          @loading = true
          editor_box.load(file)
          window.title = "Graphs Style Editor — #{editor_box.parameters.name}"
          reload_canvas(editor_box.parameters)
          stack.visible_child_name = "editor"
          @unsaved = false
          save_action.enabled = false
          @loading = false
        end

        def save_if_file_present
          unless @file.nil?
            save
          end
        end

        def save
          editor_box.save(@file)
          @unsaved = false
          save_action.enabled = false
          @style_manager.reload_user_styles
        end

        def save_as
          Gtk::FileDialog.new.tap do |dialog|
            dialog.filters = Tools.create_file_filters(true, Tools.create_file_filter("Style Files", "mplstyle"))
            dialog.initial_name = "Style.mplstyle"
            dialog.save(window) do |_source, result|
              begin
                @file = dialog.save_finish(result)
                save
              rescue GLib::Error
                nil
              end
            end
          end
        end

        def request_close_style
          if @unsaved
            AlertDialogs.present(:save_style_changes, window) do |response|
              if response == "discard"
                close_style
              elsif response == "save"
                save
                close_style
              end
            end
          else
            close_style
          end
        end

        def close_style
          @unsaved = false
          @file = nil
          window.title = "Graphs Style Editor"
          stack.visible_child_name = "grid"
          reload_grid
        end

        def on_params_changed(parameters)
          unless @loading
            @unsaved = true
            save_action.enabled = true
            window.title = "Graphs Style Editor — #{parameters.name}"
          end
          reload_canvas(parameters)
        end

        def reload_canvas(parameters)
          preview_data.set_preview_style(parameters)
          preview_data.figure_settings.title = "Title"
          preview_data.figure_settings.bottom_label = "X Label"
          preview_data.figure_settings.left_label = "Y Label"
        end

        def on_close_request
          if @unsaved
            AlertDialogs.present(:save_style_changes, window) do |response|
              if response == "discard"
                window.destroy
              elsif response == "save"
                save
                window.destroy
              end
            end
            true
          else
            false
          end
        end

        # Section: widgets

        def window
          @window ||= Gtk::ApplicationWindow.new(@application.app)
        end

        def stack = @stack ||= Gtk::Stack.new

        def grid_page
          @grid_page ||= Adwaita::ToolbarView.new.tap do |view|
            view.add_top_bar(grid_header_bar)
            view.add_bottom_bar(grid_bottom_bar)
            view.content = grid_scroll

            grid_scroll.tap do |scroll|
              scroll.child = flow_box
            end
          end
        end

        def grid_header_bar
          @grid_header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
            bar.title_widget = Adwaita::WindowTitle.new("Graphs Style Editor", "")
            bar.pack_end(grid_menu_button)
          end
        end

        def grid_menu_button
          @grid_menu_button ||= Gtk::MenuButton.new.tap do |button|
            button.icon_name = "open-menu-symbolic"
            button.tooltip_text = "Open Application Menu"
            button.primary = true
            button.menu_model = grid_menu
          end
        end

        def grid_menu
          @grid_menu ||= Gio::Menu.new.tap do |menu|
            Gio::Menu.new.tap do |section|
              section.append("New Window", "app.style-editor")
              menu.append_section(nil, section)
            end
            Gio::Menu.new.tap do |section|
              section.append("Keyboard Shortcuts", "win.show-shortcuts")
              section.append("About Graphs", "app.about")
              menu.append_section(nil, section)
            end
          end
        end

        def grid_bottom_bar
          @grid_bottom_bar ||= Adwaita::Clamp.new.tap do |clamp|
            clamp.child = grid_button_box

            grid_button_box.tap do |box|
              box.append(import_button)
              box.append(create_button)
            end
          end
        end

        def grid_button_box
          @grid_button_box ||= Gtk::Box.new(:horizontal, 24).tap do |box|
            box.margin_start = 12
            box.margin_end = 12
            box.margin_top = 12
            box.margin_bottom = 12
            box.homogeneous = true
          end
        end

        def import_button
          @import_button ||= Gtk::Button.new(label: "Import File…").tap do |button|
            button.halign = :center
            button.action_name = "win.import-style"
            button.add_css_class("pill")
          end
        end

        def create_button
          @create_button ||= Gtk::Button.new(label: "Create Style…").tap do |button|
            button.halign = :center
            button.action_name = "win.create-style"
            button.add_css_class("pill")
            button.add_css_class("suggested-action")
          end
        end

        def grid_scroll = @grid_scroll ||= Gtk::ScrolledWindow.new

        def flow_box
          @flow_box ||= Gtk::FlowBox.new.tap do |box|
            box.valign = :start
            box.max_children_per_line = 4
            box.min_children_per_line = 1
            box.row_spacing = 12
            box.column_spacing = 12
            box.margin_start = 12
            box.margin_end = 12
            box.margin_top = 12
            box.margin_bottom = 12
            box.selection_mode = :none
            box.homogeneous = true
          end
        end

        def editor_page
          @editor_page ||= Gtk::Box.new(:horizontal, 0).tap do |box|
            box.append(editor_side)
            box.append(Gtk::Separator.new(:vertical))
            box.append(canvas_side)
          end
        end

        def editor_side
          @editor_side ||= Adwaita::ToolbarView.new.tap do |view|
            view.add_top_bar(editor_header_bar)
            view.content = editor_scroll
            view.set_size_request(420, -1)

            editor_scroll.tap do |scroll|
              scroll.hscrollbar_policy = :never
              scroll.child = editor_clamp

              editor_clamp.tap do |clamp|
                clamp.margin_start = 12
                clamp.margin_end = 12
                clamp.margin_top = 12
                clamp.margin_bottom = 12
                clamp.child = editor_box.build
              end
            end
          end
        end

        def editor_header_bar
          @editor_header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
            bar.title_widget = Adwaita::WindowTitle.new("Graphs Style Editor", "")
            bar.pack_end(editor_menu_button)
          end
        end

        def editor_menu_button
          @editor_menu_button ||= Gtk::MenuButton.new.tap do |button|
            button.icon_name = "open-menu-symbolic"
            button.tooltip_text = "Open Application Menu"
            button.primary = true
            button.menu_model = editor_menu
          end
        end

        def editor_menu
          @editor_menu ||= Gio::Menu.new.tap do |menu|
            Gio::Menu.new.tap do |section|
              section.append("Save Style", "win.save-style")
              section.append("Save Style As…", "win.save-style-as")
              section.append("Close Style", "win.close-style")
              menu.append_section(nil, section)
            end
            Gio::Menu.new.tap do |section|
              section.append("Open Style…", "win.open-style")
              menu.append_section(nil, section)
            end
            Gio::Menu.new.tap do |section|
              section.append("Keyboard Shortcuts", "win.show-shortcuts")
              section.append("About Graphs", "app.about")
              menu.append_section(nil, section)
            end
          end
        end

        def editor_scroll = @editor_scroll ||= Gtk::ScrolledWindow.new
        def editor_clamp = @editor_clamp ||= Adwaita::Clamp.new

        def editor_box
          @editor_box ||= EditorBox.new { |parameters| on_params_changed(parameters) }
        end

        def canvas_side
          @canvas_side ||= Adwaita::ToolbarView.new.tap do |view|
            view.add_top_bar(canvas_header_bar)
            view.content = canvas_bin
            view.hexpand = true
          end
        end

        def canvas_header_bar
          @canvas_header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
            bar.show_title = false
          end
        end

        def canvas_bin
          @canvas_bin ||= Adwaita::Bin.new.tap do |bin|
            bin.child = canvas.build
          end
        end

        def preview_data
          @preview_data ||= Data.new.tap do |data|
            data.add_items([
              ItemFactory.new_data_item(data.selected_style_params, PREVIEW_XDATA, PREVIEW_YDATA1).tap do |item|
                item.name = "Example Item"
              end,
              ItemFactory.new_data_item(data.selected_style_params, PREVIEW_XDATA, PREVIEW_YDATA2).tap do |item|
                item.name = "Example Item"
              end,
            ])
          end
        end

        def canvas = @canvas ||= Canvas.new(data: preview_data)
    end
  end
end
