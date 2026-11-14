{ lib, pkgs, ... }:

let
  # Coding agents run commands through these shells. They get PATH and
  # nothing interactive: no aliases (plain `ls`, `cat`), prompt or key
  # bindings, no atuin recording their commands into the history, no zoxide
  # learning their directories, no direnv (`direnv exec . cmd` instead).
  # Claude Code and OpenCode mark their shells (OpenCode's have a terminal);
  # other agents' have none on stdin.
  agentMarkers = [
    "CLAUDECODE"
    "OPENCODE_TERMINAL"
  ];
  isAgentPosix = ''[ -n "${lib.concatMapStrings (v: "\${${v}-}") agentMarkers}" ] || [ ! -t 0 ]'';
  isAgentFish = lib.concatMapStrings (v: "set -q ${v}; or ") agentMarkers + "not isatty stdin";
in
{
  # PATH for every shell is modules/darwin/shells.nix. For agents each rc file
  # stops right after it.
  programs = {
    bash = {
      enable = true;
      bashrcExtra = lib.mkAfter "if ${isAgentPosix}; then return; fi";
    };
    zsh = {
      enable = true;
      initContent = lib.mkBefore "if ${isAgentPosix}; then return; fi";
    };

    fish = {
      enable = true;
      shellInit = "if ${isAgentFish}; return; end";
      shellAliases = {
        cat = "${pkgs.bat}/bin/bat";
        tree = "${pkgs.eza}/bin/eza --tree --icons";
      };
      interactiveShellInit = ''
        bind \co 'zi; commandline -f repaint'
      '';
    };

    starship = {
      enable = true;
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

    zoxide.enable = true;

    atuin = {
      enable = true;
      settings = {
        update_check = false;
        style = "compact";
        enter_accept = true;
      };
    };

    fzf = {
      enable = true;
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

    eza = {
      enable = true;
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
      shellWrapperName = "y";
      settings.manager = {
        show_hidden = true;
        sort_by = "modified";
        sort_dir_first = true;
      };
    };
  };

  # Shadows direnv's own vendor_conf.d/direnv.fish, which hooks every fish
  # shell before config.fish runs, agents' included. Home Manager hooks the
  # interactive ones in config.fish.
  xdg.configFile."fish/conf.d/direnv.fish".text = "";

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
