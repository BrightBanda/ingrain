#!/usr/bin/env bash
# Renders every app icon from the SVGs in branding/.
#
# Needs ImageMagick built with librsvg (`magick -list format | grep RSVG`) and
# the Noto Sans CJK JP font installed, which draws 浸.
#
#   bash tool/generate_icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ART=branding/app_icon.svg
MONO=branding/app_icon_monochrome.svg
MARK=branding/app_icon_mark.svg
RES=android/app/src/main/res
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Rasterise each SVG once, large, on a transparent background.
render() { magick -background none -density 576 "$1" -resize 2048x2048 "$2"; }
render "$ART" "$TMP/art.png"
render "$MONO" "$TMP/mono.png"
render "$MARK" "$TMP/mark.png"

# The artwork at `scale` of a `size` canvas, centred, on `bg` (or transparent).
place() { # src size scale bg out
  local inner
  inner=$(python3 -c "print(round($2 * $3))")
  magick -size "$2x$2" "xc:$4" \( "$1" -resize "${inner}x${inner}" \) \
    -gravity center -composite "$5"
}

# White rounded square with the artwork: legacy launcher, Play Store, web.
tile() { # size out
  local r=$(( $1 * 22 / 100 ))
  magick -size "$1x$1" xc:none -fill white \
    -draw "roundrectangle 0,0,$(( $1 - 1 )),$(( $1 - 1 )),$r,$r" "$TMP/bg.png"
  magick "$TMP/bg.png" \( "$TMP/art.png" -resize "$(( $1 * 82 / 100 ))x" \) \
    -gravity center -composite "$2"
}

# Android: adaptive icon layers (108dp canvas; the art sits inside the safe
# zone so circle, squircle and teardrop masks never cut into it).
for density in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  name=${density%%:*}; factor=${density##*:}
  dir="$RES/mipmap-$name"; mkdir -p "$dir"
  layer=$(python3 -c "print(round(108 * $factor))")
  legacy=$(python3 -c "print(round(48 * $factor))")
  place "$TMP/art.png" "$layer" 0.556 none "$dir/ic_launcher_foreground.png"
  place "$TMP/mono.png" "$layer" 0.556 none "$dir/ic_launcher_monochrome.png"
  tile "$legacy" "$dir/ic_launcher.png"
done

# Play Store listing icon: 512×512, full square (Play rounds the corners).
mkdir -p branding/store
place "$TMP/art.png" 512 0.82 white branding/store/play_store_icon_512.png

# Web app.
tile 192 web/icons/Icon-192.png
tile 512 web/icons/Icon-512.png
# Maskable: full-bleed white, artwork inside the central 80% safe circle.
place "$TMP/art.png" 192 0.62 white web/icons/Icon-maskable-192.png
place "$TMP/art.png" 512 0.62 white web/icons/Icon-maskable-512.png
# Favicon: the simplified mark.
place "$TMP/mark.png" 64 0.94 none web/favicon.png

# In-app logos (AppLogo): the full icon and the simplified mark, transparent.
mkdir -p assets/branding
place "$TMP/art.png" 512 1 none assets/branding/logo.png
place "$TMP/mark.png" 256 1 none assets/branding/logo_mark.png

echo "Icons written to $RES, web/, assets/branding/ and branding/store/."
