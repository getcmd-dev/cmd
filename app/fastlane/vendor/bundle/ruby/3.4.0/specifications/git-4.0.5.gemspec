# -*- encoding: utf-8 -*-
# stub: git 4.0.5 ruby lib

Gem::Specification.new do |s|
  s.name = "git".freeze
  s.version = "4.0.5".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://rubydoc.info/gems/git/4.0.5/file/CHANGELOG.md", "documentation_uri" => "https://rubydoc.info/gems/git/4.0.5", "homepage_uri" => "http://github.com/ruby-git/ruby-git", "rubygems_mfa_required" => "true", "source_code_uri" => "http://github.com/ruby-git/ruby-git" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Scott Chacon and others".freeze]
  s.date = "1980-01-02"
  s.description = "The git gem provides an API that can be used to\ncreate, read, and manipulate Git repositories by wrapping system calls to the git\ncommand line. The API can be used for working with Git in complex interactions\nincluding branching and merging, object inspection and manipulation, history, patch\ngeneration and more.\n".freeze
  s.email = "schacon@gmail.com".freeze
  s.homepage = "http://github.com/ruby-git/ruby-git".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.requirements = ["git 2.28.0 or greater".freeze]
  s.rubygems_version = "3.6.9".freeze
  s.summary = "An API to create, read, and manipulate Git repositories".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 5.0".freeze])
  s.add_runtime_dependency(%q<addressable>.freeze, ["~> 2.8".freeze])
  s.add_runtime_dependency(%q<process_executer>.freeze, ["~> 4.0".freeze])
  s.add_runtime_dependency(%q<rchardet>.freeze, ["~> 1.9".freeze])
  s.add_development_dependency(%q<create_github_release>.freeze, ["~> 2.1".freeze])
  s.add_development_dependency(%q<main_branch_shared_rubocop_config>.freeze, ["~> 0.1".freeze])
  s.add_development_dependency(%q<minitar>.freeze, ["~> 1.0".freeze])
  s.add_development_dependency(%q<mocha>.freeze, ["~> 2.7".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.2".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.77".freeze])
  s.add_development_dependency(%q<test-unit>.freeze, ["~> 3.6".freeze])
  s.add_development_dependency(%q<redcarpet>.freeze, ["~> 3.6".freeze])
  s.add_development_dependency(%q<yard>.freeze, ["~> 0.9".freeze, ">= 0.9.28".freeze])
  s.add_development_dependency(%q<yardstick>.freeze, ["~> 0.9".freeze])
end
