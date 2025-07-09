# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Mix Archive** project that provides `mix devenv.new` - a wrapper around Elixir project generators that automatically sets up [devenv.sh](https://devenv.sh) development environments. The project contains two main Mix tasks:

1. **`Mix.Tasks.Devenv.New`** - Creates new projects with devenv environment setup
2. **`Mix.Tasks.Deps.Changelog`** - Tracks dependency changelog updates

## Common Development Commands

```bash
# Format code
mix format

# Run tests
mix test

# Build the Mix archive
mix archive.build

# Install archive locally for testing
mix archive.install devenv_new-*.ez --force

# Update dependencies and track changes
mix update  # (alias for `mix deps.changelog deps.update --all`)

# Test the installed archive
mix devenv.new --help
```

## Architecture

### Core Components

**`/lib/mix/tasks/devenv.new.ex`** - Main task following the wrapper pattern:
- Accepts `[embedded_task | argv]` (e.g., `["phx.new", "my_app", "--devenv", "postgres"]`)
- Runs the specified Mix task: `Mix.Task.run(embedded_task, [project_name | task_argv])`
- Initializes devenv in the created project directory
- Generates `devenv.nix` with requested features

**`/lib/mix/tasks/deps.changelog.ex`** - Dependency changelog tracking:
- Creates before/after snapshots of dependency changelogs
- Processes diffs and updates `deps.CHANGELOG.md`
- Supports manual `--before`/`--after` workflow or embedded task wrapping

### devenv Feature System

The `generate_devenv_nix/2` function creates Nix configurations for:
- **Language configs**: `elixir`, `npm`, `bun` (with optional version specs)
- **Service configs**: `postgres`, `redis`, `minio` (with project-specific databases)

Feature parsing handles `feature=version` syntax (e.g., `elixir=1.17`).

## Key Design Patterns

**Wrapper Pattern**: Both tasks wrap other Mix tasks while adding functionality:
- `devenv.new` wraps project generators and adds devenv setup
- `deps.changelog` wraps update tasks and adds changelog tracking

**Mix Archive Distribution**: The project is distributed as a Mix archive, allowing global installation and usage across projects.

**Generic Interface**: Recent refactoring removed Igniter-specific dependencies, making it work with any Mix project generator (`phx.new`, `igniter.new`, `new`, etc.).

## Test Structure

- **`/test/core_test.exs`** - Unit tests for changelog functionality (non-async)
- **`/test/e2e_test.exs`** - End-to-end tests (currently skipped)
- **`/test/fixtures/`** - Mock dependencies and expected outputs for testing

Tests use temporary directories and mock dependency structures to validate changelog generation.

## Development Environment

The project uses devenv.sh with:
- Elixir runtime
- nixpkgs-stable (24.11)
- alejandra for Nix formatting
- git for version control

The `mix.exs` includes test fixture paths in compilation: `elixirc_paths(:test)` includes `"test/fixtures"`.