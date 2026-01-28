# -*- encoding: utf-8 -*-
# stub: track_open_instances 0.1.15 ruby lib

Gem::Specification.new do |s|
  s.name = "track_open_instances".freeze
  s.version = "0.1.15".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "changelog_uri" => "https://rubydoc.info/gems/track_open_instances/0.1.15/file/CHANGELOG.md", "documentation_uri" => "https://rubydoc.info/gems/track_open_instances/0.1.15", "homepage_uri" => "https://github.com/main-branch/track_open_instances", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/main-branch/track_open_instances" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["James Couball".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.description = "A mixin to track instances of Ruby classes that require explicit cleanup,\nhelping to identify potential resource leaks. It maintains a list of\ncreated instances and allows checking for any that remain unclosed.\n".freeze
  s.email = ["jcouball@yahoo.com".freeze]
  s.homepage = "https://github.com/main-branch/track_open_instances".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1.0".freeze)
  s.requirements = ["Platform: Mac, Linux, or Windows".freeze, "Ruby: MRI 3.1 or later, TruffleRuby 24 or later, or JRuby 9.4 or later".freeze]
  s.rubygems_version = "3.6.7".freeze
  s.summary = "A mixin to ensure that all instances of a class are closed".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<bundler-audit>.freeze, ["~> 0.9".freeze])
  s.add_development_dependency(%q<create_github_release>.freeze, ["~> 2.1".freeze])
  s.add_development_dependency(%q<main_branch_shared_rubocop_config>.freeze, ["~> 0.1".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.2".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.13".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.75".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.22".freeze])
  s.add_development_dependency(%q<simplecov-json>.freeze, ["~> 0.2".freeze])
  s.add_development_dependency(%q<simplecov-rspec>.freeze, ["~> 0.4".freeze])
  s.add_development_dependency(%q<redcarpet>.freeze, ["~> 3.6".freeze])
  s.add_development_dependency(%q<yard>.freeze, ["~> 0.9".freeze, ">= 0.9.28".freeze])
  s.add_development_dependency(%q<yardstick>.freeze, ["~> 0.9".freeze])
end
