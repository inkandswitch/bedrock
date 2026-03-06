# Hardware profile for a DigitalOcean droplet (KVM/QEMU guest).
#
# DO droplets use virtio for block and network devices.
# The qemu-guest profile pulls in virtio kernel modules automatically.
#
# Note: fileSystems are managed by disko (disk-config.nix) and do not
# need to be declared here. If nixos-generate-config was run on the
# live droplet, merge any additional detected modules into the lists below.
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub = {
    enable  = true;
    # disko manages the device via EF02 partition; no explicit device needed
    # but nixos-anywhere may override this.
  };

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_blk"
    "virtio_pci"
    "virtio_scsi"
    "xen_blkfront"
  ];

  boot.initrd.kernelModules = [ "virtio_gpu" ];
  boot.kernelModules        = [ "kvm-intel" ];
}
