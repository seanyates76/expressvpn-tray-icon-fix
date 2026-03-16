#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
themed_dir="$project_dir/resources/themed/img"
build_root="$project_dir/build/override"

style="${1:-colored}"
out_rcc="${2:-$build_root/$style/override.rcc}"
mode="${3:-combined}"

case "$style" in
  colored)
    dark_dir="$themed_dir/tray-dark-colored"
    light_dir="$themed_dir/tray-light-colored"
    ;;
  monochrome)
    dark_dir="$themed_dir/tray-dark-monochrome"
    if [[ -d "$themed_dir/tray-light-monochrome" ]]; then
      light_dir="$themed_dir/tray-light-monochrome"
    else
      light_dir="$themed_dir/tray-white-monochrome"
    fi
    ;;
  *)
    echo "Invalid style: $style" >&2
    echo "Expected: colored or monochrome" >&2
    exit 1
    ;;
esac

for dir in "$dark_dir" "$light_dir"; do
  if [[ ! -d "$dir" ]]; then
    echo "Missing themed asset directory: $dir" >&2
    exit 1
  fi
done

case "$mode" in
  combined|locked-dark|locked-light) ;;
  *)
    echo "Invalid mode: $mode" >&2
    echo "Expected: combined, locked-dark, or locked-light" >&2
    exit 1
    ;;
esac

find_rcc() {
  local candidate

  for candidate in \
    "$(command -v rcc 2>/dev/null || true)" \
    "$(command -v rcc6 2>/dev/null || true)" \
    /usr/lib/qt6/bin/rcc \
    /usr/lib/qt6/libexec/rcc; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done

  echo "Missing required command: rcc" >&2
  exit 1
}

rcc_bin="$(find_rcc)"

out_dir="$(dirname "$out_rcc")"
qrc_path="$out_dir/override.qrc"

mkdir -p "$out_dir"

emit_aliases() {
  local dir="$1"
  local file
  local name

  for file in "$dir"/*.png; do
    if [[ ! -f "$file" ]]; then
      continue
    fi

    name="$(basename "$file")"
    printf '    <file alias="img/tray/%s">%s</file>\n' "$name" "$file"
  done
}

emit_locked_aliases() {
  local dir="$1"
  local file
  local name
  local alt_name

  for file in "$dir"/*.png; do
    if [[ ! -f "$file" ]]; then
      continue
    fi

    name="$(basename "$file")"
    alt_name="$name"
    if [[ "$name" == square-dark-* ]]; then
      alt_name="${name/square-dark-/square-light-}"
    elif [[ "$name" == square-light-* ]]; then
      alt_name="${name/square-light-/square-dark-}"
    fi

    printf '    <file alias="img/tray/%s">%s</file>\n' "$name" "$file"
    printf '    <file alias="img/tray/%s">%s</file>\n' "$alt_name" "$file"
  done
}

{
  printf '<RCC>\n'
  printf '  <qresource prefix="/">\n'

  case "$mode" in
    combined)
      emit_aliases "$dark_dir"
      emit_aliases "$light_dir"
      ;;
    locked-dark)
      emit_locked_aliases "$dark_dir"
      ;;
    locked-light)
      emit_locked_aliases "$light_dir"
      ;;
  esac

  printf '  </qresource>\n'
  printf '</RCC>\n'
} > "$qrc_path"

"$rcc_bin" --binary --output "$out_rcc" "$qrc_path"

echo "$out_rcc"
