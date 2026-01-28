# frozen_string_literal: true

require_relative 'option_definition'

module ProcessExecuter
  module Options
    # Defines, validates, and holds a set of option values
    #
    # Options are defined by subclasses by overriding the `define_options` method.
    #
    # @example Define an options class with two options
    #   class MyOptions < ProcessExecuter::Options::Base
    #     def define_options
    #       # Call super to include options defined in the parent class
    #       [
    #         *super,
    #         ProcessExecuter::Options::OptionDefinition.new(
    #           :option1, default: '', validator: method(:assert_is_string)
    #           ),
    #         ProcessExecuter::Options::OptionDefinition.new(
    #           :option2, default: '', validator: method(:assert_is_string)
    #         ),
    #         ProcessExecuter::Options::OptionDefinition.new(
    #           :option3, default: '', validator: method(:assert_is_string)
    #         )
    #       ]
    #     end
    #     def assert_is_string(key, value)
    #       return if value.is_a?(String)
    #       errors << "#{key} must be a String but was #{value}"
    #     end
    #   end
    #   options = MyOptions.new(option1: 'value1', option2: 'value2')
    #   options.option1 # => 'value1'
    #   options.option2 # => 'value2'
    #
    # @example invalid option values
    #   begin
    #     options = MyOptions.new(option1: 1, option2: 2)
    #   rescue ProcessExecuter::ArgumentError => e
    #     e.message #=> "option1 must be a String but was 1\noption2 must be a String but was 2"
    #   end
    #
    # @api public
    class Base
      # Create a new Options object
      #
      # Normally you would use a subclass instead of instantiating this class
      # directly.
      #
      # @example
      #   options = MyOptions.new(option1: 'value1', option2: 'value2')
      #
      # @example with invalid option values
      #   begin
      #     options = MyOptions.new(option1: 1, option2: 2)
      #   rescue ProcessExecuter::ArgumentError => e
      #     e.message #=> "option1 must be a String but was 1\noption2 must be a String but was 2"
      #   end
      #
      # @param options_hash [Hash] a hash of options
      #
      def initialize(**options_hash)
        @options_hash = allowed_options.transform_values(&:default).merge(options_hash)
        @errors = []
        assert_no_unknown_options
        define_accessor_methods
        validate_options
      end

      # All the allowed options as a hash whose keys are the option names
      #
      # The returned hash what is returned from `define_options` but with the option
      # names as keys. The values are instances of `OptionDefinition`.
      #
      # The returned hash is frozen and cannot be modified.
      #
      # @example
      #   options = MyOptions.new(option1: 'value1', option2: 'value2')
      #   options.allowed_options # => {
      #     option1: #<OptionDefinition>,
      #     option2: #<OptionDefinition>
      #   }
      #
      # @return [Hash<Symbol, ProcessExecuter::Options::OptionDefinition>] A hash
      #   where keys are option names and values are their definitions.
      #
      def allowed_options
        @allowed_options ||=
          define_options.each_with_object({}) do |option, hash|
            hash[option.name] = option
          end.freeze
      end

      # A string representation of the object that includes the options
      #
      # @example
      #   options = MyOptions.new(option1: 'value1', option2: 'value2')
      #   options.to_s # => #<MyOptions option1: "value1", option2: "value2">'
      #
      # @return [String]
      #
      def to_s
        "#{super.to_s[0..-2]} #{inspect}>"
      end

      # A string representation of the options
      #
      # @example
      #   options = MyOptions.new(option1: 'value1', option2: 'value2')
      #   options.inspect # => '{:option1=>"value1", :option2=>"value2"}'
      #
      # @return [String]
      #
      def inspect
        options_hash.inspect
      end

      # A hash representation of the options
      #
      # @example
      #   options = MyOptions.new(option1: 'value1', option2: 'value2')
      #   options.to_h # => { option1: "value1", option2: "value2" }
      #
      # @return [Hash]
      #
      def to_h
        options_hash.dup
      end

      # Iterate over each option with an object
      #
      # @example
      #   options = MyOptions.new(option1: 'value1', option2: 'value2')
      #   options.each_with_object({}) { |(option_key, option_value), obj| obj[option_key] = option_value }
      #   # => { option1: "value1", option2: "value2" }
      #
      # @yield [key_value, obj]
      #
      # @yieldparam key_value [Array<Object, Object>] An array containing the option key and its value
      #
      # @yieldparam obj [Object] The object passed to the block.
      #
      # @return [Object] the obj passed to the block
      #
      def each_with_object(obj, &)
        options_hash.each_with_object(obj, &)
      end

      # Merge the given options into the current options object
      #
      # Subsequent hashes' values overwrite earlier ones for the same key.
      #
      # @example
      #   options = MyOptions.new(option1: 'value1', option2: 'value2')
      #   h1 = { option2: 'new_value2' }
      #   h2 = { option3: 'value3' }
      #   options.merge!(h1, h2) => {option1: "value1", option2: "new_value2", option3: "value3"}
      #
      # @param other_options_hashes [Array<Hash>] zero of more hashes to merge into the current options
      #
      # @return [self] the current options object with the merged options
      #
      # @api public
      #
      def merge!(*other_options_hashes)
        options_hash.merge!(*other_options_hashes)
      end

      # Returns a new options object formed by merging self with each of other_hashes
      #
      # @example
      #   options = MyOptions.new(option1: 'value1', option2: 'value2')
      #   options.object_id # => 1025
      #   h1 = { option2: 'new_value2' }
      #   h2 = { option3: 'value3' }
      #   merged_options = options.merge(h1, h2)
      #   merged_options.object_id # => 1059
      #
      # @param other_options_hashes [Array<Hash>] the options to merge into the current options
      #
      # @return [self.class]
      #
      def merge(*other_options_hashes)
        merged_options = other_options_hashes.reduce(options_hash, :merge)
        self.class.new(**merged_options)
      end

      protected

      # An array of OptionDefinition objects that define the allowed options
      #
      # Subclasses MUST override this method to define the allowed options.
      #
      # @return [Array<OptionDefinition>]
      #
      # @api private
      #
      def define_options
        [].freeze
      end

      # Determine if the given option is a valid option
      #
      # May be overridden by subclasses to add additional validation.
      #
      # @param option [Symbol] the option to be tested
      # @return [Boolean] true if the given option is a valid option
      # @api private
      def valid_option?(option)
        allowed_options.keys.include?(option)
      end

      private

      # The list of validation errors
      #
      # Validators should add error messages to this array.
      #
      # @return [Array<String>]
      #
      # @api private
      #
      attr_reader :errors

      # @!attribute [r]
      #
      # A hash of all options keyed by the option name
      #
      # @return [Hash<Object, Object>]
      #
      # @api private
      #
      attr_reader :options_hash

      # Raise an argument error for invalid option values
      # @return [void]
      # @raise [ProcessExecuter::ArgumentError] if any invalid option values are found
      # @api private
      def validate_options
        options_hash.each_key do |option_key|
          validator = allowed_options[option_key]&.validator
          instance_exec(option_key, send(option_key), &validator.to_proc) unless validator.nil?
        end

        raise ProcessExecuter::ArgumentError, errors.join("\n") unless errors.empty?
      end

      # Define accessor methods for each option
      # @return [void]
      # @api private
      def define_accessor_methods
        allowed_options.each_key do |option|
          define_singleton_method(option) do
            options_hash[option]
          end
        end
      end

      # Determine if the options hash contains any unknown options
      # @return [void]
      # @raise [ProcessExecuter::ArgumentError] if the options hash contains any unknown options
      # @api private
      def assert_no_unknown_options
        unknown_options = options_hash.keys.reject { |key| valid_option?(key) }

        return if unknown_options.empty?

        raise(
          ArgumentError,
          "Unknown option#{'s' if unknown_options.count > 1}: #{unknown_options.join(', ')}"
        )
      end
    end
  end
end
