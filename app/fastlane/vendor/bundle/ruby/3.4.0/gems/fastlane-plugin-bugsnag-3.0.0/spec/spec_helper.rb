$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require 'fastlane' # to import the Action super class
require 'fastlane/plugin/bugsnag' # import the actual plugin

FIXTURE_PATH = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))
BUGSNAG_CLI_PATH = BugsnagCli.get_bundled_path

# expands the `got` and `expected` output in the RSpec output
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.max_formatted_output_length = nil # unlimited
  end
end
