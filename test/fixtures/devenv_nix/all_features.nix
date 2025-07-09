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
  languages.javascript = {
    enable = true;
    bun.enable = true;
  };
  languages.elixir = {
    enable = true;
    package = pkgs.elixir_1_17;
  };
  languages.javascript = {
    enable = true;
    npm.enable = true;
  };

  # https://devenv.sh/processes/
  # processes.phx-server.exec = "mix phx.server";

  # https://devenv.sh/services/
  services.minio = {
    enable = true;
    accessKey = "minioadmin";
    secretKey = "minioadmin";
  };
  services.postgres = {
    enable = true;
    initialDatabases = [
      { name = "test_app_dev"; }
      { name = "test_app_test"; }
    ];
    initialScript = "CREATE USER postgres SUPERUSER;";
  };
  services.redis.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}