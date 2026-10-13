_: {
  imports = [
    ./modules/home/shell.nix
    ./modules/home/development.nix
    ./modules/home/desktop.nix
  ];

  home.stateVersion = "26.05";

  programs.man.generateCaches = false;
}
