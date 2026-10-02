#!/bin/sh

# The focused application.
#
# Normally this is just the app's own icon in the separator row. There is no
# name column any more, because stacking one character per row needed a bar
# item per letter and grew very tall for long names.
#
# If an app has no icon we can find, it falls back to the old vertical name
# column, so nothing is ever unidentified.
#
# The icon goes in the item's BACKGROUND rather than its icon property:
# SketchyBar 2.24 rejects `icon.image` outright ("Invalid property 'image'"),
# and only background.image accepts a file.
#
# The PNG is extracted at exactly 40px, the width of the row. background.image
# draws at the image's natural pixel size and background.image.scale does NOT
# resize the item -- an 80px PNG at scale 0.5 still made the row 80px tall and
# pushed everything below it down the bar. So the size is baked into the file.

PLUGIN_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins"
. "$PLUGIN_DIR/bar_display.sh"

ICON_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/icons"

APP="$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null | head -n 1)"
BUNDLE_ID="$(aerospace list-windows --focused --format '%{app-bundle-id}' 2>/dev/null | head -n 1)"

# Drop any vertical name rows; they are only drawn on the fallback path below.
clear_name_rows() {
    i=0
    while sketchybar --query "title_$i" >/dev/null 2>&1; do
        sketchybar --remove "title_$i"
        i=$((i + 1))
    done
}

# Prints a cached PNG for the given bundle id, or nothing.
#
# The cache is keyed by bundle id and extraction only runs on a miss, so
# switching apps does not shell out to mdfind, PlistBuddy and sips every time.
# The cost is that an app which changes its own icon keeps the old one until
# the cache file is deleted.
icon_for() {
    [ -n "$1" ] || return 0
    mkdir -p "$ICON_CACHE" 2>/dev/null
    png="$ICON_CACHE/$1.png"
    if [ -s "$png" ]; then
        printf '%s' "$png"
        return 0
    fi

    # Resolve the bundle WITHOUT Apple Events. The obvious
    # `osascript -e 'path to application id ...'` sends an Apple Event, and
    # macOS then asks for Automation consent for that target app -- one prompt
    # per app, every time a new one is focused. Neither of these does that:
    # mdfind is a Spotlight metadata lookup, lsappinfo talks to LaunchServices.
    app="$(mdfind "kMDItemCFBundleIdentifier == '$1'" 2>/dev/null | head -n 1)"
    if [ -z "$app" ] || [ ! -d "$app" ]; then
        # Fall back to the frontmost app -- but ONLY if it is the one we were
        # actually asked about. lsappinfo reports whatever is frontmost, which
        # is usually but not always the focused window's app; accepting it
        # blindly cached one app's icon under another app's bundle id, and that
        # wrong icon then stuck for good.
        asn="$(lsappinfo front 2>/dev/null)"
        front_id="$(lsappinfo info -only bundleid "$asn" 2>/dev/null |
                    sed -n 's/.*"CFBundleIdentifier"="\(.*\)".*/\1/p')"
        if [ -n "$front_id" ] && [ "$front_id" = "$1" ]; then
            app="$(lsappinfo info -only bundlepath "$asn" 2>/dev/null |
                   sed -n 's/.*"LSBundlePath"="\(.*\)".*/\1/p')"
        else
            app=""
        fi
    fi
    [ -n "$app" ] && [ -d "$app" ] || return 0

    # Take the icon the bundle DECLARES, which is the one macOS itself uses.
    # Grabbing the first .icns alphabetically is wrong: VS Code ships 28 of
    # them, nearly all file-type icons, and alphabetically first is bat.icns --
    # so it was showing a bat file. Ghostty also declares its icon with no file
    # extension ("Ghostty", not "Ghostty.icns"), hence the case below.
    res="$app/Contents/Resources"
    plist="$app/Contents/Info.plist"
    icns=""

    name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist" 2>/dev/null)"
    if [ -n "$name" ]; then
        case "$name" in
            *.icns) [ -f "$res/$name" ] && icns="$res/$name" ;;
            *)      [ -f "$res/$name.icns" ] && icns="$res/$name.icns" ;;
        esac
    fi
    if [ -z "$icns" ]; then
        name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$plist" 2>/dev/null)"
        [ -n "$name" ] && [ -f "$res/$name.icns" ] && icns="$res/$name.icns"
    fi
    if [ -z "$icns" ]; then
        for f in "$res"/*.icns; do
            if [ -f "$f" ]; then
                icns="$f"
                break
            fi
        done
    fi
    [ -n "$icns" ] || return 0

    sips -s format png -Z 40 "$icns" --out "$png" >/dev/null 2>&1
    [ -s "$png" ] && printf '%s' "$png"
    return 0
}

# The vertical name column, used only when there is no icon. Same as it was
# before the icon existed: one bar item per character.
draw_name_rows() {
    chars="$(printf '%s' "$1" | awk '{
        out = ""
        for (i = 1; i <= NF; i++) {
            w = $i
            if (w ~ /^[a-z]/) w = toupper(substr(w, 1, 1)) substr(w, 2)
            out = out (i > 1 ? " " : "") w
        }
        print out
    }' | fold -w1)"

    # Cap the column so a long name cannot run into the controls at the bottom.
    MAX_TITLE_CHARS=22
    chars="$(printf '%s' "$chars" | awk -v max="$MAX_TITLE_CHARS" -v dot="…" '
        NR <  max { print }
        NR == max { print dot }
    ')"

    i=0
    for ch in $chars; do
        # The first row carries the 15px gap that used to be the separator's
        # padding_left, so the column starts at y=297 -- the same place the
        # icon sits on the other path.
        if [ "$i" -eq 0 ]; then
            ROW_PAD_LEFT=15
        else
            ROW_PAD_LEFT=0
        fi
        # A space became a row of its own, which drew as an empty black block
        # under the title. Keep the row so the words stay separated, but draw
        # nothing in it.
        if [ "$ch" = " " ]; then
            ROW_BG=0x00000000
        else
            ROW_BG=0xff000000
        fi
        if ! sketchybar --set "title_$i" label="$ch" 2>/dev/null; then
            sketchybar --add item "title_$i" left --set "title_$i" \
                icon.drawing=off \
                label="$ch" \
                label.font="JetBrainsMono Nerd Font:Regular:18.0" \
                label.color=0xffffffff \
                label.align=center \
                label.width=40 \
                label.padding_left=0 \
                label.padding_right=0 \
                padding_left=$ROW_PAD_LEFT \
                padding_right=0 \
                background.drawing=on \
                background.color=$ROW_BG \
                background.corner_radius=0 \
                background.height=25
        else
            sketchybar --set "title_$i" padding_left=$ROW_PAD_LEFT \
                background.color=$ROW_BG background.height=25
        fi
        i=$((i + 1))
    done
}

ICON=""
if [ -n "$APP" ]; then
    ICON="$(icon_for "$BUNDLE_ID")"
    # A brand new app can lose the first lookup: Spotlight has not finished
    # indexing it, so mdfind comes back empty. One short retry covers that, and
    # it costs nothing for the apps already cached.
    if [ -z "$ICON" ] && [ -n "$BUNDLE_ID" ]; then
        sleep 1
        ICON="$(icon_for "$BUNDLE_ID")"
    fi
fi

# The separator row itself. Created once; every property is re-asserted on each
# run so a reload can never leave it showing the previous app's icon.
if ! sketchybar --query title_spacer >/dev/null 2>&1; then
    sketchybar --add item title_spacer left --set title_spacer \
        label.width=40 \
        background.drawing=on \
        background.height=40 \
        padding_left=15 \
        padding_right=15
fi

if [ -n "$ICON" ]; then
    clear_name_rows
    # Fully transparent behind the icon, so it sits straight on the wallpaper
    # with no black square behind it. Set explicitly rather than inherited: it
    # used to pick up whatever the previous run had set, so a fresh restart and
    # a mid-session switch could draw the same icon differently. (The note has
    # to sit above the command: a # inside a backslash-continued line ends the
    # command instead of being a comment.)
    sketchybar --set title_spacer \
        icon.drawing=off \
        label.drawing=off \
        label.padding_left=0 \
        label.padding_right=0 \
        background.drawing=on \
        background.image="$ICON" \
        background.image.scale=1.0 \
        background.color=0x00000000 \
        background.height=40 \
        background.corner_radius=0 \
        padding_left=15 \
        padding_right=15
elif [ -n "$APP" ]; then
    # No icon for this app: just the vertical name column, so the separator
    # draws nothing. The item is kept rather than removed so the row still
    # holds its 40px slot and the column does not shift up.
    # Remove the row rather than trying to collapse it: background.height is
    # accepted but ignored on this item, so it stays 40px and leaves a hole
    # above the name. The icon path re-creates it at the top of this script.
    sketchybar --remove title_spacer 2>/dev/null
    draw_name_rows "$APP"
else
    # Nothing focused: no icon and no name, so no separator either.
    clear_name_rows
    sketchybar --remove title_spacer 2>/dev/null
fi

##### Bottom Badge #####

# Circular badge pinned to the bottom of the bar.
#
# It is added to the *right* group rather than the left one. In a right-side
# bar SketchyBar anchors that group to the bottom of the screen, so the badge
# holds a fixed position no matter what else is in the bar -- no padding
# arithmetic, and no fighting over who comes last in the left group.
#
# The glyph is a *label* with label.width=40. That matters: the background hugs
# its content, so an icon would size the box to the glyph and any change of icon
# would deform the circle. A fixed-width label keeps the content box at 40px, so
# the circle survives every glyph swap.
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
