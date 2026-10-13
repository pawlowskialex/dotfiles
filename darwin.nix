{ inputs, ... }:

let
  identity = import ./user.nix;
in
{
  imports = [
    ./modules/darwin/nix.nix
    ./modules/darwin/macos.nix
    ./modules/darwin/packages.nix
    ./modules/darwin/shells.nix
    ./modules/darwin/services.nix
  ];

  # Hand `identity` to every darwin module imported above.
  _module.args = { inherit identity; };

  system = {
    stateVersion = 5;
    primaryUser = identity.username;
  };

  users.users.${identity.username} = {
    name = identity.username;
    inherit (identity) home;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs identity; };
    users.${identity.username} = import ./home.nix;
  };
}
