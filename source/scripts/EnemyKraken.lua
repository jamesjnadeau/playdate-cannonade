-- EnemyKraken.lua
-- A slow, tougher Enemy variant with a round body instead of a ship hull.
-- Draws its own body + a row of 3 small circles trailing off ahead of it,
-- doubling as a direction indicator in place of the base Enemy's bow eye-dot
-- (see EnemyKraken:draw, which overrides Enemy:draw/Ship:draw entirely rather
-- than filling a self.hull polygon). All tuning lives in Config.ENEMY_KRAKEN_*
-- (see ConfigEnemy.lua).

import "scripts/Config"
import "scripts/ConfigEnemy"
import "scripts/Utils"
import "scripts/Enemy"

local gfx <const> = playdate.graphics

class("EnemyKraken").extends(Enemy)

-- Unlocked starting this level (see Config.ENEMY_KRAKEN_MIN_LEVEL /
-- Enemy.minLevel / GameScene:spawnEnemy).
EnemyKraken.minLevel = Config.ENEMY_KRAKEN_MIN_LEVEL

-- See Enemy.displayName.
EnemyKraken.displayName = "Kraken"

function EnemyKraken:init(x, y, heading)
	EnemyKraken.super.init(self, x, y, heading)

	self.radius = Config.ENEMY_KRAKEN_RADIUS
	self.length = Config.ENEMY_KRAKEN_BODY_RADIUS -- no hull polygon to size off of; only Ship:sternPosition/beamPosition read this, and neither is called on enemies
	self.color = Config.ENEMY_KRAKEN_COLOR
	self.outlineColor = Config.ENEMY_KRAKEN_OUTLINE_COLOR
	self.health = Config.ENEMY_KRAKEN_HEALTH
	self.maxHealth = self.health -- see Enemy:drawHealthBar, shown once health < maxHealth
	self.speed = 0

	self.moveSpeed = Config.ENEMY_KRAKEN_SPEED
	self.accel = Config.ENEMY_KRAKEN_ACCEL
	self.turnRateMax = Config.ENEMY_KRAKEN_TURN_RATE_MAX
	self.turnRateMin = Config.ENEMY_KRAKEN_TURN_RATE_MIN
	self.turnRateSpeedMultiplier = Config.ENEMY_KRAKEN_TURN_RATE_SPEED_MULTIPLIER
	self.windMultiplier = Config.ENEMY_KRAKEN_WIND_MULTIPLIER
	self.damage = Config.ENEMY_KRAKEN_DAMAGE
end

function EnemyKraken:draw()
	if not self.alive then return end

	gfx.setColor(self.color)
	gfx.fillCircleAtPoint(self.x, self.y, Config.ENEMY_KRAKEN_BODY_RADIUS)
	if self.outlineColor then
		gfx.setColor(self.outlineColor)
		gfx.setLineWidth(2)
		gfx.drawCircleAtPoint(self.x, self.y, Config.ENEMY_KRAKEN_BODY_RADIUS)
	end

	-- 3 small circles trailing off to one side, spaced out ahead of the body
	-- along the heading -- reads as both a tentacle trail and a direction
	-- indicator.
	local hx, hy = Utils.heading(self.heading)
	gfx.setColor(self.color)
	for i = 1, 3 do
		local d = Config.ENEMY_KRAKEN_DOT_OFFSET + (i - 1) * Config.ENEMY_KRAKEN_DOT_SPACING
		gfx.fillCircleAtPoint(self.x + hx * d, self.y + hy * d, Config.ENEMY_KRAKEN_DOT_RADIUS)
	end

	if self.health < self.maxHealth then
		self:drawHealthBar()
	end
end
