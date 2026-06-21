{ config, lib, pkgs, ... }:

{
##### Boot ###################################################################

  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
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
      networks."Malcolm McLaren" = {
        pskRaw = "ext:psk_home";
      };
    };
  };

  # Backup uplink: wlo1 lives on a separate VLAN/subnet (mgmt, VLAN 40);
  # a high DHCP route metric keeps wired br0 primary while it's up.
  systemd.network.networks."40-wlo1" = {
    matchConfig.Name = "wlo1";
    networkConfig.DHCP = "yes";
    dhcpV4Config.RouteMetric = 2048;
    # IPv6's default route comes from Router Advertisements, not DHCPv6, so its
    # metric lives under [IPv6AcceptRA] (systemd dropped RouteMetric from the
    # [DHCPv6] section; newer networkd type-checks this and rejects it).
    ipv6AcceptRAConfig.RouteMetric = 2048;
    linkConfig.RequiredForOnline = "no";
  };

  # br0's bridge carrier is the OR of its members, and the VM TAPs always
  # have carrier — so the kernel never marks br0's default route linkdown
  # when eno2 is unplugged. BindCarrier ties br0's operational state to
  # eno2 specifically, so networkd brings br0 down on wire loss and the
  # default route falls through to wlo1.
  systemd.network.networks."40-br0" = {
    networkConfig.BindCarrier = "eno2";
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.ignore_routes_with_linkdown" = 1;
    "net.ipv6.conf.all.ignore_routes_with_linkdown" = 1;
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
