#!/usr/bin/env bash
set -euo pipefail

prefix="${1:-$HOME/.local}"

share_dir="$prefix/share/expressvpn-tray-override"
wrapper_path="$prefix/bin/expressvpn-client-tray-override"
desktop_path="$prefix/share/applications/expressvpn.desktop"

rm -f "$wrapper_path"
rm -f "$desktop_path"
rm -rf "$share_dir"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$prefix/share/applications" >/dev/null 2>&1 || true
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 >/dev/null 2>&1 || true
fi

echo "Removed ExpressVPN tray override from $prefix"
