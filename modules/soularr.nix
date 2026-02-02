{ config, pkgs, lib, ... }:

let
  # Fetch Soularr source from GitHub
  soularr-src = pkgs.fetchFromGitHub {
    owner = "mrusse";
    repo = "soularr";
    rev = "233ff0a9d05b5d40ee0f62ec4c7928b28a9c8f48";
    hash = "sha256-StSxTB3jqtXhpoQcSmyYU3Kf0gKu3LyGHzipJ0CZTEY=";
  };

  # Build pyarr package
  pyarr = pkgs.python312Packages.buildPythonPackage rec {
    pname = "pyarr";
    version = "5.2.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-jlcc9Kj1MYSsnvJkKZXXWWJVDx3KIuojjbGtl8kDUpw=";
    };

    build-system = [ pkgs.python312Packages.poetry-core ];

    # Fix build backend: poetry.masonry.api -> poetry.core.masonry.api
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail "poetry.masonry.api" "poetry.core.masonry.api"
    '';

    dependencies = with pkgs.python312Packages; [
      requests
      types-requests
      overrides
    ];

    doCheck = false;
  };

  # Build slskd-api package (pinned to 0.1.5 as required by soularr)
  slskd-api = pkgs.python312Packages.buildPythonPackage rec {
    pname = "slskd-api";
    version = "0.1.5";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-LmWP7bnK5IVid255qS2NGOmyKzGpUl3xsO5vi5uJI88=";
    };

    build-system = [ pkgs.python312Packages.setuptools ];

    dependencies = with pkgs.python312Packages; [
      requests
    ];

    doCheck = false;
  };

  # Build music-tag package
  music-tag = pkgs.python312Packages.buildPythonPackage rec {
    pname = "music-tag";
    version = "0.4.3";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-Cqtubu2o3w9TFuwtIZC9dFYbfgNWKrCRzo1Wh828//Y=";
    };

    build-system = [ pkgs.python312Packages.setuptools ];

    dependencies = with pkgs.python312Packages; [
      mutagen
    ];

    doCheck = false;
  };

  # Python environment with all dependencies
  pythonEnv = pkgs.python312.withPackages (ps: [
    ps.requests
    pyarr
    slskd-api
    music-tag
  ]);

in
{
  # Reuse existing lidarr_api_key
  sops.secrets.lidarr_api_key = {};
  # slskd_api_key is already declared in slskd.nix

  # Soularr config.ini template
  sops.templates."soularr-config.ini" = {
    content = ''
      [Lidarr]
      api_key = ${config.sops.placeholder.lidarr_api_key}
      host_url = http://127.0.0.1:8686
      download_dir = /mnt/media/slskd/downloads

      [Slskd]
      api_key = ${config.sops.placeholder.slskd_api_key}
      host_url = http://127.0.0.1:5030
      url_base = /
      download_dir = /mnt/media/slskd/downloads
      delete_searches = true
      stalled_timeout = 3600

      [Release Settings]
      use_most_common_tracknum = true
      allow_multi_disc = true
      accepted_countries = Europe,United States,UK,Australia,Canada,Netherlands
      accepted_formats = CD,Digital Media,Vinyl

      [Search Settings]
      search_timeout = 5000
      maximum_peer_queue = 50
      minimum_peer_upload_speed = 0
      minimum_filename_match_ratio = 0.9
      allowed_filetypes = flac,mp3 320,mp3 v0
      search_for_tracks = true
      album_prepend_artist = true
      number_of_albums_to_grab = 10
      remove_wanted_on_failure = false

      [Logging]
      level = INFO
      format = %%(asctime)s - %%(levelname)s - %%(message)s
      datefmt = %%Y-%%m-%%d %%H:%%M:%%S
    '';
    owner = "soularr";
    group = "soularr";
    mode = "0400";
  };

  # System user
  users.users.soularr = {
    isSystemUser = true;
    group = "soularr";
    home = "/var/lib/soularr";
    createHome = true;
    extraGroups = [ "media" ];
  };
  users.groups.soularr = {};

  # Create directories
  systemd.tmpfiles.rules = [
    "d /var/lib/soularr 0750 soularr soularr -"
    "d /var/log/soularr 0750 soularr soularr -"
  ];

  # Systemd service
  systemd.services.soularr = {
    description = "Soularr - Connect Lidarr with Soulseek";
    after = [ "network.target" "slskd.service" "lidarr.service" ];
    wants = [ "slskd.service" ];

    # Copy config to expected location before running
    preStart = ''
      cp ${config.sops.templates."soularr-config.ini".path} /var/lib/soularr/config.ini
      chmod 400 /var/lib/soularr/config.ini
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "soularr";
      Group = "soularr";
      WorkingDirectory = "/var/lib/soularr";
      ExecStart = "${pythonEnv}/bin/python ${soularr-src}/soularr.py";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [
        "/var/lib/soularr"
        "/var/log/soularr"
        "/mnt/media/slskd"
        "/mnt/media/music"
      ];
    };
  };

  # Timer to run every 5 minutes
  systemd.timers.soularr = {
    description = "Run Soularr periodically";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
      RandomizedDelaySec = "30s";
    };
  };
}
