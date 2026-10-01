#!/bin/sh
#
# The now-playing button's look, shared by the two things that touch it:
#
#   now_playing.sh        creates it, and repaints on every poller tick
#   now_playing_toggle.sh repaints the moment it is clicked
#
# The click used to have to wait for the next poller tick to be repainted,
# which left the icon looking out of step with the popover for up to two
# seconds. Defining the colours once and repainting on click keeps them
# together.

TMP="${TMPDIR:-/tmp}"
# Own the path rather than expecting the caller to set it: the click script
# named this HELD, and the mismatch silently repainted every click as idle.
HELD_FILE="${HELD_FILE:-$TMP/sketchybar-nowplaying.held}"

NP_BG_IDLE=0xff000000
NP_FG_IDLE=0xffffffff
NP_BG_HELD=0xffffffff
NP_FG_HELD=0xff000000

# Sets BTN_BG / BTN_FG for the current state: a black circle normally, white
# while the popover is held open by a click.
np_button_colours() {
    if [ -f "$HELD_FILE" ]; then
        BTN_BG=$NP_BG_HELD
        BTN_FG=$NP_FG_HELD
    else
        BTN_BG=$NP_BG_IDLE
        BTN_FG=$NP_FG_IDLE
    fi
}

# Paints an existing button. Two property writes, no polling.
np_repaint_button() {
    np_button_colours
    sketchybar --set np_button background.color=$BTN_BG label.color=$BTN_FG 2>/dev/null
}
