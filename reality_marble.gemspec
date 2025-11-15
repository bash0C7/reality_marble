require_relative "lib/reality_marble/version"

Gem::Specification.new do |spec|
  spec.name = "reality_marble"
  spec.version = RealityMarble::VERSION
  spec.authors = ["bash0C7"]
  spec.email = ["ksb.4038.nullpointer+github@gmail.com"]

  spec.summary = "Reality Marble: Next-generation mock/stub library for Ruby 3.4+"
  spec.description = "Reality Marble (固有結界) is a next-generation mock/stub library for Ruby 3.4+ that provides isolated, perfect mock/stub support using pure Ruby mechanisms. Inspired by TYPE-MOON's metaphor, it creates a temporary 'reality' where method behaviors are overridden only within specific test scopes.\n\nFeatures:\n- Pure Ruby syntax (no custom DSL)\n- Perfect isolation (zero mock leakage)\n- Nested activation support (2-5 levels verified)\n- Performance optimization with `only:` parameter\n- 90%+ test coverage\n- Thread-safe\n\nSupports 95%+ of Ruby patterns with documented workarounds for known limitations (aliases, visibility, refinements)."
  spec.homepage = "https://github.com/bash0C7/reality_marble"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bash0C7/reality_marble"
  spec.metadata["changelog_uri"] = "https://github.com/bash0C7/reality_marble/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  # (None - Reality Marble is dependency-free)

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.81"
  spec.add_development_dependency "rubocop-performance", "~> 1.26"
  spec.add_development_dependency "rubocop-rake", "~> 0.7"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "simplecov-cobertura", "~> 3.1"
  spec.add_development_dependency "test-unit", "~> 3.0"

  # Type system integration (Priority 1: rbs-inline + Steep)
  spec.add_development_dependency "rbs", "~> 3.4"
  spec.add_development_dependency "rbs-inline", "~> 0.11"
  spec.add_development_dependency "steep", "~> 1.8"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
