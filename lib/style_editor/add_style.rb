# frozen_string_literal: true

require "adwaita"
require_relative "../styles"
require_relative "../utilities"

module Graphs
  module StyleEditor
    # Ported from upstream's graphs/style_editor/add_style.vala and
    # data/ui/style-editor/add-style.blp: lets the user start a new style
    # from one of the existing ones, under a name that does not collide.
    class AddStyleDialog
      def initialize(parent:, style_manager: StyleManager.instance, &on_accept)
        @parent = parent
        @style_manager = style_manager
        @on_accept = on_accept
      end

      def present
        dialog.tap do |widget|
          widget.child = toolbar_view

          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = clamp
          end

          header_bar.tap do |bar|
            bar.pack_start(cancel_button)
            bar.pack_end(create_button)

            cancel_button.signal_connect("clicked") { dialog.close }
            create_button.signal_connect("clicked") { on_accept }
          end

          clamp.tap do |widget_clamp|
            widget_clamp.child = group

            group.tap do |preferences|
              preferences.add(style_templates)
              preferences.add(new_style_name)

              style_templates.tap do |row|
                row.model = Gtk::StringList.new(template_names)
                row.signal_connect("notify::selected") { on_template_changed }
              end
            end
          end

          on_template_changed
          widget.present(@parent)
        end
      end

      private

        def template_names = @style_manager.template_names

        def on_template_changed
          template = template_names[style_templates.selected]
          new_style_name.text = Tools.get_duplicate_string(template, @style_manager.names)
        end

        def on_accept
          @style_manager.create_style(style_templates.selected + 1, new_style_name.text).then do |file|
            dialog.close
            @on_accept&.call(file)
          end
        end

        def dialog
          @dialog ||= Adwaita::Dialog.new.tap do |widget|
            widget.title = "Create Style"
            widget.content_width = 400
          end
        end

        def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

        def header_bar
          @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
            bar.show_end_title_buttons = false
          end
        end

        def cancel_button = @cancel_button ||= Gtk::Button.new(label: "Cancel")

        def create_button
          @create_button ||= Gtk::Button.new(label: "Create").tap do |button|
            button.add_css_class("suggested-action")
          end
        end

        def clamp
          @clamp ||= Adwaita::Clamp.new.tap do |widget|
            widget.margin_start = 12
            widget.margin_end = 12
            widget.margin_top = 12
            widget.margin_bottom = 12
          end
        end

        def group = @group ||= Adwaita::PreferencesGroup.new

        def style_templates
          @style_templates ||= Adwaita::ComboRow.new.tap do |row|
            row.title = "Template"
          end
        end

        def new_style_name
          @new_style_name ||= Adwaita::EntryRow.new.tap do |row|
            row.title = "Style Name"
          end
        end
    end
  end
end
