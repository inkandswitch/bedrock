# Minimal home-manager configuration for a headless server.
#
# Required extraSpecialArgs:
#   username : Unix login name           (e.g. "expede")
#   fullName : Git author name           (e.g. "Brooklyn Zelenka")
#   email    : Git author email
#   shell    : "fish" or "zsh"
{ pkgs, username, fullName, email, shell, ... }:
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
    fish.enable     = shell == "fish";
    zsh.enable      = shell == "zsh";
    starship.enable = true;

    git = {
      enable = true;
      settings.user = {
        name  = fullName;
        email = email;
      };
    };
  };
}
