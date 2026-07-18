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
-- The playable sea is much larger than the screen; the camera scrolls over it.
Config.WORLD_W    = 6000
Config.WORLD_H    = 6000
Config.WATER_GRID = 32          -- spacing of the drawn water speckle grid


-- Explosions ------------------------------------------------------------------
-- Each field maps to one pdParticles ParticleCircle setter (see Ship:explode).
-- Ship.explosionConfig is the default every ship inherits; a subclass can
-- overwrite the whole table or just a field to get its own look.
Config.EXPLOSION = {
	mode     = Particles.modes.DISAPPEAR,
	size     = { 2, 5 },
	speed    = { 2, 9 },      -- pdParticles speed is per-frame
	spread   = { 0, 359 },
	lifespan = { 4, 9 },
	color    = gfx.kColorBlack,
	count    = 22,
	maxAge   = 120,           -- frames; safety net if particles never fully decay
}

-- Ship ----------------------------------------------------------------------
Config.SHIP_MAX_SPEED     = 130     -- pixels / second
Config.SHIP_DEFAULT_SPEED = 60      -- guaranteed baseline forward speed regardless of sail/wind
Config.SHIP_ACCEL        = 90       -- pixels / second, added per second while easing toward target speed
Config.SHIP_TURN_SCALE = 0.55   -- crank-degrees -> heading-degrees multiplier
Config.SHIP_COLLIDE_RADIUS    = 12      -- collision radius
Config.SHIP_MAX_HEALTH = 5
Config.SHIP_LENGTH    = 15      -- half-length of hull when drawn, default 22
Config.SHIP_BEAM      = 4       -- half-width of hull when drawn

-- Sail ------------------------------------------------------------------
-- Up/Down let the sail out / trim it in (0 = trimmed in, 1 = fully out).
Config.SAIL_TRIM_START = 0.5  -- trim the player starts each run with
Config.SAIL_TRIM_RATE  = 1.2  -- trim units / second while Up/Down is held
Config.SAIL_MAX_ANGLE  = 90   -- max degrees the boom can swing from the centerline (rigging limit)
Config.SAIL_LENGTH     = 14   -- px length of the drawn sail

-- Wind --------------------------------------------------------------------
-- Direction is the angle the wind blows TOWARD (same convention as heading).
Config.WIND_SPEED                = 70 -- px/s a fully-out sail catches running dead downwind
Config.WIND_DIRECTION_DRIFT_RATE = 4  -- max degrees/second the wind direction wanders
Config.WIND_INDICATOR_CIRCLE_SIZE = 20
Config.WIND_INDICATOR_SIZE = 12

-- Enemies -------------------------------------------------------------------
Config.ENEMY_SPEED      = 78    -- pixels / second (slower than you at full sail)
Config.ENEMY_RADIUS     = 11
Config.ENEMY_TURN_RATE  = 130   -- degrees / second they can rotate toward you
Config.ENEMY_SPAWN_DIST = 260   -- how far off-screen they appear, from ship
Config.ENEMY_DAMAGE     = 1
Config.ENEMY_LENGTH    = 20      -- half-length of hull when drawn, default 22
Config.ENEMY_BEAM      = 8       -- half-width of hull when drawn

-- Difficulty ramp: spawn interval shrinks from START to FLOOR over RAMP seconds
Config.SPAWN_INTERVAL_START = 2.6
Config.SPAWN_INTERVAL_FLOOR = 0.55
Config.SPAWN_RAMP_SECONDS   = 90
Config.MAX_ENEMIES          = 40

-- Cannon --------------------------------------------------------------------
Config.CHARGE_RATE      = 1.4   -- charge units / second (held), clamps at 1.0
Config.CANNON_SPEED     = 420   -- projectile speed, fixed regardless of charge
Config.CANNON_MAX_SPREAD = 40   -- degrees of random aim error at 0 charge
Config.CANNON_MAX_ACCURACY = 0.99 -- accuracy (0-1) reached once fully charged
Config.CANNON_LIFETIME  = 1.6   -- seconds before a ball falls in the sea
Config.CANNON_RADIUS    = 2
Config.TARGET_RANGE     = 200   -- max auto-target acquisition distance, default: 320
Config.AIM_LINE_LENGTH  = 18    -- length (px) of the converging aim-indicator lines
Config.AIM_LINE_WIDTH   = 2     -- stroke thickness (px) of the aim-indicator lines
Config.NO_TARGET_MARK_SIZE   = 16 -- pixel height of the "?" shown when charging with nothing in range
Config.NO_TARGET_MARK_OFFSET = 30 -- distance (px) from the ship's center to that mark

-- Levels ----------------------------------------------------------------
-- Level N clears once the player has defeated N * LEVEL_ENEMY_STEP enemies
-- since that level began (level 1 -> 5, level 2 -> 10, ...).
Config.LEVEL_ENEMY_STEP = 5

return Config
