{
  pkgs,
  inputs,
  ...
}:
{
  imports = [ ./modules/fish-ai.nix ];

  home.stateVersion = "26.05";

  programs = {
    man.generateCaches = false;

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [
        "~/.orbstack/ssh/config"
      ];
      matchBlocks = {
        "*" = {
          extraOptions = {
            IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          };
        };
        "*.github.com" = {
          hostname = "%h";
        };
      };
    };

    git = {
      enable = true;
      lfs.enable = true;
      signing.format = null;
      settings = {
        user = {
          name = "Alex Pawlowski";
          email = "pawlowski.alx@gmail.com";
        };
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        pull.rebase = true;
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
        column.ui = "auto";
        branch.sort = "-committerdate";
        fetch.prune = true;
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        dark = true;
        side-by-side = true;
        line-numbers = true;
      };
    };

    bash.enable = true;
    zsh.enable = true;

    fish = {
      enable = true;
      shellAliases = {
        cat = "${pkgs.bat}/bin/bat";
        tree = "${pkgs.eza}/bin/eza --tree --icons";
      };
      shellInit = ''
        fish_add_path ~/.lmstudio/bin
        fish_add_path ~/go/bin
        fish_add_path ~/.cargo/bin
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

    fish-ai = {
      enable = true;
      package = inputs.fish-ai;
      configuration = "openrouter";
      contexts = {
        openrouter = {
          provider = "self-hosted";
          server = "https://openrouter.ai/api/v1";
          model = "stepfun/step-3.5-flash";
        };
      };
      secrets = {
        openrouter = "op://Personal/OpenRouter CLI Tool Key/password";
      };
    };
  };

  xdg.configFile = {
    "fish/conf.d/tokyonight.fish".text = ''
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

    "ghostty/config".text = ''
      theme = tokyonight
      font-family = Iosevka Nerd Font Mono
      font-size = 14
      window-padding-x = 8
      window-padding-y = 8
      macos-titlebar-style = tabs
      copy-on-select = true
      shell-integration = fish
      cursor-style = bar
      cursor-style-blink = false
      background-opacity = 0.95
      background-blur-radius = 20
      unfocused-split-opacity = 0.85
      mouse-hide-while-typing = true
    '';

    "lazygit/config.yml".text = ''
      gui:
        nerdFontsVersion: "3"
        theme:
          activeBorderColor:
            - "#7dcfff"
            - bold
          inactiveBorderColor:
            - "#565f89"
          searchingActiveBorderColor:
            - "#e0af68"
            - bold
          optionsTextColor:
            - "#7dcfff"
          selectedLineBgColor:
            - "#33467c"
          cherryPickedCommitFgColor:
            - "#7dcfff"
          cherryPickedCommitBgColor:
            - "#33467c"
          unstagedChangesColor:
            - "#f7768e"
          defaultFgColor:
            - "#c0caf5"
      git:
        paging:
          colorArg: always
          pager: delta --dark --paging=never
    '';

    "helix/config.toml".text = ''
      theme = "tokyonight"

      [editor]
      line-number = "relative"
      cursorline = true
      bufferline = "multiple"
      color-modes = true
      true-color = true
      rulers = [100]
      idle-timeout = 0

      [editor.cursor-shape]
      insert = "bar"
      normal = "block"
      select = "underline"

      [editor.indent-guides]
      render = true
      character = "│"

      [editor.lsp]
      display-inlay-hints = true

      [editor.statusline]
      left = ["mode", "spinner", "file-name", "file-modification-indicator"]
      right = ["diagnostics", "selections", "register", "position", "file-encoding"]

      [editor.whitespace.render]
      tab = "all"

      [keys.normal]
      C-s = ":w"
      C-q = ":q"
    '';
  };
}
