-- Enemy.lua
-- A hostile ship that steers toward the player and rams them.

import "scripts/Config"
import "scripts/Utils"
import "scripts/Ship"

local gfx <const> = playdate.graphics

class("Enemy").extends(Ship)

function Enemy:init(x, y, heading)
	Enemy.super.init(self, x, y, heading)
	self.radius = Config.ENEMY_RADIUS
	self.length = Config.ENEMY_LENGTH
	self.color = gfx.kColorBlack
	self.health = 1
	self.teleportWarning = nil -- seconds left before relocation; nil when not pending

	local L, B = Config.ENEMY_LENGTH, Config.ENEMY_BEAM
	self.hull = { L, 0,  -L * 0.7, B,  -L, B * 0.55,  -L, -B * 0.55,  -L * 0.7, -B }
end

function Enemy:update(targetX, targetY)
	local dt = Config.DT
	local want = Utils.angleTo(self.x, self.y, targetX, targetY)
	local diff = Utils.angleDiff(self.heading, want)
	local maxTurn = Config.ENEMY_TURN_RATE * dt
	if diff > maxTurn then diff = maxTurn elseif diff < -maxTurn then diff = -maxTurn end
	self.heading = Utils.wrapDeg(self.heading + diff)

	local hx, hy = Utils.heading(self.heading)
	self.x = self.x + hx * Config.ENEMY_SPEED * dt
	self.y = self.y + hy * Config.ENEMY_SPEED * dt

	self:updateLeash(targetX, targetY, dt)
end

-- In an infinite world an enemy that falls behind would otherwise chase the
-- player forever. Past Config.ENEMY_MAX_DISTANCE it starts a countdown
-- (surfaced on its off-screen indicator); if it's still that far away when
-- the countdown runs out, it's relocated to the opposite side of the player
-- at the same distance (a point reflection through the player), landing it
-- back in play instead of trailing off into the distance.
function Enemy:updateLeash(shipX, shipY, dt)
	if Utils.dist(self.x, self.y, shipX, shipY) <= Config.ENEMY_MAX_DISTANCE then
		self.teleportWarning = nil
		return
	end

	if not self.teleportWarning then
		self.teleportWarning = Config.ENEMY_TELEPORT_WARN_TIME
		return
	end

	self.teleportWarning = self.teleportWarning - dt
	if self.teleportWarning <= 0 then
		self.x = 2 * shipX - self.x
		self.y = 2 * shipY - self.y
		self.teleportWarning = nil
	end
end

function Enemy:draw()
	Enemy.super.draw(self)
	
	local hx, hy = Utils.heading(self.heading)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillCircleAtPoint(self.x + hx * 6, self.y + hy * 6, 2)
end