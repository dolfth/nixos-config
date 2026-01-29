{ config, pkgs, lib, ... }:

let
  # Script to run art upload inside the container
  runArtUpload = pkgs.writeShellScript "frame-art-changer-upload" ''
    ${pkgs.incus}/bin/incus exec frame-art-changer -- /opt/frame-art-changer/run-upload.sh
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
        source=/home/dolf/Documents/art \
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
#!/usr/bin/env python3
import os
import sys
sys.path.insert(0, '/opt/frame-art-changer/samsung-tv-ws-api')

import hashlib
import json
import random
from pathlib import Path
from samsungtvws.async_art import SamsungTVAsyncArt
import asyncio

TV_IP = "192.168.20.251"
TV_TOKEN = "16534022"
ART_DIR = Path("/art")
STATE_FILE = Path("/var/lib/frame-art-changer/uploaded.json")

def get_file_hash(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        h.update(f.read())
    return h.hexdigest()

def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {}

def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

async def main():
    state = load_state()

    try:
        tv = SamsungTVAsyncArt(TV_IP, token=TV_TOKEN, port=8002)
        await asyncio.wait_for(tv.start_listening(), timeout=30)
    except Exception as e:
        print(f"Failed to connect: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        # Upload new images
        for f in ART_DIR.iterdir():
            if f.suffix.lower() in ('.png', '.jpg', '.jpeg'):
                file_hash = get_file_hash(f)

                if state.get(f.name) == file_hash:
                    print(f"Skipping {f.name} (already uploaded)")
                    continue

                file_type = 'PNG' if f.suffix.lower() == '.png' else 'JPEG'
                print(f"Uploading {f.name}...")

                data = f.read_bytes()
                result = await tv.upload(data, file_type=file_type, matte='none')
                state[f.name] = file_hash
                save_state(state)
                print(f"  Uploaded as {result}")

        # Select random user art
        available = await asyncio.wait_for(tv.available(), timeout=30)
        my_art = []
        for item in available:
            if isinstance(item, dict):
                content_id = item.get('content_id', ''')
                if content_id.startswith('MY_'):
                    my_art.append(content_id)
            elif isinstance(item, str) and item.startswith('MY_'):
                my_art.append(item)
        if my_art:
            selected = random.choice(my_art)
            print(f"Selecting: {selected}")
            await tv.select_image(selected)
            print(f"Now displaying: {selected}")
    finally:
        await tv.close()

if __name__ == "__main__":
    asyncio.run(main())
PYSCRIPT

      # Write the wrapper script
      ${pkgs.incus}/bin/incus exec frame-art-changer -- tee /opt/frame-art-changer/run-upload.sh << 'SHSCRIPT'
#!/bin/sh
exec nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#python312 \
  nixpkgs#python312Packages.websocket-client \
  nixpkgs#python312Packages.requests \
  nixpkgs#python312Packages.websockets \
  nixpkgs#python312Packages.aiohttp \
  nixpkgs#python312Packages.async-timeout \
  -c python3 /opt/frame-art-changer/upload-art.py
SHSCRIPT

      # Make scripts executable
      ${pkgs.incus}/bin/incus exec frame-art-changer -- chmod +x /opt/frame-art-changer/run-upload.sh /opt/frame-art-changer/upload-art.py

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

  # Timer for daily art rotation
  systemd.timers.frame-art-changer = {
    description = "Samsung Frame art changer timer";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Ensure art directory exists
  systemd.tmpfiles.rules = [
    "d /home/dolf/Documents/art 0755 dolf users -"
  ];
}
