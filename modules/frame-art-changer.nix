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

    installPhase = ''
      mkdir -p $out/bin $out/lib

      # Copy samsung-tv-ws-api library
      cp -r ${samsung-tv-ws-api-src} $out/lib/samsung-tv-ws-api

      # Copy and substitute scripts
      for script in upload-art.py get-token.py run-upload.sh delete-all-art.py run-delete-all.sh; do
        substituteAll $src/$script $out/bin/$script
      done
      chmod +x $out/bin/*.sh $out/bin/*.py
    '';

    samsungTvWsApiPath = "/srv/frame-art-changer/lib/samsung-tv-ws-api";
    uploadArtPath = "/srv/frame-art-changer/bin/upload-art.py";
    deleteAllArtPath = "/srv/frame-art-changer/bin/delete-all-art.py";
    pythonPath = "${pythonEnv}/bin/python3";
    tvIp = cfg.tvIp;
    tvMac = cfg.tvMac;
  };

  # Script to run art upload with retry (WOL should wake TV, so short retries)
  runArtUpload = pkgs.writeShellScript "frame-art-changer-upload" ''
    MAX_ATTEMPTS=3
    RETRY_DELAY=60  # 1 minute between retries

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
      echo "Attempt $attempt of $MAX_ATTEMPTS..."
      if ${pkgs.incus}/bin/incus exec frame-art-changer \
        --env NTFY_TOPIC="$(cat ${config.sops.secrets.ntfy_topic.path})" \
        --env TV_TOKEN="$(cat ${config.sops.secrets.tv_token.path})" \
        -- /srv/frame-art-changer/bin/run-upload.sh; then
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

  # Script to ensure container exists and is configured
  ensureContainer = pkgs.writeShellScript "ensure-frame-art-changer-container" ''
    set -e

    # Check if container exists
    if ! ${pkgs.incus}/bin/incus info frame-art-changer &>/dev/null; then
      echo "Creating frame-art-changer container..."
      ${pkgs.incus}/bin/incus launch images:nixos/unstable frame-art-changer --profile vlan20

      # Wait for container to be ready
      echo "Waiting for container to start..."
      sleep 15

      # Add art directory device
      ${pkgs.incus}/bin/incus config device add frame-art-changer art disk \
        source=${cfg.artDirectory} \
        path=/art

      # Add scripts device (read-only mount from host nix store)
      ${pkgs.incus}/bin/incus config device add frame-art-changer scripts disk \
        source=${frame-art-changer-pkg} \
        path=/srv/frame-art-changer

      # Create state directory
      ${pkgs.incus}/bin/incus exec frame-art-changer -- mkdir -p /var/lib/frame-art-changer

      echo "Container setup complete"
    fi

    # Ensure container is running
    if ! ${pkgs.incus}/bin/incus info frame-art-changer | grep -q 'Status: RUNNING'; then
      echo "Starting frame-art-changer container..."
      ${pkgs.incus}/bin/incus start frame-art-changer || true
    fi

    # Ensure Python environment is available in container
    if ! ${pkgs.incus}/bin/incus exec frame-art-changer -- test -e ${pythonEnv}/bin/python3; then
      echo "Copying Python environment to container..."
      ${pkgs.nix}/bin/nix-store --export $(${pkgs.nix}/bin/nix-store -qR ${pythonEnv}) | \
        ${pkgs.incus}/bin/incus exec frame-art-changer -- nix-store --import
    fi
  '';
in
{
  options.services.frame-art-changer = {
    enable = lib.mkEnableOption "Samsung Frame art changer";

    artDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/media/art";
      description = "Directory containing art images to display on the Samsung Frame TV";
    };

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
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.tv_token = {};

    # Ensure container exists on boot
    systemd.services.frame-art-changer-container = {
      description = "Ensure Samsung Frame art changer container exists";
      after = [ "incus.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ensureContainer;
      };
    };

    # Art upload service (runs on host, executes into container)
    systemd.services.frame-art-changer = {
      description = "Samsung Frame art changer";
      after = [ "frame-art-changer-container.service" ];
      requires = [ "frame-art-changer-container.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = runArtUpload;
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

    # Ensure art directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.artDirectory} 0755 dolf media -"
    ];
  };
}
