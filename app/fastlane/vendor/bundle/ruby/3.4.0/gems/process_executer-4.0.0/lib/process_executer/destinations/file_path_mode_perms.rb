# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles file paths with specific open modes and permissions
    #
    # @api private
    class FilePathModePerms < DestinationBase
      # Initializes a new file path with mode and permissions destination handler
      #
      # Opens the file at the given path with the specified mode and permissions.
      #
      # @param destination [Array<String, String, Integer>] array with file path, mode, and permissions
      #
      # @raise [Errno::ENOENT] if the file path is invalid
      #
      # @raise [ArgumentError] if the mode is invalid
      #
      def initialize(destination)
        super
        @file = File.open(destination[0], destination[1], destination[2])
      end

      # The opened file object
      #
      # @return [File] the opened file
      attr_reader :file

      # Writes data to the file
      #
      # @example
      #   perms_handler = ProcessExecuter::Destinations::FilePathModePerms.new(["output.log", "w", 0644])
      #   perms_handler.write("Log entry with specific permissions")
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
      # @return [Boolean] true if destination is an Array with path, mode, and permissions
      def self.handles?(destination)
        destination.is_a?(Array) &&
          destination.size == 3 &&
          destination[0].is_a?(String) &&
          destination[1].is_a?(String) &&
          destination[2].is_a?(Integer)
      end
    end
  end
end
