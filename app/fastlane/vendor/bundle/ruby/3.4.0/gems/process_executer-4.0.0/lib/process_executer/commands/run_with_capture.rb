# frozen_string_literal: true

require_relative '../errors'

module ProcessExecuter
  module Commands
    # Runs a subprocess, blocks until it completes, and returns the result
    #
    # Extends {ProcessExecuter::Commands::Run} to provide the core functionality for
    # {ProcessExecuter.run_with_capture}.
    #
    # It accepts all [Process.spawn execution
    # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options)
    # plus the additional options `timeout_after`, `raise_errors`, `logger`, and
    # `merge_output`.
    #
    # Like {Run}, any stdout or stderr redirection destinations are wrapped in a
    # {MonitoredPipe}.
    #
    # @api private
    #
    class RunWithCapture < Run
      # Run a command and return the result which includes the captured output
      #
      # @example
      #   options = ProcessExecuter::Options::RunWithCaptureOptions.new(merge_output: false)
      #   result = ProcessExecuter::Commands::RunWithCapture.new('echo hello', options).call
      #   result.success? # => true
      #   result.exitstatus # => 0
      #   result.stdout # => "hello\n"
      #
      # @raise [ProcessExecuter::SpawnError] `Process.spawn` raised an error before the
      #   command was run
      #
      # @raise [ProcessExecuter::FailedError] If the command ran and failed
      #
      # @raise [ProcessExecuter::SignaledError] If the command ran and terminated due to
      #   an unhandled signal
      #
      # @raise [ProcessExecuter::TimeoutError] If the command timed out
      #
      # @raise [ProcessExecuter::ProcessIOError] If there was an exception while
      #   collecting subprocess output
      #
      # @return [ProcessExecuter::ResultWithCapture] The result of the completed subprocess
      #
      def call
        @stdout_buffer = StringIO.new
        stdout_buffer.set_encoding(options.effective_stdout_encoding)
        @stderr_buffer = StringIO.new
        stderr_buffer.set_encoding(options.effective_stderr_encoding)

        update_capture_options

        begin
          super
        ensure
          log_command_output
        end
      end

      # The buffer used to capture stdout
      #
      # @example
      #   run.stdout_buffer #=> StringIO
      #
      # @return [StringIO]
      #
      attr_reader :stdout_buffer

      # The buffer used to capture stderr
      #
      # @example
      #   run.stderr_buffer #=> StringIO
      #
      # @return [StringIO]
      #
      attr_reader :stderr_buffer

      private

      # Create a result object that includes the captured stdout and stderr
      #
      # @return [ProcessExecuter::ResultWithCapture] The result of the command with captured output
      #
      def create_result
        ProcessExecuter::ResultWithCapture.new(
          super, stdout_buffer:, stderr_buffer:
        )
      end

      # Updates {options} to include the stdout and stderr capture options
      #
      # @return [Void]
      #
      def update_capture_options
        out = stdout_buffer
        err = options.merge_output ? [:child, 1] : stderr_buffer

        options.merge!(
          capture_option(:out, stdout_redirection_source, stdout_redirection_destination, out),
          capture_option(:err, stderr_redirection_source, stderr_redirection_destination, err)
        )
      end

      # The source for stdout redirection
      # @return [Object]
      def stdout_redirection_source = options.stdout_redirection_source

      # The source for stderr redirection
      # @return [Object]
      def stderr_redirection_source = options.stderr_redirection_source

      # The destination for stdout redirection
      # @return [Object]
      def stdout_redirection_destination = options.stdout_redirection_destination

      # The destination for stderr redirection
      # @return [Object]
      def stderr_redirection_destination = options.stderr_redirection_destination

      # Add the capture redirection to existing options (if any)
      # @param redirection_source [Symbol, Integer] The source of the redirection (e.g., :out, :err)
      # @param given_source [Symbol, Integer, nil] The source provided by the user (if any)
      # @param given_destination [Object, nil] The destination provided by the user (if any)
      # @param capture_destination [Object] The additional destination to capture output to
      # @return [Hash] The option (including the capture_destination) to merge into options
      def capture_option(redirection_source, given_source, given_destination, capture_destination)
        if given_source
          if Destinations::Tee.handles?(given_destination)
            { given_source => given_destination + [capture_destination] }
          else
            { given_source => [:tee, given_destination, capture_destination] }
          end
        else
          { redirection_source => capture_destination }
        end
      end

      # Log the captured command output to the given logger at debug level
      # @return [Void]
      def log_command_output
        options.logger&.debug { "PID #{pid}: stdout: #{stdout_buffer.string.inspect}" }
        options.logger&.debug { "PID #{pid}: stderr: #{stderr_buffer.string.inspect}" }
      end
    end
  end
end
