# frozen_string_literal: true

require "adwaita"
require_relative "item/factory"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/export_items.vala: writes the selected data
  # out as tab separated columns, one file per item.
  #
  # A single item is saved under a name of the user's choosing; several items
  # are written into a directory the user picks, each under its own name.
  module Export
    DELIMITER = "\t"
    VALUE_FORMAT = "%.12e"

    module_function

    def export_items(window)
      if window.data.empty?
        window.add_toast_string("No data to export")
      elsif window.data.n_items > 1
        export_to_folder(window)
      else
        export_single(window)
      end
    end

    def export_to_folder(window)
      Gtk::FileDialog.new.tap do |dialog|
        dialog.accept_label = "Export"
        dialog.select_folder(window.window) do |_source, result|
          dialog.select_folder_finish(result).then do |folder|
            write_all(window, folder)
            window.add_toast_string_with_file("Exported Data", folder)
          end
        rescue GLib::Error
          nil
        end
      end
    end

    def write_all(window, folder)
      used = []
      window.data.each do |item|
        Tools.get_duplicate_string(item.name.tr("/", "\\").strip, used).then do |filename|
          used << filename
          save_item_as_columns(
            item,
            folder.get_child("#{filename}.txt"),
            window.data.figure_settings,
          )
        end
      end
    end

    def export_single(window)
      window.data.get_item(0).then do |item|
        Gtk::FileDialog.new.tap do |dialog|
          dialog.initial_name = "#{item.name}.txt"
          dialog.accept_label = "Export"
          dialog.filters = Tools.create_file_filters(true, Tools.create_file_filter("Text Files", "txt"))
          dialog.save(window.window) do |_source, result|
            dialog.save_finish(result).then do |file|
              save_item_as_columns(item, file, window.data.figure_settings)
              window.add_toast_string_with_file("Exported Data", file)
            end
          rescue GLib::Error
            nil
          end
        end
      end
    end

    # An equation is sampled across its axis' limits before it is written; an
    # item that holds neither data nor an equation is skipped.
    def save_item_as_columns(item, file, figure_settings)
      holder(item, figure_settings).then do |data|
        unless data.nil?
          File.write(file.path, columns(item, data))
        end
      end
    end

    def holder(item, figure_settings)
      if item.is_a?(DataItem)
        item.data
      elsif item.is_a?(EquationItem)
        MathTools.equation_to_data(
          item.equation,
          figure_settings.min_for(item.xposition),
          figure_settings.max_for(item.xposition),
        )
      end
    end

    def columns(item, data)
      rows = []
      unless item.xlabel.empty? || item.ylabel.empty?
        rows << header(item, data)
      end
      (0...data.length).each do |index|
        rows << row(data, index)
      end
      "#{rows.join("\n")}\n"
    end

    def header(item, data)
      [item.xlabel, item.ylabel].tap do |labels|
        unless data.xerr.nil?
          labels << "x_err"
        end
        unless data.yerr.nil?
          labels << "y_err"
        end
      end.join(DELIMITER)
    end

    def row(data, index)
      [data.xdata[index], data.ydata[index]].tap do |values|
        unless data.xerr.nil?
          values << data.xerr[index]
        end
        unless data.yerr.nil?
          values << data.yerr[index]
        end
      end.map { |value| format(VALUE_FORMAT, value) }.join(DELIMITER)
    end
  end
end
