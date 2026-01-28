# frozen_string_literal: true

require 'delegate'

module ProcessExecuter
  # A decorator for ProcessExecuter::Result that adds the following attributes:
  #
  # * `stdout`: the captured stdout of the command
  # * `stderr`: the captured stderr of the command
  #
  # @api public
  #
  class ResultWithCapture < SimpleDelegator
    # Create a new ResultWithCapture object
    #
    # @param result [ProcessExecuter::Result] the result to delegate to
    # @param stdout_buffer [StringIO] the captured stdout
    # @param stderr_buffer [StringIO] the captured stderr
    #
    # @example manually create a ResultWithCapture instance
    #   stdout_buffer = StringIO.new
    #   stderr_buffer = StringIO.new
    #   command = ['echo HELLO; echo ERROR >&2']
    #   result = ProcessExecuter.run(*command, out: stdout_buffer, err: stderr_buffer)
    #   result_with_capture = ProcessExecuter::ResultWithCapture.new(result, stdout_buffer:, stderr_buffer:)
    #
    #   # Normally, you would use the `run_with_capture` method to create a
    #   # ResultWithCapture instance. The above code is equivalent to:
    #
    #   result_with_capture = ProcessExecuter.run_with_capture('echo HELLO; echo ERROR >&2')
    #
    def initialize(result, stdout_buffer:, stderr_buffer:)
      super(result)
      @stdout_buffer = stdout_buffer
      @stderr_buffer = stderr_buffer
    end

    # The buffer used to capture stdout
    # @example
    #   result.stdout_buffer #=> #<StringIO:0x00007f8c1b0a2d80>
    # @return [StringIO]
    attr_reader :stdout_buffer

    # The captured stdout of the command
    # @example
    #   result.stdout #=> "HELLO\n"
    # @return [String]
    def stdout = @stdout_buffer.string

    # The buffer used to capture stderr
    # @example
    #   result.stderr_buffer #=> #<StringIO:0x00007f8c1b0a2d80>
    # @return [StringIO]
    attr_reader :stderr_buffer

    # The captured stderr of the command
    # @example
    #   result.stderr #=> "ERROR\n"
    # @return [String]
    def stderr = @stderr_buffer.string
  end
end
