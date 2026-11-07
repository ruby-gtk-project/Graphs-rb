# frozen_string_literal: true

require "adwaita"
require_relative "curve_fitting"
require_relative "item/factory"
require_relative "math_parser"
require_relative "settings"
require_relative "utilities"

module Graphs
  # Ported from upstream's graphs/curve_fitting.vala, graphs/curve_fitting.py
  # and data/ui/curve-fitting.blp.
  #
  # Fits one of the preset equations, or a custom one, against a dataset's
  # points. Each free variable in the equation gets a row for its initial
  # guess and its lower/upper bound; running the fit shows the resulting
  # equation, R² and RMSE, and confirming adds the fitted curve — and its
  # confidence band — to the figure as two new items.
  class CurveFittingDialog
    EQUATION_ORDER = %w[linear quadratic exponential power logarithmic sigmoid gaussian].freeze

    EQUATION_LABELS = {
      "linear"      => "Linear",
      "quadratic"   => "Quadratic",
      "exponential" => "Exponential",
      "power"       => "Power",
      "logarithmic" => "Logarithmic",
      "sigmoid"     => "Sigmoid",
      "gaussian"    => "Gaussian",
      "custom"      => "Custom",
    }.freeze

    # How many standard deviations the confidence band spans, keyed the way
    # upstream's `curve-fitting.confidence` setting names them.
    CONFIDENCE_LEVELS = {"1std" => 1.0, "2std" => 2.0, "3std" => 3.0}.freeze

    def initialize(window:, item:, settings: Settings.default)
      @window = window
      @item = item
      @settings = settings.child("curve-fitting")
      @parameters = {}
      @free_vars = []
      @fit_result = nil
      @fitted_expression = nil
    end

    attr_reader :fit_result

    def build
      dialog.tap do |widget|
        widget.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = toast_overlay
        end

        header_bar.tap do |bar|
          bar.pack_start(cancel_button)
          bar.pack_end(confirm_button)

          cancel_button.signal_connect("clicked") { dialog.close }
          confirm_button.signal_connect("clicked") { on_accept }
        end

        toast_overlay.child = scrolled_window
        scrolled_window.child = clamp

        clamp.tap do |widget_clamp|
          widget_clamp.child = content_box

          content_box.tap do |box|
            box.append(equation_group)
            box.append(params_group)
            box.append(results_group)

            equation_group.tap do |group|
              group.add(equation_row)
              group.add(custom_equation_row)

              equation_row.tap do |row|
                row.model = Gtk::StringList.new(EQUATION_ORDER.map { |name| EQUATION_LABELS.fetch(name) } + ["Custom"])
                row.selected = EQUATION_ORDER.index(@settings["equation"]) || 0
                row.signal_connect("notify::selected") { on_equation_change }
              end

              custom_equation_row.tap do |row|
                row.text = @settings["custom-equation"]
                row.signal_connect("notify::text") { on_equation_change }
              end
            end

            params_group.tap do |group|
              group.add(params_box_row)
              params_box_row.child = params_box
            end

            results_group.tap do |group|
              group.add(confidence_row)
              group.add(fit_button_row)
              group.add(results_row)

              confidence_row.tap do |row|
                row.model = Gtk::StringList.new(["1 standard deviation", "2 standard deviations", "3 standard deviations"])
                row.selected = CONFIDENCE_LEVELS.keys.index(@settings["confidence"]) || 0
              end

              fit_button_row.child = fit_button
              fit_button.signal_connect("clicked") { on_fit }
            end
          end
        end

        on_equation_change
      end
    end

    def present
      build
      dialog.present(@window.window)
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |widget|
        widget.title = "Curve Fitting"
        widget.content_width = 480
        widget.content_height = 680
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
      end
    end

    def cancel_button = @cancel_button ||= Gtk::Button.new(label: "Cancel")

    def confirm_button
      @confirm_button ||= Gtk::Button.new(label: "Add Fit").tap do |button|
        button.add_css_class("suggested-action")
        button.sensitive = false
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scroll|
        scroll.propagate_natural_height = true
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

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 20)

    def equation_group
      @equation_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Equation"
        group.description = "Fitting #{@item.name}"
      end
    end

    def equation_row
      @equation_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = "Equation"
      end
    end

    def custom_equation_row
      @custom_equation_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = "Y ="
        row.max_width_chars = 25
        row.activates_default = true
      end
    end

    def params_group
      @params_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Fitting Parameters"
      end
    end

    def params_box_row
      @params_box_row ||= Adwaita::PreferencesRow.new.tap do |row|
        row.activatable = false
      end
    end

    def params_box = @params_box ||= Gtk::Box.new(:vertical, 6)

    def results_group
      @results_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Fit"
      end
    end

    def confidence_row
      @confidence_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = "Confidence Band"
      end
    end

    def fit_button_row
      @fit_button_row ||= Adwaita::PreferencesRow.new.tap do |row|
        row.activatable = false
      end
    end

    def fit_button = @fit_button ||= Gtk::Button.new(label: "Fit Curve")

    def results_row
      @results_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "No fit yet"
        row.subtitle = ""
      end
    end

    private

      def equation_name = EQUATION_ORDER[equation_row.selected] || "custom"

      def custom? = equation_row.selected >= EQUATION_ORDER.length

      def current_equation_text
        if custom?
          custom_equation_row.text
        else
          CurveFitting::EQUATIONS.fetch(equation_name)
        end
      end

      def equation_parses?(text)
        Graphs.expression_to_ast(text)
        true
      rescue MathError
        false
      end

      def on_equation_change
        custom_equation_row.visible = custom?
        confirm_button.sensitive = false
        @fit_result = nil
        rebuild_parameters
        results_row.title = "No fit yet"
        results_row.subtitle = ""
      end

      # Keeps a FittingParameter per free variable in the current equation,
      # reusing the ones the user already edited, and rebuilds the rows.
      def rebuild_parameters
        text = current_equation_text
        if equation_parses?(text)
          @free_vars = MathTools.get_free_variables(text)
        else
          @free_vars = []
        end
        @parameters = @free_vars.to_h do |name|
          [name, @parameters.fetch(name) { CurveFitting::FittingParameter.new(name) }]
        end

        while (child = params_box.last_child)
          params_box.remove(child)
        end
        @free_vars.each do |name|
          params_box.append(FittingParameterRow.new(@parameters.fetch(name)).build)
        end
      end

      def on_fit
        text = current_equation_text
        if @free_vars.empty? || !equation_parses?(text)
          show_error("Invalid equation: Check syntax and variables.")
        else
          run_fit(text)
        end
      end

      def run_fit(text)
        expression = Graphs.expression_to_ast(text)
        result = CurveFitting.fit(expression, @free_vars, @parameters, @item.xdata, @item.ydata)
        @fit_result = result
        @fitted_expression = expression
        show_results(result)
        confirm_button.sensitive = true
      rescue CurveFitting::FitError => error
        @fit_result = nil
        confirm_button.sensitive = false
        show_error(error.message)
      rescue MathError
        @fit_result = nil
        confirm_button.sensitive = false
        show_error("Invalid equation: Check syntax and variables.")
      end

      def show_results(result)
        fitted_text = Graphs.ast_to_expression(
          MathParser::Ast.new(CurveFitting.substitute(@fitted_expression.root, bindings_for(result))),
        )
        results_row.title = "Y = #{fitted_text}"
        results_row.subtitle = format("R² = %.5f    RMSE = %.5g", result.r2, result.rmse)
      end

      def bindings_for(result)
        @free_vars.each_index.to_h { |i| [@free_vars[i], result.parameters[i]] }
      end

      def show_error(message)
        toast_overlay.add_toast(Adwaita::Toast.new(message))
      end

      def on_accept
        unless @fit_result.nil?
          store_settings
          add_fit_items(@fit_result)
          @window.data.optimize_limits
          dialog.close
        end
      end

      def store_settings
        if custom?
          @settings["equation"] = "custom"
        else
          @settings["equation"] = equation_name
        end
        @settings["custom-equation"] = custom_equation_row.text
        @settings["confidence"] = CONFIDENCE_LEVELS.keys[confidence_row.selected] || "1std"
      end

      def add_fit_items(result)
        bindings = bindings_for(result)
        fitted_root = CurveFitting.substitute(@fitted_expression.root, bindings)
        fitted_ast = MathParser::Ast.new(fitted_root)

        ItemFactory.new_equation_item(@window.data.selected_style_params, fitted_ast).tap do |item|
          item.name = "Fit of #{@item.name}"
          @window.data.add_items([item])
          add_confidence_band(fitted_ast, result, item)
        end
      end

      def add_confidence_band(fitted_ast, result, fit_item)
        xdata = @item.xdata
        has_enough_points = !xdata.empty? && xdata.length >= 2
        if has_enough_points
          x_fit = MathTools.equidistant_data(xdata.min, xdata.max, :linear, 200)
          func = CurveFitting.build_function(fitted_ast, [])
          y_fit = x_fit.map { |x| func.call(x, []) }
          jacobian = jacobian_for(result, x_fit)
          z = CONFIDENCE_LEVELS.fetch(CONFIDENCE_LEVELS.keys[confidence_row.selected] || "1std")
          variances = jacobian.map { |row| CurveFitting.dot(row, CurveFitting.mat_vec(result.covariance, row)) }
          band = variances.map { |variance| z * Math.sqrt(variance.abs) }
          lower = y_fit.each_index.map { |i| y_fit[i] - band[i] }
          upper = y_fit.each_index.map { |i| y_fit[i] + band[i] }

          ItemFactory.new_fill_item(@window.data.selected_style_params, x_fit, lower, upper).tap do |item|
            item.name = "Confidence band of #{fit_item.name}"
            item.color = fit_item.color
            @window.data.add_items([item])
          end
        end
      end

      def jacobian_for(result, x_fit)
        func = CurveFitting.build_function(@fitted_expression, @free_vars)
        CurveFitting.numerical_jacobian(func, x_fit, result.parameters)
      end

    # One free variable's row: its name and the three entries for its
    # initial guess, lower bound and upper bound.
    class FittingParameterRow
      def initialize(parameter)
        @parameter = parameter
      end

      def build
        row.tap do |widget|
          widget.append(name_label)
          widget.append(initial_entry)
          widget.append(lower_entry)
          widget.append(upper_entry)

          name_label.tap do |label|
            label.label = @parameter.name
            label.width_chars = 3
          end

          initial_entry.tap do |entry|
            entry.text = format_number(@parameter.initial)
            entry.tooltip_text = "Initial value"
            entry.signal_connect("notify::text") { @parameter.initial = parsed(entry.text, @parameter.initial) }
          end

          lower_entry.tap do |entry|
            entry.text = format_number(@parameter.lower_bound)
            entry.tooltip_text = "Lower bound"
            entry.signal_connect("notify::text") { @parameter.lower_bound = parsed(entry.text, @parameter.lower_bound) }
          end

          upper_entry.tap do |entry|
            entry.text = format_number(@parameter.upper_bound)
            entry.tooltip_text = "Upper bound"
            entry.signal_connect("notify::text") { @parameter.upper_bound = parsed(entry.text, @parameter.upper_bound) }
          end
        end
      end

      def row = @row ||= Gtk::Box.new(:horizontal, 6)
      def name_label = @name_label ||= Gtk::Label.new
      def initial_entry = @initial_entry ||= Gtk::Entry.new.tap { |entry| entry.hexpand = true }
      def lower_entry = @lower_entry ||= Gtk::Entry.new.tap { |entry| entry.hexpand = true }
      def upper_entry = @upper_entry ||= Gtk::Entry.new.tap { |entry| entry.hexpand = true }

      private

        def parsed(text, fallback)
          ok, value = Graphs.try_evaluate_string(text)
          ok ? value : fallback
        end

        def format_number(value)
          if value.infinite? == 1
            "inf"
          elsif value.infinite? == -1
            "-inf"
          else
            format("%.6g", value)
          end
        end
    end
  end
end
