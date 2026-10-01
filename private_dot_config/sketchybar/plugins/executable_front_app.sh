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
#
# The padding on this item is the spacing between the three containers:
#   workspace block | <padding_left> | chevron | <padding_right> | title block
# Letters inside the title stay tight (their own padding is 0), so each
# group reads as one container.
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
    background.color=0xff000000 \
    background.corner_radius=20 \
    background.height=40 \
    padding_left=15 \
    padding_right=15 \
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
    background.color=0xff000000 \
    background.corner_radius=20 \
    background.height=40 \
    padding_left=15 \
    padding_right=15
fi

TOTAL="$(printf '%s' "$CHARS" | awk 'END { print NR }')"

i=0
IFS_BACKUP="$IFS"
IFS='
'
for CH in $CHARS; do
    # Extra padding_right on the last letter, so the title block is not flush
    # against whatever comes next. In a side bar padding_left/padding_right
    # act along the stacking axis, so this reads as space below the row.
    if [ "$i" -eq $((TOTAL - 1)) ]; then
        PAD_RIGHT=10
    else
        PAD_RIGHT=0
    fi

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
            padding_right=$PAD_RIGHT \
            background.drawing=on \
            background.color=0xff000000 \
            background.corner_radius=0 \
            background.height=25
    else
        # Reused row: the last row may have changed, so re-assert the padding.
        sketchybar --set "title_$i" padding_left=0 padding_right=$PAD_RIGHT
    fi
    i=$((i + 1))
done
IFS="$IFS_BACKUP"

# Drop characters left over from a longer previous name.
while sketchybar --query "title_$i" >/dev/null 2>&1; do
    sketchybar --remove "title_$i"
    i=$((i + 1))
done

##### Bottom Badge #####

# Circular badge pinned to the bottom of the bar.
#
# It is added to the *right* group rather than the left one. In a right-side
# bar SketchyBar anchors that group to the bottom of the screen, so the badge
# holds a fixed position no matter how long the title above it grows -- no
# padding arithmetic, and no fighting over who comes last in the left group.
#
# The glyph is a *label* with label.width=40, exactly like the separator above.
# That matters: the background hugs its content, so an icon would size the box
# to the glyph and any change of icon would deform the circle. A fixed-width
# label keeps the content box at 40px, so the circle survives every glyph swap.
# The glyph is black: black-on-white is what stays legible in a white circle.
if ! sketchybar --query title_macos >/dev/null 2>&1; then
  sketchybar --add item title_macos right --set title_macos \
      icon.drawing=off \
      label="󰆍" \
      label.drawing=on \
      label.font="JetBrainsMono Nerd Font:Bold:20.0" \
      label.color=0xffffffff \
      label.align=center \
      label.width=40 \
      label.padding_left=0 \
      label.padding_right=0 \
      background.drawing=on \
      background.color=0xff000000 \
      background.corner_radius=20 \
      background.height=40 \
      padding_left=0 \
      padding_right=0
fi
