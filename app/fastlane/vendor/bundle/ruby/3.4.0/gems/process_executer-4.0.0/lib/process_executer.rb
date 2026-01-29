# frozen_string_literal: true

# The {ProcessExecuter} module provides extended versions of
# [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn) that
# block while the command is executing. These methods provide enhanced features such
# as timeout handling, more flexible redirection options, logging, error raising, and
# output capturing.
#
# The interface of these methods is the same as the standard library
# [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
# method, but with additional options and features.
#
# These methods are:
#
# * {spawn_with_timeout}: Extends
#   [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn) to
#   run a command and wait (with timeout) for it to finish
# * {run}: Extends {ProcessExecuter.spawn_with_timeout}, adding more flexible
#   redirection and other options
# * {run_with_capture}: Extends {ProcessExecuter.run}, automatically captures stdout and stderr
#
# See the {ProcessExecuter::Error} class for the error architecture for this module.
#
# @api public
module ProcessExecuter
  # Extends `Process.spawn` to run command and wait (with timeout) for it to finish
  #
  # Accepts all [Process.spawn execution
  # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options)
  # and the additional option `timeout_after`:
  #
  # * `timeout_after: <Numeric, nil>`: the amount of time (in seconds) to wait before
  #   signaling the process with SIGKILL. 0 or nil means no timeout.
  #
  # Returns a {Result} object. The {Result} class is a decorator for
  # [Process::Status](https://docs.ruby-lang.org/en/3.4/Process/Status.html) that
  # provides additional attributes about the command's status. This includes the
  # {Result#command command} that was run, the {Result#options options} used to run
  # it, {Result#elapsed_time elapsed_time} of the command, and whether the command
  # {Result#timed_out? timed_out?}.
  #
  # @overload spawn_with_timeout(*command, **options_hash)
  #
  #   @param command [Array<String>] see [Process module, Argument `command_line` or
  #     `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument
  #     `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options_hash [Hash] In addition to the options documented in [Process
  #     module, Execution
  #     Options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options),
  #     the following options are supported: `:timeout_after`
  #
  #   @option options_hash [Numeric] :timeout_after the amount of time (in seconds)
  #     to wait before signaling the process with SIGKILL
  #
  # @overload spawn_with_timeout(*command, options)
  #
  #   @param command [Array<String>] see [Process module, Argument `command_line` or
  #     `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument
  #     `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options [ProcessExecuter::Options::SpawnWithTimeoutOptions]
  #
  # @example command line given as a single string
  #   result = ProcessExecuter.spawn_with_timeout('echo "3\n2\n1" | sort')
  #   result.exited? # => true
  #   result.success? # => true
  #   result.exitstatus # => 0
  #   result.timed_out? # => false
  #
  # @example command given as an exe_path and args
  #   result = ProcessExecuter.spawn_with_timeout('ping', '-c', '1', 'localhost')
  #
  # @example with a timeout
  #   result = ProcessExecuter.spawn_with_timeout('sleep 10', timeout_after: 0.01)
  #   result.exited? # => false
  #   result.success? # => nil
  #   result.signaled? # => true
  #   result.termsig # => 9
  #   result.timed_out? # => true
  #
  # @example with a env hash
  #   env = { 'EXITSTATUS' => '1' }
  #   result = ProcessExecuter.spawn_with_timeout(env, 'exit $EXITSTATUS')
  #   result.success? # => false
  #   result.exitstatus # => 1
  #
  # @example capture stdout to a StringIO buffer
  #   stdout_buffer = StringIO.new
  #   stdout_pipe = ProcessExecuter::MonitoredPipe.new(stdout_buffer)
  #   begin
  #     result = ProcessExecuter.spawn_with_timeout('echo "3\n2\n1" | sort', out: stdout_pipe)
  #     stdout_buffer.string # => "1\n2\n3\n"
  #   ensure
  #     stdout_pipe.close
  #   end
  #
  # @raise [ProcessExecuter::ArgumentError] If the command or an option is not valid
  #
  #   Raised if an invalid option key or value is given, or both an options object
  #   and options_hash are given.
  #
  # @raise [ProcessExecuter::SpawnError] `Process.spawn` raised an error before the
  #   command was run
  #
  #   Raised if the
  #   [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
  #   method raises an error before the command is run.
  #
  # @return [ProcessExecuter::Result]
  #
  # @api public
  #
  def self.spawn_with_timeout(*command, **options_hash)
    command, options = command_and_options(Options::SpawnWithTimeoutOptions, command, options_hash)
    ProcessExecuter::Commands::SpawnWithTimeout.new(command, options).call
  end

  # Extends {spawn_with_timeout}, adding more flexible redirection and other options
  #
  # Accepts all [Process.spawn execution
  # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options),
  # the additional options defined by {spawn_with_timeout}, and the additional
  # options `raise_errors` and `logger`:
  #
  # * `raise_errors: <Boolean>` makes execution errors an exception if true (default
  #   is `true`)
  # * `logger: <Logger>` logs the command and its result at `:info` level using the
  #   given logger (default is not to log)
  #
  # Internally, this method wraps stdout and stderr redirection options in a
  # {MonitoredPipe}, enabling more flexible output handling. It allows any object
  # that responds to `#write` to be used as a destination and supports multiple
  # destinations using the form `[:tee, destination, ...]`.
  #
  # When the command exits with a non-zero exit status or does not exit normally, one
  # of the following errors will be raised unless the option `raise_errors: false` is
  # explicitly given:
  #
  # * {ProcessExecuter::FailedError} if the command returns a non-zero exitstatus
  # * {ProcessExecuter::SignaledError} if the command exits because of an unhandled
  #   signal
  # * {ProcessExecuter::TimeoutError} if the command times out
  #
  # These errors all have a {CommandError#result result} attribute that contains the
  # {ProcessExecuter::Result} object for this command.
  #
  # If `raise_errors: false` is given and there was an error, the returned
  # {ProcessExecuter::Result} object indicates what the error is via its
  # [success?](https://docs.ruby-lang.org/en/3.4/Process/Status.html#method-i-success-3F),
  # [signaled?](https://docs.ruby-lang.org/en/3.4/Process/Status.html#method-i-signaled-3F),
  # or {Result#timed_out? timed_out?} attributes.
  #
  # A {ProcessExecuter::ProcessIOError} is raised if an exception occurs while
  # collecting subprocess output.
  #
  # Giving the option `raise_errors: false` will not suppress
  # {ProcessExecuter::ProcessIOError}, {ProcessExecuter::SpawnError}, or
  # {ProcessExecuter::ArgumentError} errors.
  #
  # @example capture stdout to a StringIO buffer
  #   out_buffer = StringIO.new
  #   result = ProcessExecuter.run('echo HELLO', out: out_buffer)
  #   out_buffer.string #=> "HELLO\n"
  #
  # @example with :raise_errors set to true
  #   begin
  #     result = ProcessExecuter.run('exit 1', raise_errors: true)
  #   rescue ProcessExecuter::FailedError => e
  #     e.result.exitstatus #=> 1
  #   end
  #
  # @example with :raise_errors set to false
  #   result = ProcessExecuter.run('exit 1', raise_errors: false)
  #   result.exitstatus #=> 1
  #
  # @example with a logger
  #   logger_buffer = StringIO.new
  #   logger = Logger.new(logger_buffer, level: :info)
  #   result = ProcessExecuter.run('echo HELLO', logger: logger)
  #   logger_buffer.string #=> "INFO -- : PID 5555: [\"echo HELLO\"] exited with status pid 5555 exit 0\n"
  #
  # @overload run(*command, **options_hash)
  #
  #   @param command [Array<String>] see [Process module, Argument `command_line` or
  #     `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument
  #     `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param [Hash] options_hash in addition to the options supported by
  #     {spawn_with_timeout}, the following options may be given: `:raise_errors` and
  #     `:logger`
  #
  #   @option options_hash [Boolean] :raise_errors if true, an error will be raised
  #   if the command fails
  #
  #   @option options_hash [Logger] :logger a logger to use for logging the command
  #   and its result at the info level
  #
  #   @option options_hash [Numeric] :timeout_after the amount of time (in seconds)
  #     to wait before signaling the process with SIGKILL
  #
  # @overload run(*command, options)
  #
  #   @param command [Array<String>] see [Process module, Argument `command_line` or
  #     `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument
  #     `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options [ProcessExecuter::Options::RunOptions]
  #
  # @raise [ProcessExecuter::ArgumentError] If the command or an option is not valid
  #
  #   Raised if an invalid option key or value is given, or both an options object
  #   and options_hash are given.
  #
  # @raise [ProcessExecuter::SpawnError] `Process.spawn` raised an error before the
  #   command was run
  #
  #   Raised if the
  #   [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
  #   method raises an error before the command is run.
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
  # @return [ProcessExecuter::Result]
  #
  # @api public
  #
  def self.run(*command, **options_hash)
    command, options = command_and_options(Options::RunOptions, command, options_hash)
    ProcessExecuter::Commands::Run.new(command, options).call
  end

  # Extends {run}, automatically capturing stdout and stderr
  #
  # Accepts all [Process.spawn execution
  # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options),
  # the additional options defined by {spawn_with_timeout} and {run}, and the
  # additional options `merge_output`, `encoding`, `stdout_encoding`, and
  # `stderr_encoding`:
  #
  # * `merge_output: <Boolean>` if true merges stdout and stderr into a single
  #   capture buffer (default is false)
  # * `encoding: <Encoding>` sets the encoding for both stdout and stderr captures
  #   (default is `Encoding::UTF_8`)
  # * `stdout_encoding: <Encoding>` sets the encoding for the stdout capture and, if
  #   not nil, overrides the `encoding` option for stdout (default is nil)
  # * `stderr_encoding: <Encoding>` sets the encoding for the stderr capture and, if
  #   not nil, overrides the `encoding` option for stderr (default is nil)
  #
  # The captured output is accessed in the returned object's `#stdout` and `#stderr`
  # methods. Merged output (if the `merged_output: true` option is given) is accessed
  # in the `#stdout` method.
  #
  # stdout and stderr redirection destinations may be given by the user (e.g. `out:
  # <destination>` or `err: <destination>`). These redirections will receive the
  # output in addition to the internal capture.
  #
  # Unless told otherwise, the internally captured output is assumed to be in UTF-8
  # encoding. This assumption can be changed with the `encoding`,
  # `stdout_encoding`, or `stderr_encoding` options. These options accept any
  # encoding objects returned by `Encoding.list` or their String equivalent given by
  # `#to_s`.
  #
  # The bytes captured are not transcoded. They are interpreted as being in the
  # specified encoding. The user will have to check the validity of the
  # encoding by calling `#valid_encoding?` on the captured output (e.g.,
  # `result.stdout.valid_encoding?`).
  #
  # A `ProcessExecuter::ArgumentError` will be raised if both an options object and
  # an options_hash are given.
  #
  # @example capture stdout and stderr
  #   result =
  #   ProcessExecuter.run_with_capture('echo HELLO; echo ERROR >&2')
  #   result.stdout #=> "HELLO\n" result.stderr #=> "ERROR\n"
  #
  # @example merge stdout and stderr
  #   result = ProcessExecuter.run_with_capture('echo HELLO; echo ERROR >&2', merge_output: true)
  #   # order of output is not guaranteed
  #   result.stdout #=> "HELLO\nERROR\n" result.stderr #=> ""
  #
  # @example default encoding
  #   result = ProcessExecuter.run_with_capture('echo HELLO')
  #   result.stdout #=> "HELLO\n"
  #   result.stdout.encoding #=> #<Encoding:UTF-8>
  #   result.stdout.valid_encoding? #=> true
  #
  # @example custom encoding
  #   result = ProcessExecuter.run_with_capture('echo HELLO', encoding: Encoding::ISO_8859_1)
  #   result.stdout #=> "HELLO\n"
  #   result.stdout.encoding #=> #<Encoding:ISO-8859-1>
  #   result.stdout.valid_encoding? #=> true
  #
  # @example custom encoding with invalid bytes
  #   File.binwrite('output.txt', "\xFF\xFE") # little-endian BOM marker is not valid UTF-8
  #   result = ProcessExecuter.run_with_capture('cat output.txt')
  #   result.stdout #=> "\xFF\xFE"
  #   result.stdout.encoding #=> #<Encoding:UTF-8>
  #   result.stdout.valid_encoding? #=> false
  #
  # @overload run_with_capture(*command, **options_hash)
  #
  #   @param command [Array<String>] see [Process module, Argument `command_line` or
  #     `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument
  #     `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options_hash [Hash] in addition to the options supported by {run},
  #     `merge_output` may be given
  #
  #   @option options_hash [Boolean] :merge_output if true, stdout and stderr will be
  #     merged into a single capture buffer
  #
  #   @option options_hash [Encoding, String] :encoding the encoding to assume for
  #     the internal stdout and stderr captures
  #
  #     The default is `Encoding::UTF_8`. This option is overridden by the `stdout_encoding`
  #     and `stderr_encoding` options if they are given and not nil.
  #
  #   @option options_hash [Encoding, String, nil] :stdout_encoding the encoding to
  #     assume for the internal stdout capture
  #
  #     The default is nil, which means the `encoding` option is used. If this option is
  #     is not nil, it is used instead of the `encoding` option.
  #
  #   @option options_hash [Encoding, String, nil] :stderr_encoding the encoding to
  #     assume for the internal stderr capture
  #
  #     The default is nil, which means the `encoding` option is used. If this option
  #     is not nil, it is used instead of the `encoding` option.
  #
  # @overload run_with_capture(*command, options)
  #
  #   @param command [Array<String>] see [Process module, Argument `command_line` or
  #     `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument
  #     `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options [ProcessExecuter::Options::RunWithCaptureOptions]
  #
  # @raise [ProcessExecuter::ArgumentError] If the command or an option is not valid
  #
  #   Raised if an invalid option key or value is given, or both an options object
  #   and options_hash are given.
  #
  # @raise [ProcessExecuter::SpawnError] `Process.spawn` raised an error before the
  #   command was run
  #
  #   Raised if the
  #   [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
  #   method raises an error before the command is run.
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
  # @return [ProcessExecuter::ResultWithCapture]
  #
  #   Where `#stdout` and `#stderr` are strings whose encoding is determined by the
  #   `:encoding`, `:stdout_encoding`, or `:stderr_encoding` options.
  #
  # @api public
  #
  def self.run_with_capture(*command, **options_hash)
    command, options = command_and_options(Options::RunWithCaptureOptions, command, options_hash)
    ProcessExecuter::Commands::RunWithCapture.new(command, options).call
  end

  # Takes a command and options_hash to determine the options object
  #
  # To support either passing an options object or an options_hash, this method takes
  # a command and an options_hash and returns the command (with the trailing options
  # object removed if one is given) and and options object.
  #
  # @example options hash not empty
  #   command, options = ProcessExecuter.command_and_options(
  #     ProcessExecuter::Options::RunOptions,
  #     ['echo hello'],
  #     { out: $stdout }
  #   )
  #   command #=> ['echo hello']
  #   options #=> a new RunOptions instance initialized with the options hash
  #
  # @example options_hash empty, command DOES NOT end with an options object
  #   command, options = ProcessExecuter.command_and_options(
  #     ProcessExecuter::Options::RunOptions,
  #     ['echo hello'],
  #     {}
  #   )
  #   command #=> ['echo hello']
  #   options #=> a new RunOptions instance initialized with defaults
  #
  # @example options_hash empty, command ends with an options object
  #   command, options = ProcessExecuter.command_and_options(
  #     ProcessExecuter::Options::RunOptions,
  #     ['echo hello', ProcessExecuter::Options::RunOptions.new(out: $stdout)],
  #     {}
  #   )
  #   command #=> ['echo hello'] # options object is removed
  #   options #=> the RunOptions object from command[-1]
  #
  # @param options_class [Class] the class of the options object
  #
  # @param command [Array] the command to be executed (possibly with an instance of
  #   options_class at the end)
  #
  # @param options_hash [Hash] the (possibly empty) hash of options
  #
  # @return [Array] An array containing two elements: the command and an options object
  #
  #   The command is an array of strings and the options is an instance of the
  #   specified options_class.
  #
  # @raise [ProcessExecuter::ArgumentError] If both an options object and an
  #   options_hash are given
  #
  # @api private
  #
  private_class_method def self.command_and_options(options_class, command, options_hash)
    if command[-1].is_a?(options_class) && !options_hash.empty?
      raise ProcessExecuter::ArgumentError, 'Provide either an options object or an options hash, not both.'
    end

    if !options_hash.empty?
      [command, options_class.new(**options_hash)]
    elsif command[-1].is_a?(options_class)
      [command[..-2], command[-1]]
    else
      [command, options_class.new]
    end
  end
end

require 'logger'
require 'timeout'

require 'process_executer/commands'
require 'process_executer/destinations'
require 'process_executer/errors'
require 'process_executer/monitored_pipe'
require 'process_executer/options'
require 'process_executer/result'
require 'process_executer/result_with_capture'
