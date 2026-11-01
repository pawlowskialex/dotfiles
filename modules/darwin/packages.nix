{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs._1password-cli
    pkgs.atuin
    pkgs.bat
    pkgs.bazelisk
    pkgs.bcftools
    pkgs.binwalk
    pkgs.codex
    pkgs.coreutils
    pkgs.delta
    pkgs.devbox
    pkgs.direnv
    pkgs.docker
    pkgs.eza
    pkgs.fd
    pkgs.fzf
    pkgs.gh
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
      "abue-ammar/tinycast"
    ];

    # Not in nixpkgs. A much faster xip(1) for unpacking Xcode.
    brews = [ "unxip" ];

    casks = [
      "1password@beta"
      "abue-ammar/tinycast/tinycast"
      "apparency"
      "balenaetcher"
      "betterdisplay"
      "blackhole-16ch"
      "blackhole-2ch"
      "brave-browser"
      "claude-code@latest"
      "claude"
      "font-iosevka-nerd-font"
      "ghostty"
      "handbrake-app"
      "hex-fiend"
      "hopper-disassembler"
      "karabiner-elements"
      "keka"
      "orbstack"
      "orcaslicer"
      "qlmarkdown"
      "quicklook-video"
      "paseo"
      "setapp"
      "signal"
      "slack"
      "spotify"
      "steermouse"
      "suspicious-package"
      "syntax-highlight"
      "tailscale-app"
      "telegram"
      "utm"
      "visual-studio-code"
      "xcodes-app"
      "zed"
    ];
  };
}
