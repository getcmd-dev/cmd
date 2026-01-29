# frozen_string_literal: true

require_relative 'spawn_options'
require_relative 'option_definition'

module ProcessExecuter
  module Options
    # Defines options for {ProcessExecuter.spawn_with_timeout}
    #
    # @api public
    #
    class SpawnWithTimeoutOptions < SpawnOptions
      private

      # The options allowed for objects of this class
      # @return [Array<OptionDefinition>]
      # @api private
      def define_options
        [
          *super,
          OptionDefinition.new(:timeout_after, default: nil, validator: method(:validate_timeout_after))
        ].freeze
      end

      # Note an error if timeout_after is not nil or a non-negative real number
      #
      # @param _key [Symbol] the option key (not used)
      #
      # @param _value [Object] the option value (not used)
      #
      # @return [void]
      #
      # @api private
      #
      def validate_timeout_after(_key, _value)
        return if timeout_after.nil?
        return if timeout_after.is_a?(Numeric) && timeout_after.real? && !timeout_after.negative?

        errors << "timeout_after must be nil or a non-negative real number but was #{timeout_after.inspect}"
      end
    end
  end
end
