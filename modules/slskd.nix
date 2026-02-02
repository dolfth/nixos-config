{ config, pkgs, lib, ... }:

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
        incomplete = "/mnt/media/slskd/incomplete";
        downloads = "/mnt/media/slskd/downloads";
      };

      shares = {
        directories = [
          "/mnt/media/music"
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

  # Create download directories
  systemd.tmpfiles.rules = [
    "d /mnt/media/slskd 0775 slskd media -"
    "d /mnt/media/slskd/downloads 0775 slskd media -"
    "d /mnt/media/slskd/incomplete 0775 slskd media -"
  ];

  # Add slskd user to media group for shared access
  users.users.slskd.extraGroups = [ "media" ];
}
