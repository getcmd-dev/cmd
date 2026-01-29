# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles IO objects
    #
    # @api private
    class IO < DestinationBase
      # Writes data to the IO object
      #
      # @example
      #   io = File.open('file.txt', 'w')
      #   io_handler = ProcessExecuter::Destinations::IO.new(io)
      #   io_handler.write("Hello world")
      #
      # @param data [String] the data to write
      #
      # @return [Integer] the number of bytes written
      #
      # @raise [IOError] if the IO object is closed
      #
      def write(data)
        super
        destination.write data
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is an IO with a valid file descriptor
      def self.handles?(destination)
        destination.is_a?(::IO) && destination.respond_to?(:fileno) && destination.fileno
      end
    end
  end
end
