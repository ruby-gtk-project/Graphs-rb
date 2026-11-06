# frozen_string_literal: true

require "adwaita"
require_relative "../../item/data_item"
require_relative "../../item/equation_item"
require_relative "../../item/fill_item"
require_relative "../../item/generated_data_item"
require_relative "base_box"
require_relative "data_box"
require_relative "equation_box"
require_relative "errorbar_group"
require_relative "fill_box"
require_relative "generated_data_box"

module Graphs
  module EditItem
    # Ported from upstream's graphs/sidebar/edit_item/page.vala and
    # data/ui/sidebar/edit-item/page.ui: the navigation page the item list
    # pushes to, assembling whichever boxes fit the item it is loading.
    class Page
      def initialize(window:)
        @window = window
      end

      def build
        navigation_page.tap do
          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = scrolled_window

            scrolled_window.child = edit_item_box
          end
        end
      end

      def widget = navigation_page

      def load_item(item)
        clear_box
        edit_item_box.append(BaseBox.new(item: item).build)
        boxes_for(item).each { |box| edit_item_box.append(box.build) }
      end

      def navigation_page
        @navigation_page ||= Adwaita::NavigationPage.new(toolbar_view, "Edit Item")
      end

      def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
      def header_bar = @header_bar ||= Adwaita::HeaderBar.new

      def scrolled_window
        @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scroll|
          scroll.propagate_natural_height = true
        end
      end

      def edit_item_box
        @edit_item_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
          box.margin_top = 12
          box.margin_bottom = 12
          box.margin_start = 12
          box.margin_end = 12
        end
      end

      private

        def clear_box
          while (child = edit_item_box.last_child)
            edit_item_box.remove(child)
          end
        end

        # Which boxes an item gets, in the order upstream's `load_item`
        # appends them: a generated dataset is a DataItem too, so it is
        # checked first.
        def boxes_for(item)
          if item.is_a?(GeneratedDataItem)
            [GeneratedDataBox.new(item: item)] + data_boxes(item)
          elsif item.is_a?(DataItem)
            data_boxes(item)
          elsif item.is_a?(EquationItem)
            [EquationBox.new(item: item)]
          elsif item.is_a?(FillItem)
            [FillBox.new(item: item, data: @window.data)]
          else
            []
          end
        end

        def data_boxes(item)
          [DataBox.new(item: item)] + errorbar_boxes(item)
        end

        def errorbar_boxes(item)
          if item.has_xerr? || item.has_yerr?
            [ErrorbarGroup.new(item: item)]
          else
            []
          end
        end
    end
  end
end
