# Minimal home-manager configuration for a headless server.
{ pkgs, username, ... }:
{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion  = "25.11";

    packages = with pkgs; [
      btop
      killall
      ripgrep
    ];
  };

  programs = {
    fish.enable     = true;
    starship.enable = true;

    git = {
      enable = true;
      settings.user = {
        name  = "Brooklyn Zelenka";
        email = "brooklyn@inkandswitch.com";
      };
    };
  };
}
