#!/usr/bin/env bash
# Generates source/assets/images/sea-serpent-head.png, the sprite
# EnemySeaSerpent.lua draws instead of its old procedural triangle head.
#
# Same background-cleanup problem as tools/render-blue-whale.sh (see that
# script's header and CLAUDE.md's "Enemy body sprites and cleaning up AI-art
# source images" section): art-src/sea_serpent_head.png is fully opaque
# (alpha=1 everywhere) with a light-gray/white checkerboard baked into its
# RGB pixels instead of a real alpha channel, so this floods the background
# out from all four corners with a wide fuzz tolerance rather than
# chroma-keying by color -- a connected-region fill that can't leak past the
# art's solid black outline into the face even though some of the face's own
# shading pixels are coincidentally close in color to the checker cells.
#
# The source art is a front-on face (crown at the top of the frame, chin at
# the bottom), not a top-down "swimming direction" view like the whale --
# after trimming, this rotates it -90 (counterclockwise) so the chin points
# along local +x, this game's heading-0 convention (see Ship:drawBodyLocal /
# Utils.heading): a front-on face reads its chin/snout as its "front", the
# same role the old triangle's tip played.
#
# Unlike the whale (whose LENGTH/BEAM sizing was already close to the source
# art's aspect ratio), the old head triangle's box (HEAD_LENGTH forward x
# HEAD_WIDTH*2 wide, originally 24x48 -- wider than long) was nothing like
# this face art's real proportions (roughly 881x717, i.e. longer than wide
# once rotated) -- forcing the image into the old box's proportions squished
# it noticeably. Config.ENEMY_SEA_SERPENT_HEAD_WIDTH was shrunk (see
# ConfigEnemy.lua) to match the art's real proportions instead of distorting
# it -- this script reads HEAD_LENGTH/HEAD_WIDTH straight out of
# ConfigEnemy.lua (see OUTPUT_WIDTH/OUTPUT_HEIGHT below) rather than
# hardcoding a copy of them, so it stays in sync if those are retuned again.
#
# Usage: tools/render-sea-serpent-head.sh [input.png] [output.png]
#   e.g. tools/render-sea-serpent-head.sh
#        -> art-src/sea_serpent_head.png -> source/assets/images/sea-serpent-head.png
#           (sized to Config.ENEMY_SEA_SERPENT_HEAD_LENGTH x 2x HEAD_WIDTH)
#
# Requires ImageMagick (`convert`) and lua5.4 on PATH.
set -euo pipefail

if [ $# -gt 2 ]; then
	echo "Usage: $0 [input.png] [output.png]" >&2
	exit 1
fi

if ! command -v convert >/dev/null 2>&1; then
	echo "Error: ImageMagick's convert not found on PATH -- install it first (e.g. apt install imagemagick)" >&2
	exit 1
fi

if ! command -v lua5.4 >/dev/null 2>&1; then
	echo "Error: lua5.4 not found on PATH -- install it first (e.g. apt install lua5.4)" >&2
	exit 1
fi

INPUT="${1:-art-src/sea_serpent_head.png}"
OUTPUT="${2:-source/assets/images/sea-serpent-head.png}"
if [ ! -f "$INPUT" ]; then
	echo "Error: $INPUT not found" >&2
	exit 1
fi

# Config.ENEMY_SEA_SERPENT_HEAD_LENGTH x 2x Config.ENEMY_SEA_SERPENT_HEAD_WIDTH --
# read live out of ConfigEnemy.lua (via the same mock_playdate.lua stand-in
# tests/ loads it under) rather than duplicated as literals here, so this
# script can't silently drift out of sync with those Config values -- see
# header.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
read -r OUTPUT_WIDTH OUTPUT_HEIGHT <<<"$(cd "$REPO_ROOT" && lua5.4 -e '
	dofile("tests/support/mock_playdate.lua")
	dofile("source/scripts/config/ConfigEnemy.lua")
	print(Config.ENEMY_SEA_SERPENT_HEAD_LENGTH, Config.ENEMY_SEA_SERPENT_HEAD_WIDTH * 2)
')"

# Background flood-fill tolerance -- see header.
BACKGROUND_FUZZ=30%

mkdir -p "$(dirname "$OUTPUT")"

TMP="$(mktemp --suffix=.png)"
trap 'rm -f "$TMP"' EXIT

read -r IN_W IN_H <<<"$(identify -format "%w %h" "$INPUT")"

convert "$INPUT" -alpha on -fuzz "$BACKGROUND_FUZZ" -fill none \
	-draw "color 0,0 floodfill" \
	-draw "color $((IN_W - 1)),0 floodfill" \
	-draw "color 0,$((IN_H - 1)) floodfill" \
	-draw "color $((IN_W - 1)),$((IN_H - 1)) floodfill" \
	-trim +repage \
	-rotate -90 +repage \
	-filter Lanczos -resize "${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}!" \
	"$TMP"
mv "$TMP" "$OUTPUT"
trap - EXIT

echo "==> $INPUT -> $OUTPUT (${OUTPUT_WIDTH}x${OUTPUT_HEIGHT})"
