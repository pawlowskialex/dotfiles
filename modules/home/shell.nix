{ lib, pkgs, ... }:

let
  # Tools that install themselves outside Nix, in front of the Nix profiles.
  userPaths = [
    "$HOME/.cargo/bin"
    "$HOME/.lmstudio/bin"
    "$HOME/go/bin"
  ];
in
{
  programs = {
    bash = {
      enable = true;
      # bash's whole environment lives here; /etc/bashrc only sources
      # nix-darwin's set-environment. This sits above .bashrc's
      # interactive-only return, so non-interactive shells get it too (Claude
      # Code's Bash tool, anything running `bash -c`). Same PATH fish ends up
      # with: mise shims, Homebrew, userPaths, the Nix profiles, the rest of
      # /etc/paths and /etc/paths.d, then OrbStack as its own init has it.
      bashrcExtra = ''
        # path_helper puts /etc/paths first and pushes the per-user Nix
        # profiles back, so move them to the front again.
        if [ -x /usr/libexec/path_helper ]; then
          eval "$(/usr/libexec/path_helper -s)"
        fi
        PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:$PATH"
        PATH="${lib.concatStringsSep ":" userPaths}:$PATH"
        if [ -x /opt/homebrew/bin/brew ]; then
          eval "$(/opt/homebrew/bin/brew shellenv bash)"
        fi
        PATH="''${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH:$HOME/.orbstack/bin"

        # Inherited PATHs (and running twice, as a login shell does via
        # .bash_profile) leave duplicates; keep each entry's first place.
        __path=
        IFS=: read -ra __dirs <<< "$PATH"
        for __dir in "''${__dirs[@]}"; do
          case ":$__path:" in
            *":$__dir:"*) ;;
            *) __path="''${__path:+$__path:}$__dir" ;;
          esac
        done
        export PATH="$__path"
        unset __path __dirs __dir
      '';
    };
    zsh.enable = true;

    fish = {
      enable = true;
      shellAliases = {
        cat = "${pkgs.bat}/bin/bat";
        tree = "${pkgs.eza}/bin/eza --tree --icons";
      };
      shellInit = ''
        fish_add_path ${lib.concatMapStringsSep " " (p: ''"${p}"'') userPaths}
      '';
      interactiveShellInit = ''
        /opt/homebrew/bin/brew shellenv fish | source
        source ~/.orbstack/shell/init2.fish 2>/dev/null || true
        bind \co 'zi; commandline -f repaint'
      '';
    };

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        directory.style = "bold cyan";
        git_branch = {
          style = "bold purple";
        };
        git_status = {
          style = "bold red";
          format = "[$all_status$ahead_behind]($style) ";
        };
        nix_shell = {
          format = "via [$symbol$state]($style) ";
          style = "bold blue";
        };
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
        cmd_duration = {
          min_time = 2000;
          style = "bold yellow";
          format = "took [$duration]($style) ";
        };
      };
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    atuin = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        update_check = false;
        style = "compact";
        enter_accept = true;
      };
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
      # Atuin owns Ctrl-R; leave fzf's history widget unbound.
      historyWidget.command = "";
      defaultCommand = "${pkgs.fd}/bin/fd --type f --hidden --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--border"
        "--preview '${pkgs.bat}/bin/bat --color=always --style=numbers --line-range=:500 {}'"
      ];
      colors = {
        bg = "#1a1b26";
        fg = "#c0caf5";
        "bg+" = "#33467c";
        "fg+" = "#c0caf5";
        hl = "#7dcfff";
        "hl+" = "#7dcfff";
        info = "#e0af68";
        prompt = "#7dcfff";
        pointer = "#bb9af7";
        marker = "#9ece6a";
        spinner = "#bb9af7";
        header = "#565f89";
      };
    };

    mise = {
      enable = true;
      enableFishIntegration = true;
    };

    eza = {
      enable = true;
      enableFishIntegration = true;
      icons = "auto";
      git = true;
      extraOptions = [ "--group-directories-first" ];
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    bat = {
      enable = true;
      config = {
        style = "numbers,changes,header";
      };
    };

    yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";
      settings.manager = {
        show_hidden = true;
        sort_by = "modified";
        sort_dir_first = true;
      };
    };
  };

  xdg.configFile."fish/conf.d/tokyonight.fish".text = ''
    # TokyoNight Night
    set -g fish_color_normal          c0caf5
    set -g fish_color_command         7dcfff
    set -g fish_color_keyword         bb9af7
    set -g fish_color_quote           e0af68
    set -g fish_color_redirection     c0caf5
    set -g fish_color_end             ff9e64
    set -g fish_color_error           f7768e
    set -g fish_color_param           9d7cd8
    set -g fish_color_comment         565f89
    set -g fish_color_selection       --background=33467C
    set -g fish_color_search_match    --background=33467C
    set -g fish_color_operator        9ece6a
    set -g fish_color_escape          bb9af7
    set -g fish_color_autosuggestion  565f89
    set -g fish_pager_color_progress     565f89
    set -g fish_pager_color_prefix       7dcfff
    set -g fish_pager_color_completion   c0caf5
    set -g fish_pager_color_description  565f89
  '';
}
