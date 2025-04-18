{ config, pkgs, inputs, ... }:

{
  services.plex = {
    enable = true;
    dataDir = "/var/lib/plex";
    };

  # Until sonarr/radarr updates upstream
  nixpkgs.config.permittedInsecurePackages = [
    "aspnetcore-runtime-6.0.36"
    "aspnetcore-runtime-wrapped-6.0.36"
    "dotnet-sdk-6.0.428"
    "dotnet-sdk-wrapped-6.0.428"
     ];

  nixarr = {
    enable = true;
    mediaDir = "/mnt/media";
    stateDir = "/mnt/media/.nixarr";
    jellyfin.enable = true;
    transmission.enable = true;
    bazarr.enable = true;
    lidarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    readarr.enable = false;
    sonarr.enable = true;
  };
}
