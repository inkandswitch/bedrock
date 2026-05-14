# Operations Guide

A working cookbook for common admin tasks on bedrock. Assumes you have an
account in `wheel` (any of the users declared in
[`configuration.nix`](./configuration.nix)) and have SSHed in:

```sh
ssh <USERNAME>@subduction.sync.inkandswitch.com
```

For deploying changes from your laptop, see the
["Deploying" section in README.md](./README.md#deploying).

## Quick reference

| You want to…                          | Run                                                                                       |
|---------------------------------------|-------------------------------------------------------------------------------------------|
| See if Subduction is running          | `systemctl status subduction`                                                             |
| Tail logs live                        | `sudo journalctl -u subduction -f -o cat`                                                 |
| Look at the last 10 min of logs       | `sudo journalctl -u subduction --since "10 minutes ago" --no-pager -o cat`                |
| Just errors / warnings                | append ` -p err` or ` -p warning` (see [Log priority filtering](#log-priority-filtering)) |
| Restart Subduction                    | `sudo systemctl restart subduction`                                                       |
| Check disk space                      | `df -h /`                                                                                 |
| Check inodes                          | `df -i /`                                                                                 |
| Count synced trees                    | `sudo ls /var/lib/subduction/trees \| wc -l`                                              |
| CPU / memory snapshot                 | `btop`                                                                                    |
| Apply a config change pulled from git | `sudo nixos-rebuild switch --flake .#bedrock`                                             |
| Bump Subduction to a new version      | `nix flake update subduction` then `nixos-rebuild switch` (see [Updating](#updating-the-server)) |
| Roll back the last deploy             | `sudo nixos-rebuild switch --rollback`                                                    |

> [!NOTE]
> The unit is **`subduction`**, not `subduction_cli`. There is no
> `subduction_cli` systemd unit on this host, so `systemctl status
> subduction_cli` will silently return nothing useful.

## Service control

| Action  | Command                                |
|---------|----------------------------------------|
| Status  | `systemctl status subduction`          |
| Stop    | `sudo systemctl stop subduction`       |
| Start   | `sudo systemctl start subduction`      |
| Restart | `sudo systemctl restart subduction`    |
| Reload  | _not supported — restart instead_      |

The service is configured in [`configuration.nix`](./configuration.nix) under
`services.subduction.server`. After editing the config, deploy with
`nixos-rebuild switch` rather than restarting manually — the rebuild restarts
the unit if its config changed.

## Logs

Subduction writes only to stdout. systemd captures everything in the journal;
there is **no** `/var/log/subduction/` directory.

### Tailing live

```sh
sudo journalctl -u subduction -f
```

### Time windows

```sh
sudo journalctl -u subduction --since "10 minutes ago" --no-pager
sudo journalctl -u subduction --since "2026-05-06 14:00" --until "2026-05-06 15:00" --no-pager
sudo journalctl -u subduction --since today --no-pager
```

`--no-pager` is useful when piping into `rg` / `grep` / `wc` (otherwise the
output goes to `less` and breaks the pipeline).

### Log priority filtering

Use `-p <level>` to filter by syslog severity. Valid levels (high → low):

```
emerg  alert  crit  err  warning  notice  info  debug
```

```sh
sudo journalctl -u subduction --since "10 minutes ago" -p err     # errors only
sudo journalctl -u subduction --since "10 minutes ago" -p warning # warnings + errors
```

> [!CAUTION]
> The level is `err`, not `error`; and `warning`, not `warn`.
> `-p error` and `-p warn` will silently match nothing.

### Filtering by string

When you want to find log lines mentioning a specific tree, peer, etc., grep
the textual output:

```sh
sudo journalctl -u subduction --since "1 hour ago" --no-pager | rg -i 'WARN|ERR'
sudo journalctl -u subduction --since today --no-pager | rg '<tree-id-prefix>'
```

(`-u WARN` to `journalctl` is **not** a level filter — `-u` selects the
systemd _unit_. The right tool is `-p` for severity or `rg` for substrings.)

### Subduction's own log level

Set in [`configuration.nix`](./configuration.nix) via:

```nix
systemd.services.subduction.serviceConfig.Environment = "RUST_LOG=subduction=info";
```

Edit + `nixos-rebuild switch` to change verbosity. Useful values: `error`,
`warn`, `info` (default), `debug`, `trace`. `trace` is _very_ chatty.

## Inspecting on-disk state

State lives under `/var/lib/subduction/`:

```sh
sudo ls /var/lib/subduction/                      # top-level layout
sudo ls /var/lib/subduction/trees | wc -l         # how many trees we host
sudo ls /var/lib/subduction/trees/<tree-id>/      # contents of one tree
sudo ls /var/lib/subduction/trees/<tree-id>/commits
```

Tree IDs are 64-hex-character strings (often padded with trailing zeros).
You can search for a known prefix with `grep`:

```sh
sudo ls /var/lib/subduction/trees | grep <first-8-chars-of-tree-id>
```

> [!IMPORTANT]
> `/var/lib/subduction/key-seed` is the server's signing-key material.
> Never `cat` it into terminal scrollback, never copy it off-host without
> encryption, and never check it into git. It is auto-generated on first
> boot (see [DECISIONS.md](./.ignore/DECISIONS.md), if present).

## Disk and inode pressure

Subduction creates many small files under `trees/`. On a small droplet,
inodes can run out before bytes do.

```sh
df -h /                                           # bytes used / free
df -i /                                           # inodes used / free
sudo du -sh /var/lib/subduction/                  # bytes under subduction state
sudo du --inodes -s /var/lib/subduction/          # inodes under subduction state
sudo du --inodes --one-file-system --separate-dirs /var/lib/subduction/
```

If `df -i` shows `IUse%` near 100, the server will start failing to create
new files even with disk space remaining. Same goes for `df -h` and bytes.

## Live system snapshot

```sh
btop                                              # interactive: q to quit
systemctl --failed                                # any units in a bad state?
systemctl list-units --type=service --state=running
journalctl --since "1 hour ago" -p err            # errors across all units
```

## Deploying changes (on the server)

When working on the server itself rather than from your laptop:

```sh
cd ~/bedrock                                      # or wherever you cloned it
git pull
sudo nixos-rebuild switch --flake .#bedrock
```

> [!CAUTION]
> The flake URI is `.#bedrock` (path `.`, attribute `bedrock`).
> `./nix#bedrock` and friends are typos — `nixos-rebuild` will report
> a confusing "path does not exist" error.

Other modes:

| Mode     | Effect                                                                |
|----------|-----------------------------------------------------------------------|
| `switch` | Build, activate now, add to bootloader (most common)                  |
| `test`   | Build and activate now, _don't_ add to bootloader (reverts on reboot) |
| `boot`   | Add to bootloader but don't activate until next reboot                |

If a deploy goes wrong, the previous generation is still in the bootloader:
reboot and pick it from the menu, or roll back from a working session with
`sudo nixos-rebuild switch --rollback`.

## Updating the server

Two things can be "updated" independently: the **flake inputs**
(Subduction, nixpkgs, etc.) and the **NixOS system itself** (rebuilding
against whatever the inputs currently point at). Most of the time you
want both, in order.

### 1. Bump flake inputs

From a checkout of this repo (laptop _or_ on the server):

```sh
nix flake update                    # update every input
nix flake update subduction         # bump just Subduction
nix flake update nixpkgs unstable   # bump just nixpkgs channels
```

This rewrites `flake.lock`. _Review the diff_ before deploying:

```sh
git diff flake.lock
```

Subduction tracks the `main` branch of
[`inkandswitch/subduction`](https://github.com/inkandswitch/subduction);
`nix flake update subduction` picks up whatever the latest commit on
that branch is. The exact commit deployed is always recorded in
`flake.lock` (see the `subduction.locked.rev` field).

To pin to a specific tag instead, edit `flake.nix`:

```nix
subduction.url = "github:inkandswitch/subduction/v0.14.0-nightly.2026-05-07";
```

…then `nix flake update subduction` to refresh the lock.

> [!NOTE]
> Stable releases are published as `vX.Y.Z` tags; nightlies are
> `vX.Y.Z-nightly.YYYY-MM-DD`. The
> [releases page](https://github.com/inkandswitch/subduction/releases)
> marks one tag as "Latest" — that's the latest _stable_, not the
> latest tag overall.

### 2. Rebuild and activate

#### From your laptop (preferred)

```sh
nixos-rebuild switch --flake .#bedrock \
  --target-host <USERNAME>@subduction.sync.inkandswitch.com \
  --build-host <USERNAME>@subduction.sync.inkandswitch.com
```

`--build-host` builds the closure on the droplet itself, which is
required when your laptop can't produce `x86_64-linux` derivations
(e.g. from Apple Silicon).

#### On the server

```sh
cd ~/bedrock
git pull                               # if the lockfile bump was committed
sudo nixos-rebuild switch --flake .#bedrock
```

For a dry run that builds without activating:

```sh
sudo nixos-rebuild build --flake .#bedrock
```

### 3. Verify after deploy

```sh
systemctl status subduction
sudo journalctl -u subduction --since "5 minutes ago" --no-pager -p warning
curl -sI https://subduction.sync.inkandswitch.com
```

Expect HTTP `200`/`426` from the public endpoint (Subduction will
upgrade to WebSocket; a plain `curl` returning `426 Upgrade Required`
is healthy). See [Health checks](#health-checks) for a fuller list.

### 4. Roll back if something is wrong

```sh
sudo nixos-rebuild switch --rollback         # back to previous generation
sudo nix-env --list-generations -p /nix/var/nix/profiles/system   # see history
sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch
```

The previous generation is also available from the GRUB menu on reboot.

### Updating just the OS (security patches)

To pick up the latest `nixos-25.11` channel without touching Subduction:

```sh
nix flake update nixpkgs
nixos-rebuild switch --flake .#bedrock --target-host … --build-host …
```

Subduction's NixOS module pins its own dependencies via the
`subduction` flake input, so a `nixpkgs` bump won't move Subduction.

### Garbage-collecting old generations

After several deploys, old system closures accumulate in the Nix store:

```sh
sudo nix-collect-garbage --delete-older-than 14d
sudo nixos-rebuild switch --flake .#bedrock        # refresh the bootloader entries
```

The `nix.gc` settings in [`nix.nix`](./nix.nix) also schedule periodic
GC; manual collection is mainly useful when disk pressure is high
_now_.

## Health checks

| Check                     | Command                                                |
|---------------------------|--------------------------------------------------------|
| HTTPS reachable           | `curl -sI https://subduction.sync.inkandswitch.com`    |
| Subduction local socket   | `curl -sI http://127.0.0.1:8080`                       |
| Prometheus scraping       | `curl -s http://127.0.0.1:9092/api/v1/targets \| jq`   |
| Grafana up                | `curl -sI http://127.0.0.1:3939`                       |
| Loki up                   | `curl -s http://127.0.0.1:3100/ready`                  |
| Caddy config valid        | `sudo systemctl status caddy`                          |

## Common gotchas

| Symptom                                         | Cause / fix                                                        |
|-------------------------------------------------|--------------------------------------------------------------------|
| `systemctl status subduction_cli` shows nothing | Wrong unit name. Use `subduction`.                                 |
| `journalctl … -p error` shows nothing           | Use `-p err` (and `-p warning`, not `-p warn`).                    |
| `journalctl … -u WARN`                          | `-u` selects the unit. Use `-p` or pipe through `rg WARN`.         |
| `nixos-rebuild` complains about path            | The flake URI is `.#bedrock`, not `./nix#bedrock`.                 |
| `--no-pager` keeps getting forgotten            | It's required when piping into `rg` / `grep` / `wc`.               |
| Logs cut off after a few hours                  | Increase `--since` window: `--since "1 day ago"`, `--since today`. |

## See also

- [`README.md`](./README.md) — architecture, deployment from your laptop
- [`configuration.nix`](./configuration.nix) — service definitions
- [Subduction repo](https://github.com/inkandswitch/subduction)
