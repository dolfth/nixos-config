{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./programs/nixvim.nix
    ./programs/fish.nix
    ./programs/sops-nix.nix

    ./services/homepage.nix
    ./services/samba.nix
    ./services/sanoid.nix
    ./services/syncthing.nix
    ./services/tailscale.nix
    ./services/zfs.nix

  ];

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

  fileSystems."/mnt/media" = {
    device = "//nas/data/";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";

      in ["${automount_opts},credentials=./smb-secrets,uid=${toString config.users.users.dolf.uid},gid=${toString config.users.groups.dolf.gid}"];
  };

  fileSystems."/mnt/docker" = {
    device = "//nas/docker";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,user,users";

      in ["${automount_opts},credentials=./smb-secrets,uid=${toString config.users.users.dolf.uid},gid=${toString config.users.groups.dolf.gid}"];
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

  users.users."dolf"= {
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
    shell = pkgs.fish;
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
  ];

  ##### Programs #################################################################

  programs = {
    bat.enable = true;
    starship.enable = true;
    starship.presets = [ "tokyo-night" ];
  };

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
