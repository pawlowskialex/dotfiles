{
  config,
  inputs,
  nixbar,
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
  commonShellInit = shell: ''
    eval "$(${pkgs.starship}/bin/starship init ${shell})"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    eval "$(${pkgs.zoxide}/bin/zoxide init ${shell})"
    eval "$(${pkgs.mise}/bin/mise activate ${shell})"
  '';
in
{
  nix = {
    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
      "darwin=${inputs.darwin}"
    ];
    package = pkgs.nixVersions.stable;
    settings = {
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
    casks = [
      "apparency"
      "1password"
      "apparency"
      "balenaetcher"
      "bambu-studio"
      "betterdisplay"
      "blackhole-16ch"
      "blackhole-2ch"
      "brave-browser"
      "claude"
      "font-iosevka-nerd-font"
      "freecad"
      "ghostty"
      "handbrake-app"
      "hex-fiend"
      "hopper-disassembler"
      "jetbrains-toolbox"
      "karabiner-elements"
      "keka"
      "lm-studio"
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
      pkgs.atuin
      pkgs.bat
      pkgs.bcftools
      pkgs.binwalk
      pkgs._1password-cli
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
      pkgs.watchman
      pkgs.yazi
      pkgs.zig
      pkgs.zoxide
      nixbar
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
