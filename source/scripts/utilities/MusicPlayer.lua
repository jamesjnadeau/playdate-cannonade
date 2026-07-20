-- MusicPlayer.lua
-- Plays a song's pre-rendered ADPCM .wav file via playdate.sound.fileplayer.
-- Songs are rendered offline (tools/render-song.sh, fluidsynth + ffmpeg)
-- as a single file per song -- fileplayer streams from flash rather than
-- loading the whole file into memory, so even a full-length song is cheap
-- to open. play() loops the song natively via fileplayer:play(0)
-- (repeatCount 0 = loop forever) rather than manually reloading a piece on
-- every finish -- an earlier version split songs into ~1-minute pieces and
-- chained them via setFinishCallback, but the reload at each piece boundary
-- caused an audible stutter; see git history for that approach.
--
-- Replaces the earlier MidiPlayer.lua, which synthesized playback live from
-- a .mid file note-by-note (see git history) -- pre-rendering trades that
-- approach's synthesized-instrument flexibility for real sampled audio and
-- a much cheaper runtime.

import "scripts/utilities/Config"

local snd <const> = playdate.sound

---@class MusicPlayer
---@field player _FilePlayer
---@field song string|nil currently loaded song (a file name under MusicPlayer.SONGS_DIR)
---@field playing boolean
MusicPlayer = {
	player = snd.fileplayer.new(),
	song = nil,
	playing = false,
}

-- Stops playback. Safe to call with nothing loaded or already stopped.
function MusicPlayer.stop()
	if MusicPlayer.playing then
		MusicPlayer.playing = false
		MusicPlayer.player:stop()
	end
end

-- Loads `songName` (a file under MusicPlayer.SONGS_DIR, or nil for "no
-- song"), stopping whatever's currently loaded. Does not start playback;
-- call play() once loaded.
---@param songName string|nil
function MusicPlayer.load(songName)
	MusicPlayer.stop()
	MusicPlayer.song = songName
	if songName then
		-- pdc compiles the song's .wav into a .pda (see render-song.sh);
		-- player:load() wants the path with no extension at all (same
		-- convention as gfx.image.new).
		MusicPlayer.player:load(MusicPlayer.SONGS_DIR .. "/" .. songName)
		MusicPlayer.applyVolume()
	end
end

-- Starts (or restarts, if stopped) the currently loaded song, looping
-- indefinitely (fileplayer:play(0) -- repeatCount 0 means loop forever).
-- No-op if nothing is loaded or it's already playing.
function MusicPlayer.play()
	if not MusicPlayer.playing and MusicPlayer.song then
		MusicPlayer.playing = true
		MusicPlayer.player:play(0)
	end
end

-- Pushes Config.MUSIC_VOLUME to the currently-loaded song. Called
-- automatically by load() (so a volume change while stopped still takes
-- effect on the next play()); call again any time Config.MUSIC_VOLUME
-- changes at runtime (e.g. from SettingsScene) to make the change audible
-- immediately. Safe to call with nothing loaded.
function MusicPlayer.applyVolume()
	MusicPlayer.player:setVolume(Config.MUSIC_VOLUME)
end

-- Background-music selection, keyed off Config.MUSIC_ENABLED/MUSIC_SONG so
-- every caller (main.lua's boot logic and system-menu "Music" checkmark,
-- SettingsScene's Song row) shares one source of truth instead of each
-- reimplementing "how to start/stop a song".

-- Where bundled songs live -- each a single file, compiled into the .pdx
-- from source/assets/songs (see tools/render-song.sh).
MusicPlayer.SONGS_DIR = "assets/songs"

-- Bundled resources are read-only and can't change mid-session, so this
-- scans MusicPlayer.SONGS_DIR once and caches the result.
local songNames = nil

-- Sorted list of song names under MusicPlayer.SONGS_DIR (suitable for
-- Config.MUSIC_SONG / selectSong below).
---@return string[]
function MusicPlayer.listSongs()
	if songNames then return songNames end
	songNames = {}
	local files = playdate.file.listFiles(MusicPlayer.SONGS_DIR) or {}
	for _, name in ipairs(files) do
		-- playdate.file.listFiles reflects the compiled .pda name -- see
		-- the extension-stripping comment in load() above.
		local base = name:match("^(.*)%.pda$")
		if base then
			songNames[#songNames + 1] = base
		end
	end
	table.sort(songNames)
	return songNames
end

-- Selects `name` (a song from listSongs(), or nil for "no song") as
-- Config.MUSIC_SONG. If music is enabled (Config.MUSIC_ENABLED), also loads
-- and plays it immediately (or just stops, for nil) so picking a song
-- previews it; if disabled, only records the choice -- setEnabled(true)
-- picks it up later.
---@param name string|nil
function MusicPlayer.selectSong(name)
	Config.MUSIC_SONG = name
	if not Config.MUSIC_ENABLED then return end
	MusicPlayer.load(name)
	if name then
		MusicPlayer.play()
	end
end

-- Turns background music on/off, syncing Config.MUSIC_ENABLED -- shared by
-- the system-menu "Music" checkmark (main.lua) and anything else that wants
-- to mute/unmute. Off stops playback without forgetting Config.MUSIC_SONG;
-- on (re)loads and plays it, if one is selected.
---@param enabled boolean
function MusicPlayer.setEnabled(enabled)
	Config.MUSIC_ENABLED = enabled
	if enabled then
		MusicPlayer.selectSong(Config.MUSIC_SONG)
	else
		MusicPlayer.stop()
	end
end

-- Called once at boot (main.lua): picks the first bundled song
-- (alphabetically) as the default if none is already selected, then plays
-- it if Config.MUSIC_ENABLED. A no-op if no songs are bundled.
function MusicPlayer.playDefault()
	if not Config.MUSIC_SONG then
		Config.MUSIC_SONG = MusicPlayer.listSongs()[1]
	end
	if Config.MUSIC_ENABLED then
		MusicPlayer.selectSong(Config.MUSIC_SONG)
	end
end
