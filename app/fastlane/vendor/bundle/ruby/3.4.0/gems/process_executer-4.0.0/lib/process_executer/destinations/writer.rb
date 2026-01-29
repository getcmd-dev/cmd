# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles generic objects that respond to `#write`
    #
    # @api private
    class Writer < DestinationBase
      # Writes data to the destination object
      #
      # @example
      #   buffer = StringIO.new
      #   writer_handler = ProcessExecuter::Destinations::Writer.new(buffer)
      #   writer_handler.write("Hello world")
      #
      # @param data [String] the data to write
      #
      # @return [Integer] the number of bytes written
      #
      def write(data)
        super
        destination.write data
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      #
      # @return [Boolean] true if destination responds to #write and is not an IO object with a #fileno
      #
      def self.handles?(destination)
        destination.respond_to?(:write) && (!destination.respond_to?(:fileno) || destination.fileno.nil?)
      end
    end
  end
end
