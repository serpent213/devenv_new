defmodule Mix.Tasks.Devenv.New do
  @shortdoc "Creates a new project with devenv development environment"
  use Mix.Task

  @devenv_options %{
    languages: %{
      elixir: "Elixir version to use",
      bun: "Install Bun runtime/package manager",
      npm: "Node.js runtime with npm"
    },
    services: %{
      minio: "MinIO object storage (S3-compatible)",
      postgres: "PostgreSQL database",
      redis: "Redis cache/session store"
    }
  }

  @help_text (fn ->
                feature_sections =
                  @devenv_options
                  |> Enum.sort_by(fn {k, _} -> k end)
                  |> Enum.map_join("\n\n", fn {category, features} ->
                    feature_list =
                      features
                      |> Enum.sort_by(fn {k, _} -> k end)
                      |> Enum.map_join("\n", fn {feature, description} ->
                        "    * #{feature} - #{description}"
                      end)

                    "  #{String.capitalize(Atom.to_string(category))}:\n#{feature_list}"
                  end)

                """
                Valid feature selectors:

                #{feature_sections}

                Features can include version specifiers, e.g. elixir=1.17
                """
              end).()

  @moduledoc """
  Creates a new project using any Mix project generator, then sets up development environment.

  ## Options

  All options are passed through to the specified task, except for the following:

  * `--devenv` - A comma-separated list of feature selectors

  ## Selectors

  #{@help_text}

  ## Examples

      # Create a Phoenix project with devenv
      mix devenv.new phx.new my_app --devenv postgres,redis

      # Create an Igniter project with devenv
      mix devenv.new igniter.new my_project --devenv elixir=1.17,postgres --install ash,ash_postgres

      # Create a basic Elixir project with devenv
      mix devenv.new new my_lib --devenv elixir=1.17,minio --sup

  This will:
  1. Create a new project using the specified generator
  2. Initialise devenv in the project
  3. Configure devenv.nix with requested features
  """

  @impl Mix.Task
  def run([]) do
    show_error_and_exit("""
    Required argument missing: embedded_task.

    Usage:

        mix devenv.new embedded_task project_name [options]

    Examples:

        mix devenv.new phx.new my_app --devenv postgres,redis
        mix devenv.new igniter.new my_app --devenv elixir=1.17,minio
    """)
  end

  def run([embedded_task | argv]) do
    ensure_devenv_available()

    {project_name, remaining_argv} = extract_project_name(argv)
    {devenv_options, task_argv} = extract_devenv_option(remaining_argv)
    features = parse_and_validate_devenv_options(devenv_options)

    Mix.shell().info("Creating project with #{embedded_task}...")

    # The embedded task might leave us in cwd or in the newly generated dir – to be sure
    # we save cwd before and work with that
    original_path = File.cwd!()

    # Protection against “random” errors like:
    # (UndefinedFunctionError) function Hex.Mix.overridden_deps/1 is undefined (module Hex.Mix is not available)
    Mix.ensure_application!(:hex)

    Mix.Task.run(embedded_task, [project_name | task_argv])

    # Continue in new project dir
    File.cd!(Path.join(original_path, project_name))

    Mix.shell().info("\nInitialising devenv...")

    case System.cmd("devenv", ["init"], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("devenv initialised successfully")

      {output, exit_code} ->
        show_error_and_exit("""
        Failed to initialise devenv (exit code: #{exit_code}):
        #{output}

        Make sure devenv is installed: https://devenv.sh/getting-started/
        """)
    end

    Mix.shell().info("Configuring devenv.nix with Elixir and requested features...")
    devenv_content = generate_devenv_nix(features, project_name)
    File.write!("devenv.nix", devenv_content)

    feature_names = Map.keys(features)

    Mix.shell().info("""

    Project #{project_name} created successfully!

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
      # Default: elixir feature only
      %{"elixir" => {true, nil}}
    else
      features =
        devenv_string
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.map(&parse_feature/1)
        |> validate_features()
        |> Map.new(fn {name, version} -> {name, {true, version}} end)

      # Ensure elixir is included
      Map.put_new(features, "elixir", {true, nil})
    end
  end

  defp parse_feature(feature_string) do
    case String.split(feature_string, "=", parts: 2) do
      [name] -> {name, nil}
      [name, version] -> {name, version}
    end
  end

  defp validate_features(features) do
    valid_features =
      @devenv_options
      |> Enum.flat_map(fn {_category, features} ->
        Map.keys(features) |> Enum.map(&Atom.to_string/1)
      end)

    Enum.each(features, fn {name, _version} ->
      unless name in valid_features do
        show_error_and_exit("""
        Invalid feature selector: #{name}

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

            mix devenv.new embedded_task project_name [options]
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
      |> get_features_by_category("languages")
      |> Enum.map_join("\n", fn {name, {_flag, version}} ->
        render_feature_template("languages", name, version, project_name)
      end)

    service_configs =
      features
      |> get_features_by_category("services")
      |> Enum.map_join("\n", fn {name, {_flag, version}} ->
        render_feature_template("services", name, version, project_name)
      end)

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

  defp get_features_by_category(features, category) do
    category_features =
      @devenv_options
      |> Map.get(String.to_atom(category), %{})
      |> Map.keys()
      |> Enum.map(&Atom.to_string/1)

    features
    |> Enum.filter(fn {name, _} -> name in category_features end)
  end

  defp render_feature_template(category, feature_name, version, project_name) do
    template_path = find_template_path(category, feature_name)

    unless File.exists?(template_path) do
      show_error_and_exit("""
      Template not found for #{category}/#{feature_name}

      Expected template at: #{template_path}
      """)
    end

    template_content = File.read!(template_path)
    assigns = [version: version, project_name: project_name]
    EEx.eval_string(template_content, assigns)
  end

  defp find_template_path(category, feature_name) do
    # With complex, nested embedded tasks, for some reason, sometimes this app gets unloaded – this way we
    # can ensure `priv_dir` will run successfully
    Mix.ensure_application!(:devenv_new)

    case :code.priv_dir(:devenv_new) do
      {:error, :bad_name} ->
        raise "Could not find the :devenv_new application in the code path."

      app_dir ->
        # app_dir is a charlist, so convert it to a string.
        # Then, join it with "priv" and the rest of the path.
        Path.join([
          to_string(app_dir),
          category,
          "#{feature_name}.eex"
        ])
    end
  end

  defp ensure_devenv_available do
    case System.cmd("devenv", ["--version"], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {_output, _exit_code} ->
        show_error_and_exit("""
        devenv is not installed or not available in PATH.

        Please install devenv first: https://devenv.sh/getting-started/
        """)
    end
  end

  defp show_error_and_exit(message) do
    Mix.shell().error(message)
    exit({:shutdown, 1})
  end
end
