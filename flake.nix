{
  description = "Ink & Switch Subduction sync servers on DigitalOcean (bedrock, bedrock-staging, coln-sync)";

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

    # Pre-release Subduction for the staging droplet.  Repoint the ref (or
    # drop this input and use `subduction`) once the branch lands on main.
    subduction-staging.url = "github:inkandswitch/subduction/keyline-take-2";
    subduction-staging.inputs.nixpkgs.follows = "nixpkgs";

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
    subduction-staging,
    unstable,
    ...
  }: let
    targetSystem = "x86_64-linux";

    # One entry per droplet.  The attribute name is both the NixOS hostname
    # and the flake attribute (`nixos-rebuild --flake .#<name>`).  `module`
    # sets the `bedrock.*` options; `subduction` picks which Subduction flake
    # input supplies the NixOS module, binary, and on-server scripts.
    hosts = {
      bedrock         = { module = ./hosts/bedrock.nix;         inherit subduction; };
      bedrock-staging = { module = ./hosts/bedrock-staging.nix; subduction = subduction-staging; };
      coln-sync       = { module = ./hosts/coln-sync.nix;       inherit subduction; };
    };

    unstablePkgs = import unstable {
      system = targetSystem;
      config.allowUnfree = true;
    };

    mkHost = hostname: { module, subduction }:
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
          module
        ];
      };
  in {
    nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;

    # `nix flake check` builds every host's system closure.
    checks.${targetSystem} = nixpkgs.lib.mapAttrs
      (_: host: host.config.system.build.toplevel)
      self.nixosConfigurations;
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
        echo "Target: ''${BEDROCK_TARGET:-bedrock}  (set BEDROCK_TARGET=bedrock-staging|coln-sync to switch)"
        menu
      '';
    };

    formatter = pkgs.nixpkgs-fmt;
  });
}
