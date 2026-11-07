# frozen_string_literal: true

require "adwaita"
require "fileutils"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/style_io.py.
  #
  # A style is a matplotlib style file: `key: value` lines, comments starting
  # at `#`, and Graphs' own parameters on `#~graphs ` prefixed lines. A name on
  # the second line as `# Name` is the legacy spelling and still accepted.
  #
  # Upstream validates each value against matplotlib's RcParams; without
  # matplotlib the values are kept as written and read by the canvas, which is
  # the only consumer.
  module StyleIO
    GRAPHS_PREFIX = "#~graphs "

    CUSTOM_PARAMS = %w[
      name
      ticklabels
      errorbar.capsize
      errorbar.capthick
      errorbar.linewidth
      errorbar.barsabove
      errorbar.color_cycle
    ].freeze

    module_function

    def parse(path)
      params = {}
      graphs_params = {}
      File.readlines(path).each_with_index do |raw, index|
        line = raw
        graphs_param = line.start_with?(GRAPHS_PREFIX)
        if graphs_param
          line = line[GRAPHS_PREFIX.length..]
        end
        if index == 1 && !graphs_params.key?("name") && line.start_with?("# ")
          graphs_params["name"] = line[2..].strip
        end
        key, value = split_line(strip_comment(line))
        unless key.nil?
          if graphs_param
            graphs_params[key] = value
          else
            params[key] = value
          end
        end
      end
      graphs_params["name"] ||= File.basename(path, ".mplstyle")
      [params, graphs_params]
    end

    def strip_comment(line)
      line.sub(/#.*\z/, "").strip
    end

    def split_line(line)
      if line.empty? || !line.include?(":")
        [nil, nil]
      else
        key, value = line.split(":", 2)
        [key.strip, value.strip.delete_prefix('"').delete_suffix('"')]
      end
    end

    def write(path, params, graphs_params)
      File.open(path, "w") do |file|
        file.puts("# SPDX-License-Identifier: GPL-3.0-or-later")
        graphs_params.each do |key, value|
          file.puts("#{GRAPHS_PREFIX}#{key}: #{value}")
        end
        params.each do |key, value|
          file.puts("#{key}: #{value}")
        end
      end
    end
  end

  # Ported from the StyleParameters class of upstream's graphs/styles.vala and
  # graphs/styles.py: the handful of values the rest of the app reads out of a
  # parsed style, with the full parameter hash kept for the canvas.
  class StyleParameters
    attr_reader :name, :params, :graphs_params

    def initialize(params, graphs_params)
      @params = params
      @graphs_params = graphs_params
      @name = graphs_params["name"]
    end

    def text_color = param("text.color", "000000")
    def background_color = param("axes.facecolor", "FFFFFF")
    def outline_color = param("figure.facecolor", "FFFFFF")
    def grid_color = param("grid.color", "9A9996")
    def tick_color = param("xtick.color", text_color)
    def ytick_color = param("ytick.color", tick_color)
    def label_color = param("axes.labelcolor", text_color)
    def font_size = param("font.size", "12").to_f
    def grid? = truthy?(param("axes.grid", "False"))
    def grid_alpha = param("grid.alpha", "1").to_f
    def grid_linewidth = param("grid.linewidth", "0.6").to_f
    def legend_frame? = truthy?(param("legend.frameon", "True"))

    def color_cycle = @color_cycle ||= parse_cycle(param("axes.prop_cycle", ""), ["1A5FB4"])

    def errorbar_cycle
      @errorbar_cycle ||= parse_cycle(graphs_param("errorbar.color_cycle", ""), ["000000"])
    end

    def errorbar_capsize = graphs_param("errorbar.capsize", "0").to_f
    def errorbar_capthick = graphs_param("errorbar.capthick", "1").to_f
    def errorbar_linewidth = graphs_param("errorbar.linewidth", "1").to_f
    def errorbar_barsabove? = truthy?(graphs_param("errorbar.barsabove", "False"))
    def ticklabels? = truthy?(graphs_param("ticklabels", "True"))

    def light? = Tools.get_luminance_from_hex(background_color) > 0.4

    def param(key, fallback) = @params.fetch(key, fallback)
    def graphs_param(key, fallback) = @graphs_params.fetch(key, fallback)

    private

      def truthy?(value) = %w[true 1 yes on].include?(value.to_s.downcase)

      # Colour cycles are written as matplotlib cyclers
      # (`cycler('color', ['1A5FB4', ...])`) in style parameters and as a bare
      # comma-separated list in the Graphs parameters.
      def parse_cycle(value, fallback)
        list = value[/\[([^\]]*)\]/, 1] || value
        colors = list.scan(/['"]([^'"]+)['"]/).flatten
        if colors.empty?
          colors = value.split(",").map(&:strip).reject(&:empty?)
        end
        if colors.empty?
          fallback
        else
          colors
        end
      end
  end

  # One entry of the style list: the system style has no file, the bundled
  # ones are read-only, and the user's own are mutable.
  class Style
    attr_reader :name, :file, :mutable
    attr_accessor :light

    def initialize(name:, file: nil, mutable: false, light: true)
      @name = name
      @file = file
      @mutable = mutable
      @light = light
    end

    def system? = @file.nil?
    def mutable? = @mutable
  end

  # Ported from the StyleManager class of upstream's graphs/styles.vala.
  #
  # Keeps the list of available styles: the system style, the styles bundled
  # with the app, and the user's own ones in the config directory.
  class StyleManager
    BUNDLED_DIR = File.expand_path("../data/styles", __dir__)

    def self.instance = @instance ||= new

    def initialize
      FileUtils.mkdir_p(style_dir)
      @styles = [Style.new(name: "System")] + bundled_styles + user_styles
    end

    attr_reader :styles

    def style_dir = File.join(Tools.config_directory, "styles")

    def names = @styles.map(&:name)

    def find(name) = @styles.find { |style| style.name == name }

    def params_for(style)
      if style.nil? || style.system?
        system_style_params
      else
        StyleParameters.new(*StyleIO.parse(style.file))
      end
    end

    def params_for_name(name) = params_for(find(name))

    # The names a template picker offers: every style except the system one,
    # in the same order `styles` holds them. The style editor's "Create
    # Style…" dialog starts a new style from one of these.
    def template_names = @styles.drop(1).map(&:name)

    # Duplicates the style at `index` (an index into `styles`, so 1 is the
    # first template) under a new name, writing it into the user's style
    # directory, and returns the Gio::File the style editor should load.
    def create_style(index, name)
      template = @styles.fetch(index)
      params, graphs_params = StyleIO.parse(template.file)
      graphs_params = graphs_params.merge("name" => name)
      file_name = "#{sanitize_filename(name)}.mplstyle"
      path = unique_path(File.join(style_dir, file_name))
      StyleIO.write(path, params.dup, graphs_params)
      reload_user_styles
      Gio::File.new_for_path(path)
    end

    # The system style follows the desktop's light/dark preference.
    def system_style_params
      if Adwaita::StyleManager.default.dark?
        bundled_params("adwaita-dark")
      else
        bundled_params("adwaita")
      end
    end

    def bundled_params(basename)
      StyleParameters.new(*StyleIO.parse(File.join(BUNDLED_DIR, "#{basename}.mplstyle")))
    end

    # Rereads the user's style directory, so a style saved by the style editor
    # shows up in the list.
    def reload_user_styles
      @styles = [Style.new(name: "System")] + bundled_styles + user_styles
    end

    private

      def bundled_styles
        style_files(BUNDLED_DIR).map do |path|
          style_for_file(path, mutable: false)
        end
      end

      def user_styles
        style_files(style_dir).map do |path|
          style_for_file(path, mutable: true)
        end
      end

      def style_files(directory)
        Dir.glob(File.join(directory, "*.mplstyle")).sort
      end

      def sanitize_filename(name)
        name.gsub(/[^\w.-]+/, "_").then { |sanitized| sanitized.empty? ? "style" : sanitized }
      end

      def unique_path(path)
        if File.exist?(path)
          base = File.basename(path, ".mplstyle")
          directory = File.dirname(path)
          number = 1
          candidate = File.join(directory, "#{base}_#{number}.mplstyle")
          while File.exist?(candidate)
            number += 1
            candidate = File.join(directory, "#{base}_#{number}.mplstyle")
          end
          candidate
        else
          path
        end
      end

      def style_for_file(path, mutable:)
        StyleParameters.new(*StyleIO.parse(path)).then do |parameters|
          Style.new(
            name:    parameters.name,
            file:    path,
            mutable: mutable,
            light:   parameters.light?,
          )
        end
      end
  end
end
