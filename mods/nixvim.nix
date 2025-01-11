{ config, pkgs, inputs, ... }:

{
  programs.nixvim = {
    enable = true;
    colorschemes.catppuccin.enable = true;
    plugins = {
      lualine.enable = true;
      treesitter = {
        enable = true;
        folding = false;
        settings.indent.enable = true;
      };
    };
  };
  programs.neovim.defaultEditor = true;
}
