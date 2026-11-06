# frozen_string_literal: true

require "adwaita"
require_relative "../../enums"

module Graphs
  module EditItem
    # Ported from upstream's graphs/sidebar/edit_item/base_box.vala and
    # data/ui/sidebar/edit-item/base.ui: the name, legend and axis-position
    # controls every item has, regardless of its kind.
    class BaseBox
      def initialize(item:)
        @item = item
      end

      def build
        box.tap do |widget|
          widget.append(group)
        end
      end

      def widget = box

      def box = @box ||= Gtk::Box.new(:vertical, 0)

      def group
        @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
          preferences.title = "Name and Position"
          preferences.add(name_row)
          preferences.add(legend_row)
          preferences.add(xposition_row)
          preferences.add(yposition_row)

          name_row.tap do |row|
            row.text = @item.name
            row.signal_connect("notify::text") { @item.name = row.text }
          end

          legend_row.tap do |row|
            if @item.legendable?
              row.visible = true
              row.active = @item.legend
              row.signal_connect("notify::active") { @item.legend = row.active? }
            end
          end

          xposition_row.tap do |row|
            row.selected = XPosition.value(@item.xposition) || 0
            row.signal_connect("notify::selected") do
              @item.xposition = XPosition.member(row.selected)
            end
          end

          yposition_row.tap do |row|
            row.selected = YPosition.value(@item.yposition) || 0
            row.signal_connect("notify::selected") do
              @item.yposition = YPosition.member(row.selected)
            end
          end
        end
      end

      def name_row
        @name_row ||= Adwaita::EntryRow.new.tap do |row|
          row.title = "Name"
          row.max_width_chars = 25
        end
      end

      def legend_row
        @legend_row ||= Adwaita::SwitchRow.new.tap do |row|
          row.title = "Show in Legend"
          row.visible = false
        end
      end

      def xposition_row
        @xposition_row ||= Adwaita::ComboRow.new.tap do |row|
          row.title = "X-Axis Position"
          row.model = Gtk::StringList.new(["Bottom", "Top"])
        end
      end

      def yposition_row
        @yposition_row ||= Adwaita::ComboRow.new.tap do |row|
          row.title = "Y-Axis Position"
          row.model = Gtk::StringList.new(["Left", "Right"])
        end
      end
    end
  end
end
