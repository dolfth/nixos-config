{ config, pkgs, ... }:

{
  virtualisation.incus = {
    enable = true;
    package = pkgs.incus;
    preseed = {
      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.0.100.1/24";
            "ipv4.nat" = "true";
          };
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              type = "nic";
	      network = "incusbr0";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
        {
          name = "vlan20";
          description = "Profile for VLAN 20 (IoT/TV network)";
          devices = {
            eth0 = {
              name = "eth0";
              type = "nic";
              nictype = "macvlan";
              parent = "eno2";
              vlan = "20";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
      ];

      storage_pools = [
        {
          name = "default";
          driver = "zfs";
          config = {
            source = "tank/incus";
	  };
        }
      ];

    };
  };
}
