#!/bin/sh

# Highlights the currently focused AeroSpace workspace.
#
# $FOCUSED is injected by AeroSpace's exec-on-workspace-change callback
# (see aerospace.toml) and avoids a round-trip to the CLI. When the script is
# run for any other reason (initial update, manual run) we fall back to asking
# AeroSpace directly.
#
# The background stays drawn for every workspace (transparent when inactive)
# so that all rows keep the same height and the spacing stays even.

WORKSPACES="1 2 3 4 5 6"
ACTIVE_BG="0xffffffff"
ACTIVE_FG="0xff000000"
INACTIVE_BG="0x00000000"
INACTIVE_FG="0xffffffff"
ACTIVE_ICON="󰐾"   # md-radiobox_marked: filled radio = the current workspace
INACTIVE_ICON="󰀻" # md-apps: regular workspace icon

[ -z "$FOCUSED" ] && FOCUSED="$(aerospace list-workspaces --focused 2>/dev/null)"

for WS in $WORKSPACES; do
  if [ "$WS" = "$FOCUSED" ]; then
    sketchybar --set "workspace.$WS" \
      icon="$ACTIVE_ICON" \
      icon.color=$ACTIVE_FG \
      label.color=$ACTIVE_FG \
      background.color=$ACTIVE_BG \
      background.drawing=on
  else
    sketchybar --set "workspace.$WS" \
      icon="$INACTIVE_ICON" \
      icon.color=$INACTIVE_FG \
      label.color=$INACTIVE_FG \
      background.color=$INACTIVE_BG \
      background.drawing=on
  fi
done