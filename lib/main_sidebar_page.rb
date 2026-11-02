# frozen_string_literal: true

require "adwaita"
require_relative "enums"

module Graphs
  # Ported from upstream's graphs/sidebar/main.vala and
  # data/ui/sidebar/main.blp: the sidebar's first page, with the item list,
  # the application menus and the three mode buttons.
  #
  # Upstream's page also holds the operations panel and a figure settings
  # button; both belong to components this port has not written yet, so the
  # page carries what it can reach.
  class MainSidebarPage
    MODE_BUTTONS = {
      pan:    ["move-tool-symbolic", "Pan Mode. Click and drag to pan"],
      zoom:   ["loupe-symbolic", "Zoom Mode. Select an area on the figure to zoom in"],
      select: ["edit-select-all-symbolic", "Select Mode. Click and drag to make a selection of data"],
    }.freeze

    def initialize(title: "Graphs")
      @title = title
    end

    def build
      page.tap do
        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box
        end

        header_bar.tap do |bar|
          bar.pack_start(add_button)
          bar.pack_end(menu_button)
        end

        content_box.tap do |box|
          box.append(item_stack)
          box.append(Gtk::Separator.new(:horizontal))
          box.append(mode_box)
          box.append(Gtk::Separator.new(:horizontal))

          item_stack.tap do |stack|
            stack.add_named(empty_page, "empty")
            stack.add_named(item_scroll, "items")

            item_scroll.tap do |scroll|
              scroll.child = item_list
            end
          end

          mode_box.tap do |modes|
            MODE_BUTTONS.each_key { |mode| modes.append(mode_button(mode)) }
          end
        end
      end
    end

    def widget = page

    def title = @title

    def set_title(title)
      @title = title
      page.title = title
    end

    # Switches between the "No Data" status page and the item list.
    def set_show_empty_data_page(show_empty)
      if show_empty
        item_stack.visible_child_name = "empty"
      else
        item_stack.visible_child_name = "items"
      end
    end

    # A short window drops the list's own scrollbar, so the sidebar scrolls
    # as a whole.
    def height_limited=(limited)
      if limited
        item_scroll.set_policy(:automatic, :never)
      else
        item_scroll.set_policy(:automatic, :automatic)
      end
    end

    def mode
      MODE_BUTTONS.keys.find { |mode| mode_button(mode).active? } || :pan
    end

    def mode=(value)
      MODE_BUTTONS.each_key do |mode|
        mode_button(mode).active = mode == value
      end
    end

    def page = @page ||= Adwaita::NavigationPage.new(toolbar_view, @title)
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def item_stack = @item_stack ||= Gtk::Stack.new

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.vexpand = true
      end
    end

    def item_scroll
      @item_scroll ||= Gtk::ScrolledWindow.new.tap do |scroll|
        scroll.vexpand = true
        scroll.hexpand = true
        scroll.hscrollbar_policy = :never
      end
    end

    def item_list
      @item_list ||= Gtk::ListBox.new.tap do |list|
        list.margin_bottom = 12
        list.margin_top = 6
        list.margin_start = 12
        list.margin_end = 12
        list.vexpand = false
        list.hexpand = true
        list.valign = :start
        list.selection_mode = :none
        list.add_css_class("boxed-list")
      end
    end

    def empty_page
      @empty_page ||= Adwaita::StatusPage.new.tap do |status|
        status.icon_name = "list-compact-symbolic"
        status.title = "No Data"
        status.description = "Add data from a file or manually as an equation"
        status.vexpand = true
        status.add_css_class("compact")
      end
    end

    def mode_box
      @mode_box ||= Gtk::Box.new(:horizontal, 10).tap do |box|
        box.margin_top = 12
        box.margin_bottom = 12
        box.margin_start = 12
        box.margin_end = 12
      end
    end

    def mode_button(mode)
      mode_buttons[mode] ||= Gtk::ToggleButton.new.tap do |button|
        MODE_BUTTONS.fetch(mode).then do |icon, tooltip|
          button.icon_name = icon
          button.tooltip_text = tooltip
        end
        button.action_name = "win.mode-#{mode}"
        button.hexpand = true
      end
    end

    def add_button
      @add_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "list-add-symbolic"
        button.tooltip_text = "Add New Data"
        button.always_show_arrow = true
        button.menu_model = add_data_menu
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "open-menu-symbolic"
        button.tooltip_text = "Open Application Menu"
        button.primary = true
        button.menu_model = primary_menu
      end
    end

    def add_data_menu
      @add_data_menu ||= Gio::Menu.new.tap do |menu|
        menu.append("Add Equation…", "win.add-equation")
      end
    end

    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |menu|
        Gio::Menu.new.tap do |section|
          section.append("New Project", "app.new-window")
          menu.append_section(nil, section)
        end
        Gio::Menu.new.tap do |section|
          section.append("Keyboard Shortcuts", "win.show-shortcuts")
          section.append("About Graphs", "app.about")
          menu.append_section(nil, section)
        end
      end
    end

    private

      def mode_buttons = @mode_buttons ||= {}
  end
end
