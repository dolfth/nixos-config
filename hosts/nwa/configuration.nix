{ config, lib, pkgs, inputs, ... }:

let
  user = "dolf";
in
{
##### Boot ###################################################################

  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = true;
    mirroredBoots = [
      { devices = [ "nodev" ]; path = "/boot1"; }
      { devices = [ "nodev" ]; path = "/boot2"; }
    ];
  };

  boot.zfs.extraPools = [ "tank" ];

##### Hardware ###############################################################

  # zram swap since ZFS doesn't support swap on zvols or swapfiles
  zramSwap.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

##### Locale #################################################################

  time.timeZone = "Europe/Amsterdam";
  console.keyMap = "us";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "nl_NL.UTF-8/UTF-8" ];

##### Networking #############################################################

  networking = {
    hostName = "nwa";
    hostId = "04ef5600";
    nftables.enable = true;
    useNetworkd = true;
    firewall.enable = false;
    bridges.br0.interfaces = [ "eno2" ];
    interfaces.br0.useDHCP = true;
  };

  # Workaround for Intel NIC hardware hang
  systemd.services.fix-eno2-hang = {
    description = "Disable TSO/GSO/EEE on eno2 to prevent hardware hang";
    after = [ "network-pre.target" ];
    before = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.ethtool}/bin/ethtool -K eno2 tso off gso off"
        "${pkgs.ethtool}/bin/ethtool --set-eee eno2 eee off"
      ];
    };
  };

##### Secrets ################################################################

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
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

  system.stateVersion = "24.11";
}
