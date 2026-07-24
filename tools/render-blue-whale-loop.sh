#!/usr/bin/env bash
# Renders art-src/blue-whale.mp4 (a breach animation: rises with a growing
# splash ring, peaks fully emerged at exactly 2.0s in, then sinks back down
# as the ring fades out over the rest of the ~5.03s clip) into the sprite-
# sheet imagetable EnemyBlueWhale.lua plays during its "breaching"/
# "surfaced"/"diving" states -- a thin wrapper around
# tools/render-video-loop.sh with the params pinned to what
# EnemyBlueWhale.lua actually expects, same idea as
# tools/render-title-hero-loop.sh for TitleScene.lua.
#
# Params that matter most:
#   --fps 10        EnemyBlueWhale.lua's WHALE_LOOP_FPS local must match --
#                    it's how frame indices are derived from state timers.
#                    Also gives an exact frame boundary at the 2.0s pause
#                    point (frame 21, 1-based), which
#                    Config.ENEMY_BLUE_WHALE_BREACH_TIME (2.0s) assumes.
#   --transparent    art-src/blue-whale.mp4 bakes the same fake checkerboard
#                    transparency as art-src/blue_whale.png -- see
#                    render-video-loop.sh's --transparent header comment.
#   --width/--height 160x160  square, matching the source's 608x608 aspect
#                    (clean scale-down, no crop loss); sized to comfortably
#                    contain the splash ring against
#                    Config.ENEMY_BLUE_WHALE_ATTACK_RADIUS's 140px diameter.
#   --max-frames 50  covers the full ~5.03s clip at 10fps (int(5.033*10)=50)
#                    so the sinking tail isn't truncated.
# NAME is pinned to "blue-whale-loop" since that's the literal string
# EnemyBlueWhale.lua passes to gfx.imagetable.new. If any of these change,
# update EnemyBlueWhale.lua (WHALE_LOOP_FPS) and
# Config.ENEMY_BLUE_WHALE_BREACH_TIME/DIVE_TIME to match.
#
# Usage: tools/render-blue-whale-loop.sh [input.mp4]
#   e.g. tools/render-blue-whale-loop.sh
#        -> art-src/blue-whale.mp4 -> source/assets/images/blue-whale-loop-table-160-160.png
#
# Requires ffmpeg/ffprobe and ImageMagick (see tools/render-video-loop.sh).
set -euo pipefail

if [ $# -gt 1 ]; then
	echo "Usage: $0 [input.mp4]" >&2
	exit 1
fi

INPUT="${1:-art-src/blue-whale.mp4}"
if [ ! -f "$INPUT" ]; then
	echo "Error: $INPUT not found" >&2
	exit 1
fi

NAME="blue-whale-loop"
FPS=10
WIDTH=160
HEIGHT=160
MAX_FRAMES=50
COLUMNS=10

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/render-video-loop.sh" "$INPUT" "$NAME" \
	--fps "$FPS" --width "$WIDTH" --height "$HEIGHT" \
	--max-frames "$MAX_FRAMES" --columns "$COLUMNS" \
	--transparent
