{ config, pkgs, lib, ... }:

let
  # Stdlib-only — no extra Python deps.
  pythonEnv = pkgs.python312;

  scriptPath = ../scripts/music-curate/music-curate.py;

  music-curate = pkgs.writeShellScriptBin "music-curate" ''
    set -eu
    envfile=${config.sops.templates."music-curate.env".path}
    if [ ! -r "$envfile" ]; then
      echo "music-curate: cannot read $envfile" >&2
      exit 2
    fi
    set -a
    . "$envfile"
    set +a
    export KEEPERS_FILE=''${KEEPERS_FILE:-/home/dolf/music-keepers.txt}
    export REPORT_FILE=''${REPORT_FILE:-/home/dolf/music-review.md}
    exec ${pythonEnv}/bin/python ${scriptPath} "$@"
  '';

in
{
  sops.secrets.lastfm_api_key = {};
  # lidarr_api_key is already declared in modules/soularr.nix

  sops.templates."music-curate.env" = {
    content = ''
      LIDARR_API_KEY=${config.sops.placeholder.lidarr_api_key}
      LASTFM_API_KEY=${config.sops.placeholder.lastfm_api_key}
    '';
    owner = "dolf";
    group = "users";
    mode = "0440";
  };

  environment.systemPackages = [ music-curate ];

  # Weekly read-only dud report. Reconcile must be run by hand.
  systemd.services.music-curate-report = {
    description = "Weekly music library dud report";
    after = [ "network-online.target" "lidarr.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "dolf";
      Group = "users";
      ExecStart = "${music-curate}/bin/music-curate report";
    };
  };

  systemd.timers.music-curate-report = {
    description = "Run weekly music dud report";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
