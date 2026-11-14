# nixpkgs

nix-darwin + home-manager configuration for my Mac (aarch64-darwin).

## Structure

- `flake.nix` — inputs (nixpkgs-unstable, nix-darwin, home-manager, treefmt-nix,
  pocket-agent, nix-rosetta-builder), the `alex` system, formatter and checks
- `user.nix` — machine identity (username, home, name, email), passed to every
  module as `identity`
- `darwin.nix` — system entry point: imports `modules/darwin`, wires up home-manager
- `home.nix` — home-manager entry point: imports `modules/home`
- `modules/darwin/`
  - `packages.nix` — system packages and Homebrew (casks are zapped when removed here)
  - `shells.nix` — PATH for every shell and for GUI apps, from `environment.systemPath`
  - `macos.nix` — macOS defaults, Touch ID for sudo
  - `nix.nix` — Nix settings, NIX_PATH pin, GC
  - `services.nix` — pocket-agent (phone-held SSH keys, 1Password fallback)
  - `linux-builder.nix` — Rosetta Linux builder for aarch64/x86_64-linux
- `modules/home/`
  - `shell.nix` — fish, starship, atuin, fzf, eza, yazi, ...
  - `development.nix` — git, ssh, delta, lazygit, helix, Claude Code settings
  - `desktop.nix` — Ghostty, Karabiner-Elements rules
  - `opencode.nix` — OpenCode behind cliffcompaction proxies
- `pkgs/` — packages not in nixpkgs

## Usage

```sh
sudo darwin-rebuild switch --flake ~/.nixpkgs#alex
nix fmt          # format
nix flake check  # formatting, statix, deadnix
```
