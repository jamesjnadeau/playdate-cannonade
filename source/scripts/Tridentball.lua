-- Tridentball.lua
-- A projectile fired from the ship toward an auto-targeted enemy.

import "scripts/Config"
import "scripts/Utils"

local gfx <const> = playdate.graphics

class("Tridentball").extends()

function Tridentball:init(x, y, dirDeg, speed)
	Tridentball.super.init(self)
	self.x = x
	self.y = y
	local hx, hy = Utils.heading(dirDeg)
	self.vx = hx * speed
	self.vy = hy * speed
	self.life = Config.TRIDENT_LIFETIME
	self.radius = Config.TRIDENT_RADIUS
	self.dead = false
end

function Tridentball:update()
	local dt = Config.DT
	self.x = self.x + self.vx * dt
	self.y = self.y + self.vy * dt
	self.life = self.life - dt
	if self.life <= 0 then self.dead = true end
end

function Tridentball:draw()
	gfx.setColor(gfx.kColorBlack)
	gfx.fillCircleAtPoint(self.x, self.y, self.radius + 1)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillCircleAtPoint(self.x, self.y, self.radius - 1)
end
