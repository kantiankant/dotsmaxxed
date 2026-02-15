#!/usr/bin/env bash
# Wallpaper selector using swww with chafa previews
# Using chafa because kitty graphics protocol hangs in fzf preview windows
# Like I told you from the bloody start

set -uo pipefail

# Configuration
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Stui"
CONFIG_FILE="$CONFIG_DIR/stuirc"

# Defaults
DEFAULT_WALLPAPER_DIR="$HOME/wallpapers"
DEFAULT_TRANSITION_TYPE="wipe"
DEFAULT_TRANSITION_ANGLE="30"
DEFAULT_TRANSITION_DURATION="0.5"
DEFAULT_TRANSITION_FPS="144"

# Load config if exists
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# Set variables with fallbacks
WALLPAPER_DIR="${WALLPAPER_DIR:-$DEFAULT_WALLPAPER_DIR}"
TRANSITION_TYPE="${TRANSITION_TYPE:-$DEFAULT_TRANSITION_TYPE}"
TRANSITION_ANGLE="${TRANSITION_ANGLE:-$DEFAULT_TRANSITION_ANGLE}"
TRANSITION_DURATION="${TRANSITION_DURATION:-$DEFAULT_TRANSITION_DURATION}"
TRANSITION_FPS="${TRANSITION_FPS:-$DEFAULT_TRANSITION_FPS}"

# Export for wrapper script
export WALLPAPER_DIR TRANSITION_TYPE TRANSITION_ANGLE TRANSITION_DURATION TRANSITION_FPS

# Preview function - CHAFA because kitty graphics don't work in fzf subshells
preview_wallpaper() {
  local file="$1"
  local full_path="$WALLPAPER_DIR/$file"
  local term_height="${FZF_PREVIEW_LINES:-30}"
  local term_width="${FZF_PREVIEW_COLUMNS:-80}"

  # Fixed dimensions for EVERY image - no variation
  local img_height=$((term_height - 5))
  local img_width=$((term_width - 4))

  [[ $img_height -lt 10 ]] && img_height=10
  [[ $img_width -lt 20 ]] && img_width=20

  echo -e "\033[1;36mFile:\033[0m $file"

  if command -v identify &>/dev/null; then
    local dims
    dims=$(identify -format "%wx%h" "$full_path" 2>/dev/null || echo "unknown")
    echo -e "\033[1;36mSize:\033[0m $dims"
  fi

  echo ""

  # Chafa with stretch mode - every image outputs EXACTLY the same dimensions
  if command -v chafa &>/dev/null; then
    chafa --stretch --fill=space -s "${img_width}x${img_height}" "$full_path" 2>/dev/null
  else
    echo -e "\033[0;90mInstall chafa for previews: sudo pacman -S chafa\033[0m"
  fi
}

export -f preview_wallpaper

# Create wrapper script for wallpaper setting
WRAPPER_SCRIPT="/tmp/stui-set-wallpaper-$$"
LOCKFILE="/tmp/stui-lock-$$"

cat >"$WRAPPER_SCRIPT" <<'WRAPPER_EOF'
#!/bin/bash
wallpaper="$1"
full_path="$WALLPAPER_DIR/$wallpaper"

# Rate limiting - don't spam swww
LOCKFILE="/tmp/stui-lock-$$"
RATE_LIMIT=1

if [[ -f "$LOCKFILE" ]]; then
    last_change=$(cat "$LOCKFILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    elapsed=$((now - last_change))
    
    if [[ $elapsed -lt $RATE_LIMIT ]]; then
        exit 0
    fi
fi

# Set wallpaper
if swww img "$full_path" \
    --transition-type "$TRANSITION_TYPE" \
    --transition-angle "$TRANSITION_ANGLE" \
    --transition-duration "$TRANSITION_DURATION" \
    --transition-fps "$TRANSITION_FPS" 2>/dev/null; then
    date +%s > "$LOCKFILE"
fi
WRAPPER_EOF

sed -i "s/\$\$/$$/" "$WRAPPER_SCRIPT"
chmod +x "$WRAPPER_SCRIPT"

trap "rm -f '$WRAPPER_SCRIPT' '$LOCKFILE'" EXIT

# Check dependencies
if ! command -v swww &>/dev/null; then
  echo "Error: swww not found."
  exit 1
fi

if ! command -v fzf &>/dev/null; then
  echo "Error: fzf not found."
  exit 1
fi

# Check for kitty
if ! command -v kitten &>/dev/null; then
  echo "Warning: kitten (kitty terminal) not found"
  echo "This script requires kitty terminal for image previews."
  echo ""
  read -p "Continue anyway? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check wallpaper directory
if [[ ! -d "$WALLPAPER_DIR" ]]; then
  echo "Error: Wallpaper directory '$WALLPAPER_DIR' doesn't exist."
  echo ""
  echo "Options:"
  echo "  1. Create: mkdir -p '$WALLPAPER_DIR'"
  echo "  2. Configure: $CONFIG_FILE"
  echo "  3. Override: WALLPAPER_DIR=/path $0"
  echo ""

  if [[ ! -f "$CONFIG_FILE" ]]; then
    read -p "Create config file now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      mkdir -p "$CONFIG_DIR"
      cat >"$CONFIG_FILE" <<'EOF'
# Stui Configuration
WALLPAPER_DIR="$HOME/wallpapers"
TRANSITION_TYPE="wipe"
TRANSITION_ANGLE="30"
TRANSITION_DURATION="0.5"
TRANSITION_FPS="144"
EOF
      echo "✓ Config created: $CONFIG_FILE"
      echo "  Edit it, then run again."
      exit 0
    fi
  fi
  exit 1
fi

# Check swww daemon
if ! pgrep -x swww-daemon &>/dev/null; then
  echo "Warning: swww daemon not running."
  read -p "Start swww daemon? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    swww init
    sleep 1
  else
    exit 1
  fi
fi

echo "Scanning wallpapers..."

# Run fzf with kitty graphics previews
find "$WALLPAPER_DIR" -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
  -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.bmp" \) \
  -printf "%P\n" | sort | fzf \
  --preview "bash -c 'preview_wallpaper {}'" \
  --preview-label='alt-p: toggle, alt-j/k: scroll, enter: set wallpaper' \
  --preview-label-pos='bottom' \
  --preview-window 'right:50%:wrap' \
  --bind 'alt-p:toggle-preview' \
  --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up' \
  --bind 'alt-k:preview-up,alt-j:preview-down' \
  --bind "enter:execute-silent($WRAPPER_SCRIPT {})" \
  --color 'pointer:green,marker:green' \
  --header 'Wallpaper Selector - Enter to set (stays open), Esc to quit' \
  --prompt 'Wallpaper: ' \
  --border=rounded \
  --layout=reverse \
  --height=95%

clear
