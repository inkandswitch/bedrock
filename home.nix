# Minimal home-manager configuration for a headless server.
#
# Per-user values are passed in via `_module.args` on each user's
# home-manager submodule (set in configuration.nix).  We can't use the
# global `home-manager.extraSpecialArgs` for these because it's shared
# across every user.
#
# Required module args:
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

    # System-wide investigation tooling lives in configuration.nix's
    # environment.systemPackages so it works under sudo and on root
    # sessions.  Only per-user shell conveniences belong here.
    packages = with pkgs; [
      btop
      killall
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
