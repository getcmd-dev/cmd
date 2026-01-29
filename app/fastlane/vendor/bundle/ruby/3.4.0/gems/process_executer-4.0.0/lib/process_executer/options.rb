# frozen_string_literal: true

require_relative 'options/base'
require_relative 'options/spawn_options'
require_relative 'options/spawn_with_timeout_options'
require_relative 'options/run_options'
require_relative 'options/run_with_capture_options'
require_relative 'options/option_definition'

module ProcessExecuter
  # Options related to spawning or running a command
  # @api public
  module Options; end
end
