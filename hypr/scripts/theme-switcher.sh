#!/usr/bin/env bash
# Theme switcher TUI - Now with 100% less mysterious disappearing act
# Rewritten because someone was running it from fish shell and didn't think to mention it

# NO set -e because apparently that causes scripts to vanish into the aether
set -uo pipefail

# Configuration
THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/themes"
CURRENT_DIR="$THEMES_DIR/current"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'
BOLD='\033[1m'

# Check dependencies
check_deps() {
  if ! command -v fzf &>/dev/null; then
    echo -e "${RED}Error: fzf not found.${RESET}" >&2
    exit 1
  fi

  if [[ ! -d "$THEMES_DIR" ]]; then
    echo -e "${RED}Error: Themes directory '$THEMES_DIR' doesn't exist.${RESET}" >&2
    exit 1
  fi
}

# Preview function
preview_theme() {
  local theme="$1"
  local theme_path="$THEMES_DIR/$theme"

  # Basic info at the top
  echo -e "${CYAN}${BOLD}Theme:${RESET} $theme"
  echo -e "${CYAN}${BOLD}Path:${RESET} $theme_path"
  echo ""

  # Check for README
  local readme=""
  if [[ -f "$theme_path/README.md" ]]; then
    readme="$theme_path/README.md"
  elif [[ -f "$theme_path/README" ]]; then
    readme="$theme_path/README"
  elif [[ -f "$theme_path/readme.md" ]]; then
    readme="$theme_path/readme.md"
  fi

  # If README exists, show it
  if [[ -n "$readme" ]]; then
    echo -e "${BOLD}Description:${RESET}"
    echo ""
    cat "$readme"
  else
    # No README - show component list
    echo -e "${BOLD}Components:${RESET}"
    [[ -d "$theme_path/waybar" ]] && echo "  ✓ Waybar" || echo "  ✗ Waybar"
    [[ -d "$theme_path/mako" ]] && echo "  ✓ Mako" || echo "  ✗ Mako"
    [[ -d "$theme_path/rofi" ]] && echo "  ✓ Rofi" || echo "  ✗ Rofi"
    [[ -d "$theme_path/walls" ]] && echo "  ✓ Wallpapers" || echo "  ✗ Wallpapers"

    echo ""
    echo -e "${YELLOW}Tip: Add README.md to describe this theme${RESET}"
  fi
}

export -f preview_theme
export THEMES_DIR CYAN BOLD RESET

# Copy a component directory
copy_component() {
  local component="$1"
  local source="$2"
  local dest="$3"

  echo -e "${CYAN}→${RESET} Copying $component..."

  if [[ ! -d "$source" ]]; then
    echo -e "${RED}  Warning: $source doesn't exist, skipping${RESET}" >&2
    return 1
  fi

  # Remove old version
  if [[ -d "$dest" ]]; then
    rm -rf "$dest"
  fi

  # Copy new version
  if cp -r "$source" "$dest"; then
    echo -e "  ${GREEN}✓${RESET} $component copied"
    return 0
  else
    echo -e "${RED}  ✗ Failed to copy $component${RESET}" >&2
    return 1
  fi
}

# Reload components
reload_components() {
  echo ""
  echo -e "${YELLOW}Reloading components...${RESET}"

  # Waybar
  if pgrep -x waybar >/dev/null 2>&1; then
    echo -e "${CYAN}→${RESET} Restarting waybar..."
    pkill waybar 2>/dev/null
    sleep 0.3
    setsid waybar >/dev/null 2>&1 &
  fi

  # Mako
  if pgrep -x mako >/dev/null 2>&1; then
    echo -e "${CYAN}→${RESET} Reloading mako..."
    if command -v makoctl &>/dev/null; then
      makoctl reload 2>/dev/null
    else
      pkill mako 2>/dev/null
      sleep 0.2
      setsid mako >/dev/null 2>&1 &
    fi
  fi

  # Hyprland
  if command -v hyprctl &>/dev/null && pgrep -x Hyprland >/dev/null 2>&1; then
    echo -e "${CYAN}→${RESET} Reloading Hyprland..."
    hyprctl reload 2>/dev/null || true
  fi

  # Wallpaper switcher
  if [[ -f "$HOME/.config/hypr/scripts/wallpaper_switcher.sh" ]]; then
    echo -e "${CYAN}→${RESET} Switching wallpaper..."
    bash "$HOME/.config/hypr/scripts/wallpaper_switcher.sh" 2>/dev/null || true
  fi

  echo -e "${CYAN}→${RESET} Rofi will use new colours on next launch"
}

# Main function
main() {
  check_deps

  echo "Scanning themes directory..."

  # Get list of themes
  local theme_list
  theme_list=$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name 'current' -printf "%f\n" | sort)

  if [[ -z "$theme_list" ]]; then
    echo -e "${RED}No themes found in $THEMES_DIR${RESET}" >&2
    exit 1
  fi

  # FZF selection
  local selected
  selected=$(echo "$theme_list" | fzf \
    --preview "bash -c 'preview_theme {}'" \
    --preview-label='alt-p: toggle preview, enter: apply theme' \
    --preview-label-pos='bottom' \
    --preview-window 'right:50%:wrap' \
    --bind 'alt-p:toggle-preview' \
    --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up' \
    --bind 'alt-k:preview-up,alt-j:preview-down' \
    --color 'pointer:green,marker:green' \
    --header 'Theme Switcher - Enter to apply, Esc to quit' \
    --prompt 'Theme: ' \
    --border=rounded \
    --layout=reverse \
    --height=95%)

  if [[ -z "$selected" ]]; then
    echo "No theme selected."
    exit 0
  fi

  clear

  local selected_path="$THEMES_DIR/$selected"

  # Validate theme has content
  if [[ ! -d "$selected_path/waybar" ]] &&
    [[ ! -d "$selected_path/mako" ]] &&
    [[ ! -d "$selected_path/rofi" ]] &&
    [[ ! -d "$selected_path/walls" ]]; then
    echo -e "${RED}Error: Theme '$selected' is empty.${RESET}" >&2
    exit 1
  fi

  echo -e "${YELLOW}Applying theme: ${BOLD}$selected${RESET}"
  echo ""

  # Create current directory
  mkdir -p "$CURRENT_DIR"

  # Copy components - count successes
  local copied=0

  if [[ -d "$selected_path/walls" ]]; then
    if copy_component "wallpapers" "$selected_path/walls" "$CURRENT_DIR/walls"; then
      copied=$((copied + 1))
    fi
  fi

  if [[ -d "$selected_path/waybar" ]]; then
    if copy_component "waybar" "$selected_path/waybar" "$CURRENT_DIR/waybar"; then
      copied=$((copied + 1))
    fi
  fi

  if [[ -d "$selected_path/mako" ]]; then
    if copy_component "mako" "$selected_path/mako" "$CURRENT_DIR/mako"; then
      copied=$((copied + 1))
    fi
  fi

  if [[ -d "$selected_path/rofi" ]]; then
    if copy_component "rofi" "$selected_path/rofi" "$CURRENT_DIR/rofi"; then
      copied=$((copied + 1))
    fi
  fi

  if [[ $copied -eq 0 ]]; then
    echo -e "${RED}Error: Nothing was copied!${RESET}" >&2
    exit 1
  fi

  # Reload everything
  reload_components

  echo ""
  echo -e "${GREEN}${BOLD}✓${RESET} Theme '${BOLD}$selected${RESET}' applied successfully!"

  # Store current theme
  echo "$selected" >"$CURRENT_DIR/.current-theme"

  # Offer wallpaper selection
  if [[ -d "$CURRENT_DIR/walls" ]]; then
    echo ""
    echo -e "${CYAN}Wallpapers available in: $CURRENT_DIR/walls/${RESET}"
  fi

  echo ""
}

# Run it
main "$@"
