#!/bin/sh

# Highlights the currently focused AeroSpace workspace.
#
# $FOCUSED is injected by AeroSpace's exec-on-workspace-change callback
# (see aerospace.toml) and avoids a round-trip to the CLI. When the script is
# run for any other reason (initial update, manual run) we fall back to asking
# AeroSpace directly.
#
# The background stays drawn for every workspace so the rows form one solid
# black container; the height is fixed so the spacing never shifts.

# The workspace block is a solid black container with white numbers; the
# focused workspace simply inverts those two colors.

WORKSPACES="1 2 3 4 5 6"
ACTIVE_BG="0xffffffff"
ACTIVE_FG="0xff000000"
INACTIVE_BG="0xff000000"
INACTIVE_FG="0xffffffff"

[ -z "$FOCUSED" ] && FOCUSED="$(aerospace list-workspaces --focused 2>/dev/null)"

# Without a focused workspace we cannot tell which row is active. Bailing out
# leaves the current highlight untouched; repainting here would mark every row
# inactive and make the active highlight flicker away.
if [ -z "$FOCUSED" ]; then
  exit 0
fi

# The highlight fills the whole row: the background covers the full 40px slot,
# so the active workspace is a complete white box, not just a box behind the
# digit.
ROW_HEIGHT=40

for WS in $WORKSPACES; do
  if [ "$WS" = "$FOCUSED" ]; then
    sketchybar --set "workspace.$WS" \
      label.color=$ACTIVE_FG \
      background.color=$ACTIVE_BG \
      background.height=$ROW_HEIGHT \
      background.drawing=on
  else
    sketchybar --set "workspace.$WS" \
      label.color=$INACTIVE_FG \
      background.color=$INACTIVE_BG \
      background.height=$ROW_HEIGHT \
      background.drawing=on
  fi
done