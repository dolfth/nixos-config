{ config, pkgs, ... }:

{
  programs = {

    fish = {
      enable = true;
      shellAliases = {
        ll = "ls -alh";
      };
    };

    bat.enable = true;

    starship = {
      enable = true;
      presets = [ "gruvbox-rainbow" ];
    };

  # Launch fish from bash
  # prevents https://fishshell.com/docs/current/index.html#default-shell
    bash = {
      interactiveShellInit = ''
        if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
        then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
        fi
      '';
    };
  };
}
