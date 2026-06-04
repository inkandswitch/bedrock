# Bedrock on-server commands.
#
# CLI wrappers available system-wide on bedrock itself.  Mirrored from the
# laptop-side dev-shell menu (see `nix/commands.nix`) but implemented
# locally — no SSH, no remote round-trip — so they're usable from any login
# session (regular SSH, Tailscale, or the DigitalOcean web console).
#
# All commands relying on root-only paths or systemd state-mutation
# (`service:restart`, `disk:trees`, …) escalate via `sudo`.  All declared
# accounts are in `wheel` with passwordless sudo, so this is non-interactive.
#
# Run `menu` to list every available command.
{
  pkgs,
  system,
  cmd,
  subduction,
}: let
  awk        = "${pkgs.gawk}/bin/awk";
  bash       = "${pkgs.bash}/bin/bash";
  coreutils  = pkgs.coreutils;
  curl       = "${pkgs.curl}/bin/curl";
  journalctl = "${pkgs.systemd}/bin/journalctl";
  nix-env    = "${pkgs.nix}/bin/nix-env";
  ripgrep    = "${pkgs.ripgrep}/bin/rg";
  systemctl  = "${pkgs.systemd}/bin/systemctl";

  # The flat-to-sharded trees migration script ships in the Subduction source,
  # pinned to the exact revision this system is built from.
  migrateTreesScript = "${subduction}/scripts/migrate-trees-sharding.sh";

  # NixOS places setuid wrappers (sudo, etc.) under /run/wrappers/bin.
  sudo = "/run/wrappers/bin/sudo";

  # ── Logs ────────────────────────────────────────────────────────────
  logs = {
    "logs:tail" = cmd "Tail Subduction logs live"
      "${journalctl} -o cat -u subduction -f";

    "logs:since" = cmd "Subduction logs since a time window (default: 10 minutes ago)" ''
      SINCE="''${1:-10 minutes ago}"
      ${journalctl} -o cat -u subduction --since "$SINCE" --no-pager
    '';

    "logs:errors" = cmd "Recent Subduction errors only (default since 1 hour ago)" ''
      SINCE="''${1:-1 hour ago}"
      ${journalctl} -o cat -u subduction --since "$SINCE" -p err --no-pager
    '';

    "logs:warn" = cmd "Recent Subduction warnings + errors (default since 1 hour ago)" ''
      SINCE="''${1:-1 hour ago}"
      ${journalctl} -o cat -u subduction --since "$SINCE" -p warning --no-pager
    '';

    "logs:grep" = cmd "Grep Subduction logs (logs:grep <pattern> [since])" ''
      PATTERN="''${1:?Usage: logs:grep <pattern> [since]}"
      SINCE="''${2:-1 hour ago}"
      ${journalctl} -o cat -u subduction --since "$SINCE" --no-pager \
        | ${ripgrep} --color=always "$PATTERN"
    '';

    "logs:journal" = cmd "Tail the entire systemd journal (all units)"
      "${journalctl} -o cat -f";
  };

  # ── Service control ─────────────────────────────────────────────────
  service = {
    "service:status" = cmd "Show Subduction service status"
      "${systemctl} status subduction";

    "service:restart" = cmd "Restart Subduction"
      "${sudo} ${systemctl} restart subduction";

    "service:start" = cmd "Start Subduction"
      "${sudo} ${systemctl} start subduction";

    "service:stop" = cmd "Stop Subduction"
      "${sudo} ${systemctl} stop subduction";

    "service:units" = cmd "Show status of every bedrock-owned service" ''
      for u in subduction caddy prometheus loki grafana alloy tailscaled sshd; do
        printf "  %-15s %s\n" "$u" "$(${systemctl} is-active "$u" 2>/dev/null || echo failed)"
      done
      echo ""
      echo "Failed units:"
      ${systemctl} --failed --no-pager
    '';
  };

  # ── Health ──────────────────────────────────────────────────────────
  health = {
    "health" = cmd "Run the full health check (public + service status + local sockets)" ''
      echo "===> Public HTTPS endpoint"
      ${curl} -sI https://subduction.sync.inkandswitch.com | ${coreutils}/bin/head -1 || echo "  (unreachable)"
      echo ""

      echo "===> Service status"
      for u in subduction caddy prometheus loki grafana alloy tailscaled; do
        printf "  %-15s %s\n" "$u" "$(${systemctl} is-active "$u" 2>/dev/null || echo failed)"
      done
      echo ""

      echo "===> Local sockets"
      printf "  %-15s " "subduction:8080"; ${curl} -sI http://127.0.0.1:8080 | ${coreutils}/bin/head -1 || echo "(none)"
      printf "  %-15s " "loki:3100";       ${curl} -s  http://127.0.0.1:3100/ready; echo ""
      printf "  %-15s " "grafana:3939";    ${curl} -sI http://127.0.0.1:3939 | ${coreutils}/bin/head -1 || echo "(none)"
    '';

    "health:http" = cmd "Probe the public HTTPS endpoint"
      "${curl} -sI https://subduction.sync.inkandswitch.com";
  };

  # ── Disk / state ────────────────────────────────────────────────────
  disk = {
    "disk:usage" = cmd "Show disk space on root filesystem"
      "${coreutils}/bin/df -h /";

    "disk:inodes" = cmd "Show inode usage on root filesystem"
      "${coreutils}/bin/df -i /";

    # Trees live two levels deep under the sharded layout
    # (trees/{4-hex bucket}/{60-hex leaf}/), so a tree is a depth-2 directory.
    "disk:trees" = cmd "Count Subduction trees currently hosted"
      "${sudo} ${pkgs.findutils}/bin/find /var/lib/subduction/trees -mindepth 2 -maxdepth 2 -type d | ${coreutils}/bin/wc -l";

    "disk:subduction" = cmd "Show bytes + inodes under /var/lib/subduction/" ''
      ${sudo} ${coreutils}/bin/du -sh /var/lib/subduction/
      ${sudo} ${coreutils}/bin/du --inodes -s /var/lib/subduction/
    '';
  };

  # ── Storage migration ───────────────────────────────────────────────
  storage = {
    "storage:migrate-trees" = cmd "Migrate trees/ from flat to sharded layout (stops Subduction)" ''
      DATA_DIR="/var/lib/subduction"

      if [ "''${1:-}" = "--dry-run" ]; then
        echo "===> Dry run (no changes, service left running)"
        ${sudo} ${bash} ${migrateTreesScript} "$DATA_DIR" --dry-run
        exit 0
      fi

      echo "===> Stopping Subduction for offline migration"
      ${sudo} ${systemctl} stop subduction

      echo "===> Migrating $DATA_DIR/trees"
      ${sudo} ${bash} ${migrateTreesScript} "$DATA_DIR"

      echo "===> Starting Subduction"
      ${sudo} ${systemctl} start subduction

      echo "===> Done.  Verify with: service:status, disk:trees"
    '';
  };

  # ── System ──────────────────────────────────────────────────────────
  system' = {
    "gens" = cmd "List system generations"
      "${sudo} ${nix-env} --list-generations -p /nix/var/nix/profiles/system";

    "users" = cmd "List human accounts (UID >= 1000)" ''
      ${awk} -F: '$3 >= 1000 && $3 < 65534 {printf "%-12s %-20s %s\n", $1, $5, $7}' /etc/passwd
    '';
  };
in
  disk // health // logs // service // storage // system'
