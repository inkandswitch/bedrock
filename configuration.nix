{ config, lib, pkgs, hostname, ... }:
  let
    publicHostname = "bedrock.subduction.keyhive.org";
  in {
    # Serial console for DigitalOcean web console access
    boot.kernelParams = [ "console=ttyS0,115200n8" ];

    networking.hostName = hostname;
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };

    time.timeZone      = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";

    users.users.expede = {
      isNormalUser = true;
      description  = "Brooklyn Zelenka";
      extraGroups  = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        # Brooke
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUKVPRsoJEVWhHtz/2RhbVTZNvyNEm08KJK/3bOSdNc"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmJy3W56uqJjXGCHYOSJkLw+Ae/SgtF8B0qtjcDxtXp"

        # Alex Warth
        "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA1o2gb/keuxDxuk4QlZKcxWMSbvWDYLENX+6vEGA/4T9Yg6eL2g7ovRKo25/rOZV6hgc5TMt//VMSgJcf6LXJngmr3KkXe+QNu3a1jimosVhFwjule2U5R5dKETGupQ2kopBaV3PWLFb+ZbvhgdlY8HeFaOvUAybxfvLOmFtj1ta5VT2ccXPXKndCjfw/eaICknNhevi36KObCdj7Eh/BhI5kN77t61cPbQW+J29UubC6eqToVIFIMG0oD913rUV+yASpAPDsYz4FsMU8ONx8vjwUTQhWLYli3aKniVyHC4HNOoJ/cDlYHJ0+RoHzpKiQueEiHtdd1e2/YVW+K8F4mw=="

        # Alex Good
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDfnGYUnlU6SKm6VGZQRxUGA+p9PgjEmaUhSKQeKx+pgAq8F1yRrmJQ6hsCsHrGu0+Rk/r1wi6MImUej2vmit8jO5wjBcv17EJM9bCXQUvrElLtaH+815r/DOIfyEsSpuZxe5tQ+IoKnasBQUKCkvGwBrPotJmqsHS5xqhke4/uGSid/g2ZSsF2ScLlD2E20+8OsTKw6nE+pfs+uchXwoiMmhclcyWK9cEwA9GLpPcjikQwdQThmeIZZGvRX7WvuPLZMp/AeoxCB+Y3KjEYpBtVS+rsv48GUAq2V0+SG35C1HJ3gGnKA+13xSdIHtfzxjlQy+7QWtagzF/0LlEgxm6gqsyC0xyDLDqiDxVRR8Nj0+ZXNejRNFubwg3YD4jx/JTIJ4u3/XDMlAw7wJGg1t3cMy+uR3/+cacsn5Py2nRZYvIxtBpToMKU9JOwVi6vz4kt+OeanLWP05a08XAnBW+c10P8qeN09he5Vvn6KL7cMr9RsGXzp9BHYqfc82PhskE="

        # "alex-zephyrus"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpk50Fj8AnhhWB8y4tHHzUlDffwhxxeE6Ra81qbtXqJ1QSzam/eKn25usvRAWYijD7JzhJHBRSftCeF90dXBWMHjAWPaRYxn/J0vXYajuv3+7KV5g97Q5mTqVb6bRIW1gWprVF0+1I2aZaU1MG2sMf/jPd1+hN0JXC+vCvS8xYdxJFCQhWNzIhNX6q5G7gfLjYJ4598kQmCcmQ03OMVGfWx94DKr24fBF3eCLdw4Ub53iP/9ClzcxsmXNIJPbCaDAebmPS8uQSUkfhFVtcwBbllueW73y2kkMdFGhbFNmJXy2k4TReDZhIk6U113ehoiikjxOxDCNutdQODyPh04C48LG6+j4YGUPbkBPsjLyveWYWJw4tcGvREB0ZN+Cql6w7NXt8ZzfbEqK01pKBq7Bmhiq2DGNqE6A2PFmEyuvaOCyigP5jBgpB0K1N0h+T56IVFlDCGqLHcB5LaCiXMxKAAD26K6v+qc/G4/AxGozpd+BS3T6Bqm+pH1vWCdNEsz0="

        # PvH
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxWJimKcZjUM4cyuroZ2brFclTxpDsoxQ3NjK43eWbn"
      ];
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
          enable        = true;
          serviceName   = publicHostname;
          socket        = "127.0.0.1:8080";
          keyFile       = "/var/lib/subduction/key-seed";
          enableMetrics = true;
          metricsPort   = 9090;
        };

        grafana.provisionDashboard = true;
      };

      prometheus = {
        enable = true;
        port   = 9092;

        scrapeConfigs = [{
          job_name = "subduction";
          static_configs = [{
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

    # Alloy config: scrape systemd journal + subduction log files → Loki
    environment.etc."alloy/config.alloy".text = ''
      // ── Loki sink ──────────────────────────────────────────────────────
      loki.write "local" {
        endpoint {
          url = "http://localhost:3100/loki/api/v1/push"
        }
      }

      // ── Systemd journal ────────────────────────────────────────────────
      loki.source.journal "journal" {
        forward_to = [loki.relabel.journal.receiver]
        max_age    = "12h"
        labels     = {
          job  = "systemd-journal",
          host = "${hostname}",
        }
      }

      loki.relabel "journal" {
        forward_to = [loki.write.local.receiver]

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
      }

      // ── Subduction log files ───────────────────────────────────────────
      local.file_match "subduction_logs" {
        path_targets = [{"__path__" = "/var/log/subduction/*.log"}]
      }

      loki.source.file "subduction" {
        targets    = local.file_match.subduction_logs.targets
        forward_to = [loki.write.local.receiver]
      }
    '';

    systemd.services.alloy.serviceConfig.ReadOnlyPaths =
      [ "/var/log/subduction" ];

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
