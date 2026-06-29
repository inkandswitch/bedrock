{ config, lib, pkgs, hostname, adminUsername, bedrockMenu, ... }:
  let
    publicHostname = "subduction.sync.inkandswitch.com";

    # Encoding conversion helpers: base58check <-> hex <-> base64.
    #
    # These are deliberately *not* part of the `bedrockMenu` command bundle:
    # that bundle prefixes every command's stdout with a "Running …" banner,
    # which would pollute copy-paste and break chaining one conv into another.
    # Plain `writeShellApplication` scripts keep stdout clean and pipeable.
    #
    # Each script reads its input from $1 or, if absent, stdin; strips
    # surrounding whitespace; and writes the result (plus a trailing newline)
    # to stdout.  `set -euo pipefail` (via writeShellApplication) makes a
    # failed decode — e.g. a bad base58check checksum — exit non-zero.
    #
    # Encodings:
    #   hex   lowercase hex            (xxd -p)
    #   b64   standard base64          (basenc --base64)
    #   b58   plain base58             (base58)
    #   b58c  base58check (4-byte sum) (base58 -c / -d -c verifies & strips)
    #
    # Raw bytes are the pivot: every conversion is "decode <from> to bytes"
    # piped into "encode bytes to <to>".  Naming: conv:<from>:<to>.
    convTools = let
      base58 = "${pkgs.python3Packages.base58}/bin/base58";
      basenc = "${pkgs.coreutils}/bin/basenc";
      cat    = "${pkgs.coreutils}/bin/cat";
      tr     = "${pkgs.coreutils}/bin/tr";
      xxd    = "${pkgs.unixtools.xxd}/bin/xxd";

      # bytes -> X
      encHex  = "${xxd} -p | ${tr} -d '\\n'";
      encB64  = "${basenc} --base64 -w0";
      encB58  = base58;
      encB58c = "${base58} -c";

      # X -> bytes
      decHex  = "${xxd} -r -p";
      decB64  = "${basenc} -d --base64";
      decB58  = "${base58} -d";
      decB58c = "${base58} -d -c";

      mkConv = name: decoder: encoder:
        pkgs.writeShellApplication {
          inherit name;
          text = ''
            { if [ "$#" -ge 1 ]; then printf '%s' "$1"; else ${cat}; fi; } \
              | ${tr} -d '[:space:]' \
              | ${decoder} \
              | ${encoder}
            echo
          '';
        };
    in pkgs.symlinkJoin {
      name = "bedrock-conv-tools";
      paths = [
        (mkConv "conv:hex:b64"  decHex  encB64)
        (mkConv "conv:hex:b58"  decHex  encB58)
        (mkConv "conv:hex:b58c" decHex  encB58c)

        (mkConv "conv:b64:hex"  decB64  encHex)
        (mkConv "conv:b64:b58"  decB64  encB58)
        (mkConv "conv:b64:b58c" decB64  encB58c)

        (mkConv "conv:b58:hex"  decB58  encHex)
        (mkConv "conv:b58:b64"  decB58  encB64)

        (mkConv "conv:b58c:hex" decB58c encHex)
        (mkConv "conv:b58c:b64" decB58c encB64)
      ];
    };

    accounts = {
      ${adminUsername} = {
        name  = "Brooklyn Zelenka";
        email = "brooklyn@inkandswitch.com";
        shell = pkgs.fish;
        keys  = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUKVPRsoJEVWhHtz/2RhbVTZNvyNEm08KJK/3bOSdNc"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmJy3W56uqJjXGCHYOSJkLw+Ae/SgtF8B0qtjcDxtXp"
        ];
      };

      alexjg = {
        name  = "Alex Good";
        email = "alex@inkandswitch.com";
        shell = pkgs.zsh;
        keys  = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDfnGYUnlU6SKm6VGZQRxUGA+p9PgjEmaUhSKQeKx+pgAq8F1yRrmJQ6hsCsHrGu0+Rk/r1wi6MImUej2vmit8jO5wjBcv17EJM9bCXQUvrElLtaH+815r/DOIfyEsSpuZxe5tQ+IoKnasBQUKCkvGwBrPotJmqsHS5xqhke4/uGSid/g2ZSsF2ScLlD2E20+8OsTKw6nE+pfs+uchXwoiMmhclcyWK9cEwA9GLpPcjikQwdQThmeIZZGvRX7WvuPLZMp/AeoxCB+Y3KjEYpBtVS+rsv48GUAq2V0+SG35C1HJ3gGnKA+13xSdIHtfzxjlQy+7QWtagzF/0LlEgxm6gqsyC0xyDLDqiDxVRR8Nj0+ZXNejRNFubwg3YD4jx/JTIJ4u3/XDMlAw7wJGg1t3cMy+uR3/+cacsn5Py2nRZYvIxtBpToMKU9JOwVi6vz4kt+OeanLWP05a08XAnBW+c10P8qeN09he5Vvn6KL7cMr9RsGXzp9BHYqfc82PhskE="
          # alex-zephyrus
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpk50Fj8AnhhWB8y4tHHzUlDffwhxxeE6Ra81qbtXqJ1QSzam/eKn25usvRAWYijD7JzhJHBRSftCeF90dXBWMHjAWPaRYxn/J0vXYajuv3+7KV5g97Q5mTqVb6bRIW1gWprVF0+1I2aZaU1MG2sMf/jPd1+hN0JXC+vCvS8xYdxJFCQhWNzIhNX6q5G7gfLjYJ4598kQmCcmQ03OMVGfWx94DKr24fBF3eCLdw4Ub53iP/9ClzcxsmXNIJPbCaDAebmPS8uQSUkfhFVtcwBbllueW73y2kkMdFGhbFNmJXy2k4TReDZhIk6U113ehoiikjxOxDCNutdQODyPh04C48LG6+j4YGUPbkBPsjLyveWYWJw4tcGvREB0ZN+Cql6w7NXt8ZzfbEqK01pKBq7Bmhiq2DGNqE6A2PFmEyuvaOCyigP5jBgpB0K1N0h+T56IVFlDCGqLHcB5LaCiXMxKAAD26K6v+qc/G4/AxGozpd+BS3T6Bqm+pH1vWCdNEsz0="
        ];
      };

      alexwarth = {
        name  = "Alex Warth";
        email = "alexwarth@inkandswitch.com";
        shell = pkgs.zsh;
        keys  = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA1o2gb/keuxDxuk4QlZKcxWMSbvWDYLENX+6vEGA/4T9Yg6eL2g7ovRKo25/rOZV6hgc5TMt//VMSgJcf6LXJngmr3KkXe+QNu3a1jimosVhFwjule2U5R5dKETGupQ2kopBaV3PWLFb+ZbvhgdlY8HeFaOvUAybxfvLOmFtj1ta5VT2ccXPXKndCjfw/eaICknNhevi36KObCdj7Eh/BhI5kN77t61cPbQW+J29UubC6eqToVIFIMG0oD913rUV+yASpAPDsYz4FsMU8ONx8vjwUTQhWLYli3aKniVyHC4HNOoJ/cDlYHJ0+RoHzpKiQueEiHtdd1e2/YVW+K8F4mw=="
        ];
      };

      chee = {
        name  = "Chee Rabbits";
        email = "chee@inkandswitch.com";
        shell = pkgs.zsh;
        keys  = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHzdaK1G+GPAqG0GfinR6xMMTzmLX2DgFMDSnLE/vEmW yay@chee.party"
        ];
      };

      pvh = {
        name  = "Peter van Hardenberg";
        email = "pvh@inkandswitch.com";
        shell = pkgs.zsh;
        keys  = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxWJimKcZjUM4cyuroZ2brFclTxpDsoxQ3NjK43eWbn"
        ];
      };

      john = {
        name  = "John Mumm";
        email = "jtfmumm@inkandswitch.com";
        shell = pkgs.bash;
        keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGWVjwE2zAGZtqe95duKLtYsUsx9RaPVbn/i4QyQ/Y/b jtfmumm@gmail.com"
        ];
      };
    };
  in {
    networking.hostName = hostname;
    networking.nftables.enable = true;
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
      logRefusedConnections = false;
    };

    time.timeZone      = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";

    users.users = lib.mapAttrs (_username: account: {
      isNormalUser = true;
      description  = account.name;
      extraGroups  = [ "wheel" ];
      shell        = account.shell;
      openssh.authorizedKeys.keys = account.keys;
    }) accounts;

    programs.bash.enable = true;
    programs.zsh.enable  = true;
    programs.fish.enable = true;

    # Per-user home-manager configuration.  Every account gets the same base
    # home.nix, parameterized by the per-account name/email/shell via
    # `_module.args` (so each user's submodule receives its own values).
    home-manager = {
      useGlobalPkgs       = true;
      useUserPackages     = true;
      backupFileExtension = "backup";

      extraSpecialArgs = {
        inherit hostname;
        isServer = true;
      };

      users = lib.mapAttrs (username: account: { ... }: {
        imports = [ ./home.nix ];
        _module.args = {
          inherit username;
          fullName = account.name;
          email    = account.email;
          shell    = account.shell;
        };
      }) accounts;
    };

    security.sudo.wheelNeedsPassword = false;
    programs.ssh.startAgent = true;

    services = {
      openssh = {
        enable = true;
        settings = {
          PermitRootLogin        = "no";
          PasswordAuthentication = false;
        };
      };

      tailscale.enable = true;

      caddy = {
        enable = true;
        email  = "hello@brooklynzelenka.com";

        # `flush_interval -1` puts Caddy into low-latency mode for
        # streamed responses (WebSocket upgrades, SSE, etc.) — it
        # disables response buffering and flushes immediately, which
        # is what long-lived WS connections need.
        #
        # `stream_close_delay 5m` keeps WebSocket connections alive
        # for 5 minutes across Caddy config reloads (cert renewal,
        # `nixos-rebuild switch`, etc.). Without this, every reload
        # forcibly closes every active WS via a Close control frame —
        # which on the subduction side manifests as the
        # "peer X disconnected: sender task stopped" cascade. The
        # 5-minute grace gives clients a chance to drain naturally.
        virtualHosts.${publicHostname}.extraConfig = ''
          reverse_proxy localhost:8080 {
            flush_interval -1
            stream_close_delay 5m
          }
        '';

        virtualHosts."dashboard.${publicHostname}".extraConfig = ''
          reverse_proxy localhost:3939
        '';
      };

      subduction = {
        server = {
          enable           = true;
          serviceName      = publicHostname;
          socket           = "127.0.0.1:8080";
          keyFile          = "/var/lib/subduction/key-seed";
          maxMessageSize   = 104857600; # 100 MiB
          maxResidentTrees = 8192;      # 2^13; LRU cap sized for the 8 GiB host
          enableMetrics    = true;
          metricsPort      = 9090;
          adminAddr        = "127.0.0.1:9091";
          auth             = "open";
          logFormat        = "json";
          logLevel         = "subduction=info";
        };

        grafana.provisionDashboard = true;
      };

      prometheus = {
        enable = true;
        port   = 9092;

        scrapeConfigs = [{
          job_name        = "subduction";
          scrape_interval = "15s";
          static_configs  = [{
            targets = [ "localhost:9090" ];
            labels.instance = "local";
          }];
        }];
      };

      loki = {
        enable = true;
        configuration = {
          auth_enabled = false;

          server.http_listen_port = 3100;

          ingester = {
            lifecycler = {
              address = "127.0.0.1";
              ring = {
                kvstore.store      = "inmemory";
                replication_factor = 1;
              };
              final_sleep = "0s";
            };
            chunk_idle_period   = "5m";
            chunk_retain_period = "30s";
          };

          schema_config.configs = [{
            from         = "2024-01-01";
            store        = "tsdb";
            object_store = "filesystem";
            schema       = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }];

          storage_config = {
            tsdb_shipper = {
              active_index_directory = "/var/lib/loki/tsdb-index";
              cache_location         = "/var/lib/loki/tsdb-cache";
            };
            filesystem.directory = "/var/lib/loki/chunks";
          };

          limits_config = {
            reject_old_samples         = true;
            reject_old_samples_max_age = "168h";
            ingestion_rate_mb          = 16;
            ingestion_burst_size_mb    = 24;
          };

          compactor = {
            working_directory            = "/var/lib/loki/compactor";
            compaction_interval          = "10m";
            retention_enabled            = true;
            retention_delete_delay       = "2h";
            retention_delete_worker_count = 150;
            delete_request_store         = "filesystem";
          };

          table_manager = {
            retention_deletes_enabled = true;
            retention_period          = "336h"; # 14 days
          };
        };
      };

      alloy = {
        enable = true;
        extraFlags = [ "--disable-reporting" ];
      };

      grafana = {
        enable = true;
        settings.server = {
          http_addr = "127.0.0.1";
          http_port = 3939;
        };

        provision.datasources.settings.datasources = [
          {
            name      = "Prometheus";
            type      = "prometheus";
            uid       = "prometheus";
            url       = "http://localhost:9092";
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            uid  = "loki";
            url  = "http://localhost:3100";
          }
        ];
      };
    };

    # Alloy config: scrape systemd journal → Loki
    environment.etc."alloy/config.alloy".text = ''
      // ── Loki sink ──────────────────────────────────────────────────────
      loki.write "local" {
        endpoint {
          url = "http://localhost:3100/loki/api/v1/push"
        }
      }

      // ── Relabel rules (applied inside the journal source) ─────────────
      // Must be a separate component so that loki.source.journal can
      // reference its `.rules` export.  The __journal_* internal labels
      // are only visible when applied via `relabel_rules`; they are
      // stripped before reaching a downstream loki.relabel receiver.
      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }

        rule {
          source_labels = ["__journal__systemd_unit"]
          regex         = "subduction\\.service"
          target_label  = "service"
          replacement   = "subduction"
        }
      }

      // ── Level extraction ───────────────────────────────────────────────
      // Subduction runs with `--log-format json`, so each journal message is a
      // JSON object carrying a `level` field (INFO/WARN/ERROR/…). Parse it and
      // promote `level` to a stream label so the Grafana "Log Rate by Level"
      // panel (which filters on `{level=~"(?i)…"}`) has data. Non-JSON lines
      // (other units) simply have no `level` field and pass through untouched.
      loki.process "subduction_level" {
        forward_to = [loki.write.local.receiver]

        stage.json {
          expressions = { level = "level" }
        }

        stage.labels {
          values = { level = "" }
        }
      }

      // ── Systemd journal ────────────────────────────────────────────────
      loki.source.journal "journal" {
        forward_to    = [loki.process.subduction_level.receiver]
        relabel_rules = loki.relabel.journal.rules
        max_age       = "12h"
        labels        = {
          job  = "systemd-journal",
          host = "${hostname}",
        }
      }
    '';

    systemd.services.subduction.serviceConfig = {
      # Generate the signing-key seed on first boot so the server can start
      # without manual intervention.  The "+" prefix runs the script as
      # root (outside the service sandbox) so chown works.  Idempotent:
      # an existing key-seed is never overwritten.
      ExecStartPre = let
        keySeed = "/var/lib/subduction/key-seed";
        script = pkgs.writeShellScript "ensure-subduction-key" ''
          if [ ! -f "${keySeed}" ]; then
            ${pkgs.coreutils}/bin/dd if=/dev/urandom bs=32 count=1 of="${keySeed}" 2>/dev/null
            ${pkgs.coreutils}/bin/chmod 0400 "${keySeed}"
            ${pkgs.coreutils}/bin/chown subduction:subduction "${keySeed}"
          fi
        '';
      in "+${script}";

      LimitNOFILE = 1048576;

      MemoryHigh = "5G";
      MemoryMax  = "6G";
      ManagedOOMMemoryPressure = "auto";
      OOMScoreAdjust = 500;
    };

    # Dedicated slice for SSH so its memory floor can never be consumed by a
    # sibling service (e.g. Subduction) sharing system.slice.  MemoryMin is a
    # *hard* reservation: the kernel reclaims and OOM-kills other cgroups
    # before ever reclaiming below this floor, so we can always log in --
    # even at ~100% RAM.  This is the direct fix for the 99.5%-RAM lockout,
    # and complements Subduction's own MemoryHigh/MemoryMax caps above.
    systemd.slices.ssh.sliceConfig = {
      MemoryAccounting = true;
      MemoryMin = "768M";
    };
    systemd.services.sshd.serviceConfig.Slice = "ssh.slice";

    # Userspace early-OOM killer.  The in-kernel OOM killer acts late and
    # picks victims heuristically (it can kill sshd).  systemd-oomd watches
    # cgroup memory-pressure (PSI) and acts *early*, killing the offending
    # cgroup before the box wedges.  Subduction now bounds itself via the
    # MemoryHigh/MemoryMax caps above and stays the preferred victim of any
    # *global* OOM via OOMScoreAdjust=500, so oomd is kept as a system-wide
    # early-OOM safety net; the ssh.slice MemoryMin floor keeps admin access
    # alive.
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
    };

    # Compressed RAM swap as a cushion for brief allocation spikes.  No disk
    # swap (the droplet has only an ext4 root); zram trades a little CPU to
    # compress cold pages and gives systemd-oomd clearer pressure signals to
    # act on before memory is truly exhausted.  Kept modest so the backing
    # store does not itself contend heavily for the 8 GiB of physical RAM.
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 25;
    };

    environment.systemPackages = (with pkgs; [
      config.services.subduction.package

      # Editors, shell, baseline
      curl
      git
      tmux
      vim

      # Process / system snapshot
      htop
      ncurses
      procs
      sysstat

      # Disk & inode forensics  (see COOKBOOK.md "Disk and inode pressure")
      dust
      duf
      iotop-c
      lsof
      ncdu

      # Networking & connections
      bandwhich
      bind             # dig, drill
      iftop
      iproute2         # ss, ip
      mtr
      nethogs
      socat
      tcpdump

      # Structured data & search
      bat
      fd
      jq
      ripgrep

      # Encoding / conversion  (base58check <-> hex <-> base64)
      python3Packages.base58   # `base58` CLI: -c for base58check, -d to decode
      unixtools.xxd            # `xxd`: hex dump / reverse  (-p plain, -r reverse)
      convTools

      # Logs
      lnav

      # Tracing & profiling
      bpftrace
      perf
      strace
    ]) ++ bedrockMenu;

    system.stateVersion = "25.11";
  }
