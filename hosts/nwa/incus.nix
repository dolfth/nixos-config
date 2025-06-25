{ config, pkgs, ... }:

{
  virtualisation.incus = {
    enable = true;
    package = pkgs.incus;
    preseed = {
      networks = [
        {
          config = {
            "ipv4.address" = "10.0.100.1/24";
            "ipv4.nat" = "true";
          };
          name = "bridge0";
          type = "bridge";
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              type = "nic";
	      nictype = "bridged";
              parent = "bridge0";
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
