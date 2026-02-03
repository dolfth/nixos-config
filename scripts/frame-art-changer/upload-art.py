#!/usr/bin/env python3
import os
import sys
sys.path.insert(0, '/opt/frame-art-changer/samsung-tv-ws-api')

import hashlib
import json
import random
import socket
import time
from pathlib import Path
from samsungtvws.async_art import SamsungTVAsyncArt
import asyncio
import requests

TV_IP = "192.168.20.251"
TV_MAC = "28:af:42:5f:5e:38"
TV_TOKEN = "16193955"
ART_DIR = Path("/art")
STATE_FILE = Path("/var/lib/frame-art-changer/uploaded.json")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC")  # Passed via incus exec --env from sops secret

def send_notification(message: str, title: str = "Frame TV"):
    """Send notification via ntfy.sh."""
    if not NTFY_TOPIC:
        print("NTFY_TOPIC not set, skipping notification")
        return
    try:
        requests.post(
            f"https://ntfy.sh/{NTFY_TOPIC}",
            data=message.encode('utf-8'),
            headers={"Title": title, "Tags": "art,frame_with_picture"}
        )
        print(f"Notification sent: {message}")
    except Exception as e:
        print(f"Failed to send notification: {e}", file=sys.stderr)

def send_wol(mac_address: str):
    """Send Wake-on-LAN magic packet."""
    mac_bytes = bytes.fromhex(mac_address.replace(":", "").replace("-", ""))
    magic_packet = b'\xff' * 6 + mac_bytes * 16

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(magic_packet, ('255.255.255.255', 9))
    print(f"Sent Wake-on-LAN packet to {mac_address}")

def wait_for_tv(ip: str, port: int = 8002, timeout: int = 60) -> bool:
    """Wait for TV to become reachable."""
    print(f"Waiting for TV at {ip}:{port} to come online...")
    start = time.time()
    while time.time() - start < timeout:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(2)
                sock.connect((ip, port))
                print("TV is online!")
                return True
        except (socket.timeout, ConnectionRefusedError, OSError):
            time.sleep(2)
    return False

def get_file_hash(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        h.update(f.read())
    return h.hexdigest()

def parse_artwork_filename(filename: str) -> dict:
    """Parse artwork filename into artist, title, and optional year.

    Expected formats:
      "Artist Name - Artwork Title.jpg"
      "Artist Name - Artwork Title (1881).jpg"
    """
    import re
    stem = Path(filename).stem

    # Try to split on " - " for artist/title
    if " - " in stem:
        artist, rest = stem.split(" - ", 1)
    else:
        artist = None
        rest = stem

    # Check for year in brackets at the end
    year_match = re.search(r'\((\d{4})\)\s*$', rest)
    if year_match:
        year = year_match.group(1)
        title = rest[:year_match.start()].strip()
    else:
        year = None
        title = rest.strip()

    return {"artist": artist, "title": title, "year": year}

def format_artwork_info(info: dict) -> str:
    """Format artwork info for display/notification."""
    parts = []
    if info.get("title"):
        parts.append(info["title"])
    if info.get("artist"):
        parts.append(f"by {info['artist']}")
    if info.get("year"):
        parts.append(f"({info['year']})")
    return " ".join(parts) if parts else "Unknown artwork"

def load_state():
    if STATE_FILE.exists():
        data = json.loads(STATE_FILE.read_text())
        # Migrate old format (flat {filename: hash}) to new format
        if data and "uploads" not in data and "artwork" not in data:
            return {"uploads": data, "artwork": {}}
        return data
    return {"uploads": {}, "artwork": {}}

def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

async def main():
    state = load_state()

    # Wake the TV
    send_wol(TV_MAC)

    # Wait for TV to come online
    if not wait_for_tv(TV_IP):
        print("TV did not come online after WOL", file=sys.stderr)
        sys.exit(1)

    # Give TV a moment to fully initialize after network is up
    time.sleep(5)

    try:
        tv = SamsungTVAsyncArt(TV_IP, token=TV_TOKEN, port=8002)
        await asyncio.wait_for(tv.start_listening(), timeout=30)
    except Exception as e:
        print(f"Failed to connect: {e}", file=sys.stderr)
        sys.exit(1)

    # Ensure TV is in Art Mode
    try:
        art_mode_status = await asyncio.wait_for(tv.get_artmode(), timeout=10)
        print(f"Current art mode status: {art_mode_status}")
        if art_mode_status != "on":
            print("Switching to Art Mode...")
            await asyncio.wait_for(tv.set_artmode("on"), timeout=10)
            # Give TV time to switch modes
            await asyncio.sleep(3)
            print("Art Mode enabled")
    except Exception as e:
        print(f"Warning: Could not set art mode: {e}", file=sys.stderr)
        # Continue anyway - might still be able to upload/select art

    # Configure display settings
    try:
        # Enable auto brightness based on ambient light
        print("Enabling brightness sensor...")
        await asyncio.wait_for(tv.set_brightness_sensor_setting(1), timeout=10)

        # Motion sensor: sensitivity 2 (medium), timer 30 minutes
        # TV will show art when motion detected, turn off after 30 min of no motion
        print("Configuring motion sensor (sensitivity: medium, timer: 30 min)...")
        await asyncio.wait_for(tv.set_motion_sensitivity(2), timeout=10)
        await asyncio.wait_for(tv.set_motion_timer(30), timeout=10)
        print("Display settings configured")
    except Exception as e:
        print(f"Warning: Could not configure display settings: {e}", file=sys.stderr)

    try:
        # Upload new images
        for f in ART_DIR.iterdir():
            if f.suffix.lower() in ('.png', '.jpg', '.jpeg'):
                file_hash = get_file_hash(f)

                if state["uploads"].get(f.name) == file_hash:
                    print(f"Skipping {f.name} (already uploaded)")
                    continue

                file_type = 'PNG' if f.suffix.lower() == '.png' else 'JPEG'
                print(f"Uploading {f.name}...")

                data = f.read_bytes()
                content_id = await tv.upload(data, file_type=file_type, matte='none')
                state["uploads"][f.name] = file_hash
                # Store artwork info mapped to content_id
                artwork_info = parse_artwork_filename(f.name)
                artwork_info["filename"] = f.name
                state["artwork"][content_id] = artwork_info
                save_state(state)
                print(f"  Uploaded as {content_id}")

        # Select random user art
        available = await asyncio.wait_for(tv.available(), timeout=30)
        my_art = []
        for item in available:
            if isinstance(item, dict):
                content_id = item.get('content_id', '')
                if content_id.startswith('MY_'):
                    my_art.append(content_id)
            elif isinstance(item, str) and item.startswith('MY_'):
                my_art.append(item)
        if my_art:
            selected = random.choice(my_art)
            artwork_info = state["artwork"].get(selected, {})
            display_name = format_artwork_info(artwork_info) if artwork_info else selected
            print(f"Selecting: {display_name} ({selected})")
            await tv.select_image(selected)
            print(f"Now displaying: {display_name}")
            send_notification(display_name)
    finally:
        await tv.close()

if __name__ == "__main__":
    asyncio.run(main())
