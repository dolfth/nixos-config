{ config, pkgs, ... }:

{
  # ZFS notifications
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    zed.settings = {
      ZED_NOTIFY_INTERVAL_SECS=3600;
      ZED_NTFY_TOPIC = "c22c0a8c-981d-471f-9cae-f36e4c89f19d";
      ZED_NOTIFY_VERBOSE = true;
      ZED_SCRUB_AFTER_RESILVER = true;
    };
  };

  # ZFS snapshots
  services.sanoid = {
    enable = true;
    interval = "hourly";
    templates = {

      frequent = {
          hourly = 24;
          daily = 7;
          monthly = 12;
          yearly = 2;
          autoprune = true;
          autosnap = true;
        };

      recent = {
        hourly = 24;
        daily = 7;
        autoprune = true;
        autosnap = true;
      };

    };
    datasets = {

      "rpool/home" = {
        useTemplate = ["frequent"];
      };

      "rpool/persist" = {
        useTemplate = ["recent"];
      };
    };
  };
}
