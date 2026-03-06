# Disko disk layout for a DigitalOcean droplet.
#
# DO droplets present a single virtio disk at /dev/vda.
# This layout creates:
#   - 512 MiB EFI system partition (for GRUB)
#   - Remainder as ext4 root
#
# After provisioning with nixos-anywhere, the hardware-configuration.nix
# fileSystems entries are superseded by disko's generated mounts.
{ ... }:
{
  disko.devices.disk.main = {
    type    = "disk";
    device  = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # BIOS boot partition (for GRUB on GPT)
        };

        root = {
          size = "100%";
          content = {
            type       = "filesystem";
            format     = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
