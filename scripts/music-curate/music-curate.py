#!/usr/bin/env python3
"""
music-curate: reconcile/report on Lidarr music library against curated sources.

Subcommands:
  report          read-only: refresh ~/music-review.md
  reconcile       monitor canonical, unmonitor everything else
  keep <substr>   add matching album(s) to keepers.txt (no copy-paste needed)
  keep --mbid X   add by MBID directly
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.parse
from pathlib import Path

LIDARR_URL = os.environ.get("LIDARR_URL", "http://127.0.0.1:8686/api/v1")
LIDARR_KEY = os.environ.get("LIDARR_API_KEY", "")
KEEPERS_FILE = Path(os.environ.get("KEEPERS_FILE", "/var/lib/lidarr/keepers.txt"))
REPORT_FILE = Path(os.environ.get("REPORT_FILE", "/home/dolf/music-review.md"))
LASTFM_KEY = os.environ.get("LASTFM_API_KEY", "")
USER_AGENT = "nwa-music-curate/0.1 (dolf-config-nixos)"
MB_BASE = "https://musicbrainz.org/ws/2"
LASTFM_BASE = "https://ws.audioscrobbler.com/2.0/"


def http_get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    req.add_header("User-Agent", USER_AGENT)
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def lidarr_get(path):
    return json.loads(http_get(LIDARR_URL + path, {"X-Api-Key": LIDARR_KEY}))


def lidarr_put(path, body):
    req = urllib.request.Request(
        LIDARR_URL + path, data=json.dumps(body).encode(), method="PUT"
    )
    req.add_header("X-Api-Key", LIDARR_KEY)
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", USER_AGENT)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def fetch_mb_series_albums(guid):
    url = f"{MB_BASE}/series/{guid}?inc=release-group-rels&fmt=json"
    data = json.loads(http_get(url))
    return [
        rel["release_group"]["id"]
        for rel in data.get("relations", [])
        if rel.get("target-type") == "release_group" and "release_group" in rel
    ]


def fetch_lastfm_top_albums(user, period="overall", limit=200):
    if not LASTFM_KEY:
        return []
    params = {
        "method": "user.getTopAlbums",
        "user": user,
        "period": period,
        "limit": limit,
        "api_key": LASTFM_KEY,
        "format": "json",
    }
    data = json.loads(http_get(LASTFM_BASE + "?" + urllib.parse.urlencode(params)))
    return [
        a["mbid"].strip()
        for a in data.get("topalbums", {}).get("album", [])
        if a.get("mbid", "").strip()
    ]


def read_keepers():
    if not KEEPERS_FILE.exists():
        return []
    ids = []
    for line in KEEPERS_FILE.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            ids.append(line)
    return ids


def compute_canonical():
    canonical = set()
    sources = []

    for il in lidarr_get("/importlist"):
        impl = il.get("implementation", "")
        name = il.get("name", "")
        if impl == "MusicBrainzSeries":
            sid = next(
                (f["value"] for f in il["fields"] if f["name"] == "seriesId"), None
            )
            if sid:
                ids = fetch_mb_series_albums(sid)
                canonical.update(ids)
                sources.append(f"{name}: {len(ids)} release groups")
                time.sleep(1.1)
        elif impl == "LastFmUser":
            uid = next(
                (f["value"] for f in il["fields"] if f["name"] == "userId"), None
            )
            period_idx = next(
                (f["value"] for f in il["fields"] if f["name"] == "period"), 0
            )
            count = next(
                (f["value"] for f in il["fields"] if f["name"] == "count"), 200
            )
            periods = ["overall", "7day", "1month", "3month", "6month", "12month"]
            period = (
                periods[min(period_idx, len(periods) - 1)]
                if isinstance(period_idx, int)
                else "overall"
            )
            if uid:
                if LASTFM_KEY:
                    ids = fetch_lastfm_top_albums(uid, period, count)
                    canonical.update(ids)
                    sources.append(f"{name}: {len(ids)} MBIDs (Last.fm)")
                else:
                    sources.append(f"{name}: SKIPPED (no LASTFM_API_KEY)")

    keepers = read_keepers()
    if keepers:
        canonical.update(keepers)
        sources.append(f"keepers.txt: {len(keepers)} MBIDs")

    return canonical, sources


def dud_report(canonical, sources):
    albums = lidarr_get("/album")
    duds = [
        a
        for a in albums
        if (a.get("statistics") or {}).get("trackFileCount", 0) > 0
        and a.get("foreignAlbumId") not in canonical
    ]
    duds.sort(
        key=lambda a: (a["artist"]["artistName"].lower(), a.get("releaseDate") or "")
    )

    REPORT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with REPORT_FILE.open("w") as f:
        f.write("# Music Review — Albums Not On Any Canonical List\n\n")
        f.write(
            "Generated by `music-curate`. Albums on disk that aren't on any Lidarr\n"
        )
        f.write("Import List or in `keepers.txt`.\n\n")
        f.write("## Adding albums to keepers — no copy-paste needed\n\n")
        f.write("```\n")
        f.write("music-curate keep \"Birks Works\"           # add by substring (artist OR title)\n")
        f.write("music-curate keep \"Dizzy\" --all           # all Dizzy duds at once\n")
        f.write("music-curate keep --mbid <mbid> --mbid <mbid>   # add by MBID directly\n")
        f.write("```\n\n")
        f.write("Then re-run `music-curate report`. Kept albums drop off this list.\n\n")
        f.write("## Canonical sources\n\n")
        for s in sources:
            f.write(f"- {s}\n")
        f.write(f"\n**Canonical set total: {len(canonical)} MBIDs**\n\n")
        f.write(f"## {len(duds)} albums on disk, not in canonical set\n\n")
        f.write("| Artist | Album | Year | MBID |\n")
        f.write("|---|---|---|---|\n")
        for a in duds:
            year = (a.get("releaseDate") or "????")[:4]
            mbid = a.get("foreignAlbumId", "")
            artist = a["artist"]["artistName"].replace("|", "\\|")
            title = (a.get("title") or "").replace("|", "\\|")
            f.write(f"| {artist} | {title} | {year} | `{mbid}` |\n")
    print(
        f"Wrote {REPORT_FILE} ({len(duds)} duds, canonical = {len(canonical)} MBIDs)"
    )
    return duds


def reconcile(canonical):
    albums = lidarr_get("/album")
    to_monitor, to_unmonitor = [], []
    for a in albums:
        mbid = a.get("foreignAlbumId")
        is_canonical = mbid in canonical
        is_monitored = a.get("monitored", False)
        if is_canonical and not is_monitored:
            to_monitor.append(a["id"])
        elif (not is_canonical) and is_monitored:
            to_unmonitor.append(a["id"])
    print(f"Will monitor {len(to_monitor)}; unmonitor {len(to_unmonitor)}")
    if to_monitor:
        lidarr_put("/album/monitor", {"albumIds": to_monitor, "monitored": True})
    if to_unmonitor:
        lidarr_put("/album/monitor", {"albumIds": to_unmonitor, "monitored": False})

    # Safety sweep — keep monitorNewItems="none" everywhere so a list created
    # via Lidarr UI (which defaults to "all") can't re-flood future releases.
    bad_lists = [
        il for il in lidarr_get("/importlist")
        if il.get("monitorNewItems") != "none"
    ]
    if bad_lists:
        print(f"Sweeping monitorNewItems=none on {len(bad_lists)} import list(s)")
        for il in bad_lists:
            il["monitorNewItems"] = "none"
            lidarr_put(f"/importlist/{il['id']}", il)
    else:
        print("Import-list sweep: all set to 'none'")

    bad_artists = [
        a["id"] for a in lidarr_get("/artist")
        if a.get("monitorNewItems") != "none"
    ]
    if bad_artists:
        print(f"Sweeping monitorNewItems=none on {len(bad_artists)} artist(s)")
        lidarr_put(
            "/artist/editor",
            {"artistIds": bad_artists, "monitorNewItems": "none"},
        )
    else:
        print("Artist sweep: all set to 'none'")


def existing_keeper_mbids():
    return set(read_keepers())


def append_keepers(rows):
    """rows: list of (mbid, comment). Appends to KEEPERS_FILE, skipping dups."""
    have = existing_keeper_mbids()
    new_lines = []
    for mbid, comment in rows:
        if mbid in have:
            continue
        new_lines.append(f"{mbid}  # {comment}")
        have.add(mbid)
    if not new_lines:
        return 0
    KEEPERS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with KEEPERS_FILE.open("a") as f:
        if KEEPERS_FILE.stat().st_size > 0:
            f.write("\n")
        f.write("\n".join(new_lines) + "\n")
    return len(new_lines)


def find_albums(terms, files_only=True):
    """Return Lidarr albums whose artist OR title contain ANY of the terms (case-insensitive)."""
    needles = [t.lower() for t in terms]
    out = []
    for a in lidarr_get("/album"):
        if files_only and (a.get("statistics") or {}).get("trackFileCount", 0) == 0:
            continue
        hay = (a["artist"]["artistName"] + " " + (a.get("title") or "")).lower()
        if any(n in hay for n in needles):
            out.append(a)
    return out


def cmd_keep(args):
    if args.mbid:
        rows = []
        idx = {a["foreignAlbumId"]: a for a in lidarr_get("/album")}
        for m in args.mbid:
            a = idx.get(m)
            if a:
                year = (a.get("releaseDate") or "????")[:4]
                rows.append((m, f"{a['artist']['artistName']} — {a.get('title')} ({year})"))
            else:
                rows.append((m, "unknown (not in Lidarr)"))
        n = append_keepers(rows)
        print(f"Added {n} keeper(s) by MBID.")
        return

    if not args.terms:
        sys.exit("usage: music-curate keep <substring>... | --mbid <mbid>...")

    matches = find_albums(args.terms, files_only=not args.any)
    if not matches:
        print("No matching albums.")
        return
    if len(matches) > 1 and not args.all:
        print(f"{len(matches)} matches — refine, or pass --all to add them all:")
        for a in matches[:20]:
            year = (a.get("releaseDate") or "????")[:4]
            print(f"  {a['foreignAlbumId']}  {a['artist']['artistName']} — {a.get('title')} ({year})")
        if len(matches) > 20:
            print(f"  ... and {len(matches)-20} more")
        return

    rows = []
    for a in matches:
        year = (a.get("releaseDate") or "????")[:4]
        rows.append((a["foreignAlbumId"], f"{a['artist']['artistName']} — {a.get('title')} ({year})"))
    n = append_keepers(rows)
    print(f"Added {n} keeper(s):")
    for mbid, comment in rows:
        print(f"  {mbid}  # {comment}")


def cmd_report(args):
    if not LIDARR_KEY:
        sys.exit("ERROR: set LIDARR_API_KEY env var")
    print("Computing canonical set...")
    canonical, sources = compute_canonical()
    for s in sources:
        print(f"  - {s}")
    print(f"Canonical total: {len(canonical)} MBIDs")
    dud_report(canonical, sources)


def cmd_reconcile(args):
    if not LIDARR_KEY:
        sys.exit("ERROR: set LIDARR_API_KEY env var")
    print("Computing canonical set...")
    canonical, sources = compute_canonical()
    for s in sources:
        print(f"  - {s}")
    print(f"Canonical total: {len(canonical)} MBIDs")
    reconcile(canonical)
    dud_report(canonical, sources)


def main():
    ap = argparse.ArgumentParser(prog="music-curate")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_report = sub.add_parser("report", help="Refresh ~/music-review.md (read-only)")
    p_report.set_defaults(func=cmd_report)

    p_rec = sub.add_parser("reconcile", help="Monitor canonical, unmonitor everything else")
    p_rec.set_defaults(func=cmd_reconcile)

    p_keep = sub.add_parser("keep", help="Add albums to keepers.txt by substring or MBID")
    p_keep.add_argument("terms", nargs="*", help="substring(s) to match (artist or album)")
    p_keep.add_argument("--mbid", action="append", default=[], help="MBID to add directly (repeatable)")
    p_keep.add_argument("--all", action="store_true", help="Add ALL matches without prompting")
    p_keep.add_argument("--any", action="store_true", help="Also match albums not on disk")
    p_keep.set_defaults(func=cmd_keep)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
