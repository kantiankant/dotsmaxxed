#!/bin/bash
# Fetcher menu with ASCII art that actually displays

clear

# Print the logo
cat <<'HEADER'
 ██████╗ ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗      ██████╗  ██████╗ ██████╗ ████████╗███████╗
██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝      ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝
██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║ ╚████╔╝ █████╗██████╔╝██║   ██║██████╔╝   ██║   ███████╗
██║   ██║██║╚██╔╝██║██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝  ╚════╝██╔═══╝ ██║   ██║██╔══██╗   ██║   ╚════██║
╚██████╔╝██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║   ██║         ██║     ╚██████╔╝██║  ██║   ██║   ███████║
 ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝         ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
HEADER

echo ""

# Compact fzf menu
choice=$(printf "pacfetch\naurfetch\nauruninstaller\nupdater" | fzf \
  --prompt="Select Programme > " \
  --layout=reverse \
  --border \
  --height=40%)

# Execute based on selection
case "$choice" in
pacfetch)
  pacfetch
  ;;
aurfetch)
  aurfetch
  ;;
auruninstaller)
  ~/aur-uninstaller.sh
  ;;
updater)
  ~/update.sh
  ;;
*)
  clear
  echo "Selection cancelled."
  exit 1
  ;;
esac
