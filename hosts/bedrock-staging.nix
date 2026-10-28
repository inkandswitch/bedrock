# bedrock-staging — pre-release Subduction sync server.
#
# DigitalOcean droplet: Basic, 4 vCPU, 8 GB RAM, 160 GB disk, x86_64.
#
# Runs Subduction from the `subduction-staging` flake input (currently the
# `keyline-take-2` branch) rather than the `subduction` input the other
# hosts share; see `hosts` in ../flake.nix.
{ ... }:
{
  bedrock = {
    publicHostname = "staging.subduction.sync.inkandswitch.com";

    # 8 GB budget (MemoryHigh thresholds), roughly:
    #   OS + sshd + journald + Caddy  ~0.5 G
    #   ssh.slice floor                0.5 G
    #   observability caps (below)     ~2 G
    #   Subduction                     4 G high / 5 G max
    # zram (25%) absorbs brief spikes before systemd-oomd steps in.
    subduction = {
      auth             = "keyhive";
      memoryHigh       = "4G";
      memoryMax        = "5G";
      maxResidentTrees = 16384; # 2^14
    };

    observability = {
      alloy      = { memoryHigh = "192M"; memoryMax = "256M"; };
      grafana    = { memoryHigh = "384M"; memoryMax = "512M"; };
      loki       = { memoryHigh = "1G";   memoryMax = "1536M"; };
      prometheus = { memoryHigh = "384M"; memoryMax = "512M"; };
    };

    sshMemoryMin = "512M";
    stateVersion = "26.05";
  };
}
