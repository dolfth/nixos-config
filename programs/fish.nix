{ config, pkgs, ... }:

{
  programs = {
    fish = {
      enable = true;
      shellAliases = {
        cc = "nvim /etc/nixos/configuration.nix";
        rr = "sudo nixos-rebuild switch";
        ll = "ls -alh";
      };
    };
    bat.enable = true;
    starship.enable = true;
    starship.presets = [ "gruvbox-rainbow" ];
  };
}
