# frozen_string_literal: true

desc 'Run the same tasks that the CI build will run'
if RUBY_PLATFORM == 'java'
  task default: %w[spec rubocop bundle:audit build]
else
  task default: %w[spec rubocop yard bundle:audit build]
end

# Bundler Audit

require 'bundler/audit/task'
Bundler::Audit::Task.new

# Bundler Gem Build

require 'bundler'
require 'bundler/gem_tasks'

# Make it so that calling `rake release` just calls `rake release:rubygems_push` to
# avoid creating and pushing a new tag.

Rake::Task['release'].clear
desc 'Customized release task to avoid creating a new tag'
task release: 'release:rubygem_push'

# RSpec

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new

CLEAN << 'coverage'
CLEAN << '.rspec_status'
CLEAN << 'rspec-report.xml'

# Rubocop

require 'rubocop/rake_task'

RuboCop::RakeTask.new

# YARD

unless RUBY_PLATFORM == 'java'
  # yard:build

  require 'yard'

  YARD::Rake::YardocTask.new('yard:build') do |t|
    t.files = %w[lib/**/*.rb examples/**/*]
    t.options = %w[--no-private]
    t.stats_options = %w[--list-undoc]
  end

  CLEAN << '.yardoc'
  CLEAN << 'doc'

  # yard:audit

  desc 'Run yardstick to show missing YARD doc elements'
  task :'yard:audit' do
    sh "yardstick 'lib/**/*.rb'"
  end

  # yard:coverage

  require 'yardstick/rake/verify'

  Yardstick::Rake::Verify.new(:'yard:coverage') do |verify|
    verify.threshold = 100
  end

  # yard

  desc 'Run all YARD tasks'
  task yard: %i[yard:build yard:audit yard:coverage]
end
