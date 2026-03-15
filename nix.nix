# Shared Nix daemon settings.
{ pkgs, ... }:
{
  nix = {
    package = pkgs.nixVersions.stable;

    optimise.automatic = true;

    gc = {
      automatic  = true;
      dates      = "weekly";
      options    = "--delete-older-than 30d";
    };

    settings = {
      trusted-users = [ "root" "@wheel" ];

      trusted-substituters = [
        "https://cache.nixos.org"
      ];

      download-buffer-size = 268435456; # 256 MiB
      experimental-features = [ "flakes" "nix-command" ];
    };
  };
}
