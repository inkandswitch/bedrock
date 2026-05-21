{
  description = "bedrock — DigitalOcean NixOS droplet with Subduction sync server";

  inputs = {
    command-utils.url = "git+https://codeberg.org/expede/nix-command-utils";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    subduction.url = "github:inkandswitch/subduction";
    subduction.inputs.nixpkgs.follows = "nixpkgs";

    unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    command-utils,
    disko,
    flake-utils,
    home-manager,
    nixpkgs,
    subduction,
    unstable,
    ...
  }: let
    hostname      = "bedrock";
    adminUsername = "expede";
    targetSystem  = "x86_64-linux";

    targetPkgs   = import nixpkgs { system = targetSystem; };
    unstablePkgs = import unstable {
      system = targetSystem;
      config.allowUnfree = true;
    };

    # On-server command bundle.  Same UX as the dev-shell menu, but the
    # underlying scripts run locally (no SSH).  Added to
    # `environment.systemPackages` in configuration.nix so every account on
    # bedrock gets `menu`, `logs:tail`, `deploy:gens`, … in their PATH.
    bedrockMenu = command-utils.commands.${targetSystem} [
      {
        commands = import ./nix/server-commands.nix {
          pkgs   = targetPkgs;
          system = targetSystem;
          cmd    = command-utils.cmd.${targetSystem};
        };
        packages = [];
      }
    ];
  in {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      system = targetSystem;

      specialArgs = {
        inherit hostname adminUsername bedrockMenu;
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
  } //
  flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs { inherit system; };
    cmd  = command-utils.cmd.${system};

    projectCommands = import ./nix/commands.nix {
      inherit pkgs system cmd;
    };

    command_menu = command-utils.commands.${system} [
      { commands = projectCommands; packages = []; }
    ];
  in {
    devShells.default = pkgs.mkShell {
      name = "bedrock-shell";

      nativeBuildInputs = [
        command_menu

        pkgs.curl
        pkgs.git
        pkgs.jq
        pkgs.nixos-rebuild
        pkgs.openssh
        pkgs.ripgrep
      ];

      shellHook = ''
        export BEDROCK_ROOT="$(pwd)"
        menu
      '';
    };

    formatter = pkgs.nixpkgs-fmt;
  });
}
