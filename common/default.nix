{ config, pkgs, ... }:

{
  imports = [
    ./fish.nix
    ./nixvim.nix
    ./tailscale.nix
  ];

}
