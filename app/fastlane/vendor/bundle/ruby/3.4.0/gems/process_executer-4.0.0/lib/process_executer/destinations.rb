# frozen_string_literal: true

require_relative 'destinations/child_redirection'
require_relative 'destinations/destination_base'
require_relative 'destinations/file_descriptor'
require_relative 'destinations/file_path'
require_relative 'destinations/file_path_mode'
require_relative 'destinations/file_path_mode_perms'
require_relative 'destinations/io'
require_relative 'destinations/monitored_pipe'
require_relative 'destinations/stderr'
require_relative 'destinations/stdout'
require_relative 'destinations/tee'
require_relative 'destinations/writer'

module ProcessExecuter
  # Collection of destination handler implementations
  #
  # @api private
  module Destinations
    # Creates appropriate destination objects based on the given destination
    #
    # This factory method dynamically finds and instantiates the appropriate
    # destination class for handling the provided destination.
    #
    # @example
    #   ProcessExecuter::Destinations.factory(1) #=> Returns a Stdout instance
    #   ProcessExecuter::Destinations.factory("output.log") #=> Returns a FilePath instance
    #
    # @param destination [Object] the destination to create a handler for
    #
    # @return [ProcessExecuter::Destinations::DestinationBase] an instance of the
    #   appropriate destination handler
    #
    # @raise [ProcessExecuter::ArgumentError] if no matching destination class is found
    #
    def self.factory(destination)
      matching_class = matching_destination_class(destination)
      return matching_class.new(destination) if matching_class

      raise ProcessExecuter::ArgumentError, "Destination #{destination.inspect} is not compatible with MonitoredPipe"
    end

    # Determines if the given destination type can be managed by a {MonitoredPipe}
    #
    # Returns true if {MonitoredPipe} can forward data to this destination type.
    #
    # Returns false otherwise (e.g., for destinations like :close or [:child, fd]
    # which have special meaning to Process.spawn and are not simply data sinks for
    # {MonitoredPipe}).
    #
    # @example
    #   ProcessExecuter::Destinations.compatible_with_monitored_pipe?(1)
    #     #=> true
    #   ProcessExecuter::Destinations.compatible_with_monitored_pipe?([:child, 6])
    #     #=> false
    #   ProcessExecuter::Destinations.compatible_with_monitored_pipe?(:close)
    #     #=> false
    #
    # @param destination [Object] the destination to check
    #
    # @return [Boolean] true if {MonitoredPipe} can forward data to this destination type
    #
    def self.compatible_with_monitored_pipe?(destination)
      matching_class = matching_destination_class(destination)
      matching_class&.compatible_with_monitored_pipe?
    end

    # Determines the destination class that can handle the given destination
    #
    # @param destination [Object] the destination to check
    #
    # @return [Class, nil] the handler class for the given destination or `nil` if no match
    #
    def self.matching_destination_class(destination)
      destination_classes =
        ProcessExecuter::Destinations.constants
                                     .map { |const| ProcessExecuter::Destinations.const_get(const) }
                                     .select { |const| const.is_a?(Class) }
                                     .reject { |klass| klass == ProcessExecuter::Destinations::DestinationBase }

      destination_classes.find { |klass| klass.handles?(destination) }
    end
  end
end
