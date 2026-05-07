{
  description = "bedrock — DigitalOcean NixOS droplet with Subduction sync server";

  inputs = {
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    subduction.url = "github:inkandswitch/subduction/v0.14.0-nightly.2026-05-07";
    subduction.inputs.nixpkgs.follows = "nixpkgs";

    unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, unstable, disko, home-manager, subduction, ... }:
    let
      system        = "x86_64-linux";
      hostname      = "bedrock";
      adminUsername = "expede";

      unstablePkgs = import unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit hostname adminUsername;
          unstable = unstablePkgs;
        };

        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          subduction.nixosModules.default

          ./configuration.nix
          ./digitalocean.nix
          ./disk-config.nix
          ./hardware-configuration.nix
          ./nix.nix
        ];
      };
    };
}
