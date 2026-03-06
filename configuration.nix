# NixOS configuration for bedrock — a DigitalOcean Subduction sync server.
#
# Services:
#   - Subduction sync server (localhost:8080, metrics on 9090)
#   - Caddy reverse proxy with automatic Let's Encrypt
#   - Prometheus / Loki / Promtail / Grafana monitoring stack
#   - Tailscale mesh VPN
#   - OpenSSH (key-only)
{ config, lib, pkgs, hostname, ... }:

let
  publicHostname = "bedrock.subduction.keyhive.org";
in {
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPUKVPRsoJEVWhHtz/2RhbVTZNvyNEm08KJK/3bOSdNc"
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

    promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };

        positions.filename = "/var/lib/promtail/positions.yaml";

        clients = [{ url = "http://localhost:3100/loki/api/v1/push"; }];

        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job  = "systemd-journal";
                host = hostname;
              };
            };
            relabel_configs = [{
              source_labels = [ "__journal__systemd_unit" ];
              target_label  = "unit";
            }];
          }
          {
            job_name = "subduction";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                job      = "subduction";
                host     = hostname;
                __path__ = "/var/log/subduction/*.log";
              };
            }];
          }
        ];
      };
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

  # Allow Promtail to read the systemd journal
  systemd.services.promtail.serviceConfig = {
    ProtectSystem  = lib.mkForce "full";
    ReadOnlyPaths  = [ "/var/log/journal" "/run/log/journal" "/etc/machine-id" ];
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
