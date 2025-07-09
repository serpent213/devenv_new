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
  languages.elixir.enable = true;

  # https://devenv.sh/processes/
  # processes.phx-server.exec = "mix phx.server";

  # https://devenv.sh/services/
  services.postgres = {
    enable = true;
    initialDatabases = [
      { name = "test_app_dev"; }
      { name = "test_app_test"; }
    ];
    initialScript = "CREATE USER postgres SUPERUSER;";
  };

  # See full reference at https://devenv.sh/reference/options/
}