# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2025-07-10

### Added
- Credo static code analysis to CI workflow
- GitHub Actions CI workflow
- Documentation with ExDoc

### Changed
- Mix.ensure_application!(:hex) to stay clear of obscure runtime errors
- Enhanced package information and metadata

## [0.2.0] - 2025-07-10

### Added
- Generic wrapper pattern for Mix project generators
- Template-based devenv.nix generation system
- Support for multiple language configurations (elixir, npm, bun)
- Support for service configurations (postgres, redis, minio)
- Comprehensive test coverage including end-to-end tests

### Changed
- Refactored to work with any Mix project generator (not just Igniter)
- Improved feature parsing with version specification support
- Enhanced documentation and package information
- Streamlined template structure with individual .eex files per feature

### Fixed
- Naming consistency for deps_changelog integration
- Test reliability and coverage

### Removed
- Alternative devenv switch implementation
- Igniter-specific dependencies for broader compatibility

## [0.1.0] - Initial Release
- Basic project structure and functionality
