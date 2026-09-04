# coln-sync — staging Subduction sync server for the Coln project.
#
# DigitalOcean droplet: 2 vCPU, 4 GB RAM, 80 GB disk, x86_64.
#
# Same software stack as bedrock; the differences are DNS, memory caps
# sized for a quarter of the RAM, and one extra account.
{ pkgs, ... }:
{
  bedrock = {
    publicHostname = "coln.sync.inkandswitch.com";

    # 4 GB budget (MemoryMax ceilings), roughly:
    #   OS + sshd + journald + Caddy  ~0.4 G
    #   ssh.slice floor                0.25 G
    #   observability caps (below)     ~1.1 G
    #   Subduction                     1.75 G high / 2.25 G max
    # zram (25%) absorbs brief spikes before systemd-oomd steps in.
    subduction = {
      memoryHigh       = "1750M";
      memoryMax        = "2250M";
      # Staging hosts a small working set; keep the resident cache modest so
      # it cannot crowd out the observability stack.
      maxResidentTrees = 8192; # 2^13
    };

    observability = {
      alloy      = { memoryHigh = "128M"; memoryMax = "192M"; };
      grafana    = { memoryHigh = "256M"; memoryMax = "384M"; };
      loki       = { memoryHigh = "512M"; memoryMax = "768M"; };
      prometheus = { memoryHigh = "256M"; memoryMax = "384M"; };
    };

    sshMemoryMin = "256M";
    stateVersion = "26.05";

    # Coln-specific accounts, in addition to the shared base set.
    accounts.acc = {
      name  = "Alex Currie-Clark";
      email = "acc@inkandswitch.com"; # TODO: confirm (only affects git author on-server)
      shell = pkgs.zsh;
      keys  = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDgPxGjZ+HWwQEVDuyAGLgpUyT0omF69ATPg1d6/7x5346hcwPvXffUhtWb7rGGYANewflTK5178UuQ4iaWJKj9I4Hwr3ySO+s4kIzXLTQa1VLgI5Smm2VepVKGidmX3YiEjwKw4LyNQf1PK9+XO9hm1Xu6eTCQvDcK2tqdJ78Zlyv7yJ2k/O7ugQfXfi2Coxg9yIts5Mst7mzZffo3+pnGG36ZZM8SuWehAFqxDIgRlWFjbcV/DHLCDoebB6JIXtFaRNAMLzXeOs16WAsBdrNcvwCMfjf1jotpD863qQZ3N6C+ZKI/0nUsZgtr4YTeZDnm7qYj23MsfQdpv4NnniFt acurrieclark@Alexs-MacBook-Pro.local"
      ];
    };
  };
}
