#!/usr/bin/env bash
set -euo pipefail

# ExpressVPN tray icon re-theme
#
# Usage:
#   ./make_evpn_tray_theme.sh INPUT_DIR OUTPUT_DIR [dark|light] [colored|monochrome] [auto|outline|original] [badge_reference_dir]
#
# Defaults:
#   theme: dark
#   status style: colored
#   base style: auto
#
# Base style resolution:
#   dark + auto  -> outline
#   light + auto -> original

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-./tray-dark-colored}"
THEME_VARIANT="${3:-dark}"
STATUS_STYLE="${4:-colored}"
BASE_STYLE="${5:-auto}"
BADGE_REFERENCE_DIR="${6:-}"

mkdir -p "$OUTPUT_DIR"

case "$THEME_VARIANT" in
  dark|light) ;;
  *)
    echo "Invalid theme variant: $THEME_VARIANT" >&2
    exit 1
    ;;
esac

case "$STATUS_STYLE" in
  colored|monochrome) ;;
  *)
    echo "Invalid status style: $STATUS_STYLE" >&2
    exit 1
    ;;
esac

case "$BASE_STYLE" in
  auto|outline|original) ;;
  *)
    echo "Invalid base style: $BASE_STYLE" >&2
    exit 1
    ;;
esac

if [[ "$BASE_STYLE" == "auto" ]]; then
  if [[ "$THEME_VARIANT" == "dark" ]]; then
    BASE_STYLE="outline"
  else
    BASE_STYLE="original"
  fi
fi

PREFIX="square-${THEME_VARIANT}-no-outline-margins"

BASE_FILE="${PREFIX}-down.png"
CONNECTED_FILE="${PREFIX}-connected.png"
CONNECTING_FILE="${PREFIX}-connecting.png"
DISCONNECTING_FILE="${PREFIX}-disconnecting.png"
SNOOZED_FILE="${PREFIX}-snoozed.png"
ALERT_FILE="${PREFIX}-alert.png"

OUTLINE_PX=1
BADGE_PADDING_PX=4
LIGHT_BADGE_PADDING_PX=2
DOT_DIAMETER_PX=18
BADGE_DIFF_THRESHOLD=5
BADGE_ICON_THRESHOLD=55

WHITE="#FFFFFF"
SNOOZE="#D1D5DB"
GREEN="#22C55E"
YELLOW="#F59E0B"
RED="#DA3940"

if [[ "$STATUS_STYLE" == "monochrome" ]]; then
  SNOOZE="$WHITE"
  GREEN="$WHITE"
  YELLOW="$WHITE"
  RED="$WHITE"
fi

BASE_IN="$INPUT_DIR/$BASE_FILE"
REFERENCE_PREFIX="square-dark-no-outline-margins"
REFERENCE_BASE_IN="$BADGE_REFERENCE_DIR/${REFERENCE_PREFIX}-down.png"

if [[ ! -f "$BASE_IN" ]]; then
  echo "Missing base file: $BASE_IN" >&2
  exit 1
fi

if [[ -n "$BADGE_REFERENCE_DIR" && ! -f "$REFERENCE_BASE_IN" ]]; then
  echo "Missing badge reference base file: $REFERENCE_BASE_IN" >&2
  exit 1
fi

BASE_MASK="$OUTPUT_DIR/__base_mask.png"
RING_MASK="$OUTPUT_DIR/__ring_mask.png"
BASE_WORKING="$OUTPUT_DIR/__base_working.png"
BADGE_DIFF_MASK="$OUTPUT_DIR/__badge_diff_mask.png"
BADGE_DISC_MASK="$OUTPUT_DIR/__badge_disc_mask.png"
BADGE_CLIP_ALPHA_MASK="$OUTPUT_DIR/__badge_clip_alpha_mask.png"
BADGE_KNOCKOUT_MASK="$OUTPUT_DIR/__badge_knockout_mask.png"
BADGE_GLYPH_MASK="$OUTPUT_DIR/__badge_glyph_mask.png"
BADGE_REFERENCE_LAYER="$OUTPUT_DIR/__badge_reference_layer.png"
BADGE_COLORED="$OUTPUT_DIR/__badge_colored.png"
BASE_PUNCHED="$OUTPUT_DIR/__base_punched.png"

cleanup() {
  rm -f \
    "$BASE_MASK" \
    "$RING_MASK" \
    "$BASE_WORKING" \
    "$BADGE_DIFF_MASK" \
    "$BADGE_DISC_MASK" \
    "$BADGE_CLIP_ALPHA_MASK" \
    "$BADGE_KNOCKOUT_MASK" \
    "$BADGE_GLYPH_MASK" \
    "$BADGE_REFERENCE_LAYER" \
    "$BADGE_COLORED" \
    "$BASE_PUNCHED"
}
trap cleanup EXIT

get_size() {
  magick identify -format '%wx%h' "$1"
}

is_dot_state() {
  case "$1" in
    connecting|snoozed)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
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

  parse_bbox "$bbox"

  local max_dim="$BBOX_W"
  if (( BBOX_H > max_dim )); then
    max_dim="$BBOX_H"
  fi

  BADGE_RADIUS=$(( (max_dim + 1) / 2 ))
  BADGE_KNOCKOUT_RADIUS=$(( BADGE_RADIUS + BADGE_PADDING_PX ))
  BADGE_CX=$(( BBOX_X + BBOX_W / 2 ))
  BADGE_CY=$(( BBOX_Y + BBOX_H / 2 ))
}

prepare_base() {
  if [[ "$BASE_STYLE" == "outline" ]]; then
    echo "Creating outline base..."
    magick "$BASE_IN" \
      -alpha extract \
      -threshold 0 \
      "$BASE_MASK"

    magick "$BASE_MASK" \
      -morphology EdgeOut Octagon:"$OUTLINE_PX" \
      -threshold 0 \
      "$RING_MASK"

    magick "$RING_MASK" \
      -fill "$WHITE" -opaque white \
      -transparent black \
      -colorspace sRGB \
      PNG32:"$BASE_WORKING"
  else
    echo "Using original base..."
    cp "$BASE_IN" "$BASE_WORKING"
  fi
}

make_plain_copy() {
  local outfile="$1"
  cp "$BASE_WORKING" "$outfile"
  echo "Wrote: $outfile"
}

make_badged() {
  local state_name="$1"
  local infile="$2"
  local outfile="$3"
  local color="$4"
  local reference_in="$5"
  local canvas_size
  local bbox
  local geometry_in="$infile"
  local geometry_base="$BASE_IN"
  local badge_padding_px="$BADGE_PADDING_PX"
  local badge_knockout_radius
  local dot_radius=$(( DOT_DIAMETER_PX / 2 ))

  if [[ ! -f "$infile" ]]; then
    echo "Skipping missing file: $infile"
    return 0
  fi

  canvas_size="$(get_size "$infile")"

  if [[ -n "$BADGE_REFERENCE_DIR" && -f "$reference_in" ]]; then
    geometry_in="$reference_in"
    geometry_base="$REFERENCE_BASE_IN"
  fi

  magick "$geometry_in" "$geometry_base" \
    -alpha off \
    -compose Difference -composite \
    -colorspace Gray \
    -threshold "${BADGE_DIFF_THRESHOLD}%" \
    "$BADGE_DIFF_MASK"

  bbox="$(magick "$BADGE_DIFF_MASK" -trim -format '%wx%h%O' info:)"
  badge_geometry "$bbox"

  if [[ "$THEME_VARIANT" == "light" ]] && ! is_dot_state "$state_name"; then
    badge_padding_px="$LIGHT_BADGE_PADDING_PX"
  fi
  badge_knockout_radius=$(( BADGE_RADIUS + badge_padding_px ))

  magick -size "$canvas_size" xc:black \
    -fill white \
    -draw "circle $BADGE_CX,$BADGE_CY $BADGE_CX,$((BADGE_CY - BADGE_RADIUS))" \
    "$BADGE_DISC_MASK"

  magick -size "$canvas_size" xc:none \
    -fill white \
    -draw "circle $BADGE_CX,$BADGE_CY $BADGE_CX,$((BADGE_CY - BADGE_RADIUS))" \
    PNG32:"$BADGE_CLIP_ALPHA_MASK"

  magick -size "$canvas_size" xc:none \
    -fill white \
    -draw "circle $BADGE_CX,$BADGE_CY $BADGE_CX,$((BADGE_CY - badge_knockout_radius))" \
    PNG32:"$BADGE_KNOCKOUT_MASK"

  magick "$BASE_WORKING" "$BADGE_KNOCKOUT_MASK" \
    -compose DstOut -composite \
    PNG32:"$BASE_PUNCHED"

  if is_dot_state "$state_name"; then
    magick -size "$canvas_size" xc:none \
      -fill "$color" \
      -draw "circle $BADGE_CX,$BADGE_CY $BADGE_CX,$((BADGE_CY - dot_radius))" \
      -colorspace sRGB \
      PNG32:"$BADGE_COLORED"
  elif [[ -n "$BADGE_REFERENCE_DIR" && -f "$reference_in" ]]; then
    magick "$reference_in" "$BADGE_CLIP_ALPHA_MASK" \
      -compose DstIn -composite \
      PNG32:"$BADGE_REFERENCE_LAYER"

    if [[ "$STATUS_STYLE" == "colored" ]]; then
      cp "$BADGE_REFERENCE_LAYER" "$BADGE_COLORED"
    else
      magick "$BADGE_REFERENCE_LAYER" \
        -channel RGB -fill "$color" -colorize 100 +channel \
        PNG32:"$BADGE_COLORED"
    fi
  else
    magick "$infile" "$BADGE_DISC_MASK" \
      -alpha off \
      -compose Multiply -composite \
      -colorspace Gray \
      -negate \
      -threshold "${BADGE_ICON_THRESHOLD}%" \
      "$BADGE_GLYPH_MASK"

    magick "$BADGE_GLYPH_MASK" \
      -colorspace sRGB \
      -fill "$color" -opaque white \
      -transparent black \
      PNG32:"$BADGE_COLORED"
  fi

  magick "$BASE_PUNCHED" "$BADGE_COLORED" \
    -compose Over -composite \
    -colorspace sRGB \
    PNG32:"$outfile"

  echo "Wrote: $outfile"
}

echo "Generating $THEME_VARIANT / $STATUS_STYLE with base style $BASE_STYLE..."
prepare_base

make_plain_copy "$OUTPUT_DIR/$BASE_FILE"

make_badged \
  "snoozed" \
  "$INPUT_DIR/$SNOOZED_FILE" \
  "$OUTPUT_DIR/$SNOOZED_FILE" \
  "$SNOOZE" \
  "$BADGE_REFERENCE_DIR/${REFERENCE_PREFIX}-snoozed.png"

make_badged \
  "connected" \
  "$INPUT_DIR/$CONNECTED_FILE" \
  "$OUTPUT_DIR/$CONNECTED_FILE" \
  "$GREEN" \
  "$BADGE_REFERENCE_DIR/${REFERENCE_PREFIX}-connected.png"

make_badged \
  "connecting" \
  "$INPUT_DIR/$CONNECTING_FILE" \
  "$OUTPUT_DIR/$CONNECTING_FILE" \
  "$YELLOW" \
  "$BADGE_REFERENCE_DIR/${REFERENCE_PREFIX}-connecting.png"

make_badged \
  "disconnecting" \
  "$INPUT_DIR/$DISCONNECTING_FILE" \
  "$OUTPUT_DIR/$DISCONNECTING_FILE" \
  "$YELLOW" \
  "$BADGE_REFERENCE_DIR/${REFERENCE_PREFIX}-disconnecting.png"

make_badged \
  "alert" \
  "$INPUT_DIR/$ALERT_FILE" \
  "$OUTPUT_DIR/$ALERT_FILE" \
  "$RED" \
  "$BADGE_REFERENCE_DIR/${REFERENCE_PREFIX}-alert.png"

echo
echo "Done."
echo "Output directory: $OUTPUT_DIR"
