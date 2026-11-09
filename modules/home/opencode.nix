{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Not in nixpkgs. Transparent API proxy that keeps long agent sessions under
  # a token budget by truncating old turns, never summarizing them
  # (https://arxiv.org/abs/2609.26779).
  cliffcompaction = pkgs.python3Packages.buildPythonApplication {
    pname = "cliffcompaction";
    version = "0.1.0-unstable-2026-09-23";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "nguyenvuthientrang";
      repo = "cliffcompaction";
      rev = "b48d660ae3c1f6037094d6cfc6b5d9f5938a7957";
      hash = "sha256-ZP4T6BZUFGDk9pVKKoM0RBZztHjE7tRiiMKsYpATz/U=";
    };

    build-system = [ pkgs.python3Packages.hatchling ];
    dependencies = with pkgs.python3Packages; [
      httpx
      starlette
      uvicorn
    ];
    nativeCheckInputs = [ pkgs.python3Packages.pytestCheckHook ];
    # Shells out to launchctl, which the build sandbox doesn't have.
    disabledTests = [ "test_service_running_shape" ];
  };

  # The proxy forwards to `upstream + request path`, so each provider host
  # gets its own instance. `cliff watch --port <port>` shows what it compacts.
  cliffInstances = {
    zai = {
      port = 8306;
      upstream = "https://api.z.ai";
      baseURL = "http://127.0.0.1:8306/api/coding/paas/v4";
    };
    openrouter = {
      port = 8307;
      upstream = "https://openrouter.ai";
      baseURL = "http://127.0.0.1:8307/api/v1";
    };
  };
in
{
  home.packages = [ cliffcompaction ];

  launchd.agents = lib.mapAttrs' (
    name: instance:
    lib.nameValuePair "cliffcompaction-${name}" {
      enable = true;
      config = {
        ProgramArguments = [
          "${cliffcompaction}/bin/cliff"
          "serve"
          "--port"
          (toString instance.port)
          "--openai-upstream"
          instance.upstream
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/cliffcompaction-${name}.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/cliffcompaction-${name}.log";
      };
    }
  ) cliffInstances;

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    providers = {
      zai-coding-plan.settings = { inherit (cliffInstances.zai) baseURL; };
      openrouter.settings = { inherit (cliffInstances.openrouter) baseURL; };
    };
    # The proxy compacts instead. OpenCode's own compaction rewrites history in
    # place, which breaks the prefix matching the proxy relies on.
    compaction.auto = false;
  };
}
