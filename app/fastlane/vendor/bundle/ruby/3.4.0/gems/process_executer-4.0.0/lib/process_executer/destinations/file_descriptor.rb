# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles numeric file descriptors
    #
    # @api private
    class FileDescriptor < DestinationBase
      # Writes data to the file descriptor
      #
      # @param data [String] the data to write
      #
      # @return [Integer] the number of bytes written
      #
      # @raise [SystemCallError] if the file descriptor is invalid
      #
      # @example
      #   fd_handler = ProcessExecuter::Destinations::FileDescriptor.new(3)
      #   fd_handler.write("Hello world")
      #
      def write(data)
        super
        io = ::IO.open(destination, mode: 'a', autoclose: false)
        io.write(data).tap { io.close }
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      #
      # @return [Boolean] true if destination is a file descriptor that's not stdout or stderr
      #
      def self.handles?(destination)
        destination.is_a?(Integer) && ![1, 2].include?(destination)
      end
    end
  end
end
