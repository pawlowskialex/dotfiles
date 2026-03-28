# nixpkgs

Nix-darwin + home-manager configuration for my macOS (aarch64-darwin) system.

## Structure

- `flake.nix` — Flake inputs (nixpkgs-unstable, nix-darwin, home-manager, fish-ai)
- `darwin.nix` — System-level config: packages, Homebrew casks, shell setup, macOS defaults
- `home.nix` — User config: git, fish, starship, fzf, helix, ghostty, lazygit, yazi, etc.
- `modules/fish-ai.nix` — Custom home-manager module for [fish-ai](https://github.com/Realiserad/fish-ai) with 1Password secret injection
- `nixbar/` — A small Swift menu bar app

## Usage

```sh
darwin-rebuild switch --flake ~/.nixpkgs#alex
```
