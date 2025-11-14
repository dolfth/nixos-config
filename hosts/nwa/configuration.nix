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
    mirroredBoots = [
      {
        devices = [ "nodev" ];
        path = "/boot1";
      }
      {
        devices = [ "nodev" ];
        path = "/boot2";
      }
    ];
  };

  boot.zfs.extraPools = [ "tank" ];

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
      nftables.enable = true;
      useNetworkd = true;
      firewall.enable = false;

      # Create bridge interface with NixOS
      bridges.br0 = {
        interfaces = [ "eno2" ];  # Your ethernet interface
      };

      # Configure bridge with DHCP, ip address fxed by router 
      interfaces.br0 = {
        useDHCP = true;
          };
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
    extraGroups = [ "wheel" "users" "media" "incus-admin"];
    packages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];
  };

  users.users.emilie= {
    isNormalUser = true;
    uid = 1001;
    group = "emilie";
    extraGroups = [ "users"];
  };

  users.groups.dolf.gid = 1000;
  users.groups.emilie.gid = 1001;

  # Enable automatic login for the user.
  services.getty.autologinUser = "dolf";

##### Packages ################################################################
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    cifs-utils
    dust
    ghostty.terminfo
    git
    htop
    iperf3
    jq
    mosh
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
