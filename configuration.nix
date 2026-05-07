{ config, lib, pkgs, hostname, adminUsername, ... }:
  let
    publicHostname = "subduction.sync.inkandswitch.com";

    accounts = {
      ${adminUsername} = {
        name  = "Brooklyn Zelenka";
        email = "brooklyn@inkandswitch.com";
        shell = "fish";
        keys  = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUKVPRsoJEVWhHtz/2RhbVTZNvyNEm08KJK/3bOSdNc"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmJy3W56uqJjXGCHYOSJkLw+Ae/SgtF8B0qtjcDxtXp"
        ];
      };

      alexjg = {
        name  = "Alex Good";
        email = "alex@inkandswitch.com";
        shell = "zsh";
        keys  = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDfnGYUnlU6SKm6VGZQRxUGA+p9PgjEmaUhSKQeKx+pgAq8F1yRrmJQ6hsCsHrGu0+Rk/r1wi6MImUej2vmit8jO5wjBcv17EJM9bCXQUvrElLtaH+815r/DOIfyEsSpuZxe5tQ+IoKnasBQUKCkvGwBrPotJmqsHS5xqhke4/uGSid/g2ZSsF2ScLlD2E20+8OsTKw6nE+pfs+uchXwoiMmhclcyWK9cEwA9GLpPcjikQwdQThmeIZZGvRX7WvuPLZMp/AeoxCB+Y3KjEYpBtVS+rsv48GUAq2V0+SG35C1HJ3gGnKA+13xSdIHtfzxjlQy+7QWtagzF/0LlEgxm6gqsyC0xyDLDqiDxVRR8Nj0+ZXNejRNFubwg3YD4jx/JTIJ4u3/XDMlAw7wJGg1t3cMy+uR3/+cacsn5Py2nRZYvIxtBpToMKU9JOwVi6vz4kt+OeanLWP05a08XAnBW+c10P8qeN09he5Vvn6KL7cMr9RsGXzp9BHYqfc82PhskE="
          # alex-zephyrus
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpk50Fj8AnhhWB8y4tHHzUlDffwhxxeE6Ra81qbtXqJ1QSzam/eKn25usvRAWYijD7JzhJHBRSftCeF90dXBWMHjAWPaRYxn/J0vXYajuv3+7KV5g97Q5mTqVb6bRIW1gWprVF0+1I2aZaU1MG2sMf/jPd1+hN0JXC+vCvS8xYdxJFCQhWNzIhNX6q5G7gfLjYJ4598kQmCcmQ03OMVGfWx94DKr24fBF3eCLdw4Ub53iP/9ClzcxsmXNIJPbCaDAebmPS8uQSUkfhFVtcwBbllueW73y2kkMdFGhbFNmJXy2k4TReDZhIk6U113ehoiikjxOxDCNutdQODyPh04C48LG6+j4YGUPbkBPsjLyveWYWJw4tcGvREB0ZN+Cql6w7NXt8ZzfbEqK01pKBq7Bmhiq2DGNqE6A2PFmEyuvaOCyigP5jBgpB0K1N0h+T56IVFlDCGqLHcB5LaCiXMxKAAD26K6v+qc/G4/AxGozpd+BS3T6Bqm+pH1vWCdNEsz0="
        ];
      };

      alexwarth = {
        name  = "Alex Warth";
        email = "alexwarth@inkandswitch.com";
        shell = "zsh";
        keys  = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA1o2gb/keuxDxuk4QlZKcxWMSbvWDYLENX+6vEGA/4T9Yg6eL2g7ovRKo25/rOZV6hgc5TMt//VMSgJcf6LXJngmr3KkXe+QNu3a1jimosVhFwjule2U5R5dKETGupQ2kopBaV3PWLFb+ZbvhgdlY8HeFaOvUAybxfvLOmFtj1ta5VT2ccXPXKndCjfw/eaICknNhevi36KObCdj7Eh/BhI5kN77t61cPbQW+J29UubC6eqToVIFIMG0oD913rUV+yASpAPDsYz4FsMU8ONx8vjwUTQhWLYli3aKniVyHC4HNOoJ/cDlYHJ0+RoHzpKiQueEiHtdd1e2/YVW+K8F4mw=="
        ];
      };

      chee = {
        name  = "Chee Rabbits";
        email = "chee@inkandswitch.com";
        shell = "zsh";
        keys  = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHzdaK1G+GPAqG0GfinR6xMMTzmLX2DgFMDSnLE/vEmW yay@chee.party"
        ];
      };

      pvh = {
        name  = "Peter van Hardenberg";
        email = "pvh@inkandswitch.com";
        shell = "zsh";
        keys  = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxWJimKcZjUM4cyuroZ2brFclTxpDsoxQ3NjK43eWbn"
        ];
      };
    };

    shellPackage = shell:
      if shell == "fish" then pkgs.fish
      else if shell == "zsh" then pkgs.zsh
      else throw "shellPackage: unknown shell '${shell}'";
  in {
    networking.hostName = hostname;
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };

    time.timeZone      = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";

    users.users = lib.mapAttrs (_username: account: {
      isNormalUser = true;
      description  = account.name;
      extraGroups  = [ "wheel" ];
      shell        = shellPackage account.shell;
      openssh.authorizedKeys.keys = account.keys;
    }) accounts;

    # Each shell needs to be enabled at the system level so login shells work.
    programs.fish.enable = lib.any (a: a.shell == "fish") (lib.attrValues accounts);
    programs.zsh.enable  = lib.any (a: a.shell == "zsh")  (lib.attrValues accounts);

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

        virtualHosts.${publicHostname}.extraConfig = ''
          reverse_proxy localhost:8080
        '';

        virtualHosts."dashboard.${publicHostname}".extraConfig = ''
          reverse_proxy localhost:3939
        '';
      };

      subduction = {
        server = {
          enable         = true;
          serviceName    = publicHostname;
          socket         = "127.0.0.1:8080";
          keyFile        = "/var/lib/subduction/key-seed";
          maxMessageSize = 104857600; # 100 MiB
          enableMetrics  = true;
          metricsPort    = 9090;
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

      // ── Systemd journal ────────────────────────────────────────────────
      loki.source.journal "journal" {
        forward_to    = [loki.write.local.receiver]
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

      # Subduction syncs many sedimentrees concurrently; raise fd limit to
      # avoid "Too many open files" under heavy publish-all workloads.
      LimitNOFILE = 1048576;
      Environment = "RUST_LOG=subduction=info";
    };

    environment.systemPackages = with pkgs; [
      curl
      git
      htop
      ncurses
      tmux
      vim
    ];

    system.stateVersion = "25.11";
  }
