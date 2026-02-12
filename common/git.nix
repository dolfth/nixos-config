{ ... }:

{
  programs.git = {
    enable = true;
    config = {
      user.name = "Dolf";
      user.email = "12677636+dolfth@users.noreply.github.com";
      init.defaultBranch = "main";
    };
  };
}
