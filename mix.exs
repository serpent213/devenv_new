defmodule DevenvNew.MixProject do
  use Mix.Project

  def project do
    [
      app: :devenv_new,
      version: "0.2.1",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      name: "devenv_new",
      docs: docs()
    ]
  end

  defp description,
    do: "Mix task wrapper to create projects in a new devenv.sh Nix environment"

  defp elixirc_paths(:test), do: ["lib", "test/fixtures"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      assets: %{"docs/assets" => "assets"},
      extras: [
        "README.md"
      ],
      formatters: ["html"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:igniter, "~> 0.5", only: :dev, optional: true},
      {:deps_changelog, "~> 0.3", only: :dev, optional: true, runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo",

        # Order might be important,
        # see https://elixirforum.com/t/cant-run-hex-mix-tasks-in-alias/65649/13
        fn _ -> Mix.ensure_application!(:hex) end,
        "hex.audit"
      ],

      # Mainly for testing deps_changelog and Igniter
      update: [
        # Isolated processes/Mix runners seem to work best when shuffling deps
        "cmd mix deps.changelog --before",
        "cmd mix deps.update igniter",
        "cmd mix igniter.upgrade --all",
        "cmd mix deps.changelog --after",
        fn _args ->
          Mix.shell().info(
            "Run `mix igniter.apply_upgrades igniter:old_version:new_version` to finish igniter update!"
          )
        end
      ]
    ]
  end

  defp package do
    [
      name: "devenv_new",
      maintainers: ["Steffen Beyer"],
      licenses: ["0BSD"],
      links: %{"GitHub" => "https://github.com/serpent213/devenv_new"}
    ]
  end
end
