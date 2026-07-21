#!/usr/bin/env bash
# Renders a MIDI file to a single ADPCM-encoded .wav via fluidsynth + ffmpeg
# -- offline preprocessing for source/scripts/utilities/MusicPlayer.lua,
# which streams the pre-rendered file far more cheaply than a live
# playdate.sound.synth-per-note approach (see Inside Playdate section 7.28:
# "ADPCM is the ideal audio format to use for Playdate games"). One file per
# song, not split into pieces -- fileplayer streams from flash rather than
# loading the whole file into memory, so a full-length file is still cheap
# to open, and it lets fileplayer loop the song natively (repeatCount 0)
# instead of MusicPlayer reloading a new piece every ~60s, which caused an
# audible stutter at every piece boundary (see git history for that
# approach). pdc auto-compiles any .wav dropped under source/assets into
# .pda at build time. The render is peak-normalized (see TARGET_PEAK_DB
# below) since fluidsynth's default gain gets nowhere near 0dBFS and
# otherwise plays back too quiet on device.
#
# Usage: tools/render-song.sh [--piano | --program N] <input.mid> [output.wav]
#   e.g. tools/render-song.sh "art-src/music/Mozart.mid" "source/assets/songs/Mozart.wav"
#        -> using each track's own instrument
#   e.g. tools/render-song.sh --piano "art-src/music/Mozart.mid" "source/assets/songs/Mozart.wav"
#        -> same, but every track (except the GM percussion channel) is
#           forced to program 0 (Acoustic Grand Piano) via
#           midi_force_program.py before rendering
#
# Requires fluidsynth and ffmpeg on PATH, and a General MIDI soundfont --
# defaults to /usr/share/sounds/sf2/default-GM.sf2 (Debian/Ubuntu's
# fluid-soundfont-gm package), override with the SOUNDFONT env var. The GM
# soundfont's instruments won't match the in-game sound of any other
# procedurally synthesized parts of the game -- this is meant as a starting
# point / proof of concept, not a drop-in tonal match. --piano/--program
# also need python3 on PATH.
set -euo pipefail

PROGRAM=""
ARGS=()
while [ $# -gt 0 ]; do
	case "$1" in
		--piano) PROGRAM=0; shift ;;
		--program) PROGRAM="$2"; shift 2 ;;
		*) ARGS+=("$1"); shift ;;
	esac
done
set -- "${ARGS[@]}"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	echo "Usage: $0 [--piano | --program N] <input.mid> [output.wav]" >&2
	echo "  e.g. $0 \"art-src/music/Mozart.mid\" \"source/assets/songs/Mozart.wav\"" >&2
	echo "  e.g. $0 --piano \"art-src/music/Mozart.mid\" \"source/assets/songs/Mozart.wav\"" >&2
	exit 1
fi

for cmd in fluidsynth ffmpeg; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Error: $cmd not found on PATH -- install it first (e.g. apt install fluidsynth ffmpeg)" >&2
		exit 1
	fi
done

if [ -n "$PROGRAM" ] && ! command -v python3 >/dev/null 2>&1; then
	echo "Error: --piano/--program needs python3 on PATH" >&2
	exit 1
fi

SOUNDFONT="${SOUNDFONT:-/usr/share/sounds/sf2/default-GM.sf2}"
if [ ! -f "$SOUNDFONT" ]; then
	echo "Error: soundfont not found at $SOUNDFONT -- install one (e.g. apt install fluid-soundfont-gm) or set SOUNDFONT=/path/to/font.sf2" >&2
	exit 1
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
	echo "Error: $INPUT not found" >&2
	exit 1
fi

OUTPUT="${2:-${INPUT%.*}.wav}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TMP_RAW="$(mktemp --suffix=.wav)"
TMP_MID=""
trap 'rm -f "$TMP_RAW" "$TMP_MID"' EXIT

SYNTH_INPUT="$INPUT"
if [ -n "$PROGRAM" ]; then
	TMP_MID="$(mktemp --suffix=.mid)"
	echo "==> Forcing every track to GM program $PROGRAM"
	python3 "$ROOT/tools/midi_force_program.py" "$INPUT" "$TMP_MID" "$PROGRAM"
	SYNTH_INPUT="$TMP_MID"
fi

echo "==> Synthesizing $INPUT with $SOUNDFONT"
fluidsynth -ni "$SOUNDFONT" "$SYNTH_INPUT" -F "$TMP_RAW" -r 44100

# fluidsynth's default synth.gain (0.2) renders well below 0dBFS -- normalize
# the peak up to TARGET_PEAK_DB so songs are consistently loud on device
# instead of however quiet a given soundfont/MIDI happens to synthesize.
# Measured via a volumedetect pass rather than a fixed multiplier so this
# adapts per song (and turns a rare already-hot render back down instead of
# clipping it).
TARGET_PEAK_DB="-1.0"
MAX_VOLUME="$(ffmpeg -hide_banner -i "$TMP_RAW" -af volumedetect -f null - 2>&1 | grep "max_volume:" | awk '{print $5}')"
GAIN_DB="$(awk -v target="$TARGET_PEAK_DB" -v max="$MAX_VOLUME" 'BEGIN { print target - max }')"
echo "==> Normalizing: peak is ${MAX_VOLUME}dB, applying ${GAIN_DB}dB gain to reach ${TARGET_PEAK_DB}dB"

echo "==> Encoding to ADPCM (44100Hz) -> $OUTPUT"
mkdir -p "$(dirname "$OUTPUT")"
ffmpeg -y -loglevel error -i "$TMP_RAW" -af "volume=${GAIN_DB}dB" -ar 44100 -acodec adpcm_ima_wav "$OUTPUT"

echo "==> Wrote $OUTPUT"
