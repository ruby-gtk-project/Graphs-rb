# frozen_string_literal: true

require "adwaita"

module Graphs
  module StyleEditor
    # Ported from upstream's data/ui/style-editor/shortcuts.blp: the keyboard
    # shortcuts of the style editor window.
    class ShortcutsDialog < Adwaita::ShortcutsDialog
      SECTIONS = {
        "General" => [
          ["Show Shortcuts", "<control>question"],
          ["Close Application Window", "<control>w"],
        ],
        "Save"    => [
          ["Save Style", "<control>s"],
          ["Save Style As", "<control><shift>s"],
          ["Open Style", "<control>o"],
        ],
      }.freeze

      def initialize
        super()
        self.title = "Keyboard Shortcuts"
      end

      def build
        tap do |dialog|
          SECTIONS.each do |title, items|
            dialog.add(section(title, items))
          end
        end
      end

      private

        def section(title, items)
          Adwaita::ShortcutsSection.new.tap do |section|
            section.title = title
            items.each { |label, accelerator| section.add(item(label, accelerator)) }
          end
        end

        def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
    end
  end
end
