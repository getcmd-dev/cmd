# frozen_string_literal: true

require 'stringio'
require 'io/wait'
require 'track_open_instances'

module ProcessExecuter
  # Acts as a pipe that writes the data written to it to one or more destinations
  #
  # {ProcessExecuter::MonitoredPipe} was created to expand the output redirection
  # options for
  # [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
  # and methods derived from it within the `ProcessExecuter` module.
  #
  # This class's initializer accepts any redirection destination supported by
  # [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
  # (this is the `value` part of the file redirection option described in [the File
  # Redirection section of
  # `Process.spawn`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-File+Redirection+-28File+Descriptor-29).
  #
  # In addition to the standard redirection destinations, {ProcessExecuter::MonitoredPipe} also
  # supports these additional types of destinations:
  #
  # - **Arbitrary Writers**
  #
  #   You can redirect subprocess output to any Ruby object that implements the
  #   `#write` method. This is particularly useful for:
  #
  #     - capturing command output in in-memory buffers like `StringIO`
  #     - sending command output to custom logging objects that do not have a file
  #       descriptor
  #     - processing with a streaming parser to parse and process command output as
  #       the command is running
  #
  # - **Multiple Destinations**
  #
  #   MonitoredPipe supports duplicating (or "teeing") output to multiple
  #   destinations simultaneously. This is achieved by providing a redirection
  #   destination in the form `[:tee, destination1, destination2, ...]`, where each
  #   `destination` can be any value that `MonitoredPipe` itself supports (including
  #   another tee or MonitoredPipe).
  #
  # When a new MonitoredPipe is created, a pipe is created (via IO.pipe) and
  # a thread is created to read data written to the pipe. As data is read from the pipe,
  # it is written to the destination provided in the MonitoredPipe initializer.
  #
  # If the destination raises an exception, the monitoring thread will exit, the
  # pipe will be closed, and the exception will be saved in `#exception`.
  #
  # > **⚠️ WARNING**
  # >
  # > `#close` must be called to ensure that (1) the pipe is closed, (2) all data is
  #   read from the pipe and written to the destination, and (3) the monitoring thread is
  #   killed.
  #
  # @example Collect pipe data into a StringIO object
  #   pipe_data = StringIO.new
  #   begin
  #     pipe = ProcessExecuter::MonitoredPipe.new(pipe_data)
  #     pipe.write("Hello World")
  #   ensure
  #     pipe.close
  #   end
  #   pipe_data.string #=> "Hello World"
  #
  # @example Collect pipe data into a string AND a file
  #   pipe_data_string = StringIO.new
  #   pipe_data_file = File.open("pipe_data.txt", "w")
  #   begin
  #     pipe = ProcessExecuter::MonitoredPipe.new([:tee, pipe_data_string, pipe_data_file])
  #     pipe.write("Hello World")
  #   ensure
  #     pipe.close
  #   end
  #   pipe_data_string.string #=> "Hello World"
  #   # It is your responsibility to close the file you opened
  #   pipe_data_file.close
  #   File.read("pipe_data.txt") #=> "Hello World"
  #
  # @example Using a MonitoredPipe with Process.spawn
  #   stdout_buffer = StringIO.new
  #   begin
  #     stdout_pipe = ProcessExecuter::MonitoredPipe.new(stdout_buffer)
  #     pid = Process.spawn('echo Hello World', out: stdout_pipe)
  #     _waited_pid, status = Process.wait2(pid)
  #   ensure
  #     stdout_pipe.close
  #   end
  #   stdout_buffer.string #=> "Hello World\n"
  #
  # @api public
  #
  class MonitoredPipe
    include TrackOpenInstances

    # Create a new monitored pipe
    #
    # Creates an IO.pipe and starts a monitoring thread to read data written to the
    # pipe.
    #
    # @example
    #   redirection_destination = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(redirection_destination)
    #
    # @param redirection_destination [Object] as data is read from the pipe,
    #   it is written to this destination
    #
    #   Accepts any redirection destination supported by
    #   [`Process.spawn`](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn).
    #   This is the `value` part of the file redirection option described in [the
    #   File Redirection section of
    #   `Process.spawn`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-File+Redirection+-28File+Descriptor-29).
    #
    #   In addition to the standard redirection destinations, `MonitoredPipe` also
    #   accepts (1) another monitored pipe, (2) any object that implements a `#write` method and
    #   (3) an array in the form `[:tee, destination1, destination2, ...]` where each
    #   `destination` can be any value that `MonitoredPipe` itself supports (including
    #   another tee or MonitoredPipe).
    #
    # @param chunk_size [Integer] the size of the chunks to read from the pipe
    #
    def initialize(redirection_destination, chunk_size: 100_000)
      @destination = Destinations.factory(redirection_destination)

      assert_destination_is_compatible_with_monitored_pipe

      @mutex = Mutex.new
      @condition_variable = ConditionVariable.new
      @chunk_size = chunk_size
      @pipe_reader, @pipe_writer = IO.pipe

      # Set the encoding of the pipe reader to ASCII_8BIT. This is not strictly
      # necessary since read_nonblock always returns a String where encoding is
      # Encoding::ASCII_8BIT, but it is a good practice to explicitly set the
      # encoding.
      pipe_reader.set_encoding(Encoding::ASCII_8BIT)

      @state = :open
      @thread = start_monitoring_thread

      self.class.add_open_instance(self)
    end

    # Set the state to `:closing` and wait for the state to be set to `:closed`
    #
    # The monitoring thread will see that the state has changed and will close the pipe.
    #
    # @example
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.state #=> :open
    #   pipe.write('Hello World')
    #   pipe.close
    #   pipe.state #=> :closed
    #   data_collector.string #=> "Hello World"
    #
    # @return [void]
    #
    def close
      mutex.synchronize do
        if state == :open
          @state = :closing
          condition_variable.wait(mutex) while @state != :closed
        end
      end

      thread.join
      destination.close
      self.class.remove_open_instance(self)
    end

    # Return the write end of the pipe so that data can be written to it
    #
    # Data written to this end of the pipe will be read by the monitor thread and
    # written to the destination.
    #
    # This is so we can provide a MonitoredPipe to Process.spawn as a FD
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.to_io.write('Hello World')
    #   pipe.close
    #   data_collector.string #=> "Hello World"
    #
    # @return [IO] the write end of the pipe
    #
    def to_io
      pipe_writer
    end

    # @!attribute [r] fileno
    #
    # The file descriptor for the write end of the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.fileno == pipe.to_io.fileno #=> true
    #
    # @return [Integer] the file descriptor for the write end of the pipe
    #
    def fileno
      pipe_writer.fileno
    end

    # Writes data to the pipe so that it can be read by the monitor thread
    #
    # Primarily used for testing.
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.write('Hello World')
    #   pipe.close
    #   data_collector.string #=> "Hello World"
    #
    # @param data [String] the data to write to the pipe
    #
    # @return [Integer] the number of bytes written to the pipe
    #
    # @raise [IOError] if the pipe is not open
    #
    def write(data)
      mutex.synchronize do
        raise IOError, 'closed stream' unless state == :open

        pipe_writer.write(data)
      end
    end

    # @!attribute [r]
    #
    # The size of the chunks to read from the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.chunk_size #=> 100_000
    #
    # @return [Integer] the size of the chunks to read from the pipe
    #
    attr_reader :chunk_size

    # @!attribute [r]
    #
    # The redirection destination to write data that is read from the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.destination #=> #<ProcessExecuter::Destinations::Writer>
    #
    # @return [ProcessExecuter::Destinations::DestinationBase]
    #
    attr_reader :destination

    # @!attribute [r]
    #
    # The state of the pipe
    #
    # Must be either `:open`, `:closing`, or `:closed`
    #
    # * `:open` - the pipe is open and data can be written to it
    # * `:closing` - the pipe is being closed and data can no longer be written to it
    # * `:closed` - the pipe is closed and data can no longer be written to it
    #
    # @example
    #   pipe = ProcessExecuter::MonitoredPipe.new($stdout)
    #   pipe.state #=> :open
    #   pipe.close
    #   pipe.state #=> :closed
    #
    # @return [Symbol] the state of the pipe
    #
    attr_reader :state

    # @!attribute [r]
    #
    # The exception raised by a destination
    #
    # If an exception is raised by a destination, it is stored here. Otherwise, it is `nil`.
    #
    # @example
    #   pipe.exception #=> nil
    #
    # @return [Exception, nil] the exception raised by a destination or `nil` if no exception was raised
    #
    attr_reader :exception

    # @!attribute [r]
    #
    # The thread that monitors the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.thread #=> #<Thread:0x00007f8b1a0b0e00>
    #
    # @return [Thread]
    #
    # @api private
    #
    attr_reader :thread

    # @!attribute [r]
    #
    # The read end of the pipe
    #
    # @example
    #   pipe = ProcessExecuter::MonitoredPipe.new($stdout)
    #   pipe.pipe_reader #=> #<IO:fd 11>
    #
    # @return [IO]
    #
    # @api private
    #
    attr_reader :pipe_reader

    # @!attribute [r]
    #
    # The write end of the pipe
    #
    # @example
    #   pipe = ProcessExecuter::MonitoredPipe.new($stdout)
    #   pipe.pipe_writer #=> #<IO:fd 12>
    #
    # @return [IO] the write end of the pipe
    #
    # @api private
    #
    attr_reader :pipe_writer

    private

    # @!attribute [r]
    #
    # The mutex used to synchronize access to the state variable
    #
    # @return [Mutex]
    #
    # @api private
    #
    attr_reader :mutex

    # @!attribute [r]
    #
    # The condition variable used to synchronize access to the state
    #
    # In particular, it is used while waiting for the state to change to :closed
    #
    # @return [ConditionVariable]
    #
    # @api private
    #
    attr_reader :condition_variable

    # Raise an error if the destination is not compatible with MonitoredPipe
    # @return [void]
    # @raise [ArgumentError] if the destination is not compatible with MonitoredPipe
    # @api private
    def assert_destination_is_compatible_with_monitored_pipe
      return if destination.compatible_with_monitored_pipe?

      raise ArgumentError, "Destination #{destination.destination} is not compatible with MonitoredPipe"
    end

    # Start the thread to monitor the pipe and write data to the destination
    # @return [void]
    # @api private
    def start_monitoring_thread
      Thread.new do
        Thread.current.report_on_exception = false
        Thread.current.abort_on_exception = false
        monitor
      end
    end

    # Read data from the pipe until `#state` is changed to `:closing`
    #
    # The state is changed to `:closed` by calling `#close`.
    #
    # Before this method returns, state is set to `:closed`
    #
    # @return [void]
    # @api private
    def monitor
      monitor_pipe until state == :closing
    ensure
      close_pipe
      mutex.synchronize do
        @state = :closed
        condition_variable.signal
      end
    end

    # Read data from the pipe until `#state` is changed to `:closing`
    #
    # Data read from the pipe is written to the destination.
    #
    # @return [void]
    # @api private
    def monitor_pipe
      # read_nonblock always returns a String where encoding is Encoding::ASCII_8BIT
      new_data = pipe_reader.read_nonblock(chunk_size)
      write_data(new_data)
    rescue IO::WaitReadable
      pipe_reader.wait_readable(0.001)
    end

    # Write the data read from the pipe to the destination
    #
    # If an exception is raised by a writer, set the state to `:closing`
    # so that the pipe can be closed.
    #
    # @param data [String] the data read from the pipe
    # @return [void]
    # @api private
    def write_data(data)
      destination.write(data)
    rescue StandardError => e
      mutex.synchronize do
        @exception = e
        @state = :closing
      end
    end

    # Read any remaining data from the pipe and close it
    #
    # @return [void]
    # @api private
    def close_pipe
      # Close the write end of the pipe so no more data can be written to it
      pipe_writer.close

      # Read remaining data from pipe_reader (if any)
      # If an exception was already raised by the last call to #write, then don't try to read remaining data
      monitor_pipe while exception.nil? && !pipe_reader.eof?

      # Close the read end of the pipe
      pipe_reader.close
    end
  end
end
