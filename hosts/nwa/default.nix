{ config, pkgs, ... }:

{
  imports = [
    ../../common
    ./configuration.nix
    ./hardware-configuration.nix

    ./adguardhome.nix
    ./homepage.nix
    ./incus.nix
    ./media.nix
    ./samba.nix
    ./scrutiny.nix
    ./syncthing.nix
    ./webdav.nix
    ./zfs.nix
  ];
}
