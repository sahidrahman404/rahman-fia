#!/usr/bin/env bash
#
# Builds the site icons, end to end:
#
#   tools/make-icon-svgs.py  derives assets/svg/icon.svg (whole animal) and
#                            assets/svg/icon-tab.svg (head crop) from the art
#   favicon.ico              48 from the full mark, 32 and 16 from the crop
#   apple-touch-icon.png     180x180 opaque, from the full mark
#
#   ./tools/build-icons.sh
#
# The two bitmaps live at the site root because browsers and iOS request those
# paths by name even when no <link> points at them.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

die() { printf 'build-icons: %s\n' "$1" >&2; exit 1; }

chrome=""
for c in google-chrome-stable google-chrome chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then chrome=$c; break; fi
done
[ -n "$chrome" ] || die "need Chrome or Chromium on PATH to render the icons"

if command -v magick >/dev/null 2>&1; then im=(magick)
elif command -v convert >/dev/null 2>&1; then im=(convert)
else die "need ImageMagick (magick or convert) to write the ico"
fi

command -v python3 >/dev/null 2>&1 || die "need python3 to derive the icon SVGs"
python3 "$root/tools/make-icon-svgs.py"

work=$(mktemp -d -t icons.XXXXXX)
trap 'rm -rf "$work"' EXIT

# Rendered at 512 and downsampled, rather than rasterising the SVG at each
# size — Chrome antialiases the curves better than a nearest-size resize does.
render() {
  "$chrome" \
    --headless \
    --disable-gpu \
    --no-sandbox \
    --hide-scrollbars \
    --window-size=512,512 \
    --virtual-time-budget=4000 \
    --screenshot="$2" \
    "file://$1" >/dev/null 2>&1
  [ -s "$2" ] || die "Chrome produced no render for $1"
}

render "$root/assets/svg/icon.svg"     "$work/full.png"
render "$root/assets/svg/icon-tab.svg" "$work/tab.png"

# iOS composites any alpha against black, so the touch icon is flattened onto
# the cream ground rather than shipped with a transparent edge.
"${im[@]}" "$work/full.png" \
  -resize 180x180 -filter Lanczos \
  -background '#FDFAE0' -alpha remove -alpha off -strip \
  "$root/apple-touch-icon.png"

# 48 keeps the whole animal; 32 and 16 switch to the head, where the same
# pixels buy a readable face instead of a grey smudge.
"${im[@]}" "$work/full.png" -resize 48x48 -filter Lanczos "$work/48.png"
"${im[@]}" "$work/tab.png"  -resize 32x32 -filter Lanczos "$work/32.png"
"${im[@]}" "$work/tab.png"  -resize 16x16 -filter Lanczos "$work/16.png"

# Listed largest first; the .ico carries all three and the browser chooses.
"${im[@]}" "$work/48.png" "$work/32.png" "$work/16.png" \
  -background '#FDFAE0' -alpha remove -alpha off -strip \
  "$root/favicon.ico"

entries=$("${im[@]}" identify -format '%wx%h ' "$root/favicon.ico")
read -r w h bytes < <("${im[@]}" identify -format '%w %h %B\n' "$root/apple-touch-icon.png" | head -1)

printf 'build-icons: wrote favicon.ico            (%s)\n' "${entries% }"
printf 'build-icons: wrote apple-touch-icon.png   (%sx%s, %s bytes)\n' "$w" "$h" "$bytes"
