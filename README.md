# devenv.new

![Elixir CI](https://github.com/serpent213/devenv_new/workflows/Elixir%20CI/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-0BSD-yellow.svg)](https://opensource.org/licenses/0BSD)
[![Hex version badge](https://img.shields.io/hexpm/v/devenv_new.svg)](https://hex.pm/packages/devenv_new)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/devenv_new)

A Mix task that wraps any Elixir Mix project generator in a [devenv.sh](https://devenv.sh/getting-started/) environment.

Note that you can [install Nix](https://nixos.org/download/) on top of macOS or most Linux distros without requiring
a full NixOS setup.

## Installation

Install the archive [directly from Hex](https://hex.pm/packages/devenv_new):

```bash
mix archive.install hex devenv_new
```

## Usage

Use `mix devenv.new` to wrap any Mix project generator:

```bash
# Create a Phoenix project with devenv
mix devenv.new phx.new my_app --devenv postgres,redis

# Create an Igniter project with devenv
mix devenv.new igniter.new my_project --devenv elixir=1.17,postgres --install ash,ash_postgres

# Create a basic Elixir project with devenv
mix devenv.new new my_lib --devenv elixir=1.17,minio --sup

# To run Mix in a temporary Elixir Nix environment
nix-shell -p elixir --run 'mix devenv.new igniter.new demo_app '\
'--devenv postgres,bun '\
'--install ash,ash_postgres,ash_authentication_phoenix,ash_graphql '\
'--auth-strategy magic_link '\
'--with phx.new'

cd demo_app
devenv up # start database service(s)
MIX_ENV=test mix ash.reset
mix test
```

See [story.html](https://hexdocs.pm/devenv_new/assets/story.html) ([local](assets/story.html)) for a full log of a generator run.

## Devenv Features

Available devenv features:

* **elixir** - Elixir runtime (enabled by default, supports version specification, e.g. `elixir=1.17`)
* **postgres** - PostgreSQL database
* **redis** - Redis cache/session store
* **minio** - MinIO object storage (S3-compatible)
* **npm** - Node.js runtime with npm
* **bun** - Bun runtime/package manager

The generator is built to be [easily extendable](https://github.com/serpent213/devenv_new/tree/master/priv),
by creating an `.eex` template file and adding it to the look-up table in `devenv.new.ex`.

## How it Works

1. Runs the specified Mix task (e.g., `phx.new`, `igniter.new`, `new`)
2. Initialises devenv in the created project directory
3. Generates `devenv.nix` with requested features

## Developer Instructions

### Installing Archive Locally

For development, install the archive from your local checkout:

```bash
# Clone and build the archive
git clone https://github.com/your-username/devenv_new.git
cd devenv_new
mix archive.build
mix archive.install devenv_new-*.ez --force

# Test the installation
mix devenv.new --help
```

### Rebuilding After Changes

```bash
# Rebuild and reinstall
mix archive.build
mix archive.install devenv_new-*.ez --force
```

### Uninstalling

```bash
mix archive.uninstall devenv_new
```

## Requirements

- Nix environment
- [devenv.sh](https://devenv.sh/getting-started/) installed
- The target project generator (e.g., `phx.new`, `igniter.new`) available
