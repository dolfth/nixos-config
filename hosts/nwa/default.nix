{ ... }:

{
  imports = [
    # Common configurations
    ../../common              # Shell, editor (shared with VMs)
    ../../common/nixvim.nix   # Nixvim (host-only)
    ../../common/tailscale.nix # Tailscale (host-specific flags)
    ../base.nix               # Users, packages, locale, sops
    ../../modules             # NAS services

    # Host-specific
    ./configuration.nix       # Boot, hardware, networking
    ./hardware-configuration.nix
    ./incus.nix
    ./power.nix
    ./microvm.nix
    ./claude-vm.nix
    ./zfs.nix
  ];

}
