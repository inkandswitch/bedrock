# Per-host knobs for the shared Subduction server configuration.
#
# Everything under `bedrock.*` is the *only* thing that differs between
# deployments.  Each `hosts/<name>.nix` sets these; `modules/common.nix`
# consumes them.  Anything not declared here is shared verbatim.
{ lib, pkgs, ... }:
let
  inherit (lib) mkOption types;

  memoryCap = types.submodule {
    options = {
      memoryHigh = mkOption { type = types.str; description = "systemd `MemoryHigh` (throttle threshold)."; };
      memoryMax  = mkOption { type = types.str; description = "systemd `MemoryMax` (hard OOM ceiling)."; };
    };
  };

  account = types.submodule {
    options = {
      name  = mkOption { type = types.str;           description = "Full name (GECOS + git author)."; };
      email = mkOption { type = types.str;           description = "Git author email."; };
      shell = mkOption { type = types.package;       description = "Login shell package (pkgs.fish, pkgs.zsh, pkgs.bash)."; };
      keys  = mkOption { type = types.listOf types.str; description = "SSH public keys."; };
    };
  };
in {
  options.bedrock = {
    publicHostname = mkOption {
      type        = types.str;
      example     = "subduction.sync.inkandswitch.com";
      description = ''
        Public DNS name Caddy serves Subduction on.  Grafana is exposed at
        `dashboard.<publicHostname>`.  Also used as Subduction's
        `serviceName`.
      '';
    };

    acmeEmail = mkOption {
      type        = types.str;
      default     = "hello@brooklynzelenka.com";
      description = "Contact email for Let's Encrypt.";
    };

    accounts = mkOption {
      type        = types.attrsOf account;
      default     = {};
      description = ''
        Human accounts.  Every entry gets a `wheel` Unix user with
        passwordless sudo, its SSH keys, and a home-manager profile.
        Hosts add to the shared base set from `modules/accounts.nix`.
      '';
    };

    subduction = {
      memoryHigh = mkOption {
        type        = types.str;
        example     = "11G";
        description = ''
          systemd `MemoryHigh` for subduction.service.  Throttles
          allocations once crossed, so it must sit well above steady-state
          RSS while leaving room for the OS, observability stack, and page
          cache for the redb file.
        '';
      };

      memoryMax = mkOption {
        type        = types.str;
        example     = "13G";
        description = "systemd `MemoryMax` for subduction.service (hard OOM ceiling).";
      };

      maxResidentTrees = mkOption {
        type        = types.int;
        default     = 32768;
        description = ''
          Resident-tree cache cap.  A cap below the subscribed working set
          causes cache-miss hydration storms on cold-tree syncs, so size it
          to the expected concurrent tree count.
        '';
      };
    };

    observability = mkOption {
      type        = types.attrsOf memoryCap;
      description = ''
        Memory caps for the observability services, keyed by systemd unit
        name (`loki`, `prometheus`, `grafana`, `alloy`).  Uncapped these
        float freely, which is harmless on a large droplet but on a small
        one lets Loki compaction or Grafana crowd out Subduction.  Keep the
        sum plus `subduction.memoryMax` plus `sshMemoryMin` under RAM.
      '';
    };

    sshMemoryMin = mkOption {
      type        = types.str;
      default     = "768M";
      description = ''
        Hard memory reservation for `ssh.slice`.  The kernel reclaims and
        OOM-kills other cgroups before dipping below this, so admins can
        always log in even at ~100% RAM.
      '';
    };

    stateVersion = mkOption {
      type        = types.str;
      description = "NixOS + home-manager `stateVersion` (the release the host was first installed with).";
    };
  };
}
