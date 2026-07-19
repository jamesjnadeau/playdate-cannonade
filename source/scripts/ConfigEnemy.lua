-- ConfigEnemy.lua
-- Enemy tuning, split out of Config.lua since it's the part that grows as
-- new enemy types are added. Still just adds fields onto the shared global
-- Config table -- import "scripts/Config" first (this file assumes
-- Config.SHIP_MAX_SPEED already exists).
local gfx <const> = playdate.graphics

-------------
-- Enemies --
-------------
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
Config.ENEMY_WIND_MULTIPLIER = 0.1 -- enemies have no sails: wind just adds a straight push of windSpeed * this, in the wind's direction, on top of their steering speed
Config.ENEMY_ACCEL      = 60    -- pixels/second, added per second while easing toward ENEMY_SPEED (see Ship:updateSpeed)
-- Lowest self.level an enemy type is allowed to spawn at (see Enemy.minLevel
-- and GameScene:spawnEnemy, which filters GameScene.enemyTypes by this each
-- time it picks a type to spawn). 1 means "eligible from the very first
-- level", i.e. always appears.
Config.ENEMY_MIN_LEVEL = 1

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

------------------------
-- Enemy: Swordfish --
------------------------
-- A smaller, faster Enemy variant (see EnemySwordfish.lua) with a long spiked
-- bill instead of a hull bow. Mirrors the base ENEMY_* tuning knobs above so
-- it can be tuned independently.
Config.ENEMY_SWORDFISH_SPEED      = math.floor(Config.ENEMY_SPEED * 1.2)   -- pixels / second, faster than the base enemy
Config.ENEMY_SWORDFISH_ACCEL      = math.floor(Config.ENEMY_ACCEL * 1.2)   -- pixels / second^2
Config.ENEMY_SWORDFISH_TURN_RATE_MAX = 110  -- degrees / second at low speed
Config.ENEMY_SWORDFISH_TURN_RATE_MIN = 30   -- degrees / second at/above max speed
Config.ENEMY_SWORDFISH_TURN_RATE_SPEED_MULTIPLIER = 1.0
Config.ENEMY_SWORDFISH_LENGTH     = math.floor(Config.ENEMY_LENGTH * 0.85) -- half-length of hull body (excludes bill), smaller than the base enemy
Config.ENEMY_SWORDFISH_BEAM       = math.floor(Config.ENEMY_BEAM * 0.85)   -- half-width of hull when drawn, slimmer than the base enemy
Config.ENEMY_SWORDFISH_BILL_LENGTH = math.floor(Config.ENEMY_SWORDFISH_LENGTH * 0.9) -- extra spike length added ahead of the body, giving the swordfish look
Config.ENEMY_SWORDFISH_RADIUS     = Config.ENEMY_SWORDFISH_LENGTH +  (Config.ENEMY_SWORDFISH_BILL_LENGTH/2)       -- collision radius 
Config.ENEMY_SWORDFISH_HEALTH     = 1
Config.ENEMY_SWORDFISH_DAMAGE     = Config.ENEMY_DAMAGE / 2
Config.ENEMY_SWORDFISH_WIND_MULTIPLIER = Config.ENEMY_WIND_MULTIPLIER
Config.ENEMY_SWORDFISH_COLOR      = gfx.kColorBlack
Config.ENEMY_SWORDFISH_OUTLINE_COLOR = gfx.kColorWhite -- distinguishes it from the base enemy's silhouette at a glance
Config.ENEMY_SWORDFISH_EYE_OFFSET = 4   -- px the eye dot sits ahead of center, scaled down to match its smaller hull
Config.ENEMY_SWORDFISH_MIN_LEVEL  = 3   -- unlocked starting this level (appears after level 2) -- see Config.ENEMY_MIN_LEVEL

return Config
