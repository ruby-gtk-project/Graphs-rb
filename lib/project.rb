# frozen_string_literal: true

require "adwaita"
require_relative "alert_dialogs"
require_relative "data"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/project.vala.
  #
  # Drives the project file dialogs and the error dialogs around them; the
  # actual reading and writing of a project dict is `Data#save`/`Data#load`
  # (ported from the current-version half of upstream's graphs/project.py).
  # The version-to-version migrations upstream's `ProjectMigrator` performs
  # and the pre-JSON legacy migration `migrate.py` does are not ported this
  # round, so `BETA_DISALLOWED`/`LEGACY_MIGRATION_DISALLOWED` and their retry
  # dialogs have nothing to retry into and are left out with them.
  module Project
    module_function

    def project_file_filter
      Tools.create_file_filter("Graphs Project File", "graphs")
    end

    def project_file_filters
      Tools.create_file_filters(false, project_file_filter)
    end

    # Section save

    # Saves `window`'s project, asking for a location with a file dialog
    # unless it already has one and `require_dialog` is false. Calls `block`
    # with whether the save went through, as upstream's async `save` returns.
    def save(window, require_dialog, &block)
      if !window.data.file.nil? && !require_dialog
        save_to_file(window, window.data.file, &block)
      else
        Gtk::FileDialog.new.tap do |dialog|
          dialog.filters = project_file_filters
          dialog.initial_name = "Project.graphs"
          dialog.save(window.window) do |_source, result|
            save_to_file(window, dialog.save_finish(result), &block)
          rescue GLib::Error
            block&.call(false)
          end
        end
      end
    end

    def save_to_file(window, file, &block)
      window.data.save(file)
      window.add_toast_string_with_file("Saved Project", window.data.file)
      block&.call(true)
    end

    # Section load

    # Loads `file` into `data`, offering to retry with relaxed flags when the
    # error is one of the ones upstream recovers from, and showing the
    # invalid-project dialog for anything else. Calls `block` with whether the
    # load succeeded.
    def load(window, data, file, &block)
      data.load(file)
      block&.call(true)
    rescue ProjectParseError => e
      AlertDialogs.build(:invalid_project).tap do |dialog|
        dialog.body = e.message
        dialog.present(window.window)
      end
      block&.call(false)
    end

    # Section open

    def open(window)
      Gtk::FileDialog.new.tap do |dialog|
        dialog.filters = project_file_filters
        dialog.open(window.window) do |_source, result|
          open_file(window, dialog.open_finish(result))
        rescue GLib::Error
          nil
        end
      end
    end

    def open_file(window, file)
      if !window.data.unsaved && window.data.file.nil?
        load(window, window.data, file)
      else
        new_window = window.application.create_main_window
        load(window, new_window.data, file) do |ok|
          if ok
            new_window.present
          else
            window.application.windows.delete(new_window)
          end
        end
      end
    end

    # Section close

    # Closes `window`'s project, asking to save unsaved changes first. Calls
    # `block` with whether the project ended up closed.
    def close(window, &block)
      if window.data.unsaved
        AlertDialogs.present(:save_project_changes, window.window) do |response|
          case response
          when "discard"
            window.data.clear
            block&.call(true)
          when "save"
            save(window, false) do |saved|
              if saved
                window.data.clear
              end
              block&.call(saved)
            end
          else
            block&.call(false)
          end
        end
      else
        window.data.clear
        block&.call(true)
      end
    end
  end
end
