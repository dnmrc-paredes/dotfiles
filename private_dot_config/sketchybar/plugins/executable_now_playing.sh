#!/bin/sh

# Now-playing: a music-note button in the bar, plus a popover window that shows
# the track.
#
# This script is the single poller. macOS has no event to subscribe to for
# media changes, so it re-reads the track on the bar's timer and publishes it
# to two files:
#
#   $TMPDIR/sketchybar-nowplaying.track     "title\nartist" (absent when idle)
#   $TMPDIR/sketchybar-nowplaying.dismiss   present -> popover stays hidden
#
# plugins/nowplaying_popup.swift watches those files, so a new track makes the
# popover appear on its own. Clicking the button toggles the dismiss file,
# which hides it until the next track change.

NP_BG=0xff000000
NP_FG=0xffffffff
NP_NOTE="$(python3 -c 'import sys; sys.stdout.write(chr(0xF0387))')"   # md_music_note
NP_BADGE_TOP=922
NP_GAP=6        # space between this button and the badge below it

TMP="${TMPDIR:-/tmp}"
TRACK_FILE="$TMP/sketchybar-nowplaying.track"
DISMISS_FILE="$TMP/sketchybar-nowplaying.dismiss"
HELD_FILE="$TMP/sketchybar-nowplaying.held"
POS_FILE="$TMP/sketchybar-nowplaying.pos"
EXIT_FILE="$TMP/sketchybar-nowplaying.exit"
MISS_FILE="$TMP/sketchybar-nowplaying.misses"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
BIN="$CACHE/nowplaying-popup"
PLUGIN_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins"
. "$PLUGIN_DIR/bar_display.sh"
. "$PLUGIN_DIR/np_button.sh"

# --- read the current track --------------------------------------------------
JSON="$(nowplaying-cli get --json title artist 2>/dev/null)"

TITLE=""
ARTIST=""
if [ -n "$JSON" ]; then
    TITLE="$(printf '%s' "$JSON" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print((d.get("title") or "").strip())')"
    ARTIST="$(printf '%s' "$JSON" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print((d.get("artist") or "").strip())')"
fi

# --- publish it --------------------------------------------------------------
if [ -z "$TITLE$ARTIST" ]; then
    # nowplaying-cli returns nothing for a single tick now and then. Acting on
    # that immediately made the button blink out and back in two seconds
    # later, which read as the icon flickering, so require two empty reads
    # in a row before treating it as really idle.
    MISSES=$(( $(cat "$MISS_FILE" 2>/dev/null || echo 0) + 1 ))
    printf '%s' "$MISSES" > "$MISS_FILE"
    if [ "$MISSES" -lt 2 ]; then
        exit 0
    fi
    # Nothing playing: drop the track, the button, and the popover.
    rm -f "$DISMISS_FILE"
    sketchybar --remove np_button 2>/dev/null
    # The popover notices the missing track file, hides, and quits by itself
    # after a short idle period -- no kill needed.
    exit 0
fi

# A track is playing, so any pending "was that a hiccup?" doubt is settled.
rm -f "$MISS_FILE"

# The popover truncates with .byTruncatingTail, so the full text is fine here.
printf '%s\n%s' "$TITLE" "$ARTIST" > "$TRACK_FILE"

# --- the button --------------------------------------------------------------
np_button_colours


# Items in a right-hand group stack upwards in the order they were added, so
# the badge (created by front_app.sh) has to exist first. Otherwise the two
# icons swap places depending on which script's first tick wins the race.
BADGE=0
sketchybar --query title_macos >/dev/null 2>&1 && BADGE=1

if [ "$BADGE" = 1 ] && ! sketchybar --query np_button >/dev/null 2>&1; then
    sketchybar --add item np_button right --set np_button \
        icon.drawing=off \
        label="$NP_NOTE" \
        label.drawing=on \
        label.font="JetBrainsMono Nerd Font:Bold:20.0" \
        label.color=$BTN_FG \
        label.align=center \
        label.width=40 \
        label.padding_left=0 \
        label.padding_right=0 \
        background.drawing=on \
        background.color=$BTN_BG \
        background.corner_radius=20 \
        background.height=40 \
        padding_left=0 \
        padding_right=$NP_GAP \
        click_script="$PLUGIN_DIR/now_playing_toggle.sh"
fi

# Publish the button's real on-screen rect so the popover can anchor to it.
# Hardcoding this meant the popup sat in the wrong place as soon as the bar
# moved to a different sized display.
if [ "$BADGE" = 1 ]; then
    sketchybar --query np_button 2>/dev/null | tr -d ' \t' | tr -d '\n' | \
      sed -n 's/.*"display-'"$BAR_DISPLAY"'":{"origin":\[\([0-9.-]*\),\([0-9.-]*\)\],"size":\[\([0-9.-]*\),\([0-9.-]*\)\]}.*/\1 \2 \3 \4/p' \
      > "$POS_FILE"
fi

# Re-assert the colours each run: the button already exists after the first
# tick, so setting them only at creation would never show the inverted state.
# A click repaints it without waiting for this, so this is only the safety net.
if [ "$BADGE" = 1 ]; then
    np_repaint_button
fi

# --- keep the popover alive --------------------------------------------------
# Launching it needs care:
#   * `nohup ... &` is not enough -- SketchyBar kills the whole process group
#     when a script finishes, so the popover dies with the script.
#   * `launchctl submit` is worse here: launchd RESTARTS the program when it
#     exits, so the popover's own idle-exit turns into a respawn loop.
# So detach it properly with a double fork (new session, new process group),
# which survives the script's process group being killed.
if [ ! -x "$BIN" ]; then
    mkdir -p "$CACHE" 2>/dev/null
    if command -v swiftc >/dev/null 2>&1; then
        swiftc -O "$PLUGIN_DIR/nowplaying_popup.swift" -o "$BIN" 2>/dev/null
    fi
fi
if [ -x "$BIN" ] && ! pgrep -x "nowplaying-popup" >/dev/null 2>&1; then
    rm -f "$EXIT_FILE"
    python3 -c '
import os, subprocess, sys
pid = os.fork()
if pid > 0:
    os._exit(0)                     # parent returns immediately
os.setsid()                        # new session: not in the script group
subprocess.Popen([sys.argv[1]],
                 stdout=subprocess.DEVNULL,
                 stderr=subprocess.DEVNULL,
                 stdin=subprocess.DEVNULL)
' "$BIN" 2>/dev/null
fi
