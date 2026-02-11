{ config, pkgs, lib, ... }:

let
  mkPythonService = import ../lib/mkPythonService.nix { inherit lib; };

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
lib.mkMerge [
  (mkPythonService {
    name = "jellyplex-watched";
    description = "JellyPlex-Watched - Sync watch status between Plex and Jellyfin";
    inherit pythonEnv;
    src = jellyplex-watched-src;
    entrypoint = "main.py";
    after = [ "network.target" "plex.service" ];
    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "5m";
    };
    extraServiceConfig = {
      EnvironmentFile = config.sops.templates."jellyplex-watched.env".path;
    };
  })
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
        LIBRARY_MAPPING={"Movies": "Movies", "TV Shows": "Shows", "Music": "Music"}
      '';
      owner = "jellyplex-watched";
      group = "jellyplex-watched";
      mode = "0400";
    };
  }
]
