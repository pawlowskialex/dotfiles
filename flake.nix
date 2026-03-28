{
  description = "nix system configuration";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fish-ai = {
      url = "github:Realiserad/fish-ai";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      darwin,
      home-manager,
      treefmt-nix,
      ...
    }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      nixbar = pkgs.callPackage ./nixbar/package.nix { };
    in
    {
      packages.${system}.nixbar = nixbar;
      darwinConfigurations = {
        alex = darwin.lib.darwinSystem {
          inherit system;
          modules = [
            home-manager.darwinModules.home-manager
            ./darwin.nix
          ];
          specialArgs = { inherit inputs nixpkgs nixbar; };
        };
      };

      formatter.${system} = treefmtEval.config.build.wrapper;

      checks.${system} = {
        formatting = treefmtEval.config.build.check self;
        statix = pkgs.runCommand "statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
          statix check ${self} -c ${self}/statix.toml
          touch $out
        '';
        deadnix = pkgs.runCommand "deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
          deadnix --fail --exclude ${self}/nixbar ${self}
          touch $out
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.statix
          pkgs.deadnix
          treefmtEval.config.build.wrapper
        ];
      };
    };
}
