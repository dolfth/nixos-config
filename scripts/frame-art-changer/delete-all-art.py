#!/usr/bin/env python3
"""
Delete all user-uploaded art from Samsung Frame TV and reset state.

Run via wrapper:
  incus exec frame-art-changer -- /srv/frame-art-changer/bin/run-delete-all.sh
"""
import sys
sys.path.insert(0, '@samsungTvWsApiPath@')

import asyncio
import json
from pathlib import Path
from samsungtvws.async_art import SamsungTVAsyncArt

TV_IP = "192.168.20.251"
TV_TOKEN = "16193955"
STATE_FILE = Path("/var/lib/frame-art-changer/uploaded.json")

async def main():
    tv = SamsungTVAsyncArt(TV_IP, token=TV_TOKEN, port=8002)
    await asyncio.wait_for(tv.start_listening(), timeout=30)

    available = await asyncio.wait_for(tv.available(), timeout=30)
    my_art = []
    for item in available:
        if isinstance(item, dict):
            content_id = item.get('content_id', '')
            if content_id.startswith('MY_'):
                my_art.append(content_id)
        elif isinstance(item, str) and item.startswith('MY_'):
            my_art.append(item)

    print(f"Found {len(my_art)} uploaded images")
    if my_art:
        await tv.delete_list(my_art)
        print("Deleted all uploaded art from TV")
    else:
        print("No uploaded art to delete")

    await tv.close()

    # Clear state file so next upload re-uploads everything
    if STATE_FILE.exists():
        STATE_FILE.unlink()
        print("Cleared upload state")

if __name__ == "__main__":
    asyncio.run(main())
