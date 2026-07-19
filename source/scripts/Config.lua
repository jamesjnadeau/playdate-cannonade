-- Config.lua
-- Central place for all tuning values so the game is easy to tweak.
-- Everything lives in a global table so any file can read it after import.
local gfx <const> = playdate.graphics

Config = {}

-- Display -------------------------------------------------------------------
Config.SCREEN_W   = 400
Config.SCREEN_H   = 240
Config.REFRESH    = 30          -- we lock to 30fps and use a fixed timestep
Config.DT         = 1 / 30

-- World ---------------------------------------------------------------------
-- The sea is infinite and all coordinates are player-centered: the camera
-- always centers on the ship and nothing clamps its position.
Config.WATER_GRID = 80             -- spacing of the drawn water speckle grid
Config.WATER_WAVELET_LENGTH_MIN = 15 -- shortest span (px) of each wavelet, perpendicular to the wind
Config.WATER_WAVELET_LENGTH_MAX = 32 -- longest span (px) of each wavelet, perpendicular to the wind
Config.WATER_WAVELET_WIDTH = 1     -- line width (px) of each wavelet segment
Config.WATER_WAVELET_SEGMENTS_PER_ZIGZAG_MIN = 6 -- fewest line segments per up/down cycle (higher = smoother curves)
Config.WATER_WAVELET_SEGMENTS_PER_ZIGZAG_MAX = 8 -- most line segments per up/down cycle
Config.WATER_WAVELET_AMPLITUDE = 6 -- how far the wave bulges along the wind direction (px)
Config.WATER_WAVELET_ZIGZAGS_MIN = 1 -- fewest up/down cycles along each wavelet
Config.WATER_WAVELET_ZIGZAGS_MAX = 3 -- most up/down cycles along each wavelet
Config.WATER_WAVELET_SPAWN_CHANCE = 0.35 -- chance (0-1) any given wavelet slot draws one at all

-- Wind --------------------------------------------------------------------
-- Direction is the angle the wind blows TOWARD (same convention as heading).
-- Every WIND_CHANGE_INTERVAL_MIN..MAX seconds a new random change fires: it
-- picks a new target speed in WIND_SPEED_MIN..MAX, eases toward it at a rate
-- in WIND_SPEED_CHANGE_RATE_MIN..MAX (px/s per second), and picks a new
-- target direction by a random +/- magnitude in WIND_DIRECTION_CHANGE_MIN..MAX
-- degrees, easing toward it at a rate in WIND_DIRECTION_CHANGE_RATE_MIN..MAX
-- (degrees per second).
Config.WIND_SPEED_MIN             = 40  -- px/s a fully-out sail catches running dead downwind
Config.WIND_SPEED_MAX             = 100
Config.WIND_SPEED_CHANGE_RATE_MIN = 1   -- px/s per second the wind eases toward its new target speed
Config.WIND_SPEED_CHANGE_RATE_MAX = 3
Config.WIND_CHANGE_INTERVAL_MIN   = 10   -- seconds between random wind changes
Config.WIND_CHANGE_INTERVAL_MAX   = 15
Config.WIND_DIRECTION_CHANGE_MIN  = 25   -- degrees the wind direction target shifts by on each change
Config.WIND_DIRECTION_CHANGE_MAX  = 45
Config.WIND_DIRECTION_CHANGE_RATE_MIN = 2  -- degrees/second the wind eases toward its new target direction
Config.WIND_DIRECTION_CHANGE_RATE_MAX = 4
Config.WIND_INDICATOR_CIRCLE_SIZE = 20
Config.WIND_INDICATOR_SIZE = 20
-- How much wind bends the player's wake spray away from directly astern,
-- toward the direction the wind is blowing (0 = wake trails straight behind
-- the ship, 1 = wake is fully re-centered on the wind direction). See
-- Player:update.
Config.WAKE_WIND_INFLUENCE = 0.4

-- Explosions ------------------------------------------------------------------
-- Each field maps to one pdParticles ParticleCircle setter (see Ship:explode).
-- Ship.explosionConfig is the default every ship inherits; a subclass can
-- overwrite the whole table or just a field to get its own look.
Config.EXPLOSION = {
	mode     = Particles.modes.DECAY,
	decay    = 0.5,
	size     = { 2, 5 },
	speed    = { 2, 9 },      -- pdParticles speed is per-frame
	spread   = { 0, 100 },
	lifespan = { 2, 3 },
	color    = gfx.kColorBlack,
	count    = 10,
	maxAge   = 120,           -- frames; safety net if particles never fully decay
}
-- How much wind bends the explosion's spread arc toward the direction the
-- wind is blowing (0 = ignore wind and use spread as authored above, 1 =
-- spread arc is fully re-centered on the wind direction). See Ship:explode.
Config.EXPLOSION_WIND_INFLUENCE = 1.0

-- Ship ----------------------------------------------------------------------
-- set max ship speed to half way between min/max wind speed
Config.SHIP_MAX_SPEED = math.floor((Config.WIND_SPEED_MAX - Config.WIND_SPEED_MIN)/2) + Config.WIND_SPEED_MIN     -- pixels / second
Config.SHIP_DEFAULT_SPEED = math.floor(Config.SHIP_MAX_SPEED * 0.1 )    -- guaranteed baseline forward speed regardless of sail/wind
Config.SHIP_ACCEL        = math.floor(Config.SHIP_MAX_SPEED * 0.18 )       -- pixels / second, added per second while easing toward target speed
Config.SHIP_TURN_SCALE = 0.55   -- crank-degrees -> heading-degrees multiplier
Config.SHIP_MAX_HEALTH = 5
Config.SHIP_LENGTH    = 20      -- half-length of hull when drawn, default 22
Config.SHIP_COLLIDE_RADIUS = Config.SHIP_LENGTH      -- collision radius
Config.SHIP_BEAM      = 7       -- half-width of hull when drawn
Config.SHIP_WIND_POWER_MULTIPLIER = 1.2
-- Continuous drag opposing every ship's speed: each second a ship loses this
-- fraction of its current speed to water resistance, on top of easing toward
-- its target speed. Kept small relative to SHIP_ACCEL/ENEMY_ACCEL so it
-- doesn't choke off top speed -- see Ship:updateSpeed.
Config.SHIP_WATER_FRICTION = 0.05
-- Extra drag applied only to the portion of speed above SHIP_MAX_SPEED (e.g.
-- from a wind boost pushing a ship past its cap): each second a ship loses
-- this fraction of every pixel/second it's over the max, on top of the
-- regular water friction above -- see Ship:updateSpeed.
Config.SHIP_OVERSPEED_FRICTION = 0.05

-- Sail ------------------------------------------------------------------
-- Up/Down let the sail out / trim it in (0 = trimmed in, 1 = fully out).
Config.SAIL_TRIM_START = 0.5  -- trim the player starts each run with
Config.SAIL_TRIM_RATE  = 1.2  -- trim units / second while Up/Down is held
Config.SAIL_MAX_ANGLE  = 90   -- max degrees the boom can swing from the centerline (rigging limit)
Config.SAIL_LENGTH     = Config.SHIP_LENGTH + (.25 * Config.SHIP_LENGTH)   -- px length of the drawn sail
-- The boom doesn't snap straight to its resting angle (see Player:sailTargetAngle)
-- -- it's animated like a lightly damped spring, so a slack sail visibly flops
-- over to lie parallel with the wind. SWING_SPEED is the spring's stiffness
-- (how hard the boom accelerates to close the gap to its target angle, in
-- deg/s^2 per degree of error); higher = snappier flop. SWING_FRICTION is the
-- fraction of angular velocity shed per second (damping); higher settles
-- faster with less overshoot, lower wobbles/oscillates longer. See
-- Player:updateSailAngle.
Config.SAIL_SWING_SPEED    = 110
Config.SAIL_SWING_FRICTION = 5



-- Enemies -------------------------------------------------------------------
Config.ENEMY_SPEED      = math.floor(Config.SHIP_MAX_SPEED * 0.75 )    -- pixels / second (should be slower than you at full sail)
-- Turn rate falls off linearly from TURN_RATE_MAX (at rest) to TURN_RATE_MIN
-- (at or above the "max speed" used for the falloff) as an enemy's current
-- speed rises -- see Enemy:update. That reference "max speed" is
-- ENEMY_SPEED * ENEMY_TURN_RATE_SPEED_MULTIPLIER, not ENEMY_SPEED directly,
-- so the falloff curve can be tuned independent of ENEMY_SPEED itself (e.g.
-- < 1 makes them lose turn rate well before reaching their target speed,
-- > 1 delays the falloff past it -- speed can exceed ENEMY_SPEED thanks to
-- wind push, up to SHIP_MAX_SPEED before overspeed friction bites).
Config.ENEMY_TURN_RATE_MAX  = 80   -- degrees / second they can rotate toward you at low speed
Config.ENEMY_TURN_RATE_MIN  = 20   -- degrees / second they can rotate toward you at/above max speed
Config.ENEMY_TURN_RATE_SPEED_MULTIPLIER = 1.0   -- multiplier on ENEMY_SPEED giving the speed at which turn rate bottoms out
Config.ENEMY_SPAWN_DIST = 300   -- how far off-screen they appear, from ship
Config.ENEMY_DAMAGE     = 1
Config.ENEMY_LENGTH    = 20      -- half-length of hull when drawn, default 22
Config.ENEMY_BEAM      = 8       -- half-width of hull when drawn
Config.ENEMY_RADIUS     = Config.ENEMY_LENGTH
Config.ENEMY_WIND_MULTIPLIER = 0.25 -- enemies have no sails: wind just adds a straight push of windSpeed * this, in the wind's direction, on top of their steering speed
Config.ENEMY_ACCEL      = 60    -- pixels/second, added per second while easing toward ENEMY_SPEED (see Ship:updateSpeed)

-- With an infinite world an enemy that loses the player would otherwise
-- chase forever; past ENEMY_MAX_DISTANCE it's flagged for relocation, warned
-- for ENEMY_TELEPORT_WARN_TIME seconds (see the off-screen indicator), then
-- teleported to the opposite side of the player at the same distance so it
-- stays an active threat instead of trailing off into the distance.
Config.ENEMY_MAX_DISTANCE      = 900
Config.ENEMY_TELEPORT_WARN_TIME = 3     -- seconds of countdown warning before relocation

-- Difficulty ramp: spawn interval shrinks from START to FLOOR over RAMP seconds
Config.SPAWN_INTERVAL_START = 2.6
Config.SPAWN_INTERVAL_FLOOR = 0.55
Config.SPAWN_RAMP_SECONDS   = 90
Config.MAX_ENEMIES          = 40

-- Trident -------------------------------------------------------------------
Config.CHARGE_RATE      = 1.4   -- charge units / second (held), clamps at 1.0
Config.TRIDENT_SPEED     = 420   -- projectile speed, fixed regardless of charge
Config.TRIDENT_MAX_SPREAD = 40   -- degrees of random aim error at 0 charge
Config.TRIDENT_MAX_ACCURACY = 0.99 -- accuracy (0-1) reached once fully charged
Config.TRIDENT_LIFETIME  = 1.6   -- seconds before a ball falls in the sea
Config.TRIDENT_RADIUS    = 2
Config.TARGET_RANGE     = 200   -- max auto-target acquisition distance, default: 320
Config.AIM_LINE_LENGTH  = 18    -- length (px) of the converging aim-indicator lines
Config.AIM_LINE_WIDTH   = 2     -- stroke thickness (px) of the aim-indicator lines
Config.NO_TARGET_MARK_SIZE   = 16 -- pixel height of the "?" shown when charging with nothing in range
Config.NO_TARGET_MARK_OFFSET = 30 -- distance (px) from the ship's center to that mark

-- HUD -------------------------------------------------------------------
-- Off-screen enemy indicators: enemies whose on-screen directions fall
-- within OFFSCREEN_INDICATOR_GROUP_ANGLE of each other share a single arrow
-- (with a count badge) instead of stacking separate ones.
Config.OFFSCREEN_INDICATOR_MARGIN      = 40  -- px inset from the screen edge
Config.OFFSCREEN_INDICATOR_SIZE        = 14  -- pixel size of the arrow glyph
Config.OFFSCREEN_INDICATOR_GROUP_ANGLE = 18  -- degrees; enemies this close together share one indicator

-- Levels ----------------------------------------------------------------
-- Level N clears once the player has defeated N * LEVEL_ENEMY_STEP enemies
-- since that level began (level 1 -> 5, level 2 -> 10, ...).
Config.LEVEL_ENEMY_STEP = 5

return Config
