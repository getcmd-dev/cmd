# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles file paths with specific open modes
    #
    # @api private
    class FilePathMode < DestinationBase
      # Initializes a new file path with mode destination handler
      #
      # Redirects to the file at destination via `open(destination[0], destination[1], 0644)`
      #
      # @param destination [Array<String, String>] array with file path and mode
      # @raise [Errno::ENOENT] if the file path is invalid
      # @raise [ArgumentError] if the mode is invalid
      def initialize(destination)
        super
        @file = File.open(destination[0], destination[1], 0o644)
      end

      # The opened file object
      #
      # @return [File] the opened file
      attr_reader :file

      # Writes data to the file
      #
      # @example
      #   mode_handler = ProcessExecuter::Destinations::FilePathMode.new(["output.log", "a"])
      #   mode_handler.write("Appended log entry")
      #
      # @param data [String] the data to write
      #
      # @return [Integer] the number of bytes written
      #
      # @raise [IOError] if the file is closed
      #
      def write(data)
        super
        file.write data
      end

      # Closes the file if it's open
      #
      # @return [void]
      def close
        file.close unless file.closed?
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is an Array with path and mode
      def self.handles?(destination)
        destination.is_a?(Array) &&
          destination.size == 2 &&
          destination[0].is_a?(String) &&
          destination[1].is_a?(String)
      end
    end
  end
end
