#!/usr/bin/env bash
# Launches the compiled .pdx in the Playdate Simulator. Per the user's own
# use, this is fine to invoke directly (see CLAUDE.md's build/run
# verification note).
#
# Playdate's Lua sandbox has no os.getenv, so MERMAID_START_SCENE is
# forwarded here as a Simulator launch argument instead; main.lua reads it
# back out of playdate.argv[1] to pick the boot scene, falling back to
# Config.START_SCENE if unset. See main.lua's sceneByName table for valid
# values (e.g. Title, GameMain, GameTraining).
./tools/build.sh

if [ -n "$MERMAID_START_SCENE" ]; then
	"$PLAYDATE_SDK_PATH/bin/PlaydateSimulator" MermaidMadness.pdx "$MERMAID_START_SCENE"
else
	"$PLAYDATE_SDK_PATH/bin/PlaydateSimulator" MermaidMadness.pdx
fi
