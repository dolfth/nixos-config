{ config, lib, pkgs, modulesPath, ... }:

{
  programs.fish = {
    enable = true;
    shellAliases = {
      cc = "nvim /etc/nixos/configuration.nix";
      rr = "sudo nixos-rebuild switch";
      ll = "ls -alh";
    };
  };
}
