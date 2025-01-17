{ config, lib, pkgs, inputs, ... }:

let
  user="dolf";
in

{
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

  boot.zfs.extraPools = [ "backup" ];

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
      #interfaces.eno2.ipv4.addresses = [{
      #  address = "192.168.2.115";
      #  prefixLength = 24;
      #}];
      useDHCP = true;
      #bridges."bridge0".interfaces = [ "eno2" ];
      #interfaces."bridge0".useDHCP = true;
      firewall.enable = false;
      nftables.enable = true;
    };

##### File Systems #############################################################

  #microvm = {
  #  hypervisor = "cloud-hypervisor";
  #  vcpu = 2;
  #  mem = 2048;
  #};

  #microvm.interfaces = [ {
  #  type = "tap";
  #  id = "vm-example1" ;
  #  mac = "02:00:00:01:01:01";
  #} ];


  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/dolf/.config/sops/age/keys.txt";
    secrets."samba/username" ={};
    secrets."samba/password" ={};
    templates."samba-credentials".content = ''
      username=${config.sops.placeholder."samba/username"}
      password=${config.sops.placeholder."samba/password"}
    '';
    };

##### User Accounts ############################################################

  users.users.${user}= {
    isNormalUser = true;
    uid = 1000;
    group = "dolf";
    description = "Dolf ter Hofste";
    extraGroups = [ "wheel" "users" ];
    packages = with pkgs; [];
  };

  users.groups.dolf.gid = 1000;

  # Enable automatic login for the user.
  services.getty.autologinUser = "dolf";

##### Packages #################################################################

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    cifs-utils
    dust
    docker-compose
    git
    htop
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    jq
    lshw
    parted
    sanoid
    smartmontools
    sops
  ];

##### Services #################################################################

  services = {
    mealie.enable = true;
    plex.enable = true;
    radarr.enable = true;
  };


##### NixOS System Installed Version (Do not edit) #############################

  system.stateVersion = "24.11";

################################################################################
}
