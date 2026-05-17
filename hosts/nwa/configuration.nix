{ config, lib, pkgs, ... }:

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

  # Disable Bluetooth to save power; WiFi (iwlwifi) is enabled as a backup link
  boot.blacklistedKernelModules = [ "btusb" ];

  # Required for iwlwifi firmware
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

##### Networking #############################################################

  networking = {
    hostName = "nwa";
    hostId = "04ef5600";
    nftables.enable = true;
    useNetworkd = true;
    firewall.enable = false;
    bridges.br0.interfaces = [ "eno2" ];
    interfaces.br0.useDHCP = true;
    wireless = {
      enable = true;
      interfaces = [ "wlo1" ];
      secretsFile = config.sops.templates."wireless.conf".path;
      networks."Johnny Rotten" = {
        pskRaw = "ext:psk_home";
      };
    };
  };

  sops.secrets.wifi_psk_home = {};
  sops.templates."wireless.conf" = {
    content = ''
      psk_home=${config.sops.placeholder.wifi_psk_home}
    '';
    owner = "wpa_supplicant";
    group = "wpa_supplicant";
  };

  # Workaround for Intel NIC hardware hang
  systemd.services.fix-eno2-hang = {
    description = "Disable offloads and EEE on eno2 to prevent hardware hang";
    after = [ "network-pre.target" ];
    before = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.ethtool}/bin/ethtool -K eno2 gso off gro off tso off tx off rx off"
        "${pkgs.ethtool}/bin/ethtool --set-eee eno2 eee off"
      ];
    };
  };

  system.stateVersion = "24.11";

##### Nix Settings ###########################################################

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
