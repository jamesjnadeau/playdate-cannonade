#!/usr/bin/env bash
# Fetches the two external dependencies into source/libraries/ if they aren't
# already present. Safe to run repeatedly. Used both locally and in CI so the
# build works whether or not you set up the git submodule.
set -euo pipefail

NOBLE_REF="${NOBLE_REF:-main}"          # branch or tag of NobleEngine to use
PARTICLES_REF="${PARTICLES_REF:-main}"  # branch/tag of pdParticles to use

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/source/libraries"
mkdir -p "$LIB"

if [ ! -f "$LIB/noble/Noble.lua" ]; then
	echo "==> Fetching Noble Engine ($NOBLE_REF)"
	rm -rf "$LIB/noble"
	git clone --depth 1 --branch "$NOBLE_REF" \
		https://github.com/NobleRobot/NobleEngine.git "$LIB/noble"
else
	echo "==> Noble Engine already present"
fi

if [ ! -f "$LIB/pdParticles.lua" ]; then
	echo "==> Fetching pdParticles ($PARTICLES_REF)"
	curl -fsSL -o "$LIB/pdParticles.lua" \
		"https://codeberg.org/PossiblyAxolotl/pdParticles/raw/branch/${PARTICLES_REF}/pdParticles.lua"
else
	echo "==> pdParticles already present"
fi

echo "==> Dependencies ready."
