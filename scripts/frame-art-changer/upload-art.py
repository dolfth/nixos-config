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
TV_TOKEN = "19899746"
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
                content_id = item.get('content_id', '')
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
