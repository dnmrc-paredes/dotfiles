# Which display the bar lives on. SketchyBar's numbering matches the order
# CGGetActiveDisplayList reports, not the "display 1" macOS Settings shows.
#
# Sourced by sketchybarrc (for --display) and by now_playing.sh (to work out
# which bounding rect belongs to the real bar) so there is one place to change.
#
#   1 = 1920x1080 @75Hz  (main, menu bar here)
#   2 = 1920x1080 @60Hz  (left external)
#   3 = 1512x982         (built-in)
BAR_DISPLAY=1
