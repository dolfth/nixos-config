{ ... }:

{
  imports = [
    # Common configurations
    ../../common              # Shell, editor, tailscale
    ../base.nix               # Users, packages, locale, sops
    ../../modules             # NAS services

    # Host-specific
    ./configuration.nix       # Boot, hardware, networking
    ./hardware-configuration.nix
    ./incus.nix
    ./power.nix
    ./zfs.nix
  ];

  # Enable services
  services.frame-art-changer.enable = true;
}
