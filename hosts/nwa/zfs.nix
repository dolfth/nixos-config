{ config, pkgs, lib, ... }:

let
  baseSnapshot = {
    hourly = 24;
    daily = 7;
    autoprune = true;
    autosnap = true;
  };
in
{
  sops.secrets.ntfy_topic = { };

  # ZFS notifications with secret substitution via sops template
  sops.templates."zed.rc" = {
    content = ''
      ZED_NOTIFY_INTERVAL_SECS=3600
      ZED_NTFY_TOPIC="${config.sops.placeholder.ntfy_topic}"
      ZED_NOTIFY_VERBOSE=1
      ZED_SCRUB_AFTER_RESILVER=1
    '';
    path = "/etc/zfs/zed.d/zed.rc";
    owner = "root";
    group = "root";
    mode = "0600";
  };

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };

  # Ensure ZED restarts when config changes
  systemd.services.zfs-zed = {
    restartTriggers = [ config.sops.templates."zed.rc".file ];
  };

  # ZFS snapshots
  services.sanoid = {
    enable = true;
    interval = "hourly";
    templates = {
      frequent = baseSnapshot // { monthly = 12; yearly = 2; };
      recent = baseSnapshot;
    };
    datasets = {

      "rpool/home" = {
        useTemplate = ["frequent"];
      };

      #"rpool/persist" = {
      #  useTemplate = ["recent"];
      #};

      "tank/media" = {
        useTemplate = ["recent"];
      };
    };
  };
}
