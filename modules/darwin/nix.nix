{ inputs, pkgs, ... }:
{
  nix = {
    # Disable nix-channel entirely; <nixpkgs> comes from the flake input.
    # Without this, processes that don't inherit the shell's NIX_PATH fall
    # back to root's stale channel profile from the pre-flake install.
    channel.enable = false;
    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
      "darwin=${inputs.darwin}"
    ];
    package = pkgs.nixVersions.stable;
    settings = {
      # Same pin at the daemon level (nix.conf), so it applies even when
      # NIX_PATH is not set in the environment.
      nix-path = [
        "nixpkgs=${inputs.nixpkgs}"
        "darwin=${inputs.darwin}"
      ];
      trusted-users = [
        "root"
        "@admin"
        "@wheel"
      ];
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    # Keep the store from growing without bound. Weekly, and only generations
    # older than 30 days, so rolling back a bad switch stays possible.
    gc = {
      automatic = true;
      interval = {
        Weekday = 7;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      interval = {
        Weekday = 7;
        Hour = 4;
        Minute = 0;
      };
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };
}
