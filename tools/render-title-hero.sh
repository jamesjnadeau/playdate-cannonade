#!/usr/bin/env bash
# Derives every in-repo asset that comes from the hi-res art-src/title-hero.png
# source art:
#
#  - source/assets/images/title-hero.png -- the 400x240 full-screen splash
#    TitleScene.lua draws behind the title menu (see that file's header for
#    why the resize happens here rather than at runtime: pdc's 1-bit
#    dithering shouldn't run against an oversized image). Left in 8-bit
#    color for pdc to dither at compile time, same as other in-game art.
#
#  - source/assets/launcher/card.png and icon.png -- the Playdate system
#    launcher's game-card (350x155) and icon (32x32) images, per pdxinfo's
#    `imagePath=assets/launcher` and the Playdate SDK's launcher-image spec.
#    Unlike the in-game splash these are pre-dithered to actual 1-bit here
#    (the launcher doesn't run assets through pdc's own dither step), which
#    matches how they're already checked in.
#
#  - source/assets/launcher/card-highlighted/{1,2}.png -- the two-frame
#    lightning-flash highlight animation shown when the game is selected in
#    the launcher (timing lives in that folder's animation.txt, which this
#    script doesn't touch). Frame 1 is identical to card.png; frame 2 is
#    card.png with its colors fully inverted -- confirmed by diffing the
#    committed files (`convert card.png -negate` exactly matches 2.png), not
#    just visual similarity.
#
# card.png/icon.png are curated crops of the source art (Poseidon+trident+
# boat for the card, just the trident for the icon), not simple scales of
# the whole image -- their regions are fixed fractions of the source
# art-src/title-hero.png's dimensions, set below by comparing crops of the
# current art against the previously-committed launcher images. If a
# replacement source image frames the scene very differently, re-tune
# CARD_CROP/ICON_CROP to match.
#
# Usage: tools/render-title-hero.sh [input.png]
#   e.g. tools/render-title-hero.sh
#        -> art-src/title-hero.png -> source/assets/images/title-hero.png
#                                  -> source/assets/launcher/card.png
#                                  -> source/assets/launcher/icon.png
#                                  -> source/assets/launcher/card-highlighted/{1,2}.png
#
# Requires ffmpeg on PATH.
set -euo pipefail

if [ $# -gt 1 ]; then
	echo "Usage: $0 [input.png]" >&2
	exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
	echo "Error: ffmpeg not found on PATH -- install it first (e.g. apt install ffmpeg)" >&2
	exit 1
fi

INPUT="${1:-art-src/title-hero.png}"
if [ ! -f "$INPUT" ]; then
	echo "Error: $INPUT not found" >&2
	exit 1
fi

HERO_OUTPUT="source/assets/images/title-hero.png"
LAUNCHER_DIR="source/assets/launcher"
CARD_OUTPUT="$LAUNCHER_DIR/card.png"
ICON_OUTPUT="$LAUNCHER_DIR/icon.png"
HIGHLIGHT_DIR="$LAUNCHER_DIR/card-highlighted"

# Fractions of the source image's width/height (top-left origin), tuned
# against the framing of the previously-committed launcher art -- see header.
CARD_CROP="iw*1.0:ih*0.73828:iw*0.0:ih*0.18880"
ICON_CROP="iw*0.25:ih*0.41667:iw*0.296875:ih*0.234375"

mkdir -p "$(dirname "$HERO_OUTPUT")" "$HIGHLIGHT_DIR"

ffmpeg -y -loglevel error -i "$INPUT" \
	-vf "scale=400:240:force_original_aspect_ratio=increase,crop=400:240" \
	"$HERO_OUTPUT"
echo "==> $INPUT -> $HERO_OUTPUT (400x240)"

ffmpeg -y -loglevel error -i "$INPUT" \
	-vf "crop=$CARD_CROP,scale=350:155,format=gray" -pix_fmt monob \
	"$CARD_OUTPUT"
echo "==> $INPUT -> $CARD_OUTPUT (350x155, 1-bit)"

ffmpeg -y -loglevel error -i "$INPUT" \
	-vf "crop=$ICON_CROP,scale=32:32,format=gray" -pix_fmt monob \
	"$ICON_OUTPUT"
echo "==> $INPUT -> $ICON_OUTPUT (32x32, 1-bit)"

cp "$CARD_OUTPUT" "$HIGHLIGHT_DIR/1.png"
ffmpeg -y -loglevel error -i "$CARD_OUTPUT" -vf "negate" -pix_fmt monob "$HIGHLIGHT_DIR/2.png"
echo "==> $CARD_OUTPUT -> $HIGHLIGHT_DIR/{1,2}.png (flash animation frames)"
