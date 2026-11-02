# frozen_string_literal: true

require "adwaita"

module Graphs
  # Ported from upstream's data/ui/dialogs/*.blp, which upstream builds with
  # `Tools.build_dialog`: the alert dialogs the app shows before it does
  # something it cannot take back.
  #
  # Each entry carries the heading, the body, and the responses with the
  # appearance the blueprint gives them, plus which response closing the dialog
  # counts as and which one is the default.
  module AlertDialogs
    DIALOGS = {
      beta_disallowed:             {
        heading:   "Beta Project",
        body:      "The project you are trying to import is from a beta version of " \
                   "Graphs. It may contain invalid data.",
        responses: [
          ["continue", "Continue", :default],
          ["close", "Abort", :default],
        ],
        close:     "close",
        preferred: "close",
      },
      delete_style:                {
        heading:   "Delete Style?",
        body:      "",
        responses: [
          ["cancel", "Cancel", :default],
          ["delete", "Delete", :destructive],
        ],
        close:     "cancel",
        preferred: "delete",
      },
      invalid_project:             {
        heading:   "Invalid Project",
        body:      "",
        responses: [["close", "Close", :default]],
        close:     "close",
        preferred: "close",
      },
      legacy_migration_disallowed: {
        heading:   "Legacy Project",
        body:      "You are trying to open a legacy project.\n\nThe legacy project " \
                   "format may contain dangerous code and may cause harm to your " \
                   "system.\n\nOnly proceed if you trust the author of this file.",
        responses: [
          ["continue", "Continue", :destructive],
          ["close", "Abort", :default],
        ],
        close:     "close",
        preferred: "close",
      },
      reset_import_settings:       {
        heading:   "Reset to Defaults?",
        body:      "Are you sure you want to reset the import settings?",
        responses: [
          ["cancel", "Cancel", :default],
          ["reset", "Reset", :destructive],
        ],
        close:     "cancel",
        preferred: "reset",
      },
      save_project_changes:        {
        heading:   "Save Changes?",
        body:      "Current project contains unsaved changes, changes that are not " \
                   "saved will be permanently lost.",
        responses: [
          ["cancel", "Cancel", :default],
          ["discard", "Discard", :destructive],
          ["save", "Save", :suggested],
        ],
        close:     "cancel",
        preferred: "discard",
      },
      save_style_changes:          {
        heading:   "Save Changes?",
        body:      "Current style contains unsaved changes, changes that are not " \
                   "saved will be permanently lost.",
        responses: [
          ["cancel", "Cancel", :default],
          ["discard", "Discard", :destructive],
          ["save", "Save", :suggested],
        ],
        close:     "cancel",
        preferred: "discard",
      },
    }.freeze

    module_function

    def build(name)
      DIALOGS.fetch(name).then do |definition|
        Adwaita::AlertDialog.new(definition[:heading], definition[:body]).tap do |dialog|
          definition[:responses].each do |id, label, appearance|
            dialog.add_response(id, label)
            dialog.set_response_appearance(id, appearance)
          end
          dialog.close_response = definition[:close]
          dialog.default_response = definition[:preferred]
        end
      end
    end

    # Shows one of the dialogs over `parent`, calling the block with the
    # response the user picked.
    def present(name, parent, &block)
      build(name).tap do |dialog|
        unless block.nil?
          dialog.signal_connect("response") { |_, response| block.call(response) }
        end
        dialog.present(parent)
      end
    end
  end
end
