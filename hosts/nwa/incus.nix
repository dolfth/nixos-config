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
	    "ipv4.address" = "auto";
            "ipv4.nat" = "true";
            "ipv6.address" = "auto";
            "ipv6.nat" = "true";
          };
        }
      ];

      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              parent = "incusbridge0";
              type = "nic";
              nictype = "bridged";
            };
            root = {
              path = "/";
              pool = "default";
              size = "35GiB";
              type = "disk";
            };
          };
        }
      ];

      storage_pools = [
        {
          name = "default";
          driver = "dir";
          config = {
            source = "/var/lib/incus/storage-pools/default";
          };
        }
      ];

    };
  };
}
