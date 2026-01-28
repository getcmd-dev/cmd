# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles a destination for writing to multiple destinations
    #
    # The destination is an array with the first element being :tee and the rest
    # being the destinations.
    #
    # @api private
    class Tee < DestinationBase
      # Initializes a destination handler for writing to multiple output destinations
      #
      # @param destination [Array<Symbol, Object...>] array in the form [:tee, destination...]
      #
      # @raise [ArgumentError] if a child destination is invalid or incompatible
      #
      def initialize(destination)
        super
        @child_destinations = destination[1..].map { |dest| ProcessExecuter::Destinations.factory(dest) }
      end

      # An array of child destinations
      #
      # @return [Array<ProcessExecuter::Destinations::DestinationBase>]
      #   An array of the child destination handlers
      #
      attr_reader :child_destinations

      # Writes data each of the {child_destinations}
      #
      # @example
      #   tee = ProcessExecuter::Destinations::Tee.new([:tee, "output1.log", "output2.log"])
      #   tee.write("Log entry with specific permissions")
      #   tee.close # Important to close the tee to ensure all data is flushed
      #
      # @param data [String] the data to write
      #
      # @return [Integer] the number of bytes in the input data (which is written to each destination)
      #
      # @raise [IOError] if the file is closed
      #
      def write(data)
        super
        child_destinations.each { |dest| dest.write(data) }
        data.bytesize
      end

      # Closes the child_destinations
      #
      # @return [void]
      def close
        child_destinations.each(&:close)
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is an Array in the form [:tee, destination...]
      def self.handles?(destination)
        destination.is_a?(Array) && destination.size > 1 && destination[0] == :tee
      end
    end
  end
end
