{ config, pkgs, ... }:

{
  imports = [
    ../../common
    ./configuration.nix
    ./hardware-configuration.nix

    ./adguardhome.nix
    ./homepage.nix
   #./nixarr.nix
    ./samba.nix
    ./syncthing.nix
    ./zfs.nix
  ];

}
