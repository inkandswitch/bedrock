{
  description = "Ink & Switch Subduction sync servers on DigitalOcean (bedrock, coln-sync)";

  inputs = {
    command-utils.url = "git+https://tangled.org/expede.wtf/nix-command-utils";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

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
    targetSystem = "x86_64-linux";

    # One entry per droplet.  The attribute name is both the NixOS hostname
    # and the flake attribute (`nixos-rebuild --flake .#<name>`); the value
    # is the host module that sets the `bedrock.*` options.
    hosts = {
      bedrock   = ./hosts/bedrock.nix;
      coln-sync = ./hosts/coln-sync.nix;
    };

    unstablePkgs = import unstable {
      system = targetSystem;
      config.allowUnfree = true;
    };

    mkHost = hostname: hostModule:
      nixpkgs.lib.nixosSystem {
        system = targetSystem;

        specialArgs = {
          inherit hostname;
          unstable = unstablePkgs;
          # Raw flake inputs the shared modules need at eval time (the
          # on-server command menu is built from them in common.nix).
          inputs = { inherit command-utils subduction; };
        };

        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          subduction.nixosModules.default

          ./modules/common.nix
          hostModule
        ];
      };
  in {
    nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;
  } //
  flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs { inherit system; };
    cmd  = command-utils.cmd.${system};

    projectCommands = import ./nix/commands.nix {
      inherit pkgs system cmd;
      hostNames = builtins.attrNames hosts;
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
        echo "Target: ''${BEDROCK_TARGET:-bedrock}  (set BEDROCK_TARGET=coln-sync to switch)"
        menu
      '';
    };

    formatter = pkgs.nixpkgs-fmt;
  });
}
