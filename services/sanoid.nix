{ config, pkgs, ... }:

{
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
