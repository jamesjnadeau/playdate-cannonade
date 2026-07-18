-- Enemy.lua
-- A hostile ship that steers toward the player and rams them.

import "scripts/Config"
import "scripts/Utils"

local gfx <const> = playdate.graphics

class("Enemy").extends()

local function rotatePts(pts, deg, ox, oy)
	local r = deg * math.pi / 180
	local c, s = math.cos(r), math.sin(r)
	local out = {}
	for i = 1, #pts, 2 do
		local lx, ly = pts[i], pts[i + 1]
		out[#out + 1] = ox + (lx * c - ly * s)
		out[#out + 1] = oy + (lx * s + ly * c)
	end
	return out
end

local function fillFan(p)
	local n = #p // 2
	for i = 2, n - 1 do
		gfx.fillTriangle(p[1], p[2], p[i * 2 - 1], p[i * 2], p[i * 2 + 1], p[i * 2 + 2])
	end
end

function Enemy:init(x, y, heading)
	Enemy.super.init(self)
	self.x = x
	self.y = y
	self.heading = heading or 0
	self.radius = Config.ENEMY_RADIUS
	self.alive = true

	local L, B = 16, 8
	self.hull = { L, 0,  -L * 0.7, B,  -L, B * 0.55,  -L, -B * 0.55,  -L * 0.7, -B }
end

function Enemy:update(targetX, targetY)
	local dt = Config.DT
	-- Turn toward the player at a limited rate, then advance.
	local want = Utils.angleTo(self.x, self.y, targetX, targetY)
	local diff = Utils.angleDiff(self.heading, want)
	local maxTurn = Config.ENEMY_TURN_RATE * dt
	if diff > maxTurn then diff = maxTurn elseif diff < -maxTurn then diff = -maxTurn end
	self.heading = Utils.wrapDeg(self.heading + diff)

	local hx, hy = Utils.heading(self.heading)
	self.x = self.x + hx * Config.ENEMY_SPEED * dt
	self.y = self.y + hy * Config.ENEMY_SPEED * dt
end

function Enemy:draw()
	local p = rotatePts(self.hull, self.heading, self.x, self.y)
	-- Solid black hull: reads clearly as "enemy" vs the white player ship.
	gfx.setColor(gfx.kColorBlack)
	fillFan(p)
	-- White bow marker so their heading is legible.
	local hx, hy = Utils.heading(self.heading)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillCircleAtPoint(self.x + hx * 6, self.y + hy * 6, 2)
end
