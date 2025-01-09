{
  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    colorschemes.catppuccin.enable = true;
    plugins.lualine.enable = true;
  };
}
