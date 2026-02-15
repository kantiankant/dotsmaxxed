#!/bin/bash

set -uo pipefail

CACHE_DIR="/tmp/system-updates-$$"
PREVIEW_SCRIPT="$CACHE_DIR/preview.sh"

# Detect AUR helper
if command -v yay &>/dev/null; then
  HELPER="yay"
elif command -v paru &>/dev/null; then
  HELPER="paru"
else
  HELPER="none"
fi

# Check fzf
if ! command -v fzf &>/dev/null; then
  echo "Error: fzf not found."
  exit 1
fi

# Create cache directory
mkdir -p "$CACHE_DIR"

# Cleanup on exit
trap "rm -rf '$CACHE_DIR'" EXIT

echo "Checking for updates..."

# Cache official updates
checkupdates 2>/dev/null >"$CACHE_DIR/pacman.txt" || echo "No updates available" >"$CACHE_DIR/pacman.txt"

# Cache AUR updates
if [[ "$HELPER" != "none" ]]; then
  $HELPER -Qua 2>/dev/null >"$CACHE_DIR/aur.txt" || echo "No AUR updates" >"$CACHE_DIR/aur.txt"
else
  echo "No AUR helper installed (yay/paru)" >"$CACHE_DIR/aur.txt"
fi

# Create preview script as a REAL FILE
cat >"$PREVIEW_SCRIPT" <<'PREVIEW_EOF'
#!/bin/bash
choice="$1"
CACHE_DIR="$2"

case "$choice" in
    "Update Official Packages")
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Official Repository Updates"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        cat "$CACHE_DIR/pacman.txt"
        ;;
    "Update AUR Packages")
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "AUR Package Updates"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        cat "$CACHE_DIR/aur.txt"
        ;;
    "Update Everything")
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "All Available Updates"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "=== Official Repositories ==="
        cat "$CACHE_DIR/pacman.txt"
        echo ""
        echo "=== AUR Packages ==="
        cat "$CACHE_DIR/aur.txt"
        ;;
esac
PREVIEW_EOF

chmod +x "$PREVIEW_SCRIPT"

# Run fzf with the ACTUAL preview script
choice=$(printf "Update Official Packages\nUpdate AUR Packages\nUpdate Everything" | fzf \
  --preview "$PREVIEW_SCRIPT {} $CACHE_DIR" \
  --preview-label='Updates available (scroll with alt-j/k)' \
  --preview-label-pos='top' \
  --preview-window 'down:60%:wrap' \
  --bind 'alt-p:toggle-preview' \
  --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up' \
  --bind 'alt-k:preview-up,alt-j:preview-down' \
  --color 'pointer:green,marker:green' \
  --header 'System Updater - Arrow keys to select, Enter to proceed, Esc to cancel' \
  --prompt 'Update: ' \
  --border=rounded \
  --layout=reverse \
  --height=95%)

if [[ -z "$choice" ]]; then
  echo "Update cancelled."
  exit 0
fi

clear

# Execute update
case "$choice" in
"Update Official Packages")
  echo "Updating official packages..."
  sudo pacman -Syu
  ;;
"Update AUR Packages")
  if [[ "$HELPER" == "none" ]]; then
    echo "Error: No AUR helper found. Install yay or paru."
    exit 1
  fi
  echo "Updating AUR packages..."
  $HELPER -Sua
  ;;
"Update Everything")
  if [[ "$HELPER" == "none" ]]; then
    echo "Updating official packages only (no AUR helper)..."
    sudo pacman -Syu
  else
    echo "Updating everything..."
    $HELPER -Syu
  fi
  ;;
esac

exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  echo ""
  if command -v gum &>/dev/null; then
    gum spin --spinner "globe" --title "Done! Press any key to close..." -- bash -c 'read -n 1 -s'
  else
    echo "✓ Update complete! Press any key to close..."
    read -n 1 -s
  fi
else
  echo ""
  echo "✗ Update failed or cancelled."
  read -n 1 -s
  exit $exit_code
fi
