#!/bin/sh
#
# Prints what the popover needs, on demand, as three lines:
#
#   1. title
#   2. artist
#   3. playing | paused
#
# This is deliberately NOT the poller. The poller (now_playing.sh) runs every
# couple of seconds and only publishes title+artist, which is cheap. The
# play/pause state lives behind `get-raw`, which is a 20KB dump because it
# includes the artwork, so it is only worth calling when the popover is on
# screen or a transport control was pressed.

nowplaying-cli get-raw 2>/dev/null | python3 -c '
import sys, json

try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

title  = (d.get("kMRMediaRemoteNowPlayingInfoTitle")  or "").strip()
artist = (d.get("kMRMediaRemoteNowPlayingInfoArtist") or "").strip()
rate   = d.get("kMRMediaRemoteNowPlayingInfoPlaybackRate")

if not title and not artist:
    raise SystemExit(1)

# A missing rate means an app that does not report it; treat that as playing
# rather than pretending it is paused.
state = "paused" if rate == 0 else "playing"

print(title)
print(artist)
print(state)
'
