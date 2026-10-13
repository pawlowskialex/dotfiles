{
  config,
  lib,
  pkgs,
  identity,
  ...
}:

let
  inherit (lib)
    concatMapStrings
    concatMapStringsSep
    concatStringsSep
    filter
    hasInfix
    replaceStrings
    splitString
    ;

  # `environment.systemPath` carries literal `$HOME`/`$USER` placeholders for
  # the per-user profiles. /etc/paths is system-wide and path_helper does not
  # expand variables, so those entries stay out of the file and every consumer
  # below puts them back in front itself.
  systemPathEntries = splitString ":" config.environment.systemPath;
  isPerUser = p: hasInfix "$HOME" p || hasInfix "$USER" p;
  perUserPath = filter isPerUser systemPathEntries;

  pathsFile = pkgs.writeText "paths" (
    concatStringsSep "\n" (filter (p: !isPerUser p) systemPathEntries) + "\n"
  );

  # Quoted so the shell expands the placeholders.
  perUserPathWords = concatMapStringsSep " " (p: ''"${p}"'') perUserPath;
  perUserPathColon = concatStringsSep ":" perUserPath;

  commonShellInit =
    shell:
    concatMapStrings (cmd: ''eval "$(${cmd})"'' + "\n") [
      "/opt/homebrew/bin/brew shellenv"
      "${pkgs.starship}/bin/starship init ${shell}"
      "${pkgs.zoxide}/bin/zoxide init ${shell}"
      "${pkgs.mise}/bin/mise activate ${shell}"
    ];
in
{
  environment = {
    shells = [ pkgs.fish ];
    variables.EDITOR = "hx";

    # Stock macOS ships `/System/Cryptexes/App/usr/bin` in `/etc/paths` (it
    # holds safaridriver); nix-darwin's systemPath does not.
    systemPath = lib.mkOrder 1300 [ "/System/Cryptexes/App/usr/bin" ];
  };

  # path_helper keeps the entries it read from the files in front and appends
  # whatever else was already in PATH, which is where the per-user profiles
  # would end up. Each shell moves them back to the front in its own idiom.
  programs = {
    bash = {
      enable = true;
      # The stock /etc/profile already ran path_helper, but nix-darwin's
      # /etc/bashrc then re-exports PATH from setEnvironment, dropping
      # /etc/paths.d again. Run it once more; it is idempotent.
      interactiveShellInit = ''
        if [ -x /usr/libexec/path_helper ]; then
          eval "$(/usr/libexec/path_helper -s)"
          IFS=: read -ra __nix_dirs <<< "${perUserPathColon}:$PATH"
          PATH=
          for __nix_dir in "''${__nix_dirs[@]}"; do
            case ":$PATH:" in
              *":$__nix_dir:"*) ;;
              *) PATH="''${PATH:+$PATH:}$__nix_dir" ;;
            esac
          done
          unset __nix_dirs __nix_dir
        fi
      ''
      + commonShellInit "bash";
    };

    zsh = {
      enable = true;
      enableCompletion = false;
      enableBashCompletion = false;

      # The stock macOS /etc/zprofile runs path_helper; nix-darwin's
      # replacement does not, so without this a login shell never sees
      # /etc/paths or /etc/paths.d.
      loginShellInit = ''
        if [ -x /usr/libexec/path_helper ]; then
          eval "$(/usr/libexec/path_helper -s)"
          path=(${perUserPathWords} $path)
          typeset -U path
        fi
      '';

      promptInit = commonShellInit "zsh";
    };

    fish = {
      enable = true;
      useBabelfish = true;
      babelfishPackage = pkgs.babelfish;

      # fish has its own path_helper reimplementation and runs it at login, but
      # nixpkgs patches that out on nix-darwin. Do it ourselves instead.
      # __fish_macos_set_env appends pre-existing entries after the ones it
      # reads from the files, so reconstruct afterwards to give
      # $fish_user_paths its precedence back.
      loginShellInit = ''
        if test -x /usr/libexec/path_helper
            __fish_macos_set_env PATH /etc/paths /etc/paths.d
            if test -n "$MANPATH"
                __fish_macos_set_env MANPATH /etc/manpaths /etc/manpaths.d
            end
            fish_add_path --global --move --path ${perUserPathWords}
            __fish_reconstruct_path
        end
      '';
    };
  };

  # path_helper silently ignores /etc/paths when it is a symlink, which is
  # exactly what `environment.etc` produces — so write it as a regular file,
  # after the /etc activation step has had its say. The Nix directories come
  # first; path_helper appends /etc/paths.d entries after them.
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

  # GUI apps inherit launchd's environment, not a shell's. Unlike the
  # sync-launchd-env agent this replaces, it only calls system binaries, so it
  # does not have to wait for /nix/store to be mounted — and going through
  # path_helper means GUI apps get /etc/paths.d too, matching a login shell.
  # The agent is installed for this user alone, so resolving the per-user
  # placeholders here is fine.
  launchd.user.agents.gui-path = {
    serviceConfig = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''eval "$(/usr/libexec/path_helper -s)" && exec /bin/launchctl setenv PATH "${
          replaceStrings [ "$HOME" "$USER" ] [ identity.home identity.username ] perUserPathColon
        }:$PATH"''
      ];
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
}
