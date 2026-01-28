# -*- encoding: utf-8 -*-
# stub: process_executer 4.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "process_executer".freeze
  s.version = "4.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "changelog_uri" => "https://rubydoc.info/gems/process_executer/4.0.0/file/CHANGELOG.md", "documentation_uri" => "https://rubydoc.info/gems/process_executer/4.0.0", "homepage_uri" => "https://github.com/main-branch/process_executer", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/main-branch/process_executer" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["James Couball".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.description = "ProcessExecuter provides a simple API for running commands in a subprocess,\nwith options for capturing output, handling timeouts, logging, and more.\nIt also provides the MonitoredPipe class which expands the output\nredirection capabilities of Ruby's Process.spawn.\n".freeze
  s.email = ["jcouball@yahoo.com".freeze]
  s.homepage = "https://github.com/main-branch/process_executer".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1.0".freeze)
  s.requirements = ["Platform: Mac, Linux, or Windows".freeze, "Ruby: MRI 3.1 or later, TruffleRuby 24 or later, or JRuby 9.4 or later".freeze]
  s.rubygems_version = "3.6.7".freeze
  s.summary = "Enhanced subprocess execution with timeouts, output capture, and flexible redirection".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<track_open_instances>.freeze, ["~> 0.1".freeze])
  s.add_development_dependency(%q<bundler-audit>.freeze, ["~> 0.9".freeze])
  s.add_development_dependency(%q<create_github_release>.freeze, ["~> 2.1".freeze])
  s.add_development_dependency(%q<main_branch_shared_rubocop_config>.freeze, ["~> 0.1".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.2".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.13".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.66".freeze])
  s.add_development_dependency(%q<semverify>.freeze, ["~> 0.3".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.22".freeze])
  s.add_development_dependency(%q<simplecov-lcov>.freeze, ["~> 0.8".freeze])
  s.add_development_dependency(%q<simplecov-rspec>.freeze, ["~> 0.3".freeze])
  s.add_development_dependency(%q<redcarpet>.freeze, ["~> 3.6".freeze])
  s.add_development_dependency(%q<yard>.freeze, ["~> 0.9".freeze, ">= 0.9.28".freeze])
  s.add_development_dependency(%q<yardstick>.freeze, ["~> 0.9".freeze])
end
