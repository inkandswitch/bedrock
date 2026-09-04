# DigitalOcean platform support.
#
# DO droplets provision networking via cloud-init (not DHCP).
# Without this module, the machine boots but has no IP addresses.
{ lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/digital-ocean-config.nix"
  ];

  # DO provisions IPs via cloud-init, not DHCP
  networking.useDHCP = lib.mkForce false;

  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      datasource_list = [
        "ConfigDrive"
        "Digitalocean"
      ];
      datasource.ConfigDrive = { };
      datasource.Digitalocean = { };

      cloud_init_modules = [
        "seed_random"
        "bootcmd"
        "write_files"
        "growpart"
        "resizefs"
        "set_hostname"
        "update_hostname"
        # "update_etc_hosts"  # not supported on NixOS
        # "users-groups"      # throws error on NixOS
        # "ssh"               # tries to edit /etc/ssh/sshd_config
        "set_password"
      ];

      cloud_config_modules = [
        "ssh-import-id"
        "keyboard"
        # "locale"  # not supported on NixOS
        "runcmd"
        "disable_ec2_metadata"
      ];

      cloud_final_modules = [
        "write_files_deferred"
        "puppet"
        "chef"
        "ansible"
        "mcollective"
        "salt_minion"
        "reset_rmc"
        # "scripts_vendor"       # install dotty agent fails
        "scripts_per_once"
        "scripts_per_boot"
        # "scripts_per_instance" # broken shebang in DO script
        "scripts_user"
        "ssh_authkey_fingerprints"
        "keys_to_console"
        "install_hotplug"
        "phone_home"
        "final_message"
      ];
    };
  };
}
