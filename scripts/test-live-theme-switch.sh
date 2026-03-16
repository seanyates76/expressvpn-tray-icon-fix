#!/usr/bin/env bash
set -euo pipefail

wrapper="${1:-$HOME/.local/bin/expressvpn-client-tray-override}"
settings_path="${XDG_CONFIG_HOME:-$HOME/.config}/expressvpn/clientsettings.json"
theme_path="${2:-/tmp/expressvpn-theme-test.ini}"
log_path="${3:-/tmp/expressvpn-tray-live-test.log}"
debug_path="${4:-/tmp/expressvpn-tray-override-debug.log}"
mode="${5:-dark-to-light}"

case "$mode" in
  dark-to-light)
    initial_theme=$'[Settings]\ngtk-application-prefer-dark-theme=true\ngtk-theme-name=Breeze-Dark\ngtk-icon-theme-name=breeze-dark\n'
    flipped_theme=$'[Settings]\ngtk-application-prefer-dark-theme=false\ngtk-theme-name=Breeze\ngtk-icon-theme-name=breeze\n'
    settings_label_initial='---settings-dark---'
    settings_label_flipped='---settings-light---'
    ;;
  light-to-dark)
    initial_theme=$'[Settings]\ngtk-application-prefer-dark-theme=false\ngtk-theme-name=Breeze\ngtk-icon-theme-name=breeze\n'
    flipped_theme=$'[Settings]\ngtk-application-prefer-dark-theme=true\ngtk-theme-name=Breeze-Dark\ngtk-icon-theme-name=breeze-dark\n'
    settings_label_initial='---settings-light---'
    settings_label_flipped='---settings-dark---'
    ;;
  *)
    echo "Unsupported mode: $mode" >&2
    echo "Expected: dark-to-light or light-to-dark" >&2
    exit 1
    ;;
esac

printf '%s' "$initial_theme" > "$theme_path"
rm -f "$log_path"
rm -f "$debug_path"

pkill -f '/opt/expressvpn/bin/expressvpn-client' >/dev/null 2>&1 || true
for _ in {1..20}; do
  if ! pgrep -f '/opt/expressvpn/bin/expressvpn-client' >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
nohup env EXPRESSVPN_TRAY_SYSTEM_THEME_FILE="$theme_path" EXPRESSVPN_TRAY_DEBUG=1 "$wrapper" >"$log_path" 2>&1 &
sleep 6

printf '%s\n' "$settings_label_initial"
sed -n '1p' "$settings_path"

printf '%s\n' '---theme-switch---'
printf '%s' "$flipped_theme" > "$theme_path"
sleep 3

printf '%s\n' "$settings_label_flipped"
sed -n '1p' "$settings_path"

printf '%s\n' '---proc---'
pgrep -af expressvpn-client || true

printf '%s\n' '---log-tail---'
sed -n '1,220p' "$log_path"

printf '%s\n' '---debug-tail---'
sed -n '1,220p' "$debug_path"
