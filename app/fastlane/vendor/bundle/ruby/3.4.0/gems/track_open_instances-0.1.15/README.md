# track_open_instances gem

[![Gem Version](https://badge.fury.io/rb/track_open_instances.svg)](https://badge.fury.io/rb/track_open_instances)
[![Build Status](https://github.com/main-branch/track_open_instances/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/main-branch/track_open_instances/actions/workflows/continuous_integration.yml)
[![Documentation](https://img.shields.io/badge/Documentation-Latest-green)](https://rubydoc.info/gems/track_open_instances/)
[![Change Log](https://img.shields.io/badge/CHANGELOG-Latest-green)](https://rubydoc.info/gems/track_open_instances/file/CHANGELOG.md)
[![Slack](https://img.shields.io/badge/slack-main--branch/track__open__instances-yellow.svg?logo=slack)](https://main-branch.slack.com/archives/C01CHR7TMM2)

`TrackOpenInstances` is a Ruby mixin designed to help manage resources that require
explicit cleanup. It provides a simple mechanism to track instances of a
class from creation until they are explicitly closed or disposed of.

By including this module in classes that manage resources like files, network
connections, or temporary objects, you can easily monitor if any instances are left
open, potentially causing resource leaks. The module keeps an internal list
of all active instances and provides methods to check the count of open instances and
assert that no instances remain unclosed, which is particularly useful in test
suites. It also stores the call stack at the time of instance creation
to aid debugging.

## Installation

Add this line to your application's or gem's Gemfile:

```Ruby
gem 'track_open_instances'
```

And then execute:

```Ruby
bundle install
```

Or install it directly from the command line:

```Ruby
gem install track_open_instances
```

## Usage

Include the `TrackOpenInstances` module in any class where you need to track
instances that require explicit cleanup.

Call `add_open_instance` when an instance is created. This is typically done in
`initialize`.

Call `remove_open_instance` when it's cleaned up. This is typically done in a `close`
method.

```Ruby
require 'track_open_instances'

# Example class managing a resource
class ManagedResource
  include TrackOpenInstances

  attr_reader :id

  def initialize(id)
    @id = id
    puts "Opening resource: #{id}"
    # Register instance for tracking
    self.class.add_open_instance(self) #
  end

  def close
    puts "Closing resource: #{id}"
    # Remove instance from tracking
    self.class.remove_open_instance(self) #
  end
end
```

With that integration, you will be able to keep track of all open instances.

```Ruby
# --- Basic Usage ---

res1 = ManagedResource.new('A')
res2 = ManagedResource.new('B')

puts "Open count: #{ManagedResource.open_instance_count}" #=> 2

res1.close #

puts "Open count: #{ManagedResource.open_instance_count}" #=> 1

# --- Checking for Leaks (e.g., in tests) ---

# Get a report of open instances
report = ManagedResource.open_instances_report
puts report if report #=>
# There is 1 open ManagedResource instance:
#  - object_id=...
#    Call stack when created:
#      ... (caller stack lines) ...

# Assert no instances are open (raises RuntimeError if any are found)
begin
  ManagedResource.assert_no_open_instances #
rescue RuntimeError => e
  puts "Assertion failed: #{e.message}"
end
# Output: Assertion failed: There is 1 open ManagedResource instance:...

res2.close

# This assertion will now pass
ManagedResource.assert_no_open_instances #
puts "All resources closed successfully."
# Output: All resources closed successfully.
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`bundle exec rake` to run tests, static analysis, and build the gem.

For experimentation, you can also run `bin/console` for an interactive (IRB) prompt that
automatically requires track_open_instances.

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/main-branch/track_open_instances>.

### Commit message guidelines

All commit messages must follow the [Conventional Commits
standard](https://www.conventionalcommits.org/en/v1.0.0/). This helps us maintain a
clear and structured commit history, automate versioning, and generate changelogs
effectively.

To ensure compliance, this project includes:

- A git commit-msg hook that validates your commit messages before they are accepted.

  To activate the hook, you must have node installed and run `npm install`.

- A GitHub Actions workflow that will enforce the Conventional Commit standard as
  part of the continuous integration pipeline.

  Any commit message that does not conform to the Conventional Commits standard will
  cause the workflow to fail and not allow the PR to be merged.

### Pull request guidelines

All pull requests must be merged using rebase merges. This ensures that commit
messages from the feature branch are preserved in the release branch, keeping the
history clean and meaningful.
