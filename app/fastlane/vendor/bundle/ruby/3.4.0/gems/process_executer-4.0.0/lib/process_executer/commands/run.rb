# frozen_string_literal: true

require_relative '../errors'
require_relative 'spawn_with_timeout'

module ProcessExecuter
  module Commands
    # Run a command and return the {ProcessExecuter::Result}
    #
    # Extends {ProcessExecuter::Commands::SpawnWithTimeout} to provide the core functionality for
    # {ProcessExecuter.run}.
    #
    # It accepts all [Process.spawn execution
    # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options)
    # plus the additional options `timeout_after`, `raise_errors` and `logger`.
    #
    # This class wraps any stdout or stderr redirection destinations in a {MonitoredPipe}.
    # This allows any class that implements `#write` to be used as an output redirection
    # destination. This means that you can redirect to a StringIO which is not possible
    # with `Process.spawn`.
    #
    # @api private
    #
    class Run < SpawnWithTimeout
      # Run a command and return the result
      #
      # Wrap the stdout and stderr redirection destinations in pipes and then execute
      # the command.
      #
      # @example
      #   options = ProcessExecuter::Options::RunOptions.new(raise_errors: true)
      #   result = ProcessExecuter::Commands::Run.new('echo hello', options).call
      #   result.success? # => true
      #   result.exitstatus # => 0
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
      # @return [ProcessExecuter::Result] The result of the completed subprocess
      #
      def call
        opened_pipes = wrap_stdout_stderr
        super.tap do
          log_result
          raise_errors if options.raise_errors
        end
      ensure
        opened_pipes.each_value(&:close)
        opened_pipes.each { |option_key, pipe| raise_pipe_error(option_key, pipe) }
      end

      private

      # Wrap the stdout and stderr redirection options with a MonitoredPipe
      # @return [Hash<Object, ProcessExecuter::MonitoredPipe>] The opened pipes (the Object is the option key)
      def wrap_stdout_stderr
        options.each_with_object({}) do |key_value, opened_pipes|
          key, value = key_value

          next unless should_wrap?(key, value)

          wrapped_destination = ProcessExecuter::MonitoredPipe.new(value)
          opened_pipes[key] = wrapped_destination
          options.merge!({ key => wrapped_destination })
        end
      end

      # Should the redirection option be wrapped by a MonitoredPipe
      # @param key [Object] The option key
      # @param value [Object] The option value
      # @return [Boolean] Whether the option should be wrapped
      def should_wrap?(key, value)
        (options.stdout_redirection?(key) || options.stderr_redirection?(key)) &&
          ProcessExecuter::Destinations.compatible_with_monitored_pipe?(value)
      end

      # Raise an error if the command failed
      # @return [void]
      # @raise [ProcessExecuter::FailedError] If the command ran and failed
      # @raise [ProcessExecuter::SignaledError] If the command ran and terminated due to an unhandled signal
      # @raise [ProcessExecuter::TimeoutError] If the command timed out
      def raise_errors
        raise TimeoutError, result if result.timed_out?
        raise SignaledError, result if result.signaled?
        raise FailedError, result unless result.success?
      end

      # Log the result of running the command
      # @return [void]
      def log_result
        options.logger.info { "PID #{pid}: #{command} exited with status #{result}" }
      end

      # Raises a ProcessIOError if the given pipe has a recorded exception
      #
      # @param option_key [Object] The redirection option key
      #
      #   For example, `:out`, or an Array like `[:out, :err]` for merged streams.
      #
      # @param pipe [ProcessExecuter::MonitoredPipe] The pipe that raised the exception
      #
      # @raise [ProcessExecuter::ProcessIOError] If there was an exception while collecting subprocess output
      #
      # @return [void]
      #
      def raise_pipe_error(option_key, pipe)
        return unless pipe.exception

        error = ProcessExecuter::ProcessIOError.new("Pipe Exception for #{command}: #{option_key.inspect}")
        raise(error, cause: pipe.exception)
      end
    end
  end
end
