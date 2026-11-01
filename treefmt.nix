{
  projectRootFile = "flake.nix";

  programs.nixfmt.enable = true;

  settings.global.excludes = [
    "*.json"
    "*.yaml"
    "*.yml"
  ];
}
