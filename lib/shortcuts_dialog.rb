# frozen_string_literal: true

require "adwaita"

module Graphs
  # Ported from upstream's data/ui/window-shortcuts.blp: the keyboard
  # shortcuts of the main window, section by section.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = {
      "General"         => [
        ["Show Shortcuts", "<control>question"],
        ["Close Application", "<control>q"],
        ["Close Application Window", "<control>w"],
      ],
      "Mode Switching"  => [
        ["Pan Mode", "<control>1"],
        ["Zoom Mode", "<control>2"],
        ["Select Mode", "<control>3"],
      ],
      "New Data"        => [
        ["Add Data from File", "<control>n"],
        ["Add Data from Equation", "<control><alt>n"],
        ["Generate Data", "<control><shift>n"],
        ["New Project", "<control><shift>n"],
        ["Open Project", "<control>o"],
        ["Delete Selected Data", "Delete"],
      ],
      "Save and Export" => [
        ["Export Data", "<control><shift>e"],
        ["Export Figure", "<control>e"],
        ["Save Project", "<control>s"],
        ["Save Project As", "<control><shift>s"],
      ],
      "View"            => [
        ["Previous View", "<alt>z"],
        ["Next View", "<alt><shift>z"],
        ["Optimize limits", "<control>0"],
        ["Zoom in", "<control>plus"],
        ["Zoom out", "<control>minus"],
        ["Toggle Sidebar", "F9"],
      ],
      "Actions"         => [
        ["Select All", "<control>a"],
        ["Select None", "<control><shift>a"],
        ["Undo Action", "<control>z"],
        ["Redo Action", "<control><shift>z"],
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

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8".
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
  end
end
