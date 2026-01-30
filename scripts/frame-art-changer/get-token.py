#!/usr/bin/env python3
"""
Get Samsung Frame TV token.

Run inside the frame-art-changer container:
  incus exec frame-art-changer -- nix --extra-experimental-features "nix-command flakes" shell --impure --option sandbox false \
    --expr '(builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux.python312.withPackages (ps: with ps; [ websocket-client requests websockets aiohttp async-timeout ])' \
    -c python3 /opt/frame-art-changer/get-token.py

Watch for the "Allow" popup on your TV and accept it.
"""
import sys
sys.path.insert(0, "/opt/frame-art-changer/samsung-tv-ws-api")

import asyncio
from samsungtvws.async_remote import SamsungTVWSAsyncRemote

TV_IP = "192.168.20.251"

async def get_token():
    print(f"Connecting to TV at {TV_IP}...")
    print("Watch for the 'Allow' popup on your TV and accept it.")
    tv = SamsungTVWSAsyncRemote(host=TV_IP, port=8002, timeout=60)
    await tv.start_listening()
    print(f"\nToken: {tv.token}")
    print(f"\nUpdate scripts/frame-art-changer/upload-art.py with:")
    print(f'TV_TOKEN = "{tv.token}"')
    await tv.close()

if __name__ == "__main__":
    asyncio.run(get_token())
