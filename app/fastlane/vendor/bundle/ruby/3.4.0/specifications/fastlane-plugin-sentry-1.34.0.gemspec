# -*- encoding: utf-8 -*-
# stub: fastlane-plugin-sentry 1.34.0 ruby lib

Gem::Specification.new do |s|
  s.name = "fastlane-plugin-sentry".freeze
  s.version = "1.34.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sentry".freeze]
  s.date = "2025-10-01"
  s.email = "hello@sentry.io".freeze
  s.homepage = "https://github.com/getsentry/sentry-fastlane-plugin".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6.0".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Upload symbols to Sentry".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<os>.freeze, ["~> 1.1".freeze, ">= 1.1.4".freeze])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<fastlane>.freeze, [">= 2.10.0".freeze])
  s.add_development_dependency(%q<pry>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0".freeze])
end
