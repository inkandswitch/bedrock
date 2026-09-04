# Memory caps for the observability services (Loki, Prometheus, Grafana,
# Alloy), sized per host via `bedrock.observability`.
#
# Uncapped, these float freely -- harmless on a 16 GB droplet, but on 4 GB a
# Loki compaction or a chatty Grafana can crowd Subduction.  Each unit gets
# its own MemoryHigh/MemoryMax so none can starve the others.  They keep the
# default OOMScoreAdjust=0 (Subduction sits at 500), so a *global* OOM still
# takes Subduction first; these caps only bound each service individually.
#
# Lives in its own module because `systemd.services` is also set piecewise
# in common.nix and Nix forbids mixing `a = …` with `a.b = …` in one attrset.
{ config, lib, ... }:
{
  systemd.services = lib.mapAttrs (_unit: cap: {
    serviceConfig = {
      MemoryHigh = cap.memoryHigh;
      MemoryMax  = cap.memoryMax;
      ManagedOOMMemoryPressure = "auto";
    };
  }) config.bedrock.observability;
}
