# frozen_string_literal: true

module Graphs
  # Ported from the DataHolder class in upstream's graphs/item/data_item.vala.
  #
  # Holds the four arrays of a dataset. Upstream keeps them as unowned double
  # arrays so the C canvas can read them without copying; here they are plain
  # Ruby arrays of floats, and the error arrays stay nil when absent.
  class DataHolder
    attr_reader :xdata, :ydata, :xerr, :yerr

    def self.empty = new([], [])

    def initialize(xdata, ydata, xerr = nil, yerr = nil)
      @xdata = xdata
      @ydata = ydata
      @xerr = xerr
      @yerr = yerr
    end

    def length = [@xdata.length, @ydata.length].min
    def empty? = length.zero?
  end
end
