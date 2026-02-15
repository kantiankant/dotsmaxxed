#!/bin/bash

# Check if weather TUI is already running
if pgrep -f "ghostty.*weather_tui.py" >/dev/null; then
  # Kill existing instance
  pkill -f "ghostty.*weather_tui.py"
else
  # Get mouse position for positioning the window
  eval $(xdotool getmouselocation --shell)

  # Launch Ghostty with the weather TUI as a floating tooltip
  ghostty \
    --class="weather-tooltip" \
    --title="Singapore Weather" \
    -e python3 ~/.config/waybar/scripts/weather_tui.py &
fi
