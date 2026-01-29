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

  # Disable wireless and bluetooth to save power
  boot.blacklistedKernelModules = [ "iwlwifi" "btusb" ];

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

  system.stateVersion = "24.11";

##### Nix Settings ###########################################################

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
