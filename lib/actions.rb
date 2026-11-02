# frozen_string_literal: true

require "adwaita"
require_relative "add_equation_dialog"
require_relative "enums"
require_relative "shortcuts_dialog"

module Graphs
  # Ported from upstream's graphs/actions.vala.
  #
  # `setup_global` adds the application's own actions, `setup_local` those of
  # one window. The accelerators are the ones upstream's window.blp binds in
  # its ShortcutController.
  module Actions
    GLOBAL_ACCELERATORS = {
      "app.quit"       => ["<control>q"],
      "app.new-window" => ["<control><shift>n"],
      "window.close"   => ["<control>w"],
    }.freeze

    LOCAL_ACCELERATORS = {
      "win.show-shortcuts"  => ["<control>question"],
      "win.add-equation"    => ["<control><alt>n"],
      "win.select-all"      => ["<control>a"],
      "win.select-none"     => ["<control><shift>a"],
      "win.undo"            => ["<control>z"],
      "win.redo"            => ["<control><shift>z"],
      "win.optimize-limits" => ["<control>0", "<control>KP_0"],
      "win.view-back"       => ["<alt>z"],
      "win.view-forward"    => ["<alt><shift>z"],
      "win.delete-selected" => ["Delete"],
      "win.toggle-sidebar"  => ["F9"],
      "win.mode-pan"        => ["<control>1"],
      "win.mode-zoom"       => ["<control>2"],
      "win.mode-select"     => ["<control>3"],
      "win.zoom-in"         => ["<control>plus", "<control>equal", "<control>KP_Add"],
      "win.zoom-out"        => ["<control>minus", "<control>KP_Subtract"],
    }.freeze

    module_function

    def setup_global(application)
      add_action(application.app, "quit") { application.quit_action }
      add_action(application.app, "about") { application.show_about }
      add_action(application.app, "new-window") { application.open_new_window }

      GLOBAL_ACCELERATORS.each do |name, accelerators|
        application.app.set_accels_for_action(name, accelerators)
      end
      LOCAL_ACCELERATORS.each do |name, accelerators|
        application.app.set_accels_for_action(name, accelerators)
      end
    end

    def setup_local(window)
      data = window.data

      add_action(window.window, "toggle-sidebar") do
        window.split_view.show_sidebar = !window.split_view.show_sidebar?
      end

      Mode.members.each do |mode|
        add_action(window.window, "mode-#{mode}") do
          window.mode = mode
          window.on_selection_changed
        end
      end

      add_action(window.window, "optimize-limits") { data.optimize_limits }
      add_action(window.window, "zoom-in") { window.canvas.zoom_in }
      add_action(window.window, "zoom-out") { window.canvas.zoom_out }

      add_action(window.window, "select-all") do
        data.select_all
        data.add_history_state
      end

      add_action(window.window, "select-none") do
        data.unselect_all
        data.add_history_state
      end

      add_action(window.window, "undo") { data.undo }
      add_action(window.window, "redo") { data.redo }
      add_action(window.window, "view-back") { data.view_back }
      add_action(window.window, "view-forward") { data.view_forward }

      add_action(window.window, "delete-selected") { delete_selected(window, data) }

      add_action(window.window, "add-equation") do
        AddEquationDialog.new(window: window).present
      end

      add_action(window.window, "show-shortcuts") do
        ShortcutsDialog.new.build.present(window.window)
      end
    end

    def add_action(target, name, &block)
      Gio::SimpleAction.new(name).tap do |action|
        action.signal_connect("activate") { block.call }
        target.add_action(action)
      end
    end

    def delete_selected(window, data)
      data.select { |item| item.selected }.then do |items|
        unless items.empty?
          data.delete_items(items)
          window.add_undo_toast("Deleted #{items.map(&:name).join(', ')}")
        end
      end
    end
  end
end
