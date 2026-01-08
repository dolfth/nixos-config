{ config, pkgs, ... }:

{
  imports = [
    ../../common
    ./configuration.nix
    ./hardware-configuration.nix

    ./homepage.nix
    ./home-assistant.nix
    ./incus.nix
    ./media.nix
    ./samba.nix
    ./scrutiny.nix
    ./syncthing.nix
    ./zfs.nix
  ];
}
