# Bedrock Cookbook

Recipes for common admin tasks on bedrock. Most recipes assume you have an account in `wheel` (any of the users declared in [`configuration.nix`](./configuration.nix)) and are SSHed in:

```sh
ssh <USERNAME>@subduction.sync.inkandswitch.com
```

For deploying changes from your laptop, see the ["Deploying" section in README.md](./README.md#deploying) and the ["Rebuild and activate" section below](#2-rebuild-and-activate).

## Bedrock command menu

The repo ships a small command vocabulary — `logs:tail`, `service:restart`, `health`, `gens`, etc. — that's available in **two** places with identical names:

| Where you are                   | How to reach it                                | Implementation                                                |
|---------------------------------|------------------------------------------------|---------------------------------------------------------------|
| Your laptop (in a repo checkout) | `nix develop` (shell prints the menu on entry) | Each command SSHs to bedrock and runs the work remotely       |
| SSHed into bedrock               | Already in your `PATH` — just run them         | Each command runs locally on the server (no SSH round-trip)   |

Same command names everywhere, so muscle memory transfers. Run `menu` in either context to list what's available.

### From your laptop (`nix develop`)

```sh
nix develop      # prints the menu on entry
menu             # re-print the menu inside the shell
```

The wrappers SSH to `bedrock` (per your `~/.ssh/config`). Override with `BEDROCK_HOST`:

```sh
export BEDROCK_HOST=expede@subduction.sync.inkandswitch.com
```

This context adds laptop-only commands the server doesn't have:

| Command            | What it does                                                                       |
|--------------------|------------------------------------------------------------------------------------|
| `deploy`           | `nixos-rebuild switch …` with the right `--target-host` / `--build-host` / `--sudo` |
| `deploy:dry`       | Same, but `dry-activate` (no commit)                                                |
| `deploy:test`      | `test`-mode rebuild (reverts on reboot)                                             |
| `deploy:rollback`  | Roll back to the previous generation                                                |
| `shell`            | Interactive SSH session on bedrock                                                  |
| `update`           | `nix flake update` (and `:subduction`, `:nixpkgs` variants)                         |

See [`nix/commands.nix`](./nix/commands.nix) for the full set.

### On the server (ambient)

After deploy, every account on bedrock has the same command vocabulary in their PATH — no shell to enter, no `nix develop`, no PATH tricks. Just SSH in and run them:

```sh
ssh bedrock
$ menu
$ logs:tail
$ service:restart
```

The on-server commands don't include the `deploy:*` family (you don't deploy from inside the system being deployed), the `shell` command (you're already there), or `update` (flake updates live in the repo on your laptop).

See [`nix/server-commands.nix`](./nix/server-commands.nix) for the full set.

### Shared command catalogue

| Command            | What it does (laptop SSHs; server runs locally)                                    |
|--------------------|------------------------------------------------------------------------------------|
| `menu`             | Print this command catalogue                                                       |
| `logs:tail`        | Follow Subduction logs live                                                        |
| `logs:since [t]`   | Show Subduction logs since `t` (default: `10 minutes ago`)                         |
| `logs:errors [t]`  | Recent Subduction errors only                                                      |
| `logs:warn [t]`    | Recent Subduction warnings + errors                                                |
| `logs:grep <pat>`  | Grep Subduction logs for a pattern                                                 |
| `logs:journal`     | Follow the entire systemd journal                                                  |
| `service:status`   | `systemctl status subduction`                                                      |
| `service:start`    | Start Subduction                                                                   |
| `service:stop`     | Stop Subduction                                                                    |
| `service:restart`  | Restart Subduction                                                                 |
| `service:units`    | Status of every bedrock-owned unit (Caddy, Loki, Grafana, Alloy, Tailscale, sshd)  |
| `health`           | Public HTTPS + service status + local sockets                                      |
| `health:http`      | Public HTTPS endpoint only                                                         |
| `disk:usage`       | `df -h /`                                                                          |
| `disk:inodes`      | `df -i /`                                                                          |
| `disk:trees`       | Count Subduction trees currently hosted                                            |
| `disk:subduction`  | Bytes + inodes under `/var/lib/subduction/`                                        |
| `gens`             | List system generations with timestamps and current marker                         |
| `users`            | List human accounts (UID ≥ 1000)                                                   |

Everything below explains what those wrappers do under the hood — useful when debugging a wrapper, working off-flake, or doing something the menu doesn't cover.

## Quick reference

| You want to…                          | Run                                                                                       |
|---------------------------------------|-------------------------------------------------------------------------------------------|
| See if Subduction is running          | `systemctl status subduction`                                                             |
| Tail logs live                        | `sudo journalctl -o cat -u subduction -f`                                                        |
| Look at the last 10 min of logs       | `sudo journalctl -o cat -u subduction --since "10 minutes ago" --no-pager`                       |
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
> The unit is **`subduction`**, not `subduction_cli`. There is no `subduction_cli` systemd unit on this host, so `systemctl status subduction_cli` will silently return nothing useful.

## Service control

| Action  | Command                                |
|---------|----------------------------------------|
| Status  | `systemctl status subduction`          |
| Stop    | `sudo systemctl stop subduction`       |
| Start   | `sudo systemctl start subduction`      |
| Restart | `sudo systemctl restart subduction`    |
| Reload  | _not supported — restart instead_      |

The service is configured in [`configuration.nix`](./configuration.nix) under `services.subduction.server`. After editing the config, deploy with `nixos-rebuild switch` rather than restarting manually — the rebuild restarts the unit if its config changed.

## Logs

Subduction writes only to stdout. systemd captures everything in the journal; there is **no** `/var/log/subduction/` directory.

### Tailing live

```sh
sudo journalctl -o cat -u subduction -f
```

### Time windows

```sh
sudo journalctl -o cat -u subduction --since "10 minutes ago" --no-pager
sudo journalctl -o cat -u subduction --since "2026-05-06 14:00" --until "2026-05-06 15:00" --no-pager
sudo journalctl -o cat -u subduction --since today --no-pager
```

`--no-pager` is useful when piping into `rg` / `grep` / `wc` (otherwise the output goes to `less` and breaks the pipeline).

### Log priority filtering

Use `-p <level>` to filter by syslog severity. Valid levels (high → low):

```
emerg  alert  crit  err  warning  notice  info  debug
```

```sh
sudo journalctl -o cat -u subduction --since "10 minutes ago" -p err     # errors only
sudo journalctl -o cat -u subduction --since "10 minutes ago" -p warning # warnings + errors
```

> [!CAUTION]
> The level is `err`, not `error`; and `warning`, not `warn`. `-p error` and `-p warn` will silently match nothing.

### Filtering by string

When you want to find log lines mentioning a specific tree, peer, etc., grep the textual output:

```sh
sudo journalctl -o cat -u subduction --since "1 hour ago" --no-pager | rg -i 'WARN|ERR'
sudo journalctl -o cat -u subduction --since today --no-pager | rg '<tree-id-prefix>'
```

(`-u WARN` to `journalctl` is **not** a level filter — `-u` selects the systemd _unit_. The right tool is `-p` for severity or `rg` for substrings.)

### Subduction's own log level

Set in [`configuration.nix`](./configuration.nix) via:

```nix
systemd.services.subduction.serviceConfig.Environment = "RUST_LOG=subduction=info";
```

Edit + `nixos-rebuild switch` to change verbosity. Useful values: `error`, `warn`, `info` (default), `debug`, `trace`. `trace` is _very_ chatty.

## Inspecting on-disk state

State lives under `/var/lib/subduction/`:

```sh
sudo ls /var/lib/subduction/                      # top-level layout
sudo ls /var/lib/subduction/trees | wc -l         # how many trees we host
sudo ls /var/lib/subduction/trees/<tree-id>/      # contents of one tree
sudo ls /var/lib/subduction/trees/<tree-id>/commits
```

Tree IDs are 64-hex-character strings (often padded with trailing zeros). You can search for a known prefix with `grep`:

```sh
sudo ls /var/lib/subduction/trees | grep <first-8-chars-of-tree-id>
```

> [!IMPORTANT]
> `/var/lib/subduction/key-seed` is the server's signing-key material. Never `cat` it into terminal scrollback, never copy it off-host without encryption, and never check it into git. It is auto-generated on first boot (see [DECISIONS.md](./.ignore/DECISIONS.md), if present).

## Disk and inode pressure

Subduction creates many small files under `trees/`. On a small droplet, inodes can run out before bytes do.

```sh
df -h /                                           # bytes used / free
df -i /                                           # inodes used / free
sudo du -sh /var/lib/subduction/                  # bytes under subduction state
sudo du --inodes -s /var/lib/subduction/          # inodes under subduction state
sudo du --inodes --one-file-system --separate-dirs /var/lib/subduction/
```

If `df -i` shows `IUse%` near 100, the server will start failing to create new files even with disk space remaining. Same goes for `df -h` and bytes.

## Live system snapshot

```sh
btop                                              # interactive: q to quit
systemctl --failed                                # any units in a bad state?
systemctl list-units --type=service --state=running
journalctl -o cat --since "1 hour ago" -p err            # errors across all units
```

## Deploying changes (on the server)

When working on the server itself rather than from your laptop:

```sh
cd ~/bedrock                                      # or wherever you cloned it
git pull
sudo nixos-rebuild switch --flake .#bedrock
```

> [!CAUTION]
> The flake URI is `.#bedrock` (path `.`, attribute `bedrock`). `./nix#bedrock` and friends are typos — `nixos-rebuild` will report a confusing "path does not exist" error.

Other modes:

| Mode     | Effect                                                                |
|----------|-----------------------------------------------------------------------|
| `switch` | Build, activate now, add to bootloader (most common)                  |
| `test`   | Build and activate now, _don't_ add to bootloader (reverts on reboot) |
| `boot`   | Add to bootloader but don't activate until next reboot                |

If a deploy goes wrong, the previous generation is still in the bootloader: reboot and pick it from the menu, or roll back from a working session with `sudo nixos-rebuild switch --rollback`.

## Updating the server

Two things can be "updated" independently: the **flake inputs** (Subduction, nixpkgs, etc.) and the **NixOS system itself** (rebuilding against whatever the inputs currently point at). Most of the time you want both, in order.

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

Subduction tracks the `main` branch of [`inkandswitch/subduction`](https://github.com/inkandswitch/subduction); `nix flake update subduction` picks up whatever the latest commit on that branch is. The exact commit deployed is always recorded in `flake.lock` (see the `subduction.locked.rev` field).

To pin to a specific tag instead, edit `flake.nix`:

```nix
subduction.url = "github:inkandswitch/subduction/v0.14.0-nightly.2026-05-07";
```

…then `nix flake update subduction` to refresh the lock.

> [!NOTE]
> Stable releases are published as `vX.Y.Z` tags; nightlies are `vX.Y.Z-nightly.YYYY-MM-DD`. The [releases page](https://github.com/inkandswitch/subduction/releases) marks one tag as "Latest" — that's the latest _stable_, not the latest tag overall.

### 2. Rebuild and activate

#### From your local machine / laptop (preferred)

```sh
nixos-rebuild switch --flake .#bedrock \
  --target-host <USERNAME>@subduction.sync.inkandswitch.com \
  --build-host  <USERNAME>@subduction.sync.inkandswitch.com \
  --sudo
```

`--sudo` makes the remote privileged steps (writing the system profile, running the activation script) escalate via `sudo` rather than expecting a root SSH login. Required here because `services.openssh.settings.PermitRootLogin = "no"`; accounts in `wheel` have passwordless sudo so this is non-interactive.

> [!CAUTION]
> Do **not** prefix the command with a local `sudo`. It accomplishes nothing useful (every privileged action happens on the remote) and _will_ break things — root locally has its own empty `~/.ssh/config`, so SSH host aliases vanish and key resolution falls back to "try every key in the agent", which trips the server's `MaxAuthTries`.
>
> The flag spelling is `--sudo` on NixOS 25.11's `nixos-rebuild-ng`. Classic Perl `nixos-rebuild` called the same thing `--use-remote-sudo`.

`--build-host` builds the closure on the droplet itself rather than locally. It's required when your laptop can't produce `x86_64-linux` derivations (e.g. from Apple Silicon).

#### From an `x86_64-linux` machine (build locally, push to remote)

If your laptop is `x86_64-linux`, drop `--build-host` and let local Nix build the closure; `nixos-rebuild` pushes it over SSH via `nix-copy-closure` before activating:

```sh
nixos-rebuild switch --flake .#bedrock \
  --target-host <USERNAME>@subduction.sync.inkandswitch.com \
  --sudo
```

Tradeoffs vs. `--build-host`:

| Build location             | Pros                                                                            | Cons                                                                     |
|----------------------------|---------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| Server (`--build-host`)    | Same command works on Linux and macOS; no closure upload; no local store growth | Uses droplet CPU/RAM/disk for the build                                  |
| Laptop (no `--build-host`) | Usually faster on a beefy laptop; doesn't tax the droplet                       | Closure cached in laptop's `/nix/store`; closure pushed over the network |

Keep `--build-host` if you want one command that works verbatim on both platforms.

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
sudo journalctl -o cat -u subduction --since "5 minutes ago" --no-pager -p warning
curl -sI https://subduction.sync.inkandswitch.com
```

Expect HTTP `200`/`426` from the public endpoint (Subduction will upgrade to WebSocket; a plain `curl` returning `426 Upgrade Required` is healthy). See [Health checks](#health-checks) for a fuller list.

### 4. Roll back if something is wrong

NixOS keeps each previous system configuration as a numbered _generation_ at `/nix/var/nix/profiles/system-N-link`. Rolling back is atomic (no half-applied state) and never destructive — old generations stay in the store and bootloader until you explicitly garbage-collect them.

#### Quick: undo the last deploy

On the server:

```sh
sudo nixos-rebuild switch --rollback
```

From your laptop:

```sh
nixos-rebuild switch --rollback \
  --target-host <USERNAME>@subduction.sync.inkandswitch.com \
  --sudo
```

Either form activates the previous generation now _and_ makes it the bootloader default for the next boot.

#### List available generations

```sh
sudo nix-env --list-generations -p /nix/var/nix/profiles/system
```

Output is one line per generation, with `(current)` marking the active one:

```
21   2026-05-21 09:55:32   (current)
20   2026-05-12 22:14:01
19   2026-05-08 11:02:55
…
```

#### Roll back to a specific generation

If "the previous one" isn't enough — e.g. you want to skip past two bad deploys — activate a specific generation by its number:

```sh
sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration <mode>
```

| `<mode>` | Activate now | Update bootloader default |
|----------|--------------|---------------------------|
| `switch` | yes          | yes                       |
| `boot`   | no           | yes (next reboot)         |
| `test`   | yes          | no (reverts on reboot)    |

`test` is the safest way to try out an old generation: if it works, follow with `switch`; if it doesn't, reboot.

#### If SSH is broken: roll back via the DigitalOcean console

If the bad generation broke networking or sshd, you can't roll back over SSH. Recovery path:

1. Open the droplet's "Console" tab in the DO web UI.
2. Reboot the droplet (`Power` → `Power Cycle`).
3. At the GRUB menu, select `NixOS - Configuration <N>` for the last known-good generation.
4. Once it boots and SSH works again, run `sudo nixos-rebuild switch --rollback` (or a specific-generation `switch-to-configuration switch`) to make the rollback the new default.

Without step 4, the next reboot lands back on the broken generation.

#### Stateful data isn't rolled back

A NixOS generation is just a closure — it doesn't snapshot the filesystem outside the store. Specifically, these survive a rollback unchanged:

| Path                     | Owned by                                           |
|--------------------------|----------------------------------------------------|
| `/var/lib/subduction/`   | Subduction (key-seed, tree data, commits)          |
| `/var/lib/loki/`         | Loki (log history, TSDB index)                     |
| `/var/lib/prometheus2/`  | Prometheus (metrics TSDB)                          |
| `/var/lib/caddy/`        | Caddy (ACME accounts, Let's Encrypt certificates)  |
| `/var/lib/grafana/`      | Grafana (UI-edited dashboards, users, secrets)     |
| `/var/log/journal/`      | systemd journal                                    |
| `/home/<user>/`          | per-user data                                      |

If a bad deploy already caused service-side mutations (corrupted DB, deleted tree, malformed config written to a service's state dir), rolling back the system closure won't undo those — restore from backup separately.

> [!CAUTION]
> If a rolled-back generation pins a different Caddy config, Caddy may re-issue Let's Encrypt certs on activation. LE has rate limits (5 duplicate certs per week per domain). Try not to thrash deploys around Caddy / cert changes.

#### Verify the rollback worked

```sh
sudo nix-env --list-generations -p /nix/var/nix/profiles/system | grep current
systemctl status subduction
sudo journalctl -o cat --since "2 minutes ago" -p err --no-pager
curl -sI https://subduction.sync.inkandswitch.com
```

`(current)` should point to the generation you rolled back to. See [Health checks](#health-checks) for a fuller post-rollback checklist.

#### Going forward again

There's no "un-rollback". Once the underlying problem is fixed in the flake, an ordinary `nixos-rebuild switch` builds the next generation (N+1) and activates it. The "bad" generations stay in the store until [garbage-collected](#garbage-collecting-old-generations).

### Updating just the OS (security patches)

To pick up the latest `nixos-25.11` channel without touching Subduction:

```sh
nix flake update nixpkgs
nixos-rebuild switch --flake .#bedrock --target-host … --build-host …
```

Subduction's NixOS module pins its own dependencies via the `subduction` flake input, so a `nixpkgs` bump won't move Subduction.

### Garbage-collecting old generations

After several deploys, old system closures accumulate in the Nix store:

```sh
sudo nix-collect-garbage --delete-older-than 14d
sudo nixos-rebuild switch --flake .#bedrock        # refresh the bootloader entries
```

The `nix.gc` settings in [`nix.nix`](./nix.nix) also schedule periodic GC; manual collection is mainly useful when disk pressure is high _now_.

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

| Symptom                                              | Cause / fix                                                                                          |
|------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| `systemctl status subduction_cli` shows nothing      | Wrong unit name. Use `subduction`.                                                                   |
| `journalctl … -p error` shows nothing                | Use `-p err` (and `-p warning`, not `-p warn`).                                                      |
| `journalctl … -u WARN`                               | `-u` selects the unit. Use `-p` or pipe through `rg WARN`.                                           |
| `nixos-rebuild` complains about path                 | The flake URI is `.#bedrock`, not `./nix#bedrock`.                                                   |
| `--no-pager` keeps getting forgotten                 | It's required when piping into `rg` / `grep` / `wc`.                                                 |
| Logs cut off after a few hours                       | Increase `--since` window: `--since "1 day ago"`, `--since today`.                                   |
| Deploy: `Permission denied` writing system profile   | Missing `--sudo` flag (or `--use-remote-sudo` on classic `nixos-rebuild`). Don't add local `sudo`.   |
| Deploy: `Could not resolve hostname …` or auth fails | You ran `sudo nixos-rebuild …` — root has a different `~/.ssh/config`. Run as your user, with `--sudo`. |

## See also

- [`README.md`](./README.md) — architecture, deployment from your laptop
- [`configuration.nix`](./configuration.nix) — service definitions
- [Subduction repo](https://github.com/inkandswitch/subduction)
