defmodule Mix.Tasks.Igniter.Devenv.New do
  @shortdoc "Creates a new Igniter application with devenv development environment"
  use Mix.Task

  @devenv_options %{
    devenv: %{
      elixir: "Elixir version to use",
      bun: "Install Bun runtime/package manager",
      minio: "MinIO object storage (S3-compatible)",
      npm: "Node.js runtime with npm",
      postgres: "PostgreSQL database",
      redis: "Redis cache/session store"
    }
  }

  @help_text (fn ->
                devenv_types =
                  @devenv_options
                  |> Map.keys()
                  |> Enum.sort()
                  |> Enum.map(&"  * #{&1}")
                  |> Enum.join("\n")

                feature_sections =
                  @devenv_options
                  |> Enum.sort_by(fn {k, _} -> k end)
                  |> Enum.map(fn {devenv_type, features} ->
                    feature_list =
                      features
                      |> Enum.sort_by(fn {k, _} -> k end)
                      |> Enum.map(fn {feature, description} ->
                        "    * #{feature} - #{description}"
                      end)
                      |> Enum.join("\n")

                    "  * for #{devenv_type}:\n#{feature_list}"
                  end)
                  |> Enum.join("\n\n")

                """
                Valid devenv type selectors:
                #{devenv_types}

                Valid feature selectors:
                #{feature_sections}

                Features can include version specifiers, e.g., elixir=1.17
                """
              end).()

  @moduledoc """
  Creates a new project using `mix igniter.new`, then sets up development environment.

  ## Options

  All options are passed through to `mix igniter.new`, except for the following:

  * `--devenv` - A comma-separated list of devenv types and feature selectors

  ## Selectors

  #{@help_text}

  ## Example

      nix shell nixpkgs#elixir -c mix igniter.devenv.new my_project --devenv elixir=1.17,postgres --install ash,ash_postgres --with phx.new

  This will:
  1. Create a new Phoenix project with Ash packages
  2. Initialize devenv in the project
  3. Configure devenv.nix with Elixir 1.17 and PostgreSQL, ready to connect
  """

  @impl Mix.Task
  def run(argv) do
    {project_name, remaining_argv} = extract_project_name(argv)
    {devenv_options, igniter_argv} = extract_devenv_option(remaining_argv)
    {devenv_type, features} = parse_and_validate_devenv_options(devenv_options)

    Mix.shell().info("Creating project with igniter.new...")
    Mix.Task.run("igniter.new", [project_name | igniter_argv])
    # ...leaves us in the newly created directory

    Mix.shell().info("Initializing devenv...")

    case System.cmd("devenv", ["init"], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("devenv initialized successfully")

      {output, exit_code} ->
        show_error_and_exit("""
        Failed to initialize devenv (exit code: #{exit_code}):
        #{output}

        Make sure devenv is installed: https://devenv.sh/getting-started/
        """)
    end

    Mix.shell().info("Configuring devenv.nix with Elixir and requested features...")
    devenv_content = generate_devenv_nix(features, project_name)
    File.write!("devenv.nix", devenv_content)

    feature_names = Map.keys(features)

    Mix.shell().info("""

    Project #{project_name} created successfully with #{devenv_type}!

    To get started:

        cd #{project_name}
        devenv shell   # unless you have direnv installed

    Enabled features: #{Enum.join(feature_names, ", ")}
    """)

    :ok
  end

  defp parse_and_validate_devenv_options(devenv_options) do
    devenv_string = Keyword.get(devenv_options, :devenv, "")

    if devenv_string == "" do
      # Default: devenv type with elixir feature
      {"devenv", %{"elixir" => {true, nil}}}
    else
      items =
        devenv_string
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)

      # Separate devenv types from features
      devenv_types = Map.keys(@devenv_options) |> Enum.map(&Atom.to_string/1)
      {types, features} = Enum.split_with(items, &(&1 in devenv_types))

      # Validate only one devenv type
      devenv_type =
        case types do
          [] ->
            "devenv"

          [type] ->
            type

          multiple ->
            show_error_and_exit("""
            Only one devenv type can be specified, got: #{Enum.join(multiple, ", ")}

            #{@help_text}
            """)
        end

      # Parse features with optional versions
      parsed_features =
        features
        |> Enum.map(&parse_feature/1)
        |> validate_features(devenv_type)
        |> Map.new(fn {name, version} -> {name, {true, version}} end)

      # Ensure elixir is included
      final_features = Map.put_new(parsed_features, "elixir", {true, nil})

      {devenv_type, final_features}
    end
  end

  defp parse_feature(feature_string) do
    case String.split(feature_string, "=", parts: 2) do
      [name] -> {name, nil}
      [name, version] -> {name, version}
    end
  end

  defp validate_features(features, devenv_type) do
    devenv_key = String.to_atom(devenv_type)

    valid_features =
      Map.get(@devenv_options, devenv_key, %{}) |> Map.keys() |> Enum.map(&Atom.to_string/1)

    Enum.each(features, fn {name, _version} ->
      unless name in valid_features do
        show_error_and_exit("""
        Invalid feature selector for #{devenv_type}: #{name}

        #{@help_text}
        """)
      end
    end)

    features
  end

  defp extract_project_name(argv) do
    case argv do
      [project_name | rest] ->
        if String.starts_with?(project_name, "-") do
          show_error_and_exit("""
          The first positional argument must be a project name that doesn't start with a dash, got: #{project_name}
          """)
        else
          {project_name, rest}
        end

      [] ->
        show_error_and_exit("""
        Required positional argument missing: project_name.

        Usage:

            mix igniter.devenv.new project_name [options]
        """)
    end
  end

  defp extract_devenv_option(argv) do
    case Enum.find_index(argv, &(&1 == "--devenv")) do
      nil ->
        {[], argv}

      index ->
        # Get the value after --devenv
        devenv_value = Enum.at(argv, index + 1)
        # Remove both --devenv and its value
        remaining = argv |> List.delete_at(index + 1) |> List.delete_at(index)
        {[devenv: devenv_value], remaining}
    end
  end

  defp generate_devenv_nix(features, project_name) do
    language_configs =
      features
      |> Enum.filter(fn {name, _} -> name in ["elixir", "npm", "bun"] end)
      |> Enum.map(fn {name, {flag, version}} -> feature(name, flag, version, project_name) end)
      |> Enum.join("\n")

    service_configs =
      features
      |> Enum.filter(fn {name, _} -> name in ["postgres", "minio", "redis"] end)
      |> Enum.map(fn {name, {flag, version}} -> feature(name, flag, version, project_name) end)
      |> Enum.join("\n")

    """
    {
      pkgs,
      lib,
      config,
      inputs,
      ...
    }:
    {
      # https://devenv.sh/basics/
      # env.GREET = "devenv";

      # https://devenv.sh/packages/
      packages = with pkgs; [
        git
      ];

      # https://devenv.sh/languages/
    #{language_configs}
      # https://devenv.sh/processes/
      # processes.phx-server.exec = "mix phx.server";

      # https://devenv.sh/services/
    #{service_configs}
      # See full reference at https://devenv.sh/reference/options/
    }
    """
  end

  defp feature("elixir", true, nil, _project_name) do
    """
      languages.elixir.enable = true;
    """
  end

  defp feature("elixir", true, version, _project_name) do
    """
      languages.elixir = {
        enable = true;
        package = pkgs.elixir_#{String.replace(version, ".", "_")};
      };
    """
  end

  defp feature("npm", true, nil, _project_name) do
    """
      languages.javascript = {
        enable = true;
        npm.enable = true;
      };
    """
  end

  defp feature("npm", true, version, _project_name) do
    """
      languages.javascript = {
        enable = true;
        package = pkgs.nodejs_#{version};
        npm.enable = true;
      };
    """
  end

  defp feature("bun", true, nil, _project_name) do
    """
      languages.javascript = {
        enable = true;
        bun.enable = true;
      };
    """
  end

  defp feature("postgres", true, nil, project_name) do
    """
      services.postgres = {
        enable = true;
        initialDatabases = [
          { name = "#{project_name}_dev"; }
          { name = "#{project_name}_test"; }
        ];
        initialScript = "CREATE USER postgres SUPERUSER;";
      };
    """
  end

  defp feature("postgres", true, version, project_name) do
    """
      services.postgres = {
        enable = true;
        package = pkgs.postgresql_#{version};
        initialDatabases = [{ name = "#{project_name}_dev"; }];
        initialScript = "CREATE USER postgres SUPERUSER;";
      };
    """
  end

  defp feature("minio", true, nil, _project_name) do
    """
      services.minio = {
        enable = true;
        accessKey = "minioadmin";
        secretKey = "minioadmin";
      };
    """
  end

  defp feature("redis", true, nil, _project_name) do
    """
      services.redis.enable = true;
    """
  end

  defp feature(feature, true, _version, _project_name) do
    show_error_and_exit("""
      Version cannot be specified for #{feature}.
    """)
  end

  defp feature(_, _, _, _), do: ""

  defp show_error_and_exit(message) do
    Mix.shell().error(message)
    exit({:shutdown, 1})
  end
end
