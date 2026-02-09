{ ... }:

{
  programs.nixvim = {
    enable = true;
    colorschemes.catppuccin.enable = true;
    plugins = {
      lualine.enable = true;
      treesitter = {
        enable = true;
        folding = false;
      };
    };
  };
  programs.neovim.defaultEditor = true;
}
