# frozen_string_literal: true

require_relative '../errors'

module ProcessExecuter
  module Commands
    # Spawns a subprocess, waits until it completes, and returns the result
    #
    # Wraps `Process.spawn` to provide the core functionality for
    # {ProcessExecuter.spawn_with_timeout}.
    #
    # It accepts all [Process.spawn execution
    # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options)
    # plus the additional option `timeout_after`.
    #
    # @api private
    #
    class SpawnWithTimeout
      # Create a new SpawnWithTimeout instance
      #
      # @example
      #   options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 5)
      #   result = ProcessExecuter::Commands::SpawnWithTimeout.new('echo hello', options).call
      #   result.success? # => true
      #   result.exitstatus # => 0
      #
      # @param command [Array<String>] The command to run in the subprocess
      # @param options [ProcessExecuter::Options::SpawnWithTimeoutOptions] The options to use when spawning the process
      #
      def initialize(command, options)
        @command = command
        @options = options
      end

      # Run a command and return the result
      #
      # @example
      #   options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 5)
      #   result = ProcessExecuter::Commands::SpawnWithTimeout.new('echo hello', options).call
      #   result.success? # => true
      #   result.exitstatus # => 0
      #   result.timed_out? # => false
      #
      # @raise [ProcessExecuter::SpawnError] `Process.spawn` raised an error before the
      #   command was run
      #
      # @return [ProcessExecuter::Result] The result of the completed subprocess
      #
      def call
        begin
          @pid = Process.spawn(*command, **options.spawn_options)
        rescue StandardError => e
          raise ProcessExecuter::SpawnError, "Failed to spawn process: #{e.message}"
        end

        wait_for_process
      end

      # The command to be run in the subprocess
      # @see Process.spawn
      # @example
      #   spawn.command #=> ['echo', 'hello']
      # @return [Array<String>]
      attr_reader :command

      # The options that were used to spawn the process
      # @example
      #   spawn.options #=> ProcessExecuter::Options::SpawnWithTimeoutOptions
      # @return [ProcessExecuter::Options::SpawnWithTimeoutOptions]
      attr_reader :options

      # The process ID of the spawned subprocess
      #
      # @example
      #   spawn.pid #=> 12345
      #
      # @return [Integer]
      #
      attr_reader :pid

      # The status returned by Process.wait2
      #
      # @example
      #   spawn.status #=> #<Process::Status: pid 12345 exit 0>
      #
      # @return [Process::Status]
      #
      attr_reader :status

      # Whether the process timed out
      #
      # @example
      #   spawn.timed_out? #=> true
      #
      # @return [Boolean]
      #
      attr_reader :timed_out

      alias timed_out? timed_out

      # The elapsed time in seconds that the command ran
      #
      # @example
      #   spawn.elapsed_time #=> 1.234
      #
      # @return [Numeric]
      #
      attr_reader :elapsed_time

      # The result of the completed subprocess
      #
      # @example
      #   spawn.result #=> ProcessExecuter::Result
      #
      # @return [ProcessExecuter::Result]
      #
      attr_reader :result

      private

      # Wait for process to terminate
      #
      # If a `:timeout_after` is specified in options, terminate the process after the
      # specified number of seconds.
      #
      # @return [ProcessExecuter::Result] The result of the completed subprocess
      #
      def wait_for_process
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @status, @timed_out = wait_for_process_raw
        @elapsed_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        @result = create_result
      end

      # Create a result object that includes the status, command, and other details
      #
      # @return [ProcessExecuter::Result] The result of the command
      #
      def create_result
        ProcessExecuter::Result.new(status, command:, options:, timed_out:, elapsed_time:)
      end

      # Wait for a process to terminate returning the status and timed out flag
      #
      # @return [Array<Process::Status, Boolean>] an array containing the process status and a boolean
      #   indicating whether the process timed out
      def wait_for_process_raw
        timed_out = false

        process_status =
          begin
            Timeout.timeout(options.timeout_after) { Process.wait2(pid).last }
          rescue Timeout::Error
            Process.kill('KILL', pid)
            timed_out = true
            Process.wait2(pid).last
          end

        [process_status, timed_out]
      end
    end
  end
end
