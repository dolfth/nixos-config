{ config, pkgs, lib, ... }:

let
  # Fetch JellyPlex-Watched source
  jellyplex-watched-src = pkgs.fetchFromGitHub {
    owner = "luigi311";
    repo = "JellyPlex-Watched";
    rev = "v8.5.0";
    hash = "sha256-6wxvEoOBQjMNLeCDm8w+xLDEGevdJ8Ke+t2AotfPIMw=";
  };

  # Python environment with dependencies
  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    loguru
    packaging
    plexapi
    pydantic
    python-dotenv
    requests
  ]);

in
{
  # Declare secrets
  sops.secrets.plex_token = {};
  sops.secrets.jellyfin_token = {};

  # Create environment file template with secrets
  sops.templates."jellyplex-watched.env" = {
    content = ''
      PLEX_BASEURL=http://127.0.0.1:32400
      PLEX_TOKEN=${config.sops.placeholder.plex_token}
      JELLYFIN_BASEURL=http://127.0.0.1:8096
      JELLYFIN_TOKEN=${config.sops.placeholder.jellyfin_token}
      DRYRUN=False
      DEBUG_LEVEL=INFO
      LOG_FILE=/var/log/jellyplex-watched/output.log
      USER_MAPPING={"dolfth": "dolf", "Emilie": "emilie"}
    '';
    owner = "jellyplex-watched";
    group = "jellyplex-watched";
    mode = "0400";
  };

  # System user for the service
  users.users.jellyplex-watched = {
    isSystemUser = true;
    group = "jellyplex-watched";
    home = "/var/lib/jellyplex-watched";
    createHome = true;
  };
  users.groups.jellyplex-watched = {};

  # Create log directory
  systemd.tmpfiles.rules = [
    "d /var/log/jellyplex-watched 0750 jellyplex-watched jellyplex-watched -"
  ];

  # Systemd service (runs every hour via timer)
  systemd.services.jellyplex-watched = {
    description = "JellyPlex-Watched - Sync watch status between Plex and Jellyfin";
    after = [ "network.target" "plex.service" ];
    wants = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "jellyplex-watched";
      Group = "jellyplex-watched";
      WorkingDirectory = jellyplex-watched-src;
      EnvironmentFile = config.sops.templates."jellyplex-watched.env".path;
      ExecStart = "${pythonEnv}/bin/python ${jellyplex-watched-src}/main.py";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ "/var/log/jellyplex-watched" ];
    };
  };

  # Timer to run hourly
  systemd.timers.jellyplex-watched = {
    description = "Run JellyPlex-Watched hourly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;  # Run immediately if missed
      RandomizedDelaySec = "5m";  # Spread load
    };
  };
}
