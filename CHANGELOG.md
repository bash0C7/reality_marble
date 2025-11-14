# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added (v0.2.0 - Phase 1: Essential Features)
- Call history tracking: `CallRecord` class and `marble.calls_for(klass, method)`
- Argument matching DSL: `expect(...).with(*args)` and `expect(...).with_any()`
- Return value specification: `expect(...).returns(value)`
- Exception raising: `expect(...).raises(ExceptionClass, message)`
- Improved test coverage (97.1% line coverage)
- Anonymous block forwarding for Ruby 3.4+ compatibility

## [0.1.0] - 2025-11-13

### Added
- Initial gem structure
- Core API: `RealityMarble.chant` and `marble.activate`
- Mock/stub support via `marble.expect`
- Method restoration via ensure blocks (alias_method approach for C extensions)
- Test::Unit integration
- SimpleCov coverage reporting
- RuboCop configuration
- CI/CD pipeline with GitHub Actions
- Comprehensive documentation (README, CLAUDE.md)
- Basic mock/stub functionality
- Ruby 3.4+ support

[Unreleased]: https://github.com/bash0C7/reality_marble/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bash0C7/reality_marble/releases/tag/v0.1.0
