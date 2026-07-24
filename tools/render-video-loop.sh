#!/usr/bin/env bash
# Converts a video (e.g. art-src/title-hero.mp4) into a matrix imagetable PNG
# under source/assets/images/ -- a single sprite-sheet image pdc slices into
# a playdate.graphics.imagetable at compile time, for looping playback via
# playdate.graphics.animation.loop. See "Playing it back" below for the
# runtime side.
#
# Why a matrix imagetable (one grid PNG) instead of one file per frame (the
# SDK's other imagetable convention, `name-table-1.png`, `name-table-2.png`,
# ...): pdc compiles a matrix sheet as a single asset, so there's one file to
# decode at load time and the frames sit contiguously in memory -- friendlier
# to the Playdate's limited RAM/flash and load time than N separate small
# assets for the same frame count. `playdate.graphics.imagetable.new(path)`
# infers the grid from the filename: `<name>-table-<cellWidth>-<cellHeight>.png`
# gives the size of ONE frame; pdc divides the sheet's total pixel dimensions
# by that to find the column/row count, so WIDTH/HEIGHT below are a single
# frame's size, not the whole sheet's.
#
# Performance knobs (all configurable, see Usage) -- an imagetable's frames
# are decompressed to 1bpp bitmaps in RAM at load (not streamed like
# MusicPlayer's fileplayer), so cost scales directly with frame count *
# WIDTH*HEIGHT: roughly ceil(WIDTH/8)*HEIGHT bytes/frame once pdc dithers to
# 1-bit. The defaults below (400x240, 10fps, 40 frames) land around 470KB --
# comfortable on the Playdate's ~16MB usable RAM, but shrink WIDTH/HEIGHT/
# MAX_FRAMES/FPS further for anything meant to run alongside a full game
# scene rather than a title-screen-style standalone loop.
#
# Frames are scaled to fill WIDTH x HEIGHT exactly (scale+crop, same
# "increase, then crop" fill as tools/render-title-hero.sh's hero image) and
# left in 8-bit color for pdc to dither at compile time, same as
# title-hero.png -- see that script's header for why pre-dithering an
# oversized image is worse than letting pdc dither the final on-screen size.
#
# --transparent: for a source video that (like art-src/blue_whale.png/
# sea_serpent_head.png) bakes a fake light-gray/white transparency checker
# into the RGB pixels themselves instead of carrying a real alpha channel --
# `identify -verbose` on such a source shows alpha=1 (fully opaque) across
# the whole frame. Plain color-keying can't strip that: the checker cells
# aren't a clean two-color pattern and the art's own white areas are
# color-indistinguishable from background cells. So this flag switches the
# pipeline from one ffmpeg tile call to: extract each sampled frame as its
# own PNG, run tools/render-blue-whale.sh's flood-fill-from-all-four-corners
# treatment on each (a connected-region fill can't leak past the art's solid
# outline into same-colored interior pixels), then `montage` them into the
# same grid layout with real per-frame alpha preserved. No -trim/-rotate step
# like that script's static-sprite case -- every cell must stay the same
# WIDTHxHEIGHT canvas for the imagetable slicer. Needs ImageMagick
# (`convert`/`montage`) in addition to ffmpeg/ffprobe.
#
# Usage: tools/render-video-loop.sh <input video> [name] [options]
#   name defaults to <input>'s basename without extension.
#   --fps N            frames sampled per second of source video (default 10)
#   --width N          px width of one frame (default 400)
#   --height N         px height of one frame (default 240)
#   --max-frames N     cap on total frames, trims from the start of the clip (default 40)
#   --columns N        grid columns in the output sheet; rows = ceil(frames/columns) (default 8)
#   --transparent [F]  strip the source's baked-in checker to real alpha via a
#                       flood fill from each frame's 4 corners, fuzz F percent
#                       tolerance (default 30)
#
#   e.g. tools/render-video-loop.sh art-src/title-hero.mp4
#        -> source/assets/images/title-hero-table-400-240.png
#   e.g. tools/render-video-loop.sh art-src/title-hero.mp4 title-hero-bg --width 200 --height 120 --fps 8 --max-frames 24
#        -> source/assets/images/title-hero-bg-table-200-120.png
#
# Playing it back (once compiled into the .pdx, e.g. in a scene's :enter()):
#   local imageTable = playdate.graphics.imagetable.new("assets/images/<name>")
#   assert(imageTable, "missing assets/images/<name>")
#   local loop = playdate.graphics.animation.loop.new(1000 / FPS, imageTable, true)
#   -- then in :update()/:draw(): loop:draw(x, y)
# animation.loop tracks elapsed time and picks the right frame internally --
# no per-frame Lua bookkeeping needed, so :draw() is the whole per-frame cost.
# (A caller that needs to pick/rotate frames itself, e.g. to sync playback to
# game state or draw via image:drawRotated, can instead index the imagetable
# directly with imageTable:getImage(n) -- see EnemyBlueWhale.lua.)
#
# Requires ffmpeg and ffprobe on PATH (plus ImageMagick for --transparent).
set -euo pipefail

FPS=10
WIDTH=400
HEIGHT=240
MAX_FRAMES=40
COLUMNS=8
TRANSPARENT=0
FUZZ=30

usage() {
	echo "Usage: $0 <input video> [name] [--fps N] [--width N] [--height N] [--max-frames N] [--columns N] [--transparent [fuzz%]]" >&2
	exit 1
}

INPUT=""
NAME=""
while [ $# -gt 0 ]; do
	case "$1" in
	--fps)
		FPS="$2"
		shift 2
		;;
	--width)
		WIDTH="$2"
		shift 2
		;;
	--height)
		HEIGHT="$2"
		shift 2
		;;
	--max-frames)
		MAX_FRAMES="$2"
		shift 2
		;;
	--columns)
		COLUMNS="$2"
		shift 2
		;;
	--transparent)
		TRANSPARENT=1
		if [ $# -ge 2 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
			FUZZ="$2"
			shift 2
		else
			shift 1
		fi
		;;
	-h | --help)
		usage
		;;
	-*)
		echo "Error: unknown option $1" >&2
		usage
		;;
	*)
		if [ -z "$INPUT" ]; then
			INPUT="$1"
		elif [ -z "$NAME" ]; then
			NAME="$1"
		else
			usage
		fi
		shift
		;;
	esac
done

[ -n "$INPUT" ] || usage

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
	echo "Error: ffmpeg/ffprobe not found on PATH -- install them first (e.g. apt install ffmpeg)" >&2
	exit 1
fi

if [ "$TRANSPARENT" -eq 1 ] && { ! command -v convert >/dev/null 2>&1 || ! command -v montage >/dev/null 2>&1; }; then
	echo "Error: ImageMagick's convert/montage not found on PATH -- install it first (e.g. apt install imagemagick)" >&2
	exit 1
fi

if [ ! -f "$INPUT" ]; then
	echo "Error: $INPUT not found" >&2
	exit 1
fi

if [ -z "$NAME" ]; then
	NAME="$(basename "$INPUT")"
	NAME="${NAME%.*}"
fi

OUTPUT="source/assets/images/${NAME}-table-${WIDTH}-${HEIGHT}.png"

DURATION="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")"
AVAILABLE_FRAMES="$(awk -v d="$DURATION" -v f="$FPS" 'BEGIN { n = int(d * f); print (n < 1) ? 1 : n }')"
FRAME_COUNT=$((AVAILABLE_FRAMES < MAX_FRAMES ? AVAILABLE_FRAMES : MAX_FRAMES))
COLUMNS=$((COLUMNS < FRAME_COUNT ? COLUMNS : FRAME_COUNT))
ROWS=$(((FRAME_COUNT + COLUMNS - 1) / COLUMNS))

mkdir -p "$(dirname "$OUTPUT")"

if [ "$TRANSPARENT" -eq 1 ]; then
	TMPDIR="$(mktemp -d)"
	trap 'rm -rf "$TMPDIR"' EXIT

	ffmpeg -y -loglevel error -i "$INPUT" \
		-vf "fps=${FPS},scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase,crop=${WIDTH}:${HEIGHT}" \
		-frames:v "$FRAME_COUNT" \
		"$TMPDIR/frame%04d.png"

	for f in "$TMPDIR"/frame*.png; do
		convert "$f" -alpha on -fuzz "${FUZZ}%" -fill none \
			-draw "color 0,0 floodfill" \
			-draw "color $((WIDTH - 1)),0 floodfill" \
			-draw "color 0,$((HEIGHT - 1)) floodfill" \
			-draw "color $((WIDTH - 1)),$((HEIGHT - 1)) floodfill" \
			"$f"
	done

	montage "$TMPDIR"/frame*.png -tile "${COLUMNS}x${ROWS}" -geometry "${WIDTH}x${HEIGHT}+0+0" -background none "$OUTPUT"

	rm -rf "$TMPDIR"
	trap - EXIT
else
	ffmpeg -y -loglevel error -i "$INPUT" \
		-vf "fps=${FPS},scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase,crop=${WIDTH}:${HEIGHT},tile=${COLUMNS}x${ROWS}" \
		-frames:v 1 \
		"$OUTPUT"
fi

CELL_BYTES=$(((WIDTH + 7) / 8 * HEIGHT))
TOTAL_KB=$((CELL_BYTES * FRAME_COUNT / 1024))

echo "==> $INPUT -> $OUTPUT"
echo "    ${FRAME_COUNT} frames (${COLUMNS}x${ROWS} grid) at ${WIDTH}x${HEIGHT}, ${FPS}fps -- ~${TOTAL_KB}KB once pdc dithers to 1bpp"
echo "    load with: playdate.graphics.imagetable.new(\"assets/images/${NAME}\")"
