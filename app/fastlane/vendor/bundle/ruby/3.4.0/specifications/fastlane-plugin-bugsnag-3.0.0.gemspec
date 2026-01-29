# -*- encoding: utf-8 -*-
# stub: fastlane-plugin-bugsnag 3.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "fastlane-plugin-bugsnag".freeze
  s.version = "3.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Delisa Mason".freeze]
  s.date = "2025-09-22"
  s.email = "iskanamagus@gmail.com".freeze
  s.homepage = "https://github.com/bugsnag/fastlane-plugin-bugsnag".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Uploads dSYM files to Bugsnag".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<xml-simple>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<git>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<abbrev>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<pry>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<parallel>.freeze, ["< 1.20.0".freeze])
  s.add_development_dependency(%q<fastlane>.freeze, [">= 2.28.5".freeze])
end
