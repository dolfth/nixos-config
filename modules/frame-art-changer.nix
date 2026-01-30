{ config, pkgs, lib, ... }:

let
  cfg = config.services.frame-art-changer;
in
{
  options.services.frame-art-changer = {
    enable = lib.mkEnableOption "Samsung Frame art changer";

    artDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/media/art";
      description = "Directory containing art images to display on the Samsung Frame TV";
    };
  };

  config = lib.mkIf cfg.enable (let
  # External scripts for easier maintenance
  uploadArtPy = builtins.readFile ../scripts/frame-art-changer/upload-art.py;
  runUploadSh = builtins.readFile ../scripts/frame-art-changer/run-upload.sh;
  getTokenPy = builtins.readFile ../scripts/frame-art-changer/get-token.py;

  # Script to run art upload with backoff retries
  # 5 attempts: 12:00, 12:30, 13:00, 17:30, 21:00
  runArtUpload = pkgs.writeShellScript "frame-art-changer-upload" ''
    DELAYS=(0 1800 1800 16200 12600)  # seconds: 0, 30min, 30min, 270min, 210min
    MAX_ATTEMPTS=5

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
      echo "Attempt $attempt of $MAX_ATTEMPTS..."
      if ${pkgs.incus}/bin/incus exec frame-art-changer -- /opt/frame-art-changer/run-upload.sh; then
        echo "Success on attempt $attempt"
        exit 0
      fi

      if [ $attempt -lt $MAX_ATTEMPTS ]; then
        delay=''${DELAYS[$attempt]}
        echo "Failed, waiting $((delay / 60)) minutes before retry..."
        sleep $delay
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

      # Set up the container
      echo "Setting up container..."
      ${pkgs.incus}/bin/incus exec frame-art-changer -- mkdir -p /opt/frame-art-changer /var/lib/frame-art-changer

      # Clone the library
      ${pkgs.incus}/bin/incus exec frame-art-changer -- \
        nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git \
        -c git clone https://github.com/NickWaterton/samsung-tv-ws-api.git /opt/frame-art-changer/samsung-tv-ws-api

      # Write the upload script
      ${pkgs.incus}/bin/incus exec frame-art-changer -- tee /opt/frame-art-changer/upload-art.py << 'PYSCRIPT'
${uploadArtPy}
PYSCRIPT

      # Write the wrapper script
      ${pkgs.incus}/bin/incus exec frame-art-changer -- tee /opt/frame-art-changer/run-upload.sh << 'SHSCRIPT'
${runUploadSh}
SHSCRIPT

      # Write the token helper script
      ${pkgs.incus}/bin/incus exec frame-art-changer -- tee /opt/frame-art-changer/get-token.py << 'PYTOKENSCRIPT'
${getTokenPy}
PYTOKENSCRIPT

      # Make scripts executable
      ${pkgs.incus}/bin/incus exec frame-art-changer -- chmod +x /opt/frame-art-changer/run-upload.sh /opt/frame-art-changer/upload-art.py /opt/frame-art-changer/get-token.py

      echo "Container setup complete"
    fi

    # Ensure container is running
    if ! ${pkgs.incus}/bin/incus info frame-art-changer | grep -q 'Status: RUNNING'; then
      echo "Starting frame-art-changer container..."
      ${pkgs.incus}/bin/incus start frame-art-changer || true
    fi
  '';
  in
  {
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
});
}
