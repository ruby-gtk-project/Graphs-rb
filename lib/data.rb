# frozen_string_literal: true

require "json"
require_relative "enums"
require_relative "figure_settings"
require_relative "item/factory"
require_relative "properties"
require_relative "settings"
require_relative "styles"
require_relative "utilities"

module Graphs
  # Raised by `Data#load` when a project file cannot be read, is missing the
  # keys a project dict must have, or carries a version this port does not
  # know how to migrate. Ported from the `ProjectParseError` of upstream's
  # graphs/project.vala and graphs/project.py.
  class ProjectParseError < StandardError
  end

  # Ported from upstream's graphs/data.vala together with its Python half,
  # graphs/data.py.
  #
  # Owns the items, the figure settings and the two histories: the undo
  # history of changes, recorded as batches of before/after values, and the
  # view history of axis limits.
  #
  # Upstream's Data is also a Gtk.SelectionModel, because the sidebar's item
  # list is built from it; this port's window builds the rows itself, so the
  # selection lives on the items and the list is rebuilt from the
  # `items-changed` signal.
  class Data
    include Properties
    include Signals
    include Enumerable

    HISTORY_SIZE = 100

    # Ported from upstream's graphs/project.py.
    CURRENT_PROJECT_VERSION = 2
    PROJECT_KEYS = %w[
      version data figure-settings history-states history-position
      view-history-states view-history-position
    ].freeze

    # Limits move on every pan and zoom; the view history records them, so the
    # undo history ignores them.
    FIGURE_SETTINGS_HISTORY_IGNORELIST = (
      FigureSettings::LIMIT_NAMES + ["min-selected", "max-selected"]
    ).map { |name| Properties.normalize(name) }.freeze

    property :can_undo, false
    property :can_redo, false
    property :can_view_back, false
    property :can_view_forward, false
    property :unsaved, false
    property :file, nil

    attr_reader :figure_settings, :selected_style_params

    def initialize(settings: Settings.default)
      @settings = settings.child("figure")
      @items = []
      @item_handlers = {}
      @notify_selection_changed = true
      @used_colors = []
      @used_errbar_colors = []
      @style_manager = StyleManager.instance
      install_figure_settings(FigureSettings.from_settings(@settings))
      init_view_history
      init_history_states
    end

    # Section items

    def get_item(position) = @items[position]
    def n_items = @items.length
    def last = @items.last
    def each(&block) = @items.each(&block)
    def items = @items.dup
    def empty? = @items.empty?
    def names = @items.map(&:name)
    def index(item) = @items.index(item)

    # Section selection

    def selected?(position) = @items[position].selected

    def select_all
      without_selection_notifications { @items.each { |item| item.selected = true } }
      emit_signal(:selection_changed)
    end

    def unselect_all
      without_selection_notifications { clear_selection }
      emit_signal(:selection_changed)
    end

    def select_item(position, unselect_rest)
      without_selection_notifications do
        if unselect_rest
          clear_selection
        end
        @items[position].selected = true
      end
      emit_signal(:selection_changed)
    end

    def unselect_item(position)
      @items[position].selected = false
    end

    # Applies the selection the undo history recorded: `mask` lists the
    # positions the batch touched, `selected` those of them that were on.
    def set_selection(selected, mask)
      unless mask.empty?
        without_selection_notifications do
          mask.each { |position| @items[position].selected = selected.include?(position) }
        end
        emit_signal(:selection_changed)
      end
    end

    # Section management

    def clear
      disconnect_from_all_items
      @items = []
      self.can_undo = false
      self.can_redo = false
      self.can_view_back = false
      self.can_view_forward = false
      install_figure_settings(FigureSettings.from_settings(@settings))
      init_view_history
      init_history_states
      self.file = nil
      self.unsaved = false
      emit_signal(:items_changed)
    end

    # Adds items, giving each a free name and colour from the style's cycle,
    # and moving an item whose axis label clashes to the opposite axis.
    def add_items(new_items)
      collect_used_colors
      used_names = names
      new_items.each do |item|
        item.name = Tools.get_duplicate_string(item.name, used_names)
        used_names << item.name
        assign_color(item)
        assign_errbar_color(item)
        place_on_x_axis(item)
        place_on_y_axis(item)
        connect_to_item(item)
        @items << item
        record(:item_added, to_dict(item))
      end
      update_used_positions
      emit_signal(:items_changed)
      optimize_limits
      add_history_state
    end

    def set_items(items)
      disconnect_from_all_items
      @items = items
      @items.each { |item| connect_to_item(item) }
      update_used_positions
      emit_signal(:items_changed)
    end

    # Deletes items and everything that depends on them, restoring the axis
    # labels the deleted items had set.
    def delete_items(items)
      to_remove = []
      queue = items.dup
      until queue.empty?
        item = queue.shift
        unless to_remove.include?(item)
          to_remove << item
          queue.concat(item.get_dependents)
        end
      end

      to_remove.each do |item|
        position = @items.index(item)
        unless position.nil?
          record(:item_removed, [position, to_dict(item)])
          remove_item(position)
          restore_axis_label(item, :x)
          restore_axis_label(item, :y)
        end
      end
      update_used_positions
      emit_signal(:items_changed)
      add_history_state
    end

    def change_position(index1, index2)
      unless index1 == index2
        @items.insert(index2, @items.delete_at(index1))
        record(:items_swapped, [index2, index1])
        emit_signal(:items_changed)
      end
    end

    # Section style

    def selected_stylename
      if figure_settings.use_custom_style
        figure_settings.custom_style
      else
        "System"
      end
    end

    def selected_style
      if figure_settings.use_custom_style
        @style_manager.find(figure_settings.custom_style)
      end
    end

    # Selects a style by name; the system style is the one named "System".
    def select_style(name)
      if name == "System"
        figure_settings.use_custom_style = false
      else
        figure_settings.custom_style = name
        figure_settings.use_custom_style = true
      end
    end

    def handle_style_change
      update_selected_style
      reset_items
      emit_signal(:style_changed)
    end

    # Section limits

    def used_positions = @used_positions

    # Fits the axis limits around the data, with a little padding, and records
    # the result in the view history.
    def optimize_limits
      axes = %w[bottom left top right].map { |direction| AxisInfo.new(figure_settings, direction) }
      equation_items = []

      each do |item|
        if figure_settings.hide_unselected && !item.selected
          next
        end

        if item.is_a?(EquationItem)
          equation_items << item
        elsif item.is_a?(DataItem)
          axes[XPosition.value(item.xposition) * 2].update_min_max(item.xdata)
          axes[(YPosition.value(item.yposition) * 2) + 1].update_min_max(item.ydata)
        end
      end

      equation_items.each do |item|
        x_axis = axes[XPosition.value(item.xposition) * 2]
        y_axis = axes[(YPosition.value(item.yposition) * 2) + 1]
        # The x axis keeps the limits it already has when no dataset sets them,
        # and the equation is sampled across those, as upstream does.
        ydata = item.get_program.eval(x_axis.xdata)
        # An equation with a pole inside the range would stretch the limits to
        # the pole; upstream detects those symbolically with sympy, here they
        # show up as non-finite values among the samples.
        if MathTools.finite?(ydata)
          y_axis.update_min_max(ydata)
        end
      end

      axes.each_with_index { |axis, position| apply_padded_limits(axis, position) }
      add_view_history_state
    end

    # Section undo history

    # Records the current batch of changes as one undo step. Nothing to record
    # means nothing to undo, which is what upstream's return value says.
    def add_history_state
      collapse_current_batch
      if @current_batch.empty?
        false
      else
        unless @history_pos == -1
          @history_states = @history_states[0..@history_pos]
        end
        @history_pos = -1
        @history_states << [@current_batch, figure_settings.limits]
        if @history_states.length > HISTORY_SIZE + 1
          @history_states = @history_states[1..]
        end
        set_data_copy
        self.can_undo = true
        self.can_redo = false
        self.unsaved = true
        true
      end
    end

    def undo
      if can_undo
        batch = @history_states[@history_pos][0]
        @history_pos -= 1
        apply_batch(batch.reverse, :undo)
        figure_settings.set_limits(@history_states[@history_pos][1])
        self.can_redo = true
        self.can_undo = @history_pos.abs < @history_states.length
        set_data_copy
        emit_signal(:items_changed)
        add_view_history_state
      end
    end

    def redo
      if can_redo
        @history_pos += 1
        state = @history_states[@history_pos]
        apply_batch(state[0], :redo)
        figure_settings.set_limits(state[1])
        self.can_redo = @history_pos < -1
        self.can_undo = true
        set_data_copy
        emit_signal(:items_changed)
        add_view_history_state
      end
    end

    # Section view history

    def add_view_history_state
      limits = figure_settings.limits
      unless MathTools.all_close?(limits, @view_history_states[@current_view_state])
        @current_view_state = (@current_view_state + 1) % HISTORY_SIZE
        @view_history_states[@current_view_state] = limits
        @newest_view_state = @current_view_state
        if @current_view_state == @oldest_view_state
          @oldest_view_state = (@oldest_view_state + 1) % HISTORY_SIZE
        end
        self.can_view_back = true
        self.can_view_forward = false
        self.unsaved = true
      end
    end

    def view_back
      if can_view_back
        @current_view_state = (@current_view_state - 1 + HISTORY_SIZE) % HISTORY_SIZE
        figure_settings.set_limits(@view_history_states[@current_view_state])
        self.can_view_back = @current_view_state != @oldest_view_state
        self.can_view_forward = true
      end
    end

    def view_forward
      if can_view_forward
        @current_view_state = (@current_view_state + 1) % HISTORY_SIZE
        figure_settings.set_limits(@view_history_states[@current_view_state])
        self.can_view_back = true
        self.can_view_forward = @current_view_state != @newest_view_state
      end
    end

    # Section project files
    #
    # Ported from the current-version half of upstream's graphs/project.py
    # (`read_project_file`, `save_project_dict`); the version-to-version
    # migrations `ProjectMigrator` performs and the pre-JSON legacy migration
    # `migrate.py` does are not covered — a project from an older version
    # raises rather than silently loading wrong data.

    # The project dict as upstream's project files store it: the items, the
    # figure settings, and both histories, in the shape `load` can read back.
    def to_project_dict
      view_states, view_position = view_history_payload
      {
        "version"               => CURRENT_PROJECT_VERSION,
        "data"                  => @items.map { |item| to_dict(item) },
        "figure-settings"       => figure_settings.to_h.transform_keys { |key| key.to_s.tr("_", "-") },
        "history-states"        => @history_states.map { |batch, limits| [serialize_batch(batch), limits] },
        "history-position"      => @history_pos,
        "view-history-states"   => view_states,
        "view-history-position" => view_position,
      }
    end

    def save(file)
      File.write(Tools.file_path(file), JSON.generate(to_project_dict))
      self.file = file
      self.unsaved = false
    end

    def load(file)
      begin
        project_dict = JSON.parse(File.read(Tools.file_path(file)))
      rescue JSON::ParserError, SystemCallError
        raise ProjectParseError, "Failed to parse project file"
      end
      PROJECT_KEYS.each do |key|
        unless project_dict.key?(key)
          raise ProjectParseError, "Project file is missing data"
        end
      end
      version = project_dict["version"].to_i
      if version > CURRENT_PROJECT_VERSION
        raise ProjectParseError, "Project is from a newer incompatible version of Graphs"
      elsif version < CURRENT_PROJECT_VERSION
        raise ProjectParseError,
          "Project is from an older version of Graphs that this port cannot migrate yet"
      end
      load_project_dict(project_dict)
      self.file = file
      self.unsaved = false
    end

    private

      # Section figure settings

      def install_figure_settings(new_settings)
        @figure_settings = new_settings
        new_settings.connect_notify do |_, property|
          on_figure_settings_changed(property)
        end
        update_used_positions
        update_selected_style
      end

      def on_figure_settings_changed(property)
        unless FIGURE_SETTINGS_HISTORY_IGNORELIST.include?(property)
          record(
            :figure_settings_changed,
            [property, @figure_settings_copy[property], figure_settings[property]],
          )
        end
        if property == :custom_style || property == :use_custom_style
          handle_style_change
        end
        emit_signal(:figure_settings_changed, property)
      end

      # Section style

      def update_selected_style
        @old_selected_style_params = @selected_style_params
        if figure_settings.use_custom_style
          @selected_style_params = custom_style_params
        else
          @selected_style_params = @style_manager.system_style_params
        end
      end

      # A style that has gone missing falls back to the system style, as
      # upstream's warning path does.
      def custom_style_params
        style = @style_manager.find(figure_settings.custom_style)
        if style.nil?
          warn("Could not find style #{figure_settings.custom_style}, defaulting to system style")
          figure_settings.use_custom_style = false
          @style_manager.system_style_params
        else
          @style_manager.params_for(style)
        end
      end

      # Items still wearing the previous style's colours follow the new one.
      def reset_items
        unless @old_selected_style_params.nil?
          old_cycle = @old_selected_style_params.color_cycle
          new_cycle = @selected_style_params.color_cycle
          old_err_cycle = @old_selected_style_params.errorbar_cycle
          new_err_cycle = @selected_style_params.errorbar_cycle
          count = 0
          errbar_count = 0

          each do |item|
            ItemFactory.reset_item(item, @old_selected_style_params, @selected_style_params)
            unless item.is_a?(DataItem) || item.is_a?(EquationItem)
              next
            end
            unless old_cycle.include?(item.color)
              next
            end

            item.color = new_cycle[count % new_cycle.length]
            count += 1

            unless item.is_a?(DataItem)
              next
            end
            unless item.has_xerr? || item.has_yerr?
              next
            end
            unless old_err_cycle.include?(item.errcolor)
              next
            end

            item.errcolor = new_err_cycle[errbar_count % new_err_cycle.length]
            errbar_count += 1
          end
        end
      end

      # Section items

      def clear_selection
        @items.each { |item| item.selected = false }
      end

      def without_selection_notifications
        @notify_selection_changed = false
        yield
        @notify_selection_changed = true
      end

      def connect_to_item(item)
        @item_handlers[item] = item.connect_notify do |changed, property|
          on_item_change(changed, property)
        end
      end

      def disconnect_from_item(item)
        @item_handlers.delete(item).then do |handler|
          unless handler.nil?
            item.disconnect_notify(handler)
          end
        end
      end

      def disconnect_from_all_items
        @items.each { |item| disconnect_from_item(item) }
      end

      def remove_item(position)
        disconnect_from_item(@items[position])
        if @items[position].respond_to?(:detach)
          @items[position].detach
        end
        @items.delete_at(position)
      end

      def on_item_change(item, property)
        case property
        when :visible then nil
        when :selected then on_item_selected(item)
        when :xposition, :yposition then on_item_position_change(item, property)
        else record_item_change(item, property)
        end
      end

      def on_item_selected(item)
        record_item_change(item, :selected)
        if @notify_selection_changed
          emit_signal(:selection_changed)
        end
        if figure_settings.hide_unselected
          item.visible = item.selected
        end
      end

      def on_item_position_change(item, property)
        record_item_change(item, property)
        optimize_limits
        update_used_positions
        emit_signal(:items_changed)
      end

      # Which of the four axes are in use; an empty figure shows the bottom
      # and left ones.
      def update_used_positions
        if @items.empty?
          @used_positions = [true, false, true, false]
        else
          used = [false, false, false, false]
          each do |item|
            if figure_settings.hide_unselected && !item.selected
              next
            end

            used[XPosition.value(item.xposition)] = true
            used[YPosition.value(item.yposition) + 2] = true
          end
          @used_positions = used
        end
      end

      # Section colours

      def collect_used_colors
        @used_colors = []
        @used_errbar_colors = []
        each do |item|
          append_used_color(item.color)
          if item.is_a?(DataItem)
            append_used_errbar_color(item.errcolor)
          end
        end
      end

      # A full cycle starts over, so a tenth item gets the first colour again.
      def append_used_color(color)
        cycle = @selected_style_params.color_cycle
        if cycle.include?(color) && !@used_colors.include?(color)
          @used_colors << color
          if @used_colors.length == cycle.length
            @used_colors = []
          end
        end
      end

      def append_used_errbar_color(color)
        cycle = @selected_style_params.errorbar_cycle
        if cycle.include?(color) && !@used_errbar_colors.include?(color)
          @used_errbar_colors << color
          if @used_errbar_colors.length == cycle.length
            @used_errbar_colors = []
          end
        end
      end

      def assign_color(item)
        if item.color.empty?
          @selected_style_params.color_cycle.find { |color| !@used_colors.include?(color) }
            .then do |color|
              unless color.nil?
                append_used_color(color)
                item.color = color
              end
            end
        end
      end

      def assign_errbar_color(item)
        if item.is_a?(DataItem) && item.errcolor.empty?
          @selected_style_params.errorbar_cycle
            .find { |color| !@used_errbar_colors.include?(color) }
            .then do |color|
              unless color.nil?
                append_used_errbar_color(color)
                item.errcolor = color
              end
            end
        end
      end

      # Section axis labels

      def default_label?(property)
        figure_settings[property] == @settings[property.to_s.tr("_", "-")]
      end

      # The first item names the bottom axis; a later item with a different
      # label moves to the top axis, and back again if that one is taken too.
      def place_on_x_axis(item)
        unless item.xlabel.empty?
          original = item.xposition
          if original == :bottom
            if default_label?(:bottom_label) || empty?
              figure_settings.bottom_label = item.xlabel
            elsif item.xlabel != figure_settings.bottom_label
              item.xposition = :top
            end
          end
          if item.xposition == :top
            if default_label?(:top_label)
              figure_settings.top_label = item.xlabel
            elsif item.xlabel != figure_settings.top_label
              item.xposition = original
            end
          end
        end
      end

      def place_on_y_axis(item)
        unless item.ylabel.empty?
          original = item.yposition
          if original == :left
            if default_label?(:left_label) || empty?
              figure_settings.left_label = item.ylabel
            elsif item.ylabel != figure_settings.left_label
              item.yposition = :right
            end
          end
          if item.yposition == :right
            if default_label?(:right_label)
              figure_settings.right_label = item.ylabel
            elsif item.ylabel != figure_settings.right_label
              item.yposition = original
            end
          end
        end
      end

      # A deleted item's label goes back to the default, as long as the axis
      # is still in use and still carries that item's label.
      def restore_axis_label(item, direction)
        if direction == :x
          position = item.xposition
          used = @used_positions[XPosition.value(position)]
          label = item.xlabel
        else
          position = item.yposition
          used = @used_positions[YPosition.value(position) + 2]
          label = item.ylabel
        end
        property = Properties.normalize("#{position}-label")
        if used && label == figure_settings[property]
          figure_settings[property] = @settings["#{position}-label"]
        end
      end

      # Section limits

      def apply_padded_limits(axis, position)
        if axis.used
          # 0.05 padding on the y axes, 0.015 on the x axes.
          if position.even?
            padding = 0.05
          else
            padding = 0.015
          end
          minimum, maximum = axis.padded(padding)
          figure_settings["min-#{axis.direction}"] = minimum
          figure_settings["max-#{axis.direction}"] = maximum
        end
      end

      def init_view_history
        @view_history_states = Array.new(HISTORY_SIZE)
        @view_history_states[0] = figure_settings.limits
        @current_view_state = 0
        @oldest_view_state = 0
        @newest_view_state = 0
      end

      # Section undo history

      def init_history_states
        @history_states = [[[], figure_settings.limits]]
        @history_pos = -1
        set_data_copy
      end

      # The values every recorded change is compared against.
      def set_data_copy
        @current_batch = []
        @data_copy = @items.map { |item| to_dict(item) }
        @figure_settings_copy = figure_settings.to_h
      end

      # Section project files

      def serialize_batch(batch)
        batch.map { |change_type, change| [change_type.to_s, change] }
      end

      def deserialize_batch(batch)
        batch.map { |change_type, change| [change_type.to_sym, change] }
      end

      # The view history's circular buffer, walked from the oldest state to
      # the newest and written out as a plain array, together with the
      # current state's negative offset from the end of that array — the
      # shape upstream's own, non-circular view history stores on disk.
      def view_history_payload
        states = []
        current_index = nil
        index = @oldest_view_state
        loop do
          states << @view_history_states[index]
          if index == @current_view_state
            current_index = states.length - 1
          end
          if index == @newest_view_state
            break
          end
          index = (index + 1) % HISTORY_SIZE
        end
        [states, current_index - states.length]
      end

      def restore_view_history(states, position)
        @view_history_states = Array.new(HISTORY_SIZE)
        states.each_with_index { |limits, i| @view_history_states[i] = limits }
        @oldest_view_state = 0
        @newest_view_state = states.length - 1
        @current_view_state = states.length + position
        figure_settings.set_limits(@view_history_states[@current_view_state])
        self.can_view_back = @current_view_state != @oldest_view_state
        self.can_view_forward = @current_view_state != @newest_view_state
      end

      def load_project_dict(dict)
        disconnect_from_all_items
        items = dict.fetch("data").map { |item_dict| ItemFactory.new_from_dict(item_dict) }
        items.each_with_index do |item, index|
          ItemFactory.resolve_dependencies(item, dict["data"][index], items)
        end
        @items = items
        @items.each { |item| connect_to_item(item) }

        install_figure_settings(
          FigureSettings.new.tap do |settings|
            dict.fetch("figure-settings").each do |key, value|
              settings[key] = FigureSettings.coerce(key, value)
            end
          end,
        )

        @history_states = dict.fetch("history-states").map do |batch, limits|
          [deserialize_batch(batch), limits]
        end
        @history_pos = dict.fetch("history-position")
        restore_view_history(dict.fetch("view-history-states"), dict.fetch("view-history-position"))

        update_used_positions
        emit_signal(:items_changed)
        set_data_copy
        self.can_redo = @history_pos < -1
        self.can_undo = @history_states[0..@history_pos].any? { |batch, _| !batch.empty? }
      end

      # An item that depends on another stores that dependency as a position,
      # which `ItemFactory.link_dependencies` puts in.
      def to_dict(item)
        ItemFactory.link_dependencies(
          item,
          ItemFactory.to_dict(item),
          @items,
        )
      end

      def record(change_type, change)
        @current_batch << [change_type, change]
      end

      def record_item_change(item, property)
        position = @items.index(item)
        unless position.nil? || @data_copy[position].nil?
          record(
            :item_property_changed,
            [
              position,
              property,
              @data_copy[position][property],
              ItemFactory.serialize_property(item, property),
            ],
          )
        end
      end

      # Repeated changes to one property collapse into a single change, and a
      # change that ends where it started is dropped. A structural change
      # (items added, removed or swapped) stops the collapsing.
      def collapse_current_batch
        unless @current_batch.empty?
          collapsed = {}
          structural = false
          @current_batch.each do |change_type, change|
            case change_type
            when :item_property_changed
              collapse_property_change(
                collapsed,
                change_type,
                change,
                change[0..1],
              )
            when :figure_settings_changed
              collapse_property_change(
                collapsed,
                change_type,
                change,
                change[0..0],
              )
            else structural = true
            end
          end
          unless structural
            @current_batch = collapsed.values
          end
        end
      end

      def collapse_property_change(collapsed, change_type, change, identity)
        key = [change_type, identity]
        new_value = change.last
        if collapsed.key?(key)
          first_old = collapsed[key][1][-2]
          if first_old == new_value
            collapsed.delete(key)
          else
            collapsed[key] = [change_type, change[0..-3] + [first_old, new_value]]
          end
        else
          collapsed[key] = [change_type, change]
        end
      end

      # Section undo and redo

      def apply_batch(batch, direction)
        selected = []
        mask = []
        batch.each do |change_type, change|
          apply_change(
            change_type,
            change,
            direction,
            selected,
            mask,
          )
        end
        set_selection(selected, mask)
      end

      def apply_change(change_type, change, direction, selected, mask)
        case change_type
        when :item_property_changed
          apply_property_change(
            change,
            direction,
            selected,
            mask,
          )
        when :item_added then apply_item_added(change, direction)
        when :item_removed then apply_item_removed(change, direction)
        when :items_swapped then apply_swap(change, direction)
        when :figure_settings_changed then apply_figure_settings_change(change, direction)
        end
      end

      def apply_property_change(change, direction, selected, mask)
        position, property = change
        if direction == :undo
          value = change[2]
        else
          value = change[3]
        end
        if property == :selected
          mask << position
          if value
            selected << position
          end
        else
          ItemFactory.deserialize_property(@items[position], property, value)
        end
      end

      def apply_item_added(change, direction)
        if direction == :undo
          remove_item(@items.length - 1)
        else
          insert_item(item_from_dict(change, @items.length), @items.length)
        end
      end

      def apply_item_removed(change, direction)
        position, dictionary = change
        if direction == :undo
          insert_item(item_from_dict(dictionary, position), position)
        else
          remove_item(position)
        end
      end

      # The item as it was, with its dependencies resolved against the list it
      # is about to be part of.
      def item_from_dict(dictionary, position)
        ItemFactory.new_from_dict(dictionary).tap do |item|
          ItemFactory.resolve_dependencies(
            item,
            dictionary,
            @items.dup.insert(position, item),
          )
        end
      end

      def apply_swap(change, direction)
        if direction == :undo
          change_position(change[0], change[1])
        else
          change_position(change[1], change[0])
        end
      end

      def apply_figure_settings_change(change, direction)
        property = change[0]
        if direction == :undo
          figure_settings[property] = change[1]
        else
          figure_settings[property] = change[2]
        end
      end

      def insert_item(item, position)
        connect_to_item(item)
        @items.insert(position, item)
      end

    # The limits of one axis while they are being fitted around the data, plus
    # the x values an equation item is sampled at. Ported from the AxisInfo
    # class inside upstream's Data.optimize_limits.
      class AxisInfo
        attr_reader :direction, :used, :scale, :min_value, :max_value

        def initialize(figure_settings, direction)
          @direction = direction
          @used = false
          @min_value = figure_settings["min-#{direction}"]
          @max_value = figure_settings["max-#{direction}"]
          @scale = figure_settings["#{direction}-scale"]
        end

        def update_min_max(data)
          MathTools.array_minmax(data, Scale.nonzero?(@scale)).then do |range|
            unless range.nil?
              if @used
                @min_value = [@min_value, range[0]].min
                @max_value = [@max_value, range[1]].max
              else
                @min_value = range[0]
                @max_value = range[1]
                @used = true
              end
            end
          end
        end

        def xdata
          @xdata ||= MathTools.equidistant_data(
            @min_value,
            @max_value,
            @scale,
            5000,
          )
        end

        # The limits with padding added — logarithmically for a logarithmic
        # axis, and only at the top for an inverse one, which cannot be pushed
        # towards zero.
        def padded(factor)
          if Scale.logarithmic?(@scale)
            logarithmic_padding(factor)
          else
            linear_padding(factor)
          end
        end

        private

          def logarithmic_padding(factor)
            log_min = log10_or_zero(@min_value)
            log_max = log10_or_zero(@max_value)
            span = log_max - log_min
            [10**(log_min - (factor * span)), 10**(log_max + (factor * span))]
          end

          def log10_or_zero(value)
            if value.positive?
              Math.log10(value)
            else
              0.0
            end
          end

          def linear_padding(factor)
            span = @max_value - @min_value
            maximum = @max_value + (factor * span)
            if @scale == :inverse
              minimum = @min_value * 0.99
            else
              minimum = @min_value - (factor * span)
            end
            [minimum, maximum]
          end
      end
  end
end
