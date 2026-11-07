# frozen_string_literal: true

require "adwaita"
require_relative "color_button"
require_relative "curve_fitting_dialog"
require_relative "item/data_item"

module Graphs
  # Ported from upstream's graphs/item_box.vala and data/ui/item-box.blp: one
  # row of the sidebar's item list, with a selection check button, the item's
  # colour and a menu to move or remove it.
  class ItemBox
    def initialize(window:, item:, index:, on_activate: nil)
      @window = window
      @item = item
      @index = index
      @on_activate = on_activate
    end

    attr_reader :item, :index

    def build
      row.tap do |widget|
        widget.add_prefix(check_button)
        widget.add_suffix(color_button.build)
        widget.add_suffix(menu_button)

        check_button.tap do |button|
          button.active = @item.selected
          button.signal_connect("toggled") { on_toggle }
        end

        widget.signal_connect("activated") { @on_activate&.call(@item) }

        @item.connect_notify do |_, property|
          on_item_change(property)
        end
      end
    end

    def widget = row

    # The actions the row's menu triggers. Rows built for the drag icon get
    # none, as upstream's `setup_interactions` says.
    def setup_interactions
      Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(delete_action)
        if @index.positive?
          group.add_action(move_up_action)
        end
        if @index + 1 < @window.data.n_items
          group.add_action(move_down_action)
        end
        if @item.is_a?(DataItem)
          group.add_action(curve_fitting_action)
        end
        row.insert_action_group("item_box", group)
      end
    end

    def change_position(source_index)
      @window.data.change_position(@index, source_index)
      @window.data.add_history_state
      @window.data.add_view_history_state
    end

    def row
      @row ||= Adwaita::ActionRow.new.tap do |widget|
        widget.title = @item.name
        widget.subtitle = @item.typename
        widget.title_lines = 1
        widget.activatable = true
      end
    end

    def check_button
      @check_button ||= Gtk::CheckButton.new.tap do |button|
        button.halign = :start
        button.add_css_class("selection-mode")
      end
    end

    def color_button
      @color_button ||= ColorButton.new(color: @item.get_rgba) do |rgba|
        on_color(rgba)
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "view-more-symbolic"
        button.vexpand = false
        button.valign = :center
        button.add_css_class("flat")
        button.popover = popover
      end
    end

    def popover
      @popover ||= Gtk::PopoverMenu.new(menu_model).tap do |widget|
        widget.has_arrow = false
      end
    end

    def menu_model
      @menu_model ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, move_section)
        menu.append_section(nil, remove_section)
      end
    end

    private

      def move_section
        Gio::Menu.new.tap do |section|
          section.append("Move Down", "item_box.move_down")
          section.append("Move Up", "item_box.move_up")
        end
      end

      def remove_section
        Gio::Menu.new.tap do |section|
          if @item.is_a?(DataItem)
            section.append("Curve Fitting", "item_box.curve_fitting")
          end
          section.append("Remove Item", "item_box.delete")
        end
      end

      def curve_fitting_action
        Gio::SimpleAction.new("curve_fitting").tap do |action|
          action.signal_connect("activate") do
            CurveFittingDialog.new(window: @window, item: @item).present
          end
        end
      end

      def delete_action
        Gio::SimpleAction.new("delete").tap do |action|
          action.signal_connect("activate") do
            name = @item.name
            @window.data.delete_items([@item])
            @window.add_undo_toast("Deleted #{name}")
          end
        end
      end

      def move_up_action
        Gio::SimpleAction.new("move_up").tap do |action|
          action.signal_connect("activate") { change_position(@index - 1) }
        end
      end

      def move_down_action
        Gio::SimpleAction.new("move_down").tap do |action|
          action.signal_connect("activate") { change_position(@index + 1) }
        end
      end

      def on_item_change(property)
        case property
        when :name then row.title = @item.name
        when :color, :alpha then color_button.color = @item.get_rgba
        when :selected then check_button.active = @item.selected
        end
      end

      def on_toggle
        unless @item.selected == check_button.active?
          @item.selected = check_button.active?
          @window.data.add_history_state
        end
      end

      def on_color(rgba)
        @item.set_rgba(rgba)
        @window.data.add_history_state
      end
  end
end
