defmodule DevenvNew.MixProject do
  use Mix.Project

  def project do
    [
      app: :devenv_new,
      version: "0.2.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/fixtures"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:igniter, "~> 0.5", only: [:dev]},
      {:deps_changelog, github: "serpent213/deps_changelog", branch: "master", only: [:dev]}
    ]
  end

  defp aliases do
    [
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
