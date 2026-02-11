{ config, pkgs, lib, ... }:

let
  cfg = config.services.frame-art-changer;

  samsung-tv-ws-api-src = pkgs.fetchFromGitHub {
    owner = "NickWaterton";
    repo = "samsung-tv-ws-api";
    rev = "d7fc3442c4cdbc4acd3c596fd328792026cee681";
    hash = "sha256-wAuiYZer3IqHe411Tj9FTeU5g53B0Uuxugh+9IB7ebI=";
  };

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    websocket-client requests websockets aiohttp async-timeout
  ]);

  frame-art-changer-pkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "frame-art-changer";
    version = "unstable-2025-01-01";
    src = ../scripts/frame-art-changer;

    dontBuild = true;

    pythonPath = "${pythonEnv}/bin/python3";
    tvIp = cfg.tvIp;
    tvMac = cfg.tvMac;

    installPhase = ''
      mkdir -p $out/bin $out/lib

      # Copy samsung-tv-ws-api library
      cp -r ${samsung-tv-ws-api-src} $out/lib/samsung-tv-ws-api

      # Override paths to use $out instead of container paths
      export samsungTvWsApiPath="$out/lib/samsung-tv-ws-api"
      export uploadArtPath="$out/bin/upload-art.py"
      export deleteAllArtPath="$out/bin/delete-all-art.py"

      # Copy and substitute scripts
      for script in upload-art.py get-token.py run-upload.sh delete-all-art.py run-delete-all.sh; do
        substituteAll $src/$script $out/bin/$script
      done
      chmod +x $out/bin/*.sh $out/bin/*.py
    '';
  };

  # Script to run art upload with retry (WOL should wake TV, so short retries)
  runArtUpload = pkgs.writeShellScript "frame-art-changer-upload" ''
    MAX_ATTEMPTS=3
    RETRY_DELAY=60  # 1 minute between retries

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
      echo "Attempt $attempt of $MAX_ATTEMPTS..."
      if ${frame-art-changer-pkg}/bin/run-upload.sh; then
        echo "Success on attempt $attempt"
        exit 0
      fi

      if [ $attempt -lt $MAX_ATTEMPTS ]; then
        echo "Failed, waiting $RETRY_DELAY seconds before retry..."
        sleep $RETRY_DELAY
      fi
    done

    echo "All $MAX_ATTEMPTS attempts failed"
    exit 1
  '';
in
{
  options.services.frame-art-changer = {
    enable = lib.mkEnableOption "Samsung Frame art changer";

    tvIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.20.251";
      description = "IP address of the Samsung Frame TV";
    };

    tvMac = lib.mkOption {
      type = lib.types.str;
      default = "28:af:42:5f:5e:38";
      description = "MAC address of the Samsung Frame TV (for Wake-on-LAN)";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file with TV_TOKEN and NTFY_TOPIC";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.frame-art-changer = {
      description = "Samsung Frame art changer";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = runArtUpload;
        StateDirectory = "frame-art-changer";
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };

    # Timer for daily art rotation at noon
    systemd.timers.frame-art-changer = {
      description = "Samsung Frame art changer timer";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "*-*-* 12:00:00";
        Persistent = true;
      };
    };
  };
}
