{
  config,
  lib,
  pkgs,
  identity,
  ...
}:

let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    filter
    hasInfix
    splitString
    ;

  brew = config.homebrew.prefix;

  # PATH is environment.systemPath everywhere: every shell, and GUI apps through
  # the launchd agent below. Each runs path_helper for /etc/paths.d, then puts
  # systemPath back in front, since path_helper would leave the per-user
  # entries ($HOME, $USER: not in /etc/paths, see below) behind it.
  systemPath = config.environment.systemPath;
  systemPathEntries = splitString ":" systemPath;
  # Quoted so the shell expands the placeholders.
  systemPathWords = concatMapStringsSep " " (p: ''"${p}"'') systemPathEntries;

  # POSIX sh: bash and the launchd agent. Field splitting only applies to
  # expansions, hence the variable.
  posixPathInit = ''
    if [ -x /usr/libexec/path_helper ]; then
      eval "$(/usr/libexec/path_helper -s)"
    fi
    __dirs="${systemPath}:$PATH" __path= __ifs=$IFS
    IFS=:
    for __dir in $__dirs; do
      case ":$__path:" in
        *":$__dir:"*) ;;
        *) __path=''${__path:+$__path:}$__dir ;;
      esac
    done
    IFS=$__ifs
    export PATH="$__path"
    unset __dirs __path __ifs __dir
  '';

  # path_helper doesn't expand variables, so /etc/paths gets the rest.
  isPerUser = p: hasInfix "$HOME" p || hasInfix "$USER" p;
  pathsFile = pkgs.writeText "paths" (
    concatStringsSep "\n" (filter (p: !isPerUser p) systemPathEntries) + "\n"
  );
in
{
  environment = {
    shells = [ pkgs.fish ];

    variables = {
      EDITOR = "hx";
      # What `brew shellenv` sets besides PATH.
      HOMEBREW_PREFIX = brew;
      HOMEBREW_CELLAR = "${brew}/Cellar";
      HOMEBREW_REPOSITORY = brew;
    };

    systemPath = lib.mkMerge [
      # Ahead of the Nix profiles.
      (lib.mkBefore [
        "${brew}/bin"
        "${brew}/sbin"
        "$HOME/.cargo/bin"
        "$HOME/go/bin"
      ])
      # After the system's. Stock macOS has `/System/Cryptexes/App/usr/bin`
      # (safaridriver) in /etc/paths; OrbStack's own shell init appends its
      # dir.
      (lib.mkOrder 1300 [
        "/System/Cryptexes/App/usr/bin"
        "$HOME/.orbstack/bin"
      ])
    ];
  };

  # Each shell's prompt, completion and tool hooks (starship, zoxide, mise,
  # ...) come from home-manager (modules/home/shell.nix); this is only PATH.
  programs = {
    bash.enable = true;

    zsh = {
      enable = true;
      enableCompletion = false;
      enableBashCompletion = false;
      promptInit = "";
      # nix-darwin's /etc/zprofile replaces the stock one, which ran
      # path_helper.
      loginShellInit = ''
        if [ -x /usr/libexec/path_helper ]; then
          eval "$(/usr/libexec/path_helper -s)"
        fi
        path=(${systemPathWords} $path)
        typeset -U path
      '';
    };

    fish = {
      enable = true;
      useBabelfish = true;
      babelfishPackage = pkgs.babelfish;
      # fish's own path_helper reimplementation runs at login, but nixpkgs
      # patches that out on nix-darwin. __fish_macos_set_env leaves
      # pre-existing entries behind the files' ones, so put systemPath and then
      # $fish_user_paths back in front.
      loginShellInit = ''
        if test -x /usr/libexec/path_helper
            __fish_macos_set_env PATH /etc/paths /etc/paths.d
            if test -n "$MANPATH"
                __fish_macos_set_env MANPATH /etc/manpaths /etc/manpaths.d
            end
        end
        fish_add_path --global --move --path ${systemPathWords}
        __fish_reconstruct_path
      '';
    };
  };

  # In .bashrc, not /etc/bashrc: /etc/bashrc returns before any of its init
  # in non-interactive shells (Claude Code's Bash tool, `bash -c`), .bashrc's
  # extra lines run before that check.
  home-manager.users.${identity.username}.programs.bash.bashrcExtra = posixPathInit;

  # path_helper silently ignores /etc/paths when it is a symlink, which is
  # exactly what `environment.etc` produces — so write it as a regular file,
  # after the /etc activation step has had its say.
  #
  # Rolling back to a generation that manages /etc/paths via environment.etc
  # trips nix-darwin's "unmanaged file exists" check; `sudo rm /etc/paths`
  # first.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    printf >&2 'setting up /etc/paths...\n'
    if ! cmp --silent ${pathsFile} /etc/paths; then
      rm -f /etc/paths
      install -m 0644 ${pathsFile} /etc/paths
    fi
  '';

  # GUI apps inherit launchd's environment, not a shell's. Only system binaries
  # and sh builtins, so it doesn't have to wait for /nix/store to be mounted.
  launchd.user.agents.gui-path.serviceConfig = {
    ProgramArguments = [
      "/bin/sh"
      "-c"
      ''
        HOME=${identity.home} USER=${identity.username}
        ${posixPathInit}
        exec /bin/launchctl setenv PATH "$PATH"
      ''
    ];
    RunAtLoad = true;
    KeepAlive = false;
  };
}
