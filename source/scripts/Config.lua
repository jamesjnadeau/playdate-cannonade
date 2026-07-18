-- Config.lua
-- Central place for all tuning values so the game is easy to tweak.
-- Everything lives in a global table so any file can read it after import.

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
Config.WATER_GRID = 64          -- spacing of the drawn water speckle grid

-- Ship ----------------------------------------------------------------------
Config.SHIP_MAX_SPEED = 130     -- pixels / second
Config.SHIP_ACCEL     = 90      -- pixels / second, added per second while held
Config.SHIP_TURN_SCALE = 0.55   -- crank-degrees -> heading-degrees multiplier
Config.SHIP_RADIUS    = 12      -- collision radius
Config.SHIP_MAX_HEALTH = 5
Config.SHIP_LENGTH    = 22      -- half-length of hull when drawn
Config.SHIP_BEAM      = 9       -- half-width of hull when drawn

-- Enemies -------------------------------------------------------------------
Config.ENEMY_SPEED      = 78    -- pixels / second (slower than you at full sail)
Config.ENEMY_RADIUS     = 11
Config.ENEMY_TURN_RATE  = 130   -- degrees / second they can rotate toward you
Config.ENEMY_SPAWN_DIST = 260   -- how far off-screen they appear, from ship
Config.ENEMY_DAMAGE     = 1

-- Difficulty ramp: spawn interval shrinks from START to FLOOR over RAMP seconds
Config.SPAWN_INTERVAL_START = 2.6
Config.SPAWN_INTERVAL_FLOOR = 0.55
Config.SPAWN_RAMP_SECONDS   = 90
Config.MAX_ENEMIES          = 40

-- Cannon --------------------------------------------------------------------
Config.CHARGE_RATE     = 1.4    -- charge units / second (held), clamps at 1.0
Config.CANNON_MIN_SPEED = 240   -- projectile speed at 0 charge
Config.CANNON_MAX_SPEED = 520   -- projectile speed at full charge
Config.CANNON_LIFETIME  = 1.6   -- seconds before a ball falls in the sea
Config.CANNON_RADIUS    = 3
Config.TARGET_RANGE     = 320   -- max auto-target acquisition distance

return Config
