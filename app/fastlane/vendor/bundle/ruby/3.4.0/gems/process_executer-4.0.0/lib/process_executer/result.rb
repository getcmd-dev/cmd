# frozen_string_literal: true

require 'delegate'

module ProcessExecuter
  # A decorator for Process::Status that adds the following attributes:
  #
  # * `command`: the command that was used to spawn the process
  # * `options`: the options that were used to spawn the process
  # * `elapsed_time`: the seconds the command ran
  # * `timed_out?`: true if the process timed out
  #
  # @api public
  #
  class Result < SimpleDelegator
    # Create a new Result object
    #
    # @example
    #   command = ['sleep 1']
    #   options = ProcessExecuter::Options::SpawnOptions.new
    #   pid = Process.spawn(*command, **options.spawn_options)
    #   _pid, status = Process.wait2(pid)
    #   timed_out = false
    #   elapsed_time = 0.01
    #
    #   ProcessExecuter::Result.new(status, command:, options:, timed_out:, elapsed_time:)
    #
    # @param status [Process::Status] the status to delegate to
    #
    # @param command [Array] the command that was used to spawn the process
    #
    # @param options [ProcessExecuter::Options::Base] the options that were used to spawn the process
    #
    # @param timed_out [Boolean] true if the process timed out
    #
    # @param elapsed_time [Numeric] the seconds the command ran
    #
    def initialize(status, command:, options:, timed_out:, elapsed_time:)
      super(status)
      @command = command
      @options = options
      @timed_out = timed_out
      @elapsed_time = elapsed_time
    end

    # The command that was used to spawn the process
    # @see Process.spawn
    # @example
    #   result.command #=> [{ 'GIT_DIR' => '/path/to/repo' }, 'git', 'status']
    # @return [Array]
    attr_reader :command

    # The options that were used to spawn the process
    #
    # @see Process.spawn
    #
    # @example
    #   # Looks like a hash, but is actually an object that derives from
    #   # ProcessExecuter::Options::Base
    #   result.options #=> { chdir: '/path/to/repo', timeout_after: 0.5 }
    #
    # @return [ProcessExecuter::Options::Base]
    #
    attr_reader :options

    # The seconds the command ran
    # @example
    #   result.elapsed_time #=> 10.0
    # @return [Numeric]
    attr_reader :elapsed_time

    # @!attribute [r] timed_out?
    # True if the process timed out and was sent the SIGKILL signal
    # @example
    #   result = ProcessExecuter.spawn_with_timeout('sleep 10', timeout_after: 0.01)
    #   result.timed_out? # => true
    # @return [Boolean]
    #
    attr_reader :timed_out
    alias timed_out? timed_out

    # Overrides the default `success?` method to return `nil` if the process timed out
    #
    # This is because when a timeout occurs, Windows will still return true.
    #
    # @example
    #   result = ProcessExecuter.spawn_with_timeout('sleep 10', timeout_after: 0.01)
    #   result.success? # => nil
    # @return [true, false, nil]
    #
    def success?
      return nil if timed_out? # rubocop:disable Style/ReturnNilInPredicateMethodDefinition

      super
    end

    # Return a string representation of the result
    # @example
    #   result = ProcessExecuter.spawn_with_timeout('sleep 10', timeout_after: 1)
    #   # This message is platform dependent, but will look like this on Linux:
    #   result.to_s #=> "pid 70144 SIGKILL (signal 9) timed out after 1s"
    # @return [String]
    #
    def to_s
      "#{super}#{" timed out after #{options.timeout_after}s" if timed_out?}"
    end
  end
end
