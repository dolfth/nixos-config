{ config, pkgs, ... }:

{
  imports = [
    ../../common
    ./configuration.nix
    ./hardware-configuration.nix

    ./gatus.nix
    ./incus.nix
    ./jellyplex-watched.nix
    ./media.nix
    ./samba.nix
    ./power.nix
    ./scrutiny.nix
    ./syncthing.nix
    ./zfs.nix
  ];
}
