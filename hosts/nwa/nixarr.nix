{ config, pkgs, inputs, ... }:

{
  programs.nixarr = {
    enable = true;
    mediaDir = "/mnt/media";
    stateDir = "/home/dolf/nixarr";

    jellyfin.enable = true;
    transmission.enable = true;
    bazarr.enable = true;
    lidarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    readarr.enable = true;
    sonarr.enable = true;
  };

}
