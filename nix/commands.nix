# Dev-shell commands.
#
# Most commands target a remote droplet.  Two environment variables select
# which one:
#
#   BEDROCK_TARGET  flake attribute / NixOS hostname (`bedrock`, `coln-sync`).
#                   Default: `bedrock`.  Drives `--flake .#$TARGET` and the
#                   public-URL lookups.
#   BEDROCK_HOST    SSH destination.  Default: same as $TARGET, i.e. an
#                   alias in `~/.ssh/config` (`Host bedrock`, `Host coln-sync`).
#
#     export BEDROCK_TARGET=coln-sync
#     export BEDROCK_HOST=expede@coln.sync.inkandswitch.com   # optional
#
# Run `menu` inside `nix develop` to list every command.
{
  pkgs,
  system,
  cmd,
  hostNames,
}: let
  defaultTarget = "bedrock";

  # Pinned tool paths for reproducibility.
  coreutils     = pkgs.coreutils;
  curl          = "${pkgs.curl}/bin/curl";
  nix           = "${pkgs.nix}/bin/nix";
  nixos-rebuild = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
  ripgrep       = "${pkgs.ripgrep}/bin/rg";
  ssh           = "${pkgs.openssh}/bin/ssh";

  # Common prologue: resolve $TARGET (validated against the flake's hosts)
  # and $HOST (SSH destination).
  resolveHost = ''
    TARGET="''${BEDROCK_TARGET:-${defaultTarget}}"
    case "$TARGET" in
      ${lib.concatStringsSep "|" hostNames}) ;;
      *) echo "BEDROCK_TARGET=$TARGET is not one of: ${lib.concatStringsSep " " hostNames}" >&2; exit 2 ;;
    esac
    HOST="''${BEDROCK_HOST:-$TARGET}"
  '';

  # Public DNS name of $TARGET, read from the host's `bedrock.publicHostname`
  # so the dev shell never hardcodes a URL.
  resolvePublic = ''
    PUBLIC="$(${nix} eval --raw "''${BEDROCK_ROOT:-.}#nixosConfigurations.$TARGET.config.bedrock.publicHostname")"
  '';

  inherit (pkgs) lib;

  # ── Logs ────────────────────────────────────────────────────────────
  logs = {
    "logs:tail" = cmd "Tail Subduction logs live" ''
      ${resolveHost}
      ${ssh} "$HOST" 'sudo journalctl -o cat -u subduction -f'
    '';

    "logs:since" = cmd "Subduction logs since a time window (default: 10 minutes ago)" ''
      ${resolveHost}
      SINCE="''${1:-10 minutes ago}"
      ${ssh} "$HOST" "sudo journalctl -o cat -u subduction --since '$SINCE' --no-pager"
    '';

    "logs:errors" = cmd "Recent Subduction errors only (default since 1 hour ago)" ''
      ${resolveHost}
      SINCE="''${1:-1 hour ago}"
      ${ssh} "$HOST" "sudo journalctl -o cat -u subduction --since '$SINCE' -p err --no-pager"
    '';

    "logs:warn" = cmd "Recent Subduction warnings + errors (default since 1 hour ago)" ''
      ${resolveHost}
      SINCE="''${1:-1 hour ago}"
      ${ssh} "$HOST" "sudo journalctl -o cat -u subduction --since '$SINCE' -p warning --no-pager"
    '';

    "logs:grep" = cmd "Grep Subduction logs (logs:grep <pattern> [since])" ''
      ${resolveHost}
      PATTERN="''${1:?Usage: logs:grep <pattern> [since]}"
      SINCE="''${2:-1 hour ago}"
      ${ssh} "$HOST" "sudo journalctl -o cat -u subduction --since '$SINCE' --no-pager" \
        | ${ripgrep} --color=always "$PATTERN"
    '';

    "logs:journal" = cmd "Tail the entire systemd journal (all units)" ''
      ${resolveHost}
      ${ssh} "$HOST" 'sudo journalctl -o cat -f'
    '';
  };

  # ── Service control ─────────────────────────────────────────────────
  service = {
    "service:status" = cmd "Show Subduction service status" ''
      ${resolveHost}
      ${ssh} "$HOST" 'systemctl status subduction'
    '';

    "service:restart" = cmd "Restart Subduction" ''
      ${resolveHost}
      ${ssh} "$HOST" 'sudo systemctl restart subduction'
    '';

    "service:start" = cmd "Start Subduction" ''
      ${resolveHost}
      ${ssh} "$HOST" 'sudo systemctl start subduction'
    '';

    "service:stop" = cmd "Stop Subduction" ''
      ${resolveHost}
      ${ssh} "$HOST" 'sudo systemctl stop subduction'
    '';

    "service:units" = cmd "Show status of every service the target owns" ''
      ${resolveHost}
      ${ssh} "$HOST" 'systemctl is-active subduction caddy prometheus loki grafana alloy tailscaled sshd; systemctl --failed --no-pager'
    '';
  };

  # ── Health ──────────────────────────────────────────────────────────
  health = {
    "health" = cmd "Run the full health check (public + remote + local sockets)" ''
      ${resolveHost}
      ${resolvePublic}

      echo "===> Public HTTPS endpoint ($PUBLIC)"
      ${curl} -sI "https://$PUBLIC" | ${coreutils}/bin/head -1 || echo "  (unreachable)"
      echo ""

      echo "===> Remote services"
      ${ssh} "$HOST" 'for u in subduction caddy prometheus loki grafana alloy tailscaled; do
        printf "  %-15s %s\n" "$u" "$(systemctl is-active "$u" 2>/dev/null || echo failed)"
      done'
      echo ""

      echo "===> Local sockets (on remote)"
      ${ssh} "$HOST" '
        printf "  %-15s " "subduction:8080"; ${pkgs.curl}/bin/curl -sI http://127.0.0.1:8080 | head -1 || echo "(none)"
        printf "  %-15s " "loki:3100";       ${pkgs.curl}/bin/curl -s  http://127.0.0.1:3100/ready
        printf "  %-15s " "grafana:3939";    ${pkgs.curl}/bin/curl -sI http://127.0.0.1:3939 | head -1 || echo "(none)"
      '
    '';

    "health:http" = cmd "Probe the public HTTPS endpoint" ''
      ${resolveHost}
      ${resolvePublic}
      ${curl} -sI "https://$PUBLIC"
    '';
  };

  # ── Deploy ──────────────────────────────────────────────────────────
  deploy = {
    "deploy" = cmd "Build on remote, activate now, update bootloader (the standard deploy)" ''
      ${resolveHost}
      ${nixos-rebuild} switch --flake ".#$TARGET" \
        --target-host "$HOST" \
        --build-host  "$HOST" \
        --sudo
    '';

    "deploy:dry" = cmd "Build on remote, show what activation would do, then stop" ''
      ${resolveHost}
      ${nixos-rebuild} dry-activate --flake ".#$TARGET" \
        --target-host "$HOST" \
        --build-host  "$HOST" \
        --sudo
    '';

    "deploy:test" = cmd "Build + activate now, do not update bootloader (reverts on reboot)" ''
      ${resolveHost}
      ${nixos-rebuild} test --flake ".#$TARGET" \
        --target-host "$HOST" \
        --build-host  "$HOST" \
        --sudo
    '';

    "deploy:rollback" = cmd "Roll back to the previous generation" ''
      ${resolveHost}
      ${nixos-rebuild} switch --rollback \
        --target-host "$HOST" \
        --sudo
    '';

    "deploy:gens" = cmd "List system generations with timestamps and current marker" ''
      ${resolveHost}
      ${ssh} "$HOST" 'sudo nix-env --list-generations -p /nix/var/nix/profiles/system'
    '';
  };

  # ── Disk / state ────────────────────────────────────────────────────
  disk = {
    "disk:usage" = cmd "Show disk space on remote root filesystem" ''
      ${resolveHost}
      ${ssh} "$HOST" 'df -h /'
    '';

    "disk:inodes" = cmd "Show inode usage on remote root filesystem" ''
      ${resolveHost}
      ${ssh} "$HOST" 'df -i /'
    '';

    "disk:trees" = cmd "Count Subduction trees currently hosted" ''
      ${resolveHost}
      ${ssh} "$HOST" 'sudo find /var/lib/subduction/trees -mindepth 2 -maxdepth 2 -type d | wc -l'
    '';

    "disk:subduction" = cmd "Show bytes + inodes under /var/lib/subduction/" ''
      ${resolveHost}
      ${ssh} "$HOST" 'sudo du -sh /var/lib/subduction/; sudo du --inodes -s /var/lib/subduction/'
    '';
  };

  # ── Shell / users ───────────────────────────────────────────────────
  shell = {
    "shell" = cmd "Open an interactive SSH session on the target" ''
      ${resolveHost}
      ${ssh} "$HOST"
    '';

    "users" = cmd "List human accounts (UID >= 1000) on the target" ''
      ${resolveHost}
      ${ssh} "$HOST" "awk -F: '\$3 >= 1000 && \$3 < 65534 {printf \"%-12s %-20s %s\\n\", \$1, \$5, \$7}' /etc/passwd"
    '';
  };

  # ── Storage migration ───────────────────────────────────────────────
  storage = {
    "storage:migrate-trees" = cmd "Migrate trees/ from flat to sharded layout on the target (stops Subduction)" ''
      ${resolveHost}
      # Delegates to the on-server menu command, which holds the script path
      # pinned to the running system's Subduction revision.  Pass --dry-run
      # through to preview without stopping the service.
      ${ssh} -t "$HOST" "storage:migrate-trees ''${1:-}"
    '';
  };

  # ── Flake / updates ─────────────────────────────────────────────────
  update = {
    "update" = cmd "Update every flake input" "nix flake update";

    "update:subduction" = cmd "Update just the Subduction flake input"
      "nix flake update subduction";

    "update:nixpkgs" = cmd "Update just the nixpkgs + unstable inputs"
      "nix flake update nixpkgs unstable";
  };
in
  deploy // disk // health // logs // service // shell // storage // update
