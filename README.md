# devenv.new

A Mix archive that wraps any Elixir project generator with [devenv.sh](https://devenv.sh) environment setup.

## Installation

Install the archive directly from this repository:

```bash
mix archive.install git https://github.com/serpent213/devenv_new.git
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
devenv up
MIX_ENV=test mix ash.reset
mix test
```

See [STORY.html](https://htmlpreview.github.io/?https://github.com/serpent213/devenv_new/blob/master/STORY.html) for a full log of a generator run.

## Devenv Features

Available devenv features:

* **elixir** - Elixir runtime (supports version specification, e.g., `elixir=1.17`)
* **postgres** - PostgreSQL database with project-specific databases
* **redis** - Redis cache/session store
* **minio** - MinIO object storage (S3-compatible)
* **npm** - Node.js runtime with npm
* **bun** - Bun runtime/package manager

## Examples

### Phoenix with PostgreSQL and Redis
```bash
mix devenv.new phx.new my_phoenix_app --devenv postgres,redis
cd my_phoenix_app
devenv shell  # or use direnv
```

### Igniter with Ash and PostgreSQL
```bash
mix devenv.new igniter.new my_ash_app --devenv elixir=1.17,postgres --install ash,ash_postgres
```

### Basic Elixir Library with MinIO
```bash
mix devenv.new new my_lib --devenv elixir=1.17,minio --sup
```

## How it Works

1. Runs the specified Mix task (e.g., `phx.new`, `igniter.new`, `new`)
2. Initializes devenv in the created project directory
3. Generates `devenv.nix` with requested features
4. Creates project-specific database configurations when applicable

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

- Elixir/Mix installed
- [devenv.sh](https://devenv.sh/getting-started/) installed
- The target project generator (e.g., `phx.new`, `igniter.new`) available
