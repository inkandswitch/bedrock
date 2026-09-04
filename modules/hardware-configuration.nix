# Hardware configuration for a DigitalOcean droplet.
#
# The DO platform module (digitalocean.nix) imports qemu-guest.nix and
# sets up virtio + GRUB + serial console. This file adds any extra
# kernel modules detected on the live hardware. fileSystems are managed
# by disko (disk-config.nix).
{ lib, ... }:
{
  boot.loader.grub = {
    enable = true;
    # digital-ocean-config.nix and disko both add /dev/vda, causing a
    # "duplicated devices in mirroredBoots" error. Force a single entry.
    devices = lib.mkForce [ "/dev/vda" ];
  };

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_blk"
    "xen_blkfront"
  ];
}
