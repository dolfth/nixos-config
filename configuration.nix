{ config, lib, pkgs, inputs, ... }:

let
  user="dolf";
in

{
  imports = [
    ./hardware-configuration.nix
    ./mods/nixvim.nix
    ./mods/fish.nix
    ./mods/homepage.nix
    ./mods/samba.nix
    ./mods/syncthing.nix
    ./mods/tailscale.nix
    ./mods/zfs.nix
  ];



  nix.settings.experimental-features = [ "nix-command" "flakes" ];
##### Boot Settings ############################################################

  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    mirroredBoots = [
      { devices = ["nodev"]; path ="/boot"; }
    ];
  };

##### File Systems #############################################################

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/dolf/.config/sops/age/keys.txt";
    secrets.samba_username ={};
    secrets.samba_password ={};
    templates."samba-credentials".content = ''
      username=${config.sops.placeholder.samba_username}
      password=${config.sops.placeholder.samba_password}
    '';
    };

  fileSystems."/mnt/media" = {
    device = "//nas/data/";
    fsType = "cifs";
    options = 
      let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";

      in ["${automount_opts},credentials=./smb-secrets,uid=${toString config.users.users.${user}.uid},gid=${toString config.users.groups.${user}.gid}"];
  };

  fileSystems."/mnt/docker" = {
    device = "//nas/docker";
    fsType = "cifs";
    options = 
      let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";

      in ["${automount_opts}"
      "credentials=${config.sops.templates.samba-credentials.path}"
      "uid=${toString config.users.users.${user}.uid}"
      "gid=${toString config.users.groups.${user}.gid}"
      ];
  };

##### Hardware and Graphics ####################################################

  # Enable zram swap as OpenZFS doesn't support swap on zvols
  # nor on swapfiles on a ZFS dataset.

  zramSwap.enable = true;

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
      ];
    };

##### Timezone & Locale ########################################################

  time.timeZone = "Europe/Amsterdam";
  console.keyMap = "us";
  i18n = {
    supportedLocales = [ "en_US.UTF-8/UTF-8" "nl_NL.UTF-8/UTF-8" ];
  };

##### Networking ###############################################################

  networking = {
    hostName = "nwa";
    hostId = "04ef5600";
    interfaces.en02.ipv4.addresses = [{
      address = "192.168.2.115";
      prefixLength = 24;
    }];
    #useDHCP = false;
    #bridges."bridge0".interfaces = [ "eno2" ];
    #interfaces."bridge0".useDHCP = true;
    firewall.enable = false;
    nftables.enable = true;
  };

##### User Accounts ############################################################

  users.users.${user}= {
    isNormalUser = true;
    uid = 1000;
    group = "dolf";
    description = "Dolf ter Hofste";
    extraGroups = [ "wheel" "docker" "users" ];
    packages = with pkgs; [];
  };

  users.users."docker"= {
    isNormalUser = true;
    uid = 1003;
    group = "docker";
    extraGroups = [ "users" ];
    packages = with pkgs; [];
  };

  users.groups.dolf.gid = 1000;
  #users.groups.docker.gid = 1003;

  # Enable automatic login for the user.
  services.getty.autologinUser = "dolf";

##### Packages #################################################################

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    cifs-utils
    docker-compose
    git
    htop
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    jq
    lshw
    mealie

    parted
    sanoid
    smartmontools
    sops
  ];

##### Services #################################################################

  services = {
    mealie.enable = true;
    scrutiny.enable = true;
    jellyfin.enable = true;
    plex.enable = true;
    radarr.enable = true;
  };

##### Containers ###############################################################

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      userland-proxy = false;
      experimental = true;
      metrics-addr = "0.0.0.0:9323";
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
    };
  };

##### Voodoo ###################################################################

  # Launch fish from bash
  # prevents https://fishshell.com/docs/current/index.html#default-shell

  programs.bash = {
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

##### NixOS System Installed Version (Do not edit) #############################

  system.stateVersion = "24.11";

################################################################################
}
