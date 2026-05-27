{ config, pkgs, ... }:

let
  # Per-host prompt accent: a gruvbox palette color + Nerd Font icon keyed off
  # the hostname, so each machine (nwa, hermes, …) is distinct at a glance.
  # Palette names come from the gruvbox-rainbow preset (gruvbox_dark).
  hostThemes = {
    nwa    = { color = "color_green";  icon = "󰒋"; };   # NAS / server
    hermes = { color = "color_purple"; icon = "󰚩"; };   # agent VM
  };
  host = hostThemes.${config.networking.hostName} or { color = "color_blue"; icon = "󰌽"; };

  # Powerline separators, by codepoint so the exact glyphs can't be mangled:
  #  U+E0B6 rounded left cap, U+E0B0 arrow divider, U+E0B4 rounded right cap.
  pl = {
    capL = builtins.fromJSON ''"\ue0b6"'';
    sep  = builtins.fromJSON ''"\ue0b0"'';
    capR = builtins.fromJSON ''"\ue0b4"'';
  };
in
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
      settings = {
        # gruvbox-rainbow chain with a per-host segment prepended at the front
        # (the stock preset has no hostname segment). Written as one string
        # because TOML strips the preset's `\`-line-continuations at parse time.
        # If you bump starship and the preset tail changes, resync from $os on.
        format =
          "[${pl.capL}](${host.color})$hostname[${pl.sep}](fg:${host.color} bg:color_orange)"
          + "$os$username[${pl.sep}](bg:color_yellow fg:color_orange)"
          + "$directory[${pl.sep}](fg:color_yellow bg:color_aqua)$git_branch$git_status"
          + "[${pl.sep}](fg:color_aqua bg:color_blue)$c$cpp$rust$golang$nodejs$php$java$kotlin$haskell$python"
          + "[${pl.sep}](fg:color_blue bg:color_bg3)$docker_context$conda$pixi"
          + "[${pl.sep}](fg:color_bg3 bg:color_bg1)$time[ ${pl.capR}](fg:color_bg1)$line_break$character";

        hostname = {
          ssh_only = false;
          format = "[ ${host.icon} $hostname ]($style)";
          style = "fg:color_fg0 bg:${host.color}";
        };

        # Breathing room before the OS (NixOS) symbol; default is "[$symbol]".
        os.format = "[ $symbol]($style)";
      };
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
