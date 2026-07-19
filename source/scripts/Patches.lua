-- Patches.lua
-- A "GM-lite" bank of synthesized instrument patches for MidiPlayer: since
-- the Playdate SDK has no General MIDI sound set, MIDI playback needs
-- something to turn "track N, note on" into an actual synth voice, and this
-- supplies it. Adapted from https://github.com/plaidate/midiplayer's
-- patches.lua (MIT license) -- the recipes and drum kit are carried over
-- as-is, with Config.MUSIC_MAX_VOICES replacing that project's own cap.

import "scripts/Config"
import "scripts/Utils"

local snd <const> = playdate.sound

---@class Patches
Patches = {}

-- name -> {waveform, attack, decay, sustain, release, volume}
local RECIPES = {
	lead  = { snd.kWaveSquare,   0.005, 0.10, 0.55, 0.08, 0.20 },
	pluck = { snd.kWaveSawtooth, 0.000, 0.12, 0.15, 0.05, 0.24 },
	pad   = { snd.kWaveSine,     0.050, 0.10, 0.70, 0.20, 0.11 },
	organ = { snd.kWaveSine,     0.010, 0.05, 0.90, 0.10, 0.16 },
	bass  = { snd.kWaveTriangle, 0.002, 0.08, 0.70, 0.03, 0.32 },
}

-- Names MidiPlayer.load's per-song map/guessPatch heuristic may assign.
Patches.names = { "lead", "pluck", "pad", "organ", "bass", "drums" }

---@param recipe table
---@return _Synth
local function makeVoice(recipe)
	local s = snd.synth.new(recipe[1])
	s:setADSR(recipe[2], recipe[3], recipe[4], recipe[5])
	s:setVolume(recipe[6])
	return s
end

-- A single percussion voice, keyed by GM note number in drumKit below.
---@param wave integer
---@param decay number
---@param vol number
---@return _Synth
local function drumVoice(wave, decay, vol)
	local s = snd.synth.new(wave)
	s:setADSR(0, decay, 0, 0.02)
	s:setVolume(vol)
	return s
end

---@return _Instrument
local function drumKit()
	local inst = snd.instrument.new()
	-- kick: low sine thump (GM notes 35/36 land at ~58Hz, reads as a kick)
	inst:addVoice(drumVoice(snd.kWaveSine, 0.12, 0.90), 35)
	inst:addVoice(drumVoice(snd.kWaveSine, 0.12, 0.90), 36)
	-- snare / clap / toms: noise bursts of varying length
	inst:addVoice(drumVoice(snd.kWaveNoise, 0.09, 0.50), 38)
	inst:addVoice(drumVoice(snd.kWaveNoise, 0.07, 0.45), 39)
	inst:addVoice(drumVoice(snd.kWaveNoise, 0.06, 0.42), 40)
	inst:addVoice(drumVoice(snd.kWaveTriangle, 0.15, 0.55), 41)
	inst:addVoice(drumVoice(snd.kWaveTriangle, 0.15, 0.55), 43)
	inst:addVoice(drumVoice(snd.kWaveTriangle, 0.12, 0.50), 45)
	inst:addVoice(drumVoice(snd.kWaveTriangle, 0.12, 0.50), 47)
	-- hats / cymbals: short bright noise
	inst:addVoice(drumVoice(snd.kWaveNoise, 0.03, 0.22), 42)
	inst:addVoice(drumVoice(snd.kWaveNoise, 0.03, 0.22), 44)
	inst:addVoice(drumVoice(snd.kWaveNoise, 0.18, 0.22), 46)
	inst:addVoice(drumVoice(snd.kWaveNoise, 0.35, 0.28), 49)
	inst:addVoice(drumVoice(snd.kWaveNoise, 0.20, 0.20), 51)
	return inst
end

-- Builds an instrument for `name`, stacking up to Config.MUSIC_MAX_VOICES
-- copies of its voice so simultaneous notes (chords) don't steal-cut each
-- other. "drums" ignores poly and always returns the fixed multi-note kit
-- above (one voice per GM percussion note, not stacked).
---@param name string one of Patches.names
---@param poly? integer voices to stack, clamped to [1, Config.MUSIC_MAX_VOICES]
---@return _Instrument
function Patches.instrument(name, poly)
	if name == "drums" then
		return drumKit()
	end
	local recipe = RECIPES[name] or RECIPES.lead
	local inst = snd.instrument.new()
	local n = Utils.clamp(poly or 1, 1, Config.MUSIC_MAX_VOICES)
	for _ = 1, n do
		inst:addVoice(makeVoice(recipe))
	end
	return inst
end
