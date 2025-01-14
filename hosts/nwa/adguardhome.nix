{ config, pkgs, ... }:

{
  services = {
    adguardhome = {
      enable = true;
    };
  };
}
