{ config, lib, pkgs, modulesPath, ... }:
{
  # ZFS notifications
  services.lldap = {
    enable = true;
    settings = {
    };
  };
}
