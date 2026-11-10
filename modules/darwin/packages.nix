{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs._1password-cli
    pkgs.atuin
    pkgs.bat
    pkgs.bazelisk
    pkgs.bcftools
    pkgs.binwalk
    pkgs.coreutils
    pkgs.delta
    pkgs.direnv
    pkgs.docker
    pkgs.eza
    pkgs.fd
    pkgs.fzf
    pkgs.gh
    pkgs.ghidra
    pkgs.git
    pkgs.git-lfs
    pkgs.go
    pkgs.helix
    pkgs.htslib
    pkgs.hyperfine
    pkgs.jq
    pkgs.just
    pkgs.lazygit
    pkgs.mise
    pkgs.nixd
    pkgs.nixfmt
    pkgs.nixpacks
    pkgs.nodejs_24
    (pkgs.callPackage ../../pkgs/pcb.nix { })
    pkgs.python3
    pkgs.ripgrep
    pkgs.rustup
    pkgs.starship
    pkgs.tealdeer
    pkgs.tio
    pkgs.uv
    pkgs.zig
    pkgs.zoxide
  ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    greedyCasks = true;

    # `brew bundle` keeps a tap as long as a fully-qualified cask name still
    # references it, so these are documentation more than necessity. Trust is
    # handled by the `trusted: true` nix-darwin puts on every cask line.
    taps = [
      "anomalyco/tap"
    ];

    brews = [ "anomalyco/tap/opencode-v2" ];

    casks = [
      "1password@beta"
      "apparency"
      "betterdisplay"
      "blackhole-16ch"
      "blackhole-2ch"
      "brave-browser"
      "claude"
      "claude-code@latest"
      "font-iosevka-nerd-font"
      "ghostty"
      "hex-fiend"
      "hopper-disassembler"
      "karabiner-elements"
      "keka"
      "kicad"
      "orbstack"
      "orcaslicer"
      "paseo"
      "qlmarkdown"
      "quicklook-video"
      "setapp"
      "signal"
      "spotify"
      "steermouse"
      "suspicious-package"
      "syntax-highlight"
      "tailscale-app"
      "telegram"
      "tinycast"
      "utm"
      "xcodes-app"
      "zed"
    ];
  };
}
