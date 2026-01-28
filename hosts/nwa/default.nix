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
    ./services.nix
    ./syncthing.nix
    ./zfs.nix
  ];
}
