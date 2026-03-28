{
  projectRootFile = "flake.nix";

  programs.nixfmt.enable = true;

  settings.global.excludes = [
    "nixbar/*"
    "*.json"
    "*.yaml"
    "*.yml"
  ];
}
