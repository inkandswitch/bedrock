# Bedrock

NixOS configuration for a DigitalOcean droplet running a [Subduction](https://github.com/inkandswitch/subduction) sync server with full observability.

## Architecture

```mermaid
graph TD
    Internet -->|":80 / :443"| Caddy["Caddy (TLS)"]

    Caddy -->|subduction.sync…| Subduction[":8080 — Subduction"]
    Caddy -->|dashboard.subduction.sync…| Grafana[":3939 — Grafana"]

    Subduction -->|":9090 metrics"| Prometheus[":9092 — Prometheus"]
    Prometheus -.-> Grafana

    Alloy["Grafana Alloy"] -->|push| Loki[":3100 — Loki"]
    Alloy -.-|systemd journal| Journal(("journal"))
    Loki -.-> Grafana
```

Caddy terminates TLS via Let's Encrypt and reverse-proxies to Subduction and Grafana. Prometheus scrapes Subduction metrics. Grafana Alloy ships the systemd journal to Loki (Subduction logs only to stdout — there's no file-based log source). Tailscale provides a mesh VPN overlay for administrative access.

## Files

| File                         | Purpose                                                                                          |
|------------------------------|--------------------------------------------------------------------------------------------------|
| `flake.nix`                  | Flake entry point — pins nixpkgs, disko, home-manager, and subduction                            |
| `configuration.nix`          | System services: Subduction, Caddy, Prometheus, Loki, Grafana Alloy, Grafana, Tailscale, OpenSSH |
| `digitalocean.nix`           | DigitalOcean platform support: cloud-init, DO metadata services, networking                      |
| `disk-config.nix`            | Disko partition layout (BIOS boot + ext4 root on `/dev/vda`)                                     |
| `hardware-configuration.nix` | Extra kernel modules for DO/QEMU hardware                                                        |
| `home.nix`                   | Minimal home-manager config (fish, starship, git, iroh, ripgrep)                                 |
| `nix.nix`                    | Nix daemon settings (flakes, GC, trusted substituters)                                           |

## Deploying

### Initial provisioning

Create a DigitalOcean droplet (Ubuntu 24.04, SSH key added), point `subduction.sync.inkandswitch.com` DNS at its IP, then provision with [nixos-anywhere](https://github.com/nix-community/nixos-anywhere):

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#bedrock \
  root@<droplet-ip>
```

Subduction's signing-key seed is generated automatically by an `ExecStartPre` script on the first boot — no manual `dd if=/dev/urandom` step is required. The seed lives at `/var/lib/subduction/key-seed` and is preserved across rebuilds.

### Updating the configuration

`nixos-anywhere` is only for the initial install (it wipes the disk). For ongoing changes, edit the nix files locally and use `nixos-rebuild` to apply them over SSH:

```bash
nixos-rebuild switch --flake .#bedrock \
  --target-host <USERNAME>@subduction.sync.inkandswitch.com \
  --build-host  <USERNAME>@subduction.sync.inkandswitch.com \
  --sudo
```

- `--sudo` escalates the remote privileged steps via passwordless sudo (root SSH is disabled).
- `--build-host` builds the closure on the droplet rather than locally — required when your laptop can't produce `x86_64-linux` derivations (e.g. Apple Silicon). On an `x86_64-linux` laptop you can drop it and let local Nix build the closure.

See [`COOKBOOK.md` § Rebuild and activate](./COOKBOOK.md#2-rebuild-and-activate) for the full deploy workflow, dry-runs, rollback, and the gotchas (including why you should _not_ prefix the command with a local `sudo`).

## Services

| Service       | Listen Address   | Notes                                                 |
| ------------- | ---------------- | ----------------------------------------------------- |
| Subduction    | `127.0.0.1:8080` | Sync server; key at `/var/lib/subduction/key-seed`    |
| Caddy         | `:80`, `:443`    | Automatic TLS via Let's Encrypt                       |
| Grafana       | `127.0.0.1:3939` | Exposed at `dashboard.subduction.sync.inkandswitch.com` |
| Prometheus    | `:9092`          | Scrapes Subduction metrics on `:9090`                 |
| Loki          | `:3100`          | Log aggregation (TSDB, 14-day retention)              |
| Grafana Alloy | —                | Ships the systemd journal to Loki                     |
| Tailscale     | —                | Mesh VPN for admin access                             |
| OpenSSH       | `:22`            | Key-only, root login disabled                         |

## Firewall

Only ports **22**, **80**, and **443** are open. All other services (Grafana, Prometheus, Loki) bind to localhost and are reachable through Caddy or Tailscale.

## Day-to-day operations

See [`COOKBOOK.md`](./COOKBOOK.md) for common on-server tasks: tailing logs, filtering by severity, restarting Subduction, checking disk and inode pressure, inspecting on-disk state, deploying changes, rolling back, and the gotchas that come up most often.
