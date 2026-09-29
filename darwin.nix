{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:

with lib;

let
  user = config.users.users.alex;
  exportVariables = mapAttrsToList (n: v: ''export ${n}="${v}"'') config.environment.variables;
  resolvedSystemPath =
    replaceStrings [ "$HOME" "$USER" ] [ user.home user.name ]
      config.environment.systemPath;
  commonShellInit =
    shell:
    lib.concatMapStrings (cmd: ''eval "$(${cmd})"'' + "\n") [
      "/opt/homebrew/bin/brew shellenv"
      "${pkgs.starship}/bin/starship init ${shell}"
      "${pkgs.zoxide}/bin/zoxide init ${shell}"
      "${pkgs.mise}/bin/mise activate ${shell}"
    ];
in
{
  nix = {
    # Disable nix-channel entirely; <nixpkgs> comes from the flake input.
    # Without this, processes that don't inherit the shell's NIX_PATH fall
    # back to root's stale channel profile from the pre-flake install.
    channel.enable = false;
    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
      "darwin=${inputs.darwin}"
    ];
    package = pkgs.nixVersions.stable;
    settings = {
      # Same pin at the daemon level (nix.conf), so it applies even when
      # NIX_PATH is not set in the environment.
      nix-path = [
        "nixpkgs=${inputs.nixpkgs}"
        "darwin=${inputs.darwin}"
      ];
      "trusted-users" = [
        "alex"
        "root"
        "@admin"
        "@wheel"
      ];
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    stateVersion = 5;
    primaryUser = "alex";

    defaults = {
      dock = {
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.2;
        tilesize = 50;
        static-only = false;
        showhidden = false;
        show-recents = false;
        show-process-indicators = true;
        orientation = "bottom";
        mru-spaces = false;
      };

      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXEnableExtensionChangeWarning = false;
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        AppleInterfaceStyle = "Dark";
        InitialKeyRepeat = 10;
        KeyRepeat = 1;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };

      screencapture.location = "~/Desktop";
    };

    build.setEnvironment = pkgs.writeText "set-environment" ''
      export __NIX_DARWIN_SET_ENVIRONMENT_DONE=1

      ${concatStringsSep "\n" exportVariables}
      ${config.environment.extraInit}
    '';
  };

  users.users.alex = {
    name = "alex";
    home = "/Users/alex";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.alex = import ./home.nix;
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };
    greedyCasks = true;
    casks = [
      "1password@beta"
      "apparency"
      "balenaetcher"
      "betterdisplay"
      "bitwarden"
      "blackhole-16ch"
      "blackhole-2ch"
      "brave-browser"
      "claude-code"
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
      "raycast"
      "rectangle"
      "roblox"
      "robloxstudio"
      "setapp"
      "signal"
      "slack"
      "spotify"
      "stablyai/orca/orca"
      "steermouse"
      "suspicious-package"
      "syntax-highlight"
      "tailscale-app"
      "telegram"
      "utm"
      "visual-studio-code"
      "xcodes-app"
      "zed"
      "zoom"
      "zwift"
    ];
  };

  environment = {
    shells = [ pkgs.fish ];
    systemPackages = [
      pkgs._1password-cli
      pkgs.atuin
      pkgs.bat
      pkgs.bazelisk
      pkgs.bcftools
      pkgs.bitwarden-cli
      pkgs.binwalk
      pkgs.bws
      pkgs.coreutils
      pkgs.delta
      pkgs.devbox
      pkgs.direnv
      pkgs.docker
      pkgs.eza
      pkgs.fd
      pkgs.fzf
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
    variables = {
      EDITOR = "hx";
    };
    etc = {
      "paths".text = concatStringsSep "\n" (splitString ":" config.environment.systemPath);
    };
  };

  programs = {
    bash = {
      enable = true;
      interactiveShellInit = commonShellInit "bash";
    };
    zsh = {
      enable = true;
      enableCompletion = false;
      enableBashCompletion = false;
      promptInit = commonShellInit "zsh";
    };
    fish = {
      enable = true;
      useBabelfish = true;
      babelfishPackage = pkgs.babelfish;
    };
  };

  # SSH agent that keeps private keys on the phone (approved over Tailscale).
  # Keys the phone does not have are forwarded to the 1Password agent.
  services.pocket-agent = {
    enable = true;
    settings.upstream_socket = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };

  launchd.user.agents.sync-launchd-env = {
    command = toString (
      pkgs.writeShellScript "sync-launchd-env" ''
        while [ ! -d /nix/store ]; do
          sleep 1
        done
        launchctl setenv PATH '${resolvedSystemPath}'
      ''
    );
    serviceConfig.KeepAlive = false;
    serviceConfig.RunAtLoad = true;
  };
}
