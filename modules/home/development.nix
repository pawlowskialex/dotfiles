{ identity, pkgs, ... }:
{
  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [
        "~/.orbstack/ssh/config"
      ];
      settings = {
        "*" = {
          # pocket-agent: keys on the phone are signed there; anything else is
          # forwarded to the 1Password agent (see services.pocket-agent in
          # modules/darwin/services.nix).
          IdentityAgent = "~/.pocket-agent/agent.sock";
        };
      };
    };

    git = {
      enable = true;
      lfs.enable = true;
      signing.format = null;
      settings = {
        user = {
          name = identity.fullName;
          inherit (identity) email;
        };
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        pull.rebase = true;
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
        column.ui = "auto";
        branch.sort = "-committerdate";
        fetch.prune = true;

        # Fetch GitHub over HTTPS (gh token) and only push over SSH, so
        # background fetches (e.g. Paseo's every-3-minutes `git fetch`) don't
        # ask pocket-agent for a signature.
        url."https://github.com/".insteadOf = [
          "git@github.com:"
          "ssh://git@github.com/"
        ];
        url."git@github.com:".pushInsteadOf = [
          "git@github.com:"
          "ssh://git@github.com/"
        ];
        credential."https://github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
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
  };

  xdg.configFile = {
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
