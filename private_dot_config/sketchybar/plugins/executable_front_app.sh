#!/bin/sh

# Vertical title of the focused application.
# The side bar is only 40px wide, so the app name is stacked one character
# per row by maintaining one bar item per character (title_0, title_1, ...).
#
# The items are created/updated/removed in place, so their order in the bar
# stays stable across app switches.

APP="$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null | head -n 1)"

CHARS="$(printf '%s' "$APP" | awk '{
    out = ""
    for (i = 1; i <= NF; i++) {
        w = $i
        if (w ~ /^[a-z]/) w = toupper(substr(w, 1, 1)) substr(w, 2)
            out = out (i > 1 ? " " : "") w
        }
    print out
}' | fold -w1)"

# Chevron separator (">" pointing down) between the workspace block and the title.
if ! sketchybar --set title_spacer \
    icon.drawing=off \
    label="" \
    label.font="JetBrainsMono Nerd Font:Bold:18.0" \
    label.color=0xffffffff \
    label.drawing=on \
    label.align=center \
    label.width=40 \
    label.padding_left=0 \
    label.padding_right=0 \
    background.drawing=on \
    background.color=0x00000000 \
    background.height=25 \
    padding_left=10 \
    padding_right=10 \
    2>/dev/null; then
sketchybar --add item title_spacer left --set title_spacer \
    icon.drawing=off \
    label="" \
    label.font="JetBrainsMono Nerd Font:Bold:18.0" \
    label.color=0xffffffff \
    label.drawing=on \
    label.align=center \
    label.width=40 \
    label.padding_left=0 \
    label.padding_right=0 \
    background.drawing=on \
    background.color=0x00000000 \
    background.height=25 \
    padding_left=10 \
    padding_right=10
fi

IFS_BACKUP="$IFS"
IFS='
'
i=0
for CH in $CHARS; do
    if ! sketchybar --set "title_$i" label="$CH" 2>/dev/null; then
        sketchybar --add item "title_$i" left --set "title_$i" \
            icon.drawing=off \
            label="$CH" \
            label.font="JetBrainsMono Nerd Font:Regular:18.0" \
            label.color=0xffffffff \
            label.align=center \
            label.width=40 \
            label.padding_left=0 \
            label.padding_right=0 \
            padding_left=0 \
            padding_right=0 \
            background.drawing=on \
            background.color=0x00000000 \
            background.corner_radius=5 \
            background.height=25
    fi
    i=$((i + 1))
done
IFS="$IFS_BACKUP"

# Drop characters left over from a longer previous name.
while sketchybar --query "title_$i" >/dev/null 2>&1; do
    sketchybar --remove "title_$i"
    i=$((i + 1))
done
