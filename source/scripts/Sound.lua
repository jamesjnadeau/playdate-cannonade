-- Sound.lua
-- Procedurally synthesized sound effects. The game ships no audio assets --
-- everything here is built from playdate.sound.synth/twopolefilter/envelope
-- at import time and retriggered on demand, rather than sample playback.

import "scripts/Config"

local snd <const> = playdate.sound

---@class Sound
Sound = {}

-- Trident-launch whoosh: white noise through a resonant bandpass filter,
-- with the filter's center frequency swept up then back down by an
-- envelope. The rising/falling cutoff is what reads as a prong rushing
-- past rather than a flat hiss. Built once and reused (retriggered) on
-- every shot instead of allocating new synth/filter/envelope objects per
-- shot, since Tridentballs can fire in quick succession.
local whooshChannel = snd.channel.new()

local whooshSynth = snd.synth.new(snd.kWaveNoise)
whooshSynth:setADSR(Config.SOUND_WHOOSH_ATTACK, Config.SOUND_WHOOSH_DECAY, 0, Config.SOUND_WHOOSH_RELEASE)
whooshChannel:addSource(whooshSynth)

local whooshFilter = snd.twopolefilter.new(snd.kFilterBandPass)
whooshFilter:setResonance(Config.SOUND_WHOOSH_FILTER_RESONANCE)
whooshFilter:setMix(1)
whooshChannel:addEffect(whooshFilter)

-- Modulates whooshFilter's center frequency: 0 -> 1 over the attack, then
-- back to a sustain of 0 over the decay, scaled/offset into Hz. Retrigger
-- is on so a fast second shot always starts the sweep from 0 Hz-offset
-- rather than jumping from wherever the previous sweep had decayed to.
local whooshSweep = snd.envelope.new(Config.SOUND_WHOOSH_SWEEP_ATTACK, Config.SOUND_WHOOSH_SWEEP_DECAY, 0, 0.05)
whooshSweep:setRetrigger(true)
whooshSweep:setScale(Config.SOUND_WHOOSH_SWEEP_RANGE_HZ)
whooshSweep:setOffset(Config.SOUND_WHOOSH_SWEEP_MIN_HZ)
whooshFilter:setFrequencyMod(whooshSweep)

-- Plays the trident-launch whoosh. Safe to call rapidly -- each call
-- retriggers the shared synth/envelope rather than layering new voices.
function Sound.playTridentWhoosh()
	whooshSweep:trigger(1, Config.SOUND_WHOOSH_LENGTH)
	whooshSynth:playNote("C4", Config.SOUND_WHOOSH_VOLUME, Config.SOUND_WHOOSH_LENGTH)
end
