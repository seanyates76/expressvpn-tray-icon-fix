#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="${1:-$repo_root/build/ai-review-bundle.txt}"

mkdir -p "$(dirname "$output_path")"

docs=(
  "README.md"
  "SECURITY.md"
  "CONTRIBUTING.md"
  "RELEASING.md"
  "docs/COMPATIBILITY.md"
  "docs/TRANSPARENCY.md"
  "resources/original/README.md"
  "packaging/man/expressvpn-tray-icon-fix.1"
)

{
  printf '=== tree -L 3 ===\n\n'
  tree -L 3 "$repo_root"

  for relpath in "${docs[@]}"; do
    abspath="$repo_root/$relpath"
    if [[ -f "$abspath" ]]; then
      printf '\n=== %s ===\n\n' "$relpath"
      sed -n '1,$p' "$abspath"
    fi
  done

  printf '\n=== packaging/bin/expressvpn-tray-icon-fix ===\n\n'
  sed -n '1,$p' "$repo_root/packaging/bin/expressvpn-tray-icon-fix"

  printf '\n=== packaging/arch/PKGBUILD ===\n\n'
  sed -n '1,$p' "$repo_root/packaging/arch/PKGBUILD"
} > "$output_path"

printf 'Wrote review bundle: %s\n' "$output_path"
