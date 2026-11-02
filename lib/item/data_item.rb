# frozen_string_literal: true

require_relative "base"
require_relative "data_holder"

module Graphs
  # Ported from the DataItem class of upstream's graphs/item/data_item.vala: a
  # dataset of x/y values, optionally with error bars, drawn as a line, as
  # markers, or both.
  class DataItem < Item
    property :data, nil
    property :downsample, true
    property :errbarsabove, false
    property :errcapsize, 0.0
    property :errcapthick, 1.0
    property :errcolor, ""
    property :errlinewidth, 1.0
    property :legend, true
    property :linestyle, 1
    property :linewidth, 3.0
    property :markerstyle, 0
    property :markersize, 7.0
    property :showxerr, true
    property :showyerr, true

    def typename = "Dataset"
    def legendable? = true

    def initialize(data: nil)
      self.data = data || DataHolder.empty
    end

    def xdata = data.xdata
    def ydata = data.ydata
    def xerr = data.xerr
    def yerr = data.yerr

    def has_xerr? = !data.xerr.nil?
    def has_yerr? = !data.yerr.nil?

    # Datasets past this many points are drawn with fewer, so panning stays
    # responsive; the window tells the user when that happens.
    def exceeds_downsample_threshold? = xdata.length >= DOWNSAMPLE_THRESHOLD
  end
end
