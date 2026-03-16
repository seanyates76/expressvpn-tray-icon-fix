#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input_dir="$project_dir/resources/original/img/tray"
themed_dir="$project_dir/resources/themed/img"
generator="$project_dir/scripts/make_evpn_tray_theme.sh"
dark_logo_embolden="$project_dir/scripts/embolden-dark-logo-lines.sh"
required_original_base="$input_dir/square-dark-no-outline-margins-down.png"

if [[ -n "${1:-}" ]]; then
  dark_colored_source="$1"
else
  dark_colored_source="$themed_dir/tray-dark-colored"
fi

if [[ ! -d "$dark_colored_source" ]]; then
  echo "Missing dark colored source directory: $dark_colored_source" >&2
  exit 1
fi

if [[ ! -f "$required_original_base" ]]; then
  for required_dir in \
    "$themed_dir/tray-dark-colored" \
    "$themed_dir/tray-dark-monochrome" \
    "$themed_dir/tray-light-colored" \
    "$themed_dir/tray-light-monochrome"; do
    if [[ ! -d "$required_dir" ]]; then
      echo "Missing canonical themed asset directory: $required_dir" >&2
      exit 1
    fi
  done

  echo "Original tray assets not present; using checked-in canonical themed assets."
  echo
  echo "Prepared tray variants:"
  echo "  dark-colored:    $themed_dir/tray-dark-colored"
  echo "  dark-monochrome: $themed_dir/tray-dark-monochrome"
  echo "  light-colored:   $themed_dir/tray-light-colored"
  echo "  light-monochrome:$themed_dir/tray-light-monochrome"
  exit 0
fi

mkdir -p "$themed_dir/tray-dark-colored"
if [[ "$dark_colored_source" != "$themed_dir/tray-dark-colored" ]]; then
  cp "$dark_colored_source"/square-dark-no-outline-margins-*.png "$themed_dir/tray-dark-colored/"
fi

badge_reference_dir="$themed_dir/tray-dark-colored"

"$generator" "$input_dir" "$themed_dir/tray-dark-monochrome" dark monochrome outline "$badge_reference_dir"
"$generator" "$input_dir" "$themed_dir/tray-light-colored" light colored original "$badge_reference_dir"
"$generator" "$input_dir" "$themed_dir/tray-light-monochrome" light monochrome original "$badge_reference_dir"
"$dark_logo_embolden" "$themed_dir/tray-dark-colored"
"$dark_logo_embolden" "$themed_dir/tray-dark-monochrome"

echo
echo "Prepared tray variants:"
echo "  dark-colored:    $themed_dir/tray-dark-colored"
echo "  dark-monochrome: $themed_dir/tray-dark-monochrome"
echo "  light-colored:   $themed_dir/tray-light-colored"
echo "  light-monochrome:$themed_dir/tray-light-monochrome"
