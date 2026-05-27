{ config, pkgs, lib, ... }:

let
  mediaDir = config.local.mediaDir;
in
{
  # Secrets for Soulseek network credentials
  sops.secrets.slskd_soulseek_username = {};
  sops.secrets.slskd_soulseek_password = {};
  sops.secrets.slskd_web_password = {};
  sops.secrets.slskd_api_key = {};

  # Environment file with all credentials
  # - SLSKD_SLSK_* for Soulseek network auth
  # - SLSKD_USERNAME/PASSWORD for web UI auth
  # - SLSKD_API_KEY for API authentication (used by soularr)
  sops.templates."slskd.env" = {
    content = ''
      SLSKD_SLSK_USERNAME=${config.sops.placeholder.slskd_soulseek_username}
      SLSKD_SLSK_PASSWORD=${config.sops.placeholder.slskd_soulseek_password}
      SLSKD_USERNAME=admin
      SLSKD_PASSWORD=${config.sops.placeholder.slskd_web_password}
      SLSKD_API_KEY=${config.sops.placeholder.slskd_api_key}
    '';
    owner = "slskd";
    group = "slskd";
    mode = "0400";
  };

  services.slskd = {
    enable = true;
    domain = null;  # Don't use nginx reverse proxy
    openFirewall = true;  # Opens port 50300 for Soulseek connections
    environmentFile = config.sops.templates."slskd.env".path;

    settings = {
      soulseek = {
        description = "slskd user";
        listen_port = 50300;
      };

      directories = {
        incomplete = "${mediaDir}/slskd/incomplete";
        downloads = "${mediaDir}/slskd/downloads";
      };

      shares = {
        directories = [
          "${mediaDir}/music"
        ];
      };

      web = {
        port = 5030;
        url_base = "/";
      };

      # Retention settings
      retention = {
        transfers = {
          upload = {
            succeeded = 1440;  # 24 hours
            errored = 1440;
            cancelled = 1440;
          };
          download = {
            succeeded = 1440;
            errored = 1440;
            cancelled = 1440;
          };
        };
      };
    };
  };

  # Create download directories with SGID so new subdirs inherit group=media.
  # Combined with UMask=0002 below, slskd's downloads end up group-writable for
  # soularr (which is also in media) so the import-into-Lidarr move can complete.
  systemd.tmpfiles.rules = [
    "d ${mediaDir}/slskd 2775 slskd media -"
    "d ${mediaDir}/slskd/downloads 2775 slskd media -"
    "d ${mediaDir}/slskd/incomplete 2775 slskd media -"
  ];

  # Make every file/dir slskd creates group-writable.
  systemd.services.slskd.serviceConfig.UMask = "0002";

  # Add slskd user to media group for shared access
  users.users.slskd.extraGroups = [ "media" ];
}
