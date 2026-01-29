# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles [:child, fd] redirection options as supported by `Process.spawn`
    #
    # @api private
    class ChildRedirection < DestinationBase
      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if the destination is an array in the format [:child, file_descriptor]
      def self.handles?(destination)
        destination.is_a?(Array) && destination.size == 2 && destination[0] == :child
      end

      # This class should not be wrapped in a monitored pipe
      # @return [Boolean]
      def self.compatible_with_monitored_pipe? = false
    end
  end
end
