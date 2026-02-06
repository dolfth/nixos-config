{ config, pkgs, ... }:

let
  user = "dolf";
in
{
##### Locale #################################################################

  time.timeZone = "Europe/Amsterdam";
  console.keyMap = "us";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "nl_NL.UTF-8/UTF-8" ];

##### Secrets ################################################################

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/dolf/.config/sops/age/keys.txt";
  };

##### Users ##################################################################

  users.users.${user} = {
    isNormalUser = true;
    uid = 1000;
    group = "dolf";
    description = "Dolf ter Hofste";
    extraGroups = [ "wheel" "users" "media" "incus-admin" ];
    packages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];
  };

  users.users.emilie = {
    isNormalUser = true;
    uid = 1001;
    group = "emilie";
    extraGroups = [ "users" ];
  };

  users.groups.dolf.gid = 1000;
  users.groups.emilie.gid = 1001;

  services.getty.autologinUser = "dolf";

##### Nix ####################################################################

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.auto-optimise-store = true;

##### Packages ###############################################################

  environment.systemPackages = with pkgs; [
    cifs-utils
    dust
    ethtool
    ghostty.terminfo
    git
    hdparm
    htop
    iperf3
    jq
    mosh
    sanoid
    smartmontools
    sops
  ];
}
