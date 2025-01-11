{ config, pkgs, ... }:

{
  programs = {
    fish = {
      enable = true;
      shellAliases = {
        cc = "nvim ~/.config/nixos/configuration.nix";
        ll = "ls -alh";
	cat = "bat";
      };
    };
    bat.enable = true;
    starship.enable = true;
    starship.presets = [ "gruvbox-rainbow" ];
  };
}
