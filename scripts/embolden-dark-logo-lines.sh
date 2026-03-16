#!/usr/bin/env bash
set -euo pipefail

input_dir="${1:-}"
output_dir="${2:-$input_dir}"

if [[ -z "$input_dir" ]]; then
  echo "Usage: $0 INPUT_DIR [OUTPUT_DIR]" >&2
  exit 1
fi

down_name="square-dark-no-outline-margins-down.png"
states=(connected connecting disconnecting snoozed alert)
badge_padding_px=4
badge_diff_threshold=5
fringe_alpha=0.80
preserve_radius_delta_px=-5

if [[ ! -f "$input_dir/$down_name" ]]; then
  echo "Missing dark down icon: $input_dir/$down_name" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

source_dir="$work_dir/source"
mkdir -p "$source_dir" "$output_dir"
cp "$input_dir"/square-dark-no-outline-margins-*.png "$source_dir"/

down_in="$source_dir/$down_name"
down_out="$output_dir/$down_name"

get_size() {
  magick identify -format '%wx%h' "$1"
}

parse_bbox() {
  local bbox="$1"

  BBOX_W="${bbox%%x*}"
  local rest="${bbox#*x}"
  BBOX_H="${rest%%+*}"
  rest="${rest#*+}"
  BBOX_X="${rest%%+*}"
  BBOX_Y="${rest##*+}"
}

badge_geometry() {
  local bbox="$1"
  local max_dim

  parse_bbox "$bbox"
  max_dim="$BBOX_W"
  if (( BBOX_H > max_dim )); then
    max_dim="$BBOX_H"
  fi

  BADGE_RADIUS=$(( (max_dim + 1) / 2 ))
  BADGE_PRESERVE_RADIUS=$(( BADGE_RADIUS + badge_padding_px + preserve_radius_delta_px ))
  if (( BADGE_PRESERVE_RADIUS < 1 )); then
    BADGE_PRESERVE_RADIUS=1
  fi
  BADGE_CX=$(( BBOX_X + BBOX_W / 2 ))
  BADGE_CY=$(( BBOX_Y + BBOX_H / 2 ))
}

magick "$down_in" -alpha extract -threshold 0 "$work_dir/base_mask.png"
magick "$work_dir/base_mask.png" -morphology Dilate Diamond:1 "$work_dir/dilated_mask.png"
magick "$work_dir/dilated_mask.png" "$work_dir/base_mask.png" \
  -compose MinusSrc -composite -threshold 0 "$work_dir/ring_mask.png"
magick "$work_dir/ring_mask.png" \
  -fill white -opaque white -transparent black \
  -alpha on -channel A -evaluate multiply "$fringe_alpha" +channel \
  PNG32:"$work_dir/fringe.png"
magick "$work_dir/fringe.png" "$down_in" -compose Over -composite PNG32:"$down_out"

for state in "${states[@]}"; do
  in_file="$source_dir/square-dark-no-outline-margins-$state.png"
  out_file="$output_dir/square-dark-no-outline-margins-$state.png"

  if [[ ! -f "$in_file" ]]; then
    echo "Skipping missing state: $in_file" >&2
    continue
  fi

  canvas_size="$(get_size "$in_file")"

  magick "$in_file" "$down_in" \
    -alpha off \
    -compose Difference -composite \
    -colorspace Gray \
    -threshold "${badge_diff_threshold}%" \
    "$work_dir/diff_mask.png"

  bbox="$(magick "$work_dir/diff_mask.png" -trim -format '%wx%h%O' info:)"
  badge_geometry "$bbox"

  magick -size "$canvas_size" xc:black \
    -fill white \
    -draw "circle $BADGE_CX,$BADGE_CY $BADGE_CX,$((BADGE_CY - BADGE_PRESERVE_RADIUS))" \
    -threshold 0 \
    PNG32:"$work_dir/badge_preserve_mask.png"

  magick "$work_dir/fringe.png" "$work_dir/badge_preserve_mask.png" \
    -compose DstOut -composite \
    PNG32:"$work_dir/fringe_outside_badge.png"

  magick "$work_dir/fringe_outside_badge.png" "$in_file" \
    -compose Over -composite \
    PNG32:"$out_file"
done

echo "Emboldened dark logo lines:"
echo "  input:  $input_dir"
echo "  output: $output_dir"
