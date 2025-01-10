{ config, pkgs, inputs, ... }:

# let
#     nixvim = import (builtins.fetchGit {
#         url = "https://github.com/nix-community/nixvim";
#         # When using a different channel you can use `ref = "nixos-<version>"` to set it here
#     });
# in
{
  imports = [nixvim.nixosModules.nixvim];

  programs.nixvim = {
    enable = true;
    colorschemes.catppuccin.enable = true;
    plugins.lualine.enable = true;
  };
}
