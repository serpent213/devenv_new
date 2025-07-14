defmodule DevenvNewTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    original_cwd = File.cwd!()
    File.cd!(tmp_dir)

    on_exit(fn ->
      File.cd!(original_cwd)
    end)

    %{original_cwd: original_cwd, tmp_dir: tmp_dir}
  end

  describe "devenv.new wrapper" do
    test "generates correct devenv.nix for elixir+postgres", %{tmp_dir: tmp_dir} do
      project_name = "test_app"

      # Mock devenv init command success
      with_mock_devenv_init(tmp_dir, fn ->
        # Use the full Mix task to create the project
        capture_io(fn ->
          Mix.Task.reenable("test.mock")
          Mix.Tasks.Devenv.New.run(["test.mock", project_name, "--devenv", "postgres"])
        end)

        # Check that devenv.nix was created
        assert File.exists?("devenv.nix")

        # Compare generated content with fixture
        generated_content = File.read!("devenv.nix")
        fixture_content = File.read!(fixture_path("postgres.nix"))

        # Normalize whitespace for comparison
        assert normalize_nix_content(generated_content) == normalize_nix_content(fixture_content)
      end)
    end

    test "generates correct devenv.nix for all features", %{tmp_dir: tmp_dir} do
      project_name = "test_app"

      # Mock devenv init command success
      with_mock_devenv_init(tmp_dir, fn ->
        # Use the full Mix task to create the project with all features
        capture_io(fn ->
          Mix.Task.reenable("test.mock")

          Mix.Tasks.Devenv.New.run([
            "test.mock",
            project_name,
            "--devenv",
            "elixir=1.17,postgres,redis,minio,npm,bun"
          ])
        end)

        # Check that devenv.nix was created
        assert File.exists?("devenv.nix")

        # Compare generated content with fixture
        generated_content = File.read!("devenv.nix")
        fixture_content = File.read!(fixture_path("all_features.nix"))

        # Normalize whitespace for comparison
        assert normalize_nix_content(generated_content) == normalize_nix_content(fixture_content)
      end)
    end

    test "handles missing project name gracefully", %{tmp_dir: tmp_dir} do
      assert catch_exit(
               # Mock devenv init command success
               with_mock_devenv_init(tmp_dir, fn ->
                 capture_io(:stderr, fn ->
                   Mix.Task.reenable("test.mock")
                   Mix.Tasks.Devenv.New.run(["test.mock"])
                 end)
               end)
             ) == {:shutdown, 1}
    end

    test "handles missing embedded task gracefully", %{tmp_dir: tmp_dir} do
      assert catch_exit(
               # Mock devenv init command success
               with_mock_devenv_init(tmp_dir, fn ->
                 capture_io(:stderr, fn ->
                   Mix.Task.reenable("test.mock")
                   Mix.Tasks.Devenv.New.run([])
                 end)
               end)
             ) == {:shutdown, 1}
    end
  end

  # Helper functions
  defp fixture_path(filename) do
    Path.join([
      __DIR__,
      "fixtures",
      "devenv_nix",
      filename
    ])
  end

  defp normalize_nix_content(content) do
    content
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/\s*;\s*/, ";")
    |> String.replace(~r/\s*=\s*/, "=")
    |> String.replace(~r/\s*\{\s*/, "{")
    |> String.replace(~r/\s*\}\s*/, "}")
    |> String.trim()
  end

  defp with_mock_devenv_init(tmp_dir, test_fn) do
    # Create a mock devenv binary that always succeeds
    mock_devenv_path = Path.join(tmp_dir, "devenv")

    File.write!(mock_devenv_path, """
    #!/bin/bash
    case "$1" in
      init)
        echo "devenv initialised successfully"
        exit 0
        ;;
      --version)
        echo "devenv 1.6.1 (aarch64-darwin)"
        exit 0
        ;;
      *)
        echo "Mock devenv: unknown command $1"
        exit 1
        ;;
    esac
    """)

    File.chmod!(mock_devenv_path, 0o755)

    # Temporarily modify PATH to use our mock
    original_path = System.get_env("PATH")
    mock_dir = Path.dirname(mock_devenv_path)
    System.put_env("PATH", "#{mock_dir}:#{original_path}")

    try do
      test_fn.()
    after
      System.put_env("PATH", original_path)
      File.rm(mock_devenv_path)
    end
  end
end
