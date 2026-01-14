{ config, pkgs, ... }:

{
  imports = [
    ../../common
    ./configuration.nix
    ./hardware-configuration.nix

    ./homepage.nix
    ./incus.nix
    ./media.nix
    ./samba.nix
    ./power.nix
    ./scrutiny.nix
    ./syncthing.nix
    ./zfs.nix
  ];
}
