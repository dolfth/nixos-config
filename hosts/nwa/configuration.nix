{ config, lib, pkgs, inputs, ... }:

let
  user="dolf";
in

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  services = {
    mealie.enable = true;
  };

##### Boot Settings ###########################################################

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

  boot.zfs.extraPools = [ "backup" "tank" ];

##### Hardware and Graphics ###################################################

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

##### Timezone & Locale #######################################################

    time.timeZone = "Europe/Amsterdam";
    console.keyMap = "us";
    i18n = {
      supportedLocales = [ "en_US.UTF-8/UTF-8" "nl_NL.UTF-8/UTF-8" ];
    };

##### Networking ##############################################################

    networking = {
      hostName = "nwa";
      hostId = "04ef5600";
      useDHCP = true;
      firewall.enable = false;
      nftables.enable = true;
    };

##### Secrets #################################################################

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/dolf/.config/sops/age/keys.txt";
    };

##### User Accounts ###########################################################

  users.users.${user}= {
    isNormalUser = true;
    uid = 1000;
    group = "dolf";
    description = "Dolf ter Hofste";
    extraGroups = [ "wheel" "users" ];
    packages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];
  };

  users.groups.dolf.gid = 1000;

  # Enable automatic login for the user.
  services.getty.autologinUser = "dolf";

##### Packages ################################################################

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    cifs-utils
    dust
    git
    htop
    jq
    lshw
    parted
    sanoid
    smartmontools
    sops
  ];

##### NixOS System Installed Version (Do not edit) #############################

  system.stateVersion = "24.11";

################################################################################
}
