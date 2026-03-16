#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_root="${1:?usage: $0 <out-root>}"

themed_dir="$project_dir/resources/themed/img"
build_root="$project_dir/build/package-runtime"

mkdir -p "$out_root/lib"

"$project_dir/scripts/build_tray_variants.sh"
make -C "$project_dir" override-preload >/dev/null

install -m 0755 \
  "$project_dir/build/libexpressvpn-tray-override.so" \
  "$out_root/lib/libexpressvpn-tray-override.so"

stage_style() {
  local style="$1"
  local dark_dir="$2"
  local light_dir="$3"
  local style_root="$out_root/styles/$style"
  local assets_dark_dir="$style_root/assets/dark"
  local assets_light_dir="$style_root/assets/light"

  mkdir -p "$assets_dark_dir" "$assets_light_dir"

  "$project_dir/scripts/build-override-rcc.sh" "$style" "$style_root/override.rcc" combined >/dev/null
  "$project_dir/scripts/build-override-rcc.sh" "$style" "$style_root/override-dark.rcc" locked-dark >/dev/null
  "$project_dir/scripts/build-override-rcc.sh" "$style" "$style_root/override-light.rcc" locked-light >/dev/null
  rm -f "$style_root/override.qrc"

  install -m 0644 "$dark_dir"/square-dark-no-outline-margins-*.png "$assets_dark_dir"/
  install -m 0644 "$light_dir"/square-light-no-outline-margins-*.png "$assets_light_dir"/
}

stage_style \
  colored \
  "$themed_dir/tray-dark-colored" \
  "$themed_dir/tray-light-colored"

stage_style \
  monochrome \
  "$themed_dir/tray-dark-monochrome" \
  "$themed_dir/tray-light-monochrome"

echo "$out_root"
