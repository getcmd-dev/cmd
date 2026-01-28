# frozen_string_literal: true

require_relative 'option_definition'
require_relative 'run_options'

module ProcessExecuter
  module Options
    # Define options for {ProcessExecuter.run_with_capture}
    #
    # @api public
    #
    class RunWithCaptureOptions < RunOptions
      # The default encoding used for stdout and stderr
      # if no other encoding is specified.
      #
      # @return [Encoding]
      #
      DEFAULT_ENCODING = Encoding::UTF_8

      # Determines the character encoding to use for stdout
      #
      # It prioritizes `stdout_encoding` if set, otherwise falls back to
      # `encoding`, and finally defaults to `DEFAULT_ENCODING` if neither
      # is available.
      #
      # @return [Encoding]
      #
      # @api private
      #
      def effective_stdout_encoding
        stdout_encoding || encoding || DEFAULT_ENCODING
      end

      # Determines the character encoding to use for stderr
      #
      # It prioritizes `stderr_encoding` if set, otherwise falls back to
      # `encoding`, and finally defaults to `DEFAULT_ENCODING` if neither
      # is available.
      #
      # @return [Encoding]
      #
      # @api private
      #
      def effective_stderr_encoding
        stderr_encoding || encoding || DEFAULT_ENCODING
      end

      private

      # The options allowed for objects of this class
      # @return [Array<OptionDefinition>]
      # @api private
      def define_options
        [
          *super,
          OptionDefinition.new(:merge_output, default: false, validator: method(:validate_merge_output)),
          OptionDefinition.new(:encoding, default: DEFAULT_ENCODING, validator: method(:validate_encoding_option)),
          OptionDefinition.new(:stdout_encoding, default: nil, validator: method(:validate_encoding_option)),
          OptionDefinition.new(:stderr_encoding, default: nil, validator: method(:validate_encoding_option))
        ].freeze
      end

      # Note any errors in the merge_output option
      #
      # Possible errors include:
      # - if the merge_output value is not a Boolean
      # - if merge_output: true and a stderr redirection is given
      # - if merge_output: true and stdout and stderr encodings are different
      #
      # @param _key [Symbol] the option key (not used)
      # @param _value [Object] the option value (not used)
      # @return [Void]
      # @api private
      def validate_merge_output(_key, _value)
        unless [true, false].include?(merge_output)
          errors << "merge_output must be true or false but was #{merge_output.inspect}"
        end

        return unless merge_output == true

        errors << 'Cannot give merge_output: true AND a stderr redirection' if stderr_redirection_source

        return if effective_stdout_encoding == effective_stderr_encoding

        errors << 'Cannot give merge_output: true AND give different encodings for stdout and stderr'
      end

      # Note an error if the encoding option is not valid
      # @param key [Symbol] the option key
      # @param value [Object] the option value
      # @return [Void]
      # @api private
      def validate_encoding_option(key, value)
        return unless valid_encoding_type?(key, value)

        return if value.nil? || value.is_a?(Encoding)

        validate_encoding_symbol(key, value) if value.is_a?(Symbol)

        validate_encoding_string(key, value) if value.is_a?(String)
      end

      # False if the value is not a valid encoding type, true otherwise
      #
      # @param key [Symbol] the option key
      #
      # @param value [Object] the option value
      #
      # @return [Boolean]
      #
      # @api private
      #
      def valid_encoding_type?(key, value)
        return true if value.nil? || value.is_a?(Encoding) || value.is_a?(Symbol) || value.is_a?(String)

        errors << "#{key} must be an Encoding object, String, Symbol (:binary, :default_external), " \
                  "or nil, but was #{value.inspect}"

        false
      end

      # Note an error if the encoding symbol is not valid
      #
      # @param key [Symbol] the option key
      #
      # @param value [Symbol] the option value
      #
      # @return [Void]
      #
      # @api private
      #
      def validate_encoding_symbol(key, value)
        return if %i[binary default_external].include?(value)

        errors << "#{key} when given as a symbol must be :binary or :default_external, " \
                  "but was #{value.inspect}"
      end

      # Note an error if the encoding string is not valid
      #
      # @param key [Symbol] the option key
      #
      # @param value [String] the option value
      #
      # @return [void]
      #
      # @api private
      #
      def validate_encoding_string(key, value)
        Encoding.find(value)
      rescue ::ArgumentError
        errors << "#{key} specifies an unknown encoding name: #{value.inspect}"
      end
    end
  end
end
