# frozen_string_literal: true

require_relative 'spawn_with_timeout_options'
require_relative 'option_definition'

module ProcessExecuter
  module Options
    # Define options for {ProcessExecuter.run}
    #
    # @api public
    #
    class RunOptions < SpawnWithTimeoutOptions
      private

      # The options allowed for objects of this class
      # @return [Array<OptionDefinition>]
      # @api private
      def define_options
        [
          *super,
          OptionDefinition.new(:raise_errors, default: true, validator: method(:validate_raise_errors)),
          OptionDefinition.new(:logger, default: Logger.new(nil), validator: method(:validate_logger))
        ].freeze
      end

      # Note an error if raise_errors is not true or false
      # @param _key [Symbol] the option key (not used)
      # @param _value [Object] the option value (not used)
      # @return [Void]
      # @api private
      def validate_raise_errors(_key, _value)
        return if [true, false].include?(raise_errors)

        errors << "raise_errors must be true or false but was #{raise_errors.inspect}"
      end

      # Note an error if the logger option is not valid
      # @param _key [Symbol] the option key (not used)
      # @param _value [Object] the option value (not used)
      # @return [Void]
      # @api private
      def validate_logger(_key, _value)
        return if logger.respond_to?(:info) && logger.respond_to?(:debug)

        errors << "logger must respond to #info and #debug but was #{logger.inspect}"
      end
    end
  end
end
