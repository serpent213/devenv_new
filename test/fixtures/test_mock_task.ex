defmodule Mix.Tasks.Test.Mock do
  @moduledoc """
  Mock Mix task for testing devenv.new wrapper.
  Simulates project generators like phx.new, igniter.new, etc.
  """
  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    case argv do
      [project_name | _rest] ->
        File.mkdir_p!(project_name)
        File.cd!(project_name)

        # Create a minimal project structure
        File.write!("mix.exs", """
        defmodule #{Macro.camelize(project_name)}.MixProject do
          use Mix.Project

          def project do
            [
              app: :#{project_name},
              version: "0.1.0",
              elixir: "~> 1.16"
            ]
          end
        end
        """)

        # Create basic lib structure
        File.mkdir_p!("lib")

        File.write!("lib/#{project_name}.ex", """
        defmodule #{Macro.camelize(project_name)} do
          def hello do
            :world
          end
        end
        """)

        Mix.shell().info("* creating #{project_name}")

      [] ->
        Mix.shell().error("Expected project name as first argument")
        exit({:shutdown, 1})
    end
  end
end
