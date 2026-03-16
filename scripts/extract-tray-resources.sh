#!/usr/bin/env zsh
set -euo pipefail

project_dir=${0:A:h:h}
build_dir="$project_dir/build"
dump_dir="$project_dir/resources/original"
preload="$build_dir/libexpressvpn-tray-dump.so"
log_file="$build_dir/extract.log"

if [[ ! -f "$preload" ]]; then
  echo "missing preload library: $preload" >&2
  exit 1
fi

mkdir -p "$dump_dir"

env \
  EXPRESSVPN_TRAY_DUMP_DIR="$dump_dir" \
  LD_PRELOAD="$preload" \
  timeout 15s /opt/expressvpn/bin/expressvpn-client --quiet >"$log_file" 2>&1 || true

if [[ ! -f "$dump_dir/manifest.txt" ]]; then
  echo "resource extraction did not produce a manifest; see $log_file" >&2
  exit 1
fi

echo "extracted tray resources into $dump_dir"
