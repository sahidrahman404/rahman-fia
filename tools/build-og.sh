#!/usr/bin/env bash
#
# Renders tools/og-card.html into assets/img/og-cover.jpg, the 1200x630 image
# chat apps and timelines show when the invitation is shared.
#
#   ./tools/build-og.sh
#
# Re-run it whenever the date, venue, names or artwork change, then commit the
# regenerated jpg — the deployed card is the file, not the template.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
card="$root/tools/og-card.html"
out="$root/assets/img/og-cover.jpg"

# Rendered at 2x and downsampled, so the script type keeps its edges.
width=1200
height=630
quality=84

# Past this, WhatsApp quietly drops the image and shows a text-only preview.
max_bytes=300000

die() { printf 'build-og: %s\n' "$1" >&2; exit 1; }

chrome=""
for c in google-chrome-stable google-chrome chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then chrome=$c; break; fi
done
[ -n "$chrome" ] || die "need Chrome or Chromium on PATH to render the card"

if command -v magick >/dev/null 2>&1; then im=(magick)
elif command -v convert >/dev/null 2>&1; then im=(convert)
else die "need ImageMagick (magick or convert) to encode the jpg"
fi

shot=$(mktemp -t og-render.XXXXXX.png)
trap 'rm -f "$shot"' EXIT

# --virtual-time-budget lets the webfonts and SVGs finish before the capture;
# without it the card can screenshot mid-load with fallback type.
"$chrome" \
  --headless \
  --disable-gpu \
  --no-sandbox \
  --hide-scrollbars \
  --force-device-scale-factor=2 \
  --window-size="$width,$height" \
  --virtual-time-budget=6000 \
  --screenshot="$shot" \
  "file://$card" >/dev/null 2>&1

[ -s "$shot" ] || die "Chrome produced no screenshot"

# -strip drops the colour profile and metadata; a scraper never reads them and
# they are pure weight. 4:2:0 is safe here — no fine detail sits on a hard edge.
"${im[@]}" "$shot" \
  -resize "${width}x${height}" \
  -filter Lanczos \
  -background '#FDFAE0' -alpha remove -alpha off \
  -sampling-factor 4:2:0 \
  -strip \
  -interlace JPEG \
  -quality "$quality" \
  "$out"

# The trailing newline matters: without it `read` returns non-zero on EOF even
# though it assigned every variable, and set -e would kill the script here.
read -r w h bytes < <("${im[@]}" identify -format '%w %h %B\n' "$out")

[ "$w" = "$width" ] && [ "$h" = "$height" ] \
  || die "expected ${width}x${height}, got ${w}x${h}"

printf 'build-og: wrote %s (%sx%s, %s bytes)\n' "${out#"$root"/}" "$w" "$h" "$bytes"

if [ "$bytes" -gt "$max_bytes" ]; then
  printf 'build-og: WARNING %s bytes is over the ~%s byte mark where WhatsApp\n' \
    "$bytes" "$max_bytes" >&2
  printf '          starts dropping previews. Lower quality= in this script.\n' >&2
fi
