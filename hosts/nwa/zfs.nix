{ config, pkgs, lib, ... }:

{
  sops.secrets.ntfy_topic = { };

  # ZFS notifications with secret substitution via sops template
  sops.templates."zed.rc" = {
    content = ''
      ZED_NOTIFY_INTERVAL_SECS=3600
      ZED_NTFY_TOPIC="${config.sops.placeholder.ntfy_topic}"
      ZED_NOTIFY_VERBOSE=true
      ZED_SCRUB_AFTER_RESILVER=true
    '';
    owner = "root";
    mode = "0600";
  };

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };

  environment.etc."zfs/zed.d/zed.rc".source = lib.mkForce config.sops.templates."zed.rc".path;

  # Ensure ZED restarts when config changes and starts after secrets are available
  systemd.services.zfs-zed = {
    restartTriggers = [ config.sops.templates."zed.rc".file ];
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
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

      #"rpool/persist" = {
      #  useTemplate = ["recent"];
      #};

      "tank/media" = {
        useTemplate = ["recent"];
      };
    };
  };
}
