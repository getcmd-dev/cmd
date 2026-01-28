# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles standard output redirection
    #
    # @api private
    class Stdout < DestinationBase
      # Writes data to standard output
      #
      # @example
      #   stdout_handler = ProcessExecuter::Destinations::Stdout.new(:out)
      #   stdout_handler.write("Hello world")
      #
      # @param data [String] the data to write
      #
      # @return [Integer] the number of bytes written
      #
      def write(data)
        super
        $stdout.write data
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is :out or 1
      def self.handles?(destination)
        [:out, 1].include?(destination)
      end
    end
  end
end
