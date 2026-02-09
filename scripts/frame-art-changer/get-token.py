#!/usr/bin/env python3
"""
Get Samsung Frame TV token.

Run inside the frame-art-changer container:
  incus exec frame-art-changer -- /srv/frame-art-changer/bin/run-upload.sh

Or manually:
  incus exec frame-art-changer -- @pythonPath@ /srv/frame-art-changer/bin/get-token.py

Watch for the "Allow" popup on your TV and accept it.
"""
import sys
sys.path.insert(0, "@samsungTvWsApiPath@")

import asyncio
from samsungtvws.async_remote import SamsungTVWSAsyncRemote

TV_IP = "@tvIp@"

async def get_token():
    print(f"Connecting to TV at {TV_IP}...")
    print("Watch for the 'Allow' popup on your TV and accept it.")
    tv = SamsungTVWSAsyncRemote(host=TV_IP, port=8002, timeout=60)
    await tv.start_listening()
    print(f"\nToken: {tv.token}")
    print(f"\nAdd this token to sops secrets as 'tv_token':")
    print(f"  sops secrets/secrets.yaml  # then add: tv_token: {tv.token}")
    await tv.close()

if __name__ == "__main__":
    asyncio.run(get_token())
