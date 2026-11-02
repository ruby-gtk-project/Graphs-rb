# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "rb/version"
require_relative "../actions"
require_relative "../data"
require_relative "../window"

module Graphs
  # Ported from upstream's graphs/application.vala.
  #
  # Owns the application object, the stylesheet and the bundled icons, and
  # creates the main windows; each window has its own Data, as upstream's
  # several-projects-at-once model requires.
  class Application
    APPLICATION_ID = "org.rubygtkproject.Graphs"

    HOMEPAGE_URL = "https://apps.gnome.org/Graphs"
    ISSUE_URL = "https://gitlab.gnome.org/World/Graphs/-/issues"

    DEVELOPERS = [
      "Sjoerd Stendahl <contact@sjoerd.se>",
      "Christoph Matthias Kohnen <mail@cmkohnen.de>",
    ].freeze

    DATA_DIR = File.expand_path("../../data", __dir__)
    STYLESHEET = File.expand_path("../style.css", __dir__)

    def build
      app.tap do
        app.signal_connect("startup") { on_startup }
        app.signal_connect("activate") { on_activate }
      end
    end

    def run(argv = ARGV) = app.run(argv)

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the widgets are Adwaita.
    def app = @app ||= Gtk::Application.new(APPLICATION_ID, :default_flags)

    def version = Graphs::Rb::VERSION

    def windows = @windows ||= []

    def open_new_window
      create_main_window.tap(&:present)
    end

    def create_main_window
      Window.new(application: self).tap do |window|
        window.build
        windows << window
      end
    end

    def quit_action = app.quit

    def show_about
      Adwaita::AboutDialog.new.tap do |dialog|
        dialog.application_name = "Graphs"
        dialog.application_icon = APPLICATION_ID
        dialog.developer_name = "The Graphs Developers"
        dialog.version = version
        dialog.website = HOMEPAGE_URL
        dialog.issue_url = ISSUE_URL
        dialog.developers = DEVELOPERS
        dialog.copyright = "© 2022 – 2025 The Graphs Developers"
        dialog.license_type = Gtk::License::GPL_3_0
        dialog.present(app.active_window)
      end
    end

    private

      def on_startup
        Adwaita.init
        load_stylesheet
        load_icons
        Actions.setup_global(self)
      end

      def on_activate
        if windows.empty?
          open_new_window
        else
          windows.first.present
        end
      end

      # The canvas colours come from the style, the rest of the chrome from
      # upstream's data/style.css.
      def load_stylesheet
        Gtk::CssProvider.new.tap do |provider|
          provider.load_from_path(STYLESHEET)
          Gtk::StyleContext.add_provider_for_display(
            Gdk::Display.default,
            provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end
      end

      # Graphs draws some of its buttons with icons of its own, which live
      # beside the app rather than in the system icon theme.
      def load_icons
        Gtk::IconTheme.get_for_display(Gdk::Display.default).tap do |theme|
          theme.add_search_path(File.join(DATA_DIR, "icons"))
        end
      end
  end
end
