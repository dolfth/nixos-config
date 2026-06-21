{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    # We make nixvim's nixpkgs `follows` ours; pin its source explicitly to
    # match so it doesn't warn about the default being overridden by `follows`.
    nixpkgs.source = pkgs.path;
    colorschemes.catppuccin.enable = true;
    plugins = {
      lualine.enable = true;
      treesitter = {
        enable = true;
        folding.enable = false;
      };
    };
  };
  programs.neovim.defaultEditor = true;
}
