# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles the :close redirection option as supported by `Process.spawn`
    #
    # @api private
    class Close < DestinationBase
      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if the destination is the symbol `:close`
      def self.handles?(destination)
        destination == :close
      end

      # This class should not be wrapped in a monitored pipe
      # @return [Boolean]
      def self.compatible_with_monitored_pipe? = false
    end
  end
end
