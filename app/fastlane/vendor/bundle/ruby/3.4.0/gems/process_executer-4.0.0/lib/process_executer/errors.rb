# frozen_string_literal: true

module ProcessExecuter
  # rubocop:disable Layout/LineLength

  # Base class for all {ProcessExecuter} errors
  #
  # It is recommended to rescue {ProcessExecuter::Error} to catch any runtime error
  # raised by this gem unless you need more specific error handling.
  #
  # Custom errors are arranged in the following class hierarchy:
  #
  # ```text
  # ::StandardError
  #   └─> Error
  #       ├─> ArgumentError
  #       ├─> CommandError
  #       │   ├─> FailedError
  #       │   └─> SignaledError
  #       │       └─> TimeoutError
  #       ├─> ProcessIOError
  #       └─> SpawnError
  # ```
  #
  # | Error Class | Description |
  # | --- | --- |
  # | `Error` | This catch-all error serves as the base class for other custom errors. |
  # | `ArgumentError` | Raised when an invalid argument is passed to a method. |
  # | `CommandError` | A subclass of this error is raised when there is a problem executing a command. |
  # | `FailedError` | Raised when the command exits with a non-zero exit status. |
  # | `SignaledError` | Raised when the command is terminated as a result of receiving a signal. This could happen if the process is forcibly terminated or if there is a serious system error. |
  # | `TimeoutError` | This is a specific type of `SignaledError` that is raised when the command times out and is killed via the SIGKILL signal. |
  # | `ProcessIOError` | Raised when an error was encountered reading or writing to the command's subprocess. |
  # | `SpawnError` | Raised when the process could not execute. Check the `#cause` for the original exception from `Process.spawn`.  |
  #
  # @example Rescuing any error
  #   begin
  #     ProcessExecuter.run('git', 'status')
  #   rescue ProcessExecuter::Error => e
  #     puts "An error occurred: #{e.message}"
  #   end
  #
  # @example Rescuing a timeout error
  #   begin
  #     timeout_after = 0.1 # seconds
  #     ProcessExecuter.run('sleep', '1', timeout_after:)
  #   rescue ProcessExecuter::TimeoutError => e # Catch the more specific error first!
  #     puts "Command took too long and timed out: #{e}"
  #   rescue ProcessExecuter::Error => e
  #     puts "Some other error occurred: #{e}"
  #   end
  #
  # @api public
  #
  class Error < ::StandardError; end

  # rubocop:enable Layout/LineLength

  # Raised when an invalid argument is passed to a method
  #
  # @example Raising ProcessExecuter::ArgumentError due to invalid option value
  #   begin
  #     ProcessExecuter.run('echo Hello', timeout_after: 'not_a_number')
  #   rescue ProcessExecuter::ArgumentError => e
  #     e.message #=> 'timeout_after must be nil or a non-negative real number but was "not_a_number"'
  #   end
  #
  # @api public
  #
  class ArgumentError < ProcessExecuter::Error; end

  # Raised when a command fails or exits because of an uncaught signal
  #
  # The command executed and its result are available from this object.
  #
  # This gem will raise a more specific error for each type of failure:
  #
  # * {FailedError}: when the command exits with a non-zero status
  # * {SignaledError}: when the command exits because of an uncaught signal
  # * {TimeoutError}: when the command times out
  #
  # @api public
  #
  class CommandError < ProcessExecuter::Error
    # Create a CommandError object
    #
    # @example
    #   `exit 1` # set $? appropriately for this example
    #   result_data = {
    #     command: ['exit 1'],
    #     options: ProcessExecuter::Options::RunOptions.new,
    #     timed_out: false,
    #     elapsed_time: 0.01
    #   }
    #   result = ProcessExecuter::Result.new($?, **result_data)
    #   error = ProcessExecuter::CommandError.new(result)
    #   error.to_s #=> '["exit 1"], status: pid 29686 exit 1'
    #
    # @param result [ProcessExecuter::Result] The result of the command including the
    #   command and exit status
    #
    def initialize(result)
      @result = result
      super(error_message)
    end

    # The human readable representation of this error
    #
    # @example
    #   error.error_message #=> '["git", "status"], status: pid 89784 exit 1'
    #
    # @return [String]
    #
    def error_message
      "#{result.command}, status: #{result}"
    end

    # @attribute [r] result
    #
    # The result of the command including the command, its status and its output
    #
    # @example
    #   error.result #=> #<ProcessExecuter::Result:0x00007f9b1b8b3d20>
    #
    # @return [ProcessExecuter::Result]
    #
    attr_reader :result
  end

  # Raised when the command returns a non-zero exit status
  #
  # @api public
  #
  class FailedError < ProcessExecuter::CommandError; end

  # Raised when the command exits because of an uncaught signal
  #
  # @api public
  #
  class SignaledError < ProcessExecuter::CommandError; end

  # Raised when the command takes longer than the configured timeout_after
  #
  # @example
  #   begin
  #     ProcessExecuter.spawn_with_timeout('sleep 1', timeout_after: 0.1)
  #   rescue ProcessExecuter::TimeoutError => e
  #     puts "Command timed out: #{e.result.command}"
  #   end
  #
  # @api public
  #
  class TimeoutError < ProcessExecuter::SignaledError; end

  # Raised if an exception occurred while processing subprocess output
  #
  # @api public
  #
  class ProcessIOError < ProcessExecuter::Error; end

  # Raised when spawn could not execute the process
  #
  # See the `cause` for the exception that Process.spawn raised.
  #
  # @api public
  #
  class SpawnError < ProcessExecuter::Error; end
end
