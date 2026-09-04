# bedrock — production Subduction sync server.
#
# DigitalOcean droplet: 16 GB RAM, x86_64.
{ ... }:
{
  bedrock = {
    publicHostname = "subduction.sync.inkandswitch.com";

    # Leave room for the OS, observability stack, and enough page cache to
    # hold the redb file.
    subduction = {
      memoryHigh       = "11G";
      memoryMax        = "13G";
      maxResidentTrees = 32768; # 2^15
    };

    # Generous: these never bind in practice on 16 GB; they exist so a
    # runaway Loki compaction cannot take the whole box.
    observability = {
      alloy      = { memoryHigh = "512M"; memoryMax = "768M"; };
      grafana    = { memoryHigh = "1G";   memoryMax = "1536M"; };
      loki       = { memoryHigh = "2G";   memoryMax = "3G"; };
      prometheus = { memoryHigh = "1G";   memoryMax = "1536M"; };
    };

    sshMemoryMin = "768M";
    stateVersion = "25.11";
  };
}
