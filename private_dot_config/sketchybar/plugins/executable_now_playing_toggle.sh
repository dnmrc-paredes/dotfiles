#!/bin/sh

# Click handler for the now-playing button.
#
# This is the click concern, and it is independent of the popover showing the
# info for each new song. A click holds the popover open; a second click
# closes it straight away. The popover watches for the held file appearing and
# disappearing and does nothing else with it.

TMP="${TMPDIR:-/tmp}"
PLUGIN_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins"
. "$PLUGIN_DIR/np_button.sh"
HELD="$TMP/sketchybar-nowplaying.held"
DISMISSED="$TMP/sketchybar-nowplaying.dismiss"
if [ -f "$HELD" ]; then
    rm -f "$HELD"          # second click: close it now
else
    : > "$HELD"            # first click: keep it open
fi

# Drop a stale "off" marker so holding always wins.
rm -f "$DISMISSED"

# Repaint now rather than waiting for the poller's next tick, so the icon
# switches over with the popover instead of trailing it by up to two seconds.
np_repaint_button

# Deliberately does NOT run now_playing.sh. That is the song concern's poller,
# and calling it from a click meant a click could look like a new song and pop
# the panel straight back up. The popover watches the held file on its own.
