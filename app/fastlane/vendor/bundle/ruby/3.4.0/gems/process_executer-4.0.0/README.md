# The ProcessExecuter Gem

[![Gem Version](https://badge.fury.io/rb/process_executer.svg)](https://badge.fury.io/rb/process_executer)
[![Documentation](https://img.shields.io/badge/Documentation-Latest-green)](https://rubydoc.info/gems/process_executer/)
[![Change Log](https://img.shields.io/badge/CHANGELOG-Latest-green)](https://rubydoc.info/gems/process_executer/file/CHANGELOG.md)
[![Build Status](https://github.com/main-branch/process_executer/actions/workflows/continuous-integration.yml/badge.svg)](https://github.com/main-branch/process_executer/actions/workflows/continuous-integration.yml)
[![Conventional
Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Slack](https://img.shields.io/badge/slack-main--branch/process__executer-yellow.svg?logo=slack)](https://main-branch.slack.com/archives/C07NG2BPG8Y)

ProcessExecuter provides an enhanced API for executing commands in subprocesses,
extending Ruby's built-in `Process.spawn` functionality.

It has additional features like capturing output, handling timeouts, streaming output
to multiple destinations, and providing detailed result information.

This README documents the HEAD version of process_executer which may contain
unreleased information. To see the README for the version you are using, consult
RubyGems.org. Go to the [process_executer page in
RubyGems.org](https://rubygems.org/gems/process_executer), select your version, and
then click the "Documentation" link.

## Requirements

- Ruby 3.1.0 or later
- Compatible with MRI 3.1+, TruffleRuby 24+, and JRuby 9.4+
- Works on Mac, Linux, and Windows platforms

## Table of contents

- [Requirements](#requirements)
- [Table of contents](#table-of-contents)
- [Usage](#usage)
  - [Key methods](#key-methods)
  - [ProcessExecuter::MonitoredPipe](#processexecutermonitoredpipe)
  - [Encoding](#encoding)
    - [Encoding summary](#encoding-summary)
    - [Encoding details](#encoding-details)
- [Breaking Changes](#breaking-changes)
  - [2.x](#2x)
    - [`ProcessExecuter.spawn`](#processexecuterspawn)
    - [`ProcessExecuter.run`](#processexecuterrun)
    - [`ProcessExecuter::Result`](#processexecuterresult)
    - [Other](#other)
  - [3.x](#3x)
    - [`ProcessExecuter.run`](#processexecuterrun-1)
  - [4.x](#4x)
    - [`ProcessExecuter.spawn_and_wait`](#processexecuterspawn_and_wait)
    - [`ProcessExecuter::Result`](#processexecuterresult-1)
    - [`ProcessExecuter.spawn_and_wait_with_options`](#processexecuterspawn_and_wait_with_options)
    - [`ProcessExecuter.run_with_options`](#processexecuterrun_with_options)
    - [Other](#other-1)
- [Installation](#installation)
- [Contributing](#contributing)
  - [Reporting Issues](#reporting-issues)
  - [Developing](#developing)
  - [Commit message guidelines](#commit-message-guidelines)
  - [Pull request guidelines](#pull-request-guidelines)
  - [Releasing](#releasing)
- [License](#license)

## Usage

[Full YARD documentation](https://rubydoc.info/gems/process_executer/) for this gem
is hosted on RubyGems.org. Read below for an overview and several examples.

### Key methods

ℹ️ See [the ProcessExecuter module
  documentation](https://rubydoc.info/gems/process_executer/ProcessExecuter) for
  more details and examples of using the methods described here.

The `ProcessExecuter` module provides extended versions of
[Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn) that
block while the command is executing. These methods provide enhanced features such as
timeout handling, more flexible redirection options, logging, error raising, and
output capturing.

The interface of these methods is the same as the standard library
[Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
method but with additional options.

These methods are:

| Method | Description |
|--------|-------------|
| `ProcessExecuter.spawn_with_timeout` | Extends [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn) to run a command and wait (with timeout) for it to finish |
| `ProcessExecuter.run` | Extends `spawn_with_timeout` with more flexible redirection and other options. |
| `ProcessExecuter.run_with_capture` | Extends `run` with capture of stdout and stderr |

See the `ProcessExecuter::Error` class for the error architecture for this module.

### ProcessExecuter::MonitoredPipe

ℹ️ See [the ProcessExecuter::MonitoredPipe class
  documentation](https://rubydoc.info/gems/process_executer/ProcessExecuter/MonitoredPipe)
  for more details and examples of using this class.

`ProcessExecuter::MonitoredPipe` was created to expand the output redirection options
for `Process.spawn` and methods derived from it within the `ProcessExecuter` module.

This class's initializer accepts any compatible redirection destination supported by
`Process.spawn` (this is the `value` part of the file redirection option described in
[the File Redirection section of
`Process.spawn`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-File+Redirection+-28File+Descriptor-29).

In addition to the standard redirection destinations, `MonitoredPipe` also
supports these additional types of destinations:

- **Arbitrary writers**

  You can redirect subprocess output to any Ruby object that implements the
  `#write` method. This is particularly useful for:

  - capturing command output in in-memory buffers like `StringIO`,
  - sending command output to custom logging objects that do not have a file descriptor, and
  - processing with a streaming parser to parse and process command output as the
    command runs

- **Multiple destinations**

  MonitoredPipe supports duplicating (or "teeing") output to multiple
  destinations simultaneously. This is achieved by providing an array in the
  format `[:tee, destination1, destination2, ...]`, where each `destination` can
  be any value that `MonitoredPipe` itself supports (including another tee or
  MonitoredPipe).

### Encoding

#### Encoding summary

The gem's core (`MonitoredPipe`) passes through raw bytes from the subprocess without
attempting to interpret or transcode them. `ProcessExecuter.run_with_capture` allows
text encodings to be specified for the captured stdout and stderr (defaulting to
`UTF-8`). For these outputs, the raw bytes are interpreted as being in that specified
encoding. The original byte sequence is preserved and the resulting captured string
is tagged with the target encoding. No transcoding between different text encodings
(e.g., `Latin-1` to `UTF-8`) is performed.

#### Encoding details

`ProcessExecuter::MonitoredPipe` is encoding agnostic. Bytes pass through this class
from the subprocesses output to the destination object as a stream of unaltered
bytes. No transcoding is applied. Strings written to the destination are tagged for
the ASCII-8BIT (aka BINARY) encoding.

`ProcessExecuter` methods `.spawn_with_timeout`, `.run`, and `.run_with_capture` are
also encoding agnostic except with one exception: the user can specify the assumed
encoding for strings returned from `ResultWithCapture#stdout` and
`ResultWithCapture#stderr`.

As a convenience, the captured output is assumed to be UTF-8 by default:

```ruby
result = ProcessExecuter.run_with_capture('pwd')
result.stdout #=> "/Users/James/projects/process_executer\n"
result.stdout.encoding #=> #<Encoding::UTF-8>
```

You can changed the assumed encoding for the captured stdout and stderr via options
passed to `#run_with_capture`:

```ruby
# Set the assumed encoding for both stdout and stderr
result = ProcessExecuter.run_with_capture('pwd', encoding: Encoding::BINARY)
result.stdout #=> "/Users/James/projects/process_executer\n"
result.stdout.encoding #=> #<Encoding:BINARY (ASCII-8BIT)>

# You can set the assumed encoding separately for stdout and stderr
# Encoding may be different for each
result = ProcessExecuter.run_with_capture('pwd', stdout_encoding: 'BINARY', stderr_encoding: 'UTF-8')
result.stdout.encoding #=> #<Encoding:BINARY (ASCII-8BIT)>
result.stderr.encoding #=> #<Encoding:UTF-8>
```

It is possible that the bytes captured are not valid in the given encoding. The user
will need to check the `#valid_encoding?` method to know for sure.

```ruby
File.binwrite('output.txt', "\xFF\xFE") # little-endian BOM marker is not valid UTF-8
result = ProcessExecuter.run_with_capture('cat output.txt')
result.stdout #=> "\xFF\xFE"
result.stdout.encoding #=> #<Encoding:UTF-8>
result.stdout.valid_encoding? #=> false
```

Encoding options accept any encoding objects returned by `Encoding.list` or their
String equivalent given by `#to_s`:

```ruby
Encoding::UTF_8.to_s #=> 'UTF-8'
```

Changing the assumed encoding DOES NOT cause transcoding. It simply interprets the
bytes captured as the given encoding.

These encoding options ONLY affect the internally captured stdout and stderr for
`ProcessExecuter::run_with_capture`. If you give an `out:` or `err:` option, these
will result in BINARY encoded strings and you will need to handle setting the right
encoding or transcoding after collecting the output.

## Breaking Changes

### 2.x

This major release focused on changes to the interface to make it more understandable.

#### `ProcessExecuter.spawn`

- This method was renamed to `ProcessExecuter.spawn_with_timeout`
- The `:timeout` option was renamed to `:timeout_after`

#### `ProcessExecuter.run`

- The `:timeout` option was renamed to `:timeout_after`

#### `ProcessExecuter::Result`

- The `#timeout` method was renamed to `#timed_out`

#### Other

- Dropped support for Ruby 3.0

### 3.x

#### `ProcessExecuter.run`

- The `:merge` option was removed

  This was removed because `Process.spawn` already provides this functionality but in
  a different way. To merge, you will need to define a redirection where the source
  is an array of the file descriptors you want to merge. For instance:

  ```Ruby
  [:out, :err] => 'output.txt'
  ```

  will merge stdout and stderr from the subprocess into the file output.txt.

- Stdout and stderr redirections no longer default to new instances of `StringIO`

  Calls to `ProcessExecuter.run` that do not define a redirection for stdout or
  stderr will have to add explicit redirection(s) in order to capture the output.

  This is to align with the functionality in `Process.spawn`. In `Process.spawn`, when
  an explicit redirection is not given for stdout and stderr, this output will be
  passed through to the parent process's stdout and stderr.

### 4.x

#### `ProcessExecuter.spawn_and_wait`

`ProcessExecuter.spawn_and_wait` has been renamed to `ProcessExecuter.spawn_with_timeout`.

#### `ProcessExecuter::Result`

`Result#stdout` and `Result#stderr` were removed. Users depending on these methods
will either have to capture this output themselves or change from using
`.spawn_and_wait`/`.run` to `.run_with_capture` which returns a `ResultWithCapture`
object.

#### `ProcessExecuter.spawn_and_wait_with_options`

`ProcessExecuter.spawn_and_wait_with_options` has been removed. Instead call
`ProcessExecuter.spawn_with_timeout` which is overloaded to take the same method
arguments.

#### `ProcessExecuter.run_with_options`

`ProcessExecuter.run_with_options` has been removed. Instead call
`ProcessExecuter.run` which is overloaded to take the same method arguments.

#### Other

In places where users of this gem rescued `::ArgumentError`, they will have to change
the rescued class to `ProcessExecuter::ArgumentError`.

## Installation

Install the gem and add to the application's Gemfile by executing:

```shell
bundle add process_executer
```

If bundler is not being used to manage dependencies, install the gem by executing:

```shell
gem install process_executer
```

## Contributing

### Reporting Issues

Bug reports and other support requests are welcome on [this project's
GitHub issue tracker](https://github.com/main-branch/process_executer)

### Developing

Clone the repo, run `bin/setup` to install dependencies, and then run `rake spec` to
run the tests. You can also run `bin/console` for an interactive prompt that will
allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

### Commit message guidelines

All commit messages must follow the [Conventional Commits
standard](https://www.conventionalcommits.org/en/v1.0.0/). This helps us maintain a
clear and structured commit history, automate versioning, and generate changelogs
effectively.

To ensure compliance, this project includes:

- A git commit-msg hook that validates your commit messages before they are accepted.

  To activate the hook, you must have Node.js installed and run `npm install`.

- A GitHub Actions workflow that will enforce the Conventional Commit standard as
  part of the continuous integration pipeline.

  Any commit message that does not conform to the Conventional Commits standard will
  cause the workflow to fail and not allow the PR to be merged.

### Pull request guidelines

All pull requests must be merged using rebase merges. This ensures that commit
messages from the feature branch are preserved in the release branch, keeping the
history clean and meaningful.

### Releasing

In the root directory of this project with the `main` branch checked out, run
the following command:

```shell
create-github-release {major|minor|patch}
```

Follow the directions given by the `create-github-release` to publish the new version
of the gem.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).
