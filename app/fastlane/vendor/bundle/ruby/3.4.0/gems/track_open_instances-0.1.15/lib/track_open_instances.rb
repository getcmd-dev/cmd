# frozen_string_literal: true

require_relative 'track_open_instances/version'

# Mixin to track instances of a class that require explicit cleanup
#
# This module provides a mechanism to track instances of classes that need
# to be explicitly closed or cleaned up. It maintains a list of all instances
# created and allows checking for any unclosed instances, which can help in
# identifying resource leaks.
#
# @example Basic Usage
#   class ManagedFile
#     include TrackOpenInstances
#
#     attr_reader :path
#
#     def initialize(path)
#       @path = path
#       # Simulate opening the file
#       puts "Opening file: #{path}"
#       # Register the instance for tracking
#       self.class.add_open_instance(self)
#     end
#
#     # Implement the close logic specific to the resource
#     def close
#       # Simulate closing the file
#       puts "Closing file: #{path}"
#       # Remove the instance from tracking
#       self.class.remove_open_instance(self)
#     end
#   end
#
#   file1 = ManagedFile.new('/tmp/file1.txt')
#   file2 = ManagedFile.new('/tmp/file2.txt')
#
#   puts ManagedFile.open_instances.count #=> 2
#   puts ManagedFile.open_instances.keys.inspect #=> [#<ManagedFile:...>, #<ManagedFile:...>]
#
#   file1.close
#
#   puts ManagedFile.open_instances.count #=> 1
#   puts ManagedFile.open_instances.keys.inspect #=> [#<ManagedFile:...>]
#
#   # In a test suite's teardown, you might use:
#   # ManagedFile.assert_no_open_instances # This would raise if file2 wasn't closed
#
#   file2.close
#   ManagedFile.assert_no_open_instances # This will now pass
#
# @api public
module TrackOpenInstances
  # Represents an open instance of a class that includes TrackOpenInstances
  #
  # @attr_reader [Object] instance The tracked instance
  # @attr_reader [Array<String>] creation_stack The call stack at the time of instance creation
  #
  #  This is useful for debugging and identifying where the instance was created.
  #
  # @api private
  class OpenInstance
    attr_reader :instance, :creation_stack

    # Initializes a new OpenInstance
    #
    # @param instance [Object] The tracked instance
    # @param creation_stack [Array<Thread::Backtrace::Location>] The call stack at
    #   the time of instance creation
    #
    # @return [void]
    #
    # @api private
    #
    def initialize(instance, creation_stack)
      @instance = instance
      @creation_stack = creation_stack
    end
  end

  # Ruby hook executed when this module is included in a base class
  #
  # Sets up the necessary class instance variables and extends the base
  # class with ClassMethods.
  #
  # @param base [Class] The class including this module
  #
  # @return [void]
  #
  # @api private
  def self.included(base)
    base.extend(ClassMethods)
    # @!attribute [rw] open_instances
    #   Internal storage for all tracked instances
    #   @return [Hash{Object => OpenInstance}] The list of currently tracked instances
    base.instance_variable_set(:@open_instances, {}.compare_by_identity)
    # @!visibility private
    # @!attribute [r] open_instances_mutex
    #   Mutex to ensure thread-safe access to the open_instances hash
    base.instance_variable_set(:@open_instances_mutex, Thread::Mutex.new)
  end

  # Contains class-level methods added to classes including TrackOpenInstances
  module ClassMethods
    # @!attribute [r] open_instances
    #
    # Direct access to the internal list of tracked instances
    #
    # Note: This returns all instances ever tracked unless explicitly removed.
    # Use `open_instances` for checking leaks. Direct use is uncommon.
    #
    # @example
    #   # Assuming MyResource includes TrackOpenInstances
    #   res1 = MyResource.new
    #   res2 = MyResource.new
    #   res1.close
    #   MyResource.open_instances.keys #=> [#<MyResource... object_id=res2>] (after res1 removed)
    #
    # @return [Hash{Object => OpenInstance}] The raw list of currently tracked instances
    #
    # @api private
    def open_instances
      @open_instances_mutex.synchronize do
        @open_instances.dup.freeze
      end
    end

    # Adds an instance to the tracking list (thread-safe)
    #
    # Typically called automatically by the instance's `initialize` method.
    #
    # @param instance [Object] The instance to add
    #
    # @return [void]
    #
    # @api private
    def add_open_instance(instance)
      @open_instances_mutex.synchronize do
        @open_instances[instance] = OpenInstance.new(instance, caller_locations(3))
      end
    end

    # Removes an instance from the tracking list (thread-safe)
    #
    # Typically called automatically by the instance's `close` method.
    #
    # @param instance [Object] The instance to remove
    #
    # @return [void]
    #
    # @api private
    def remove_open_instance(instance)
      @open_instances_mutex.synchronize do
        @open_instances.delete(instance)
      end
    end

    # The number of currently open instances
    #
    # @example
    #   res1 = MyResource.new
    #   res2 = MyResource.new
    #   MyResource.open_instance_count #=> 2
    #
    # @return [Integer]
    #
    # @api public
    #
    def open_instance_count
      @open_instances_mutex.synchronize do
        @open_instances.size
      end
    end

    # Generates a report string listing unclosed instances and their creation stacks
    #
    # Useful for debugging resource leaks. Returns nil if no instances are unclosed.
    #
    # @example
    #   res = MyResource.new
    #   puts MyResource.open_instances_report
    #   There is 1 open MyResource instance(s):
    #   - object_id=701
    #     Created at:
    #       (caller stack line 1)
    #       (caller stack line 2)\n..."
    #
    # @return [String, nil] A formatted report string or nil if none are open
    #
    # @api public
    def open_instances_report
      @open_instances_mutex.synchronize do
        return nil if @open_instances.count.zero?

        String.new.tap do |report|
          report << open_instances_report_header
          report << open_instances_report_body
        end
      end
    end

    # The header string for the report
    #
    # @return [String]
    #
    # @api private
    #
    def open_instances_report_header
      count = @open_instances.count
      class_name = name || 'anonymous class'

      "There #{count == 1 ? 'is' : 'are'} #{count} " \
        "open #{class_name} instance#{count == 1 ? '' : 's'}:\n"
    end

    # The body of the report detailing each open instance
    #
    # @return [String]
    #
    # @api private
    #
    def open_instances_report_body
      String.new.tap do |body|
        @open_instances.each do |instance, open_instance|
          body << " - object_id=#{instance.object_id}\n"
          body << "   Call stack when created:\n"
          open_instance.creation_stack.each do |location|
            body << "     #{location.path}:#{location.lineno}:in `#{location.label}'\n"
          end
        end
      end
    end

    # Asserts that no instances of the class remain unclosed
    #
    # Commonly used in test suite teardown blocks to enure that all resources were
    # released.
    #
    # @example
    #   # In RSpec teardown (e.g., after(:each))
    #   MyResource.assert_no_open_instances
    #
    # @raise [RuntimeError] If any instances are found unclosed with a report of
    # unclosed instances
    #
    # @return [void]
    #
    # @api public
    def assert_no_open_instances
      report = open_instances_report
      raise(report.to_s) if report
    end
  end
end
