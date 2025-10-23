{ config, pkgs, ... }:

{
  imports = [
    ../../common
    ./configuration.nix
    ./hardware-configuration.nix

    ./adguardhome.nix
    ./homepage.nix
    ./home-assistant.nix
    ./media.nix
    ./samba.nix
    ./scrutiny.nix
    ./syncthing.nix
    ./zfs.nix
  ];
}
