_:
let
  # Global instructions for every coding agent: what this machine has and how
  # to install things on it. Read-only links into the store, so agents can't
  # append to them; edit here instead.
  instructions = ''
    # Environment

    macOS on Apple Silicon (aarch64-darwin). The whole system is declared with
    nix-darwin + home-manager in ~/.nixpkgs; don't change it imperatively.

    ## Installing things

    - Never `brew install`. Homebrew only holds the GUI casks listed in
      ~/.nixpkgs, and anything else is removed on the next rebuild.
    - Never install Python packages system-wide: no `pip install` outside a
      virtualenv, no `--user`, `--break-system-packages` or `sudo pip`. The
      `pip3` on PATH is Apple's /usr/bin/pip3; leave it alone.
    - No `npm install -g`, `cargo install`, `go install` or `curl | sh`
      installers either.
    - For a tool you need for a command or two: `nix run nixpkgs#<pkg> -- <args>`
      or `nix shell nixpkgs#<pkg> nixpkgs#<pkg2> -c <cmd>`. Find package names
      with `nix search nixpkgs <name>`.
    - If it should be installed permanently, tell me and suggest the line for
      ~/.nixpkgs/modules/darwin/packages.nix. Don't run `darwin-rebuild` (it
      needs sudo).

    ## Languages

    - Python: uv. In projects `uv run`, `uv add`, `uv sync`; for standalone
      scripts `uv run --with <pkg> script.py` or inline script metadata; for
      Python CLIs `uvx <tool>`. `uv python install` if a project needs another
      Python version.
    - Node: Node 24 with npm. Dependencies stay in the project; `npx` for
      one-off CLIs.
    - Rust via rustup/cargo; Go and Zig are installed.
    - Projects with a flake.nix, shell.nix or .envrc: run commands in their
      environment with `nix develop -c <cmd>` or `direnv exec . <cmd>`. direnv
      is not hooked into your shell.

    ## Containers and Linux

    - Docker is OrbStack: `docker`, `docker compose` and `docker buildx` work
      with no setup.
    - Nix builds for aarch64-linux and x86_64-linux go to a Linux builder VM
      automatically (the first one boots it, which takes a minute).

    ## Also on PATH

    GNU coreutils ahead of the BSD ones (`stat`, `date`, `ls` etc. take GNU
    flags; `sed` is still BSD), rg, fd, jq, gh, just, hyperfine, bazelisk.
  '';
in
{
  home.file.".claude/CLAUDE.md".text = instructions;
  xdg.configFile."opencode/AGENTS.md".text = instructions;
}
