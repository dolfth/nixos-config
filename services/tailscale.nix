{ config, lib, pkgs, modulesPath, ... }:
{
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--ssh" ];
    useRoutingFeatures = "server";
  };
}
