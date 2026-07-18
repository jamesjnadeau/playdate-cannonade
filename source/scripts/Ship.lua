-- Ship.lua
-- The player's pirate ship. Plain object (not a playdate sprite): the whole
-- game renders in immediate mode inside the scene's update(), which Noble runs
-- *after* the sprite/background pass, so everything composites on top cleanly.

import "scripts/Config"
import "scripts/Utils"

local gfx <const> = playdate.graphics

class("Ship").extends()

-- Rotate a flat list of local-space points {x1,y1,...} by `deg` degrees and
-- translate to (ox, oy). Returns a new flat list of screen/world coords.
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

-- Fill a convex polygon (flat coord list) as a triangle fan.
local function fillFan(p)
	local n = #p // 2
	for i = 2, n - 1 do
		gfx.fillTriangle(p[1], p[2], p[i * 2 - 1], p[i * 2], p[i * 2 + 1], p[i * 2 + 2])
	end
end

-- Stroke the outline of a polygon (flat coord list).
local function strokeLoop(p)
	local n = #p // 2
	for i = 1, n do
		local j = (i % n) + 1
		gfx.drawLine(p[i * 2 - 1], p[i * 2], p[j * 2 - 1], p[j * 2])
	end
end

function Ship:init(x, y)
	Ship.super.init(self)
	self.x = x
	self.y = y
	self.heading = -90            -- start pointing "north" (up the screen)
	self.speed = 0
	self.health = Config.SHIP_MAX_HEALTH
	self.invuln = 0               -- seconds of post-hit invulnerability

	-- Wake trail: small dark churn behind the hull (dark reads on the pale sea).
	self.wake = ParticleCircle(x, y)
	self.wake:setMode(Particles.modes.DECAY)
	self.wake:setSize(2, 4)
	self.wake:setDecay(0.35)
	self.wake:setSpeed(1, 3)          -- pdParticles speed is per-frame; keep small
	self.wake:setColor(gfx.kColorBlack)

	-- Hull outline in local space (bow points toward +x).
	local L, B = Config.SHIP_LENGTH, Config.SHIP_BEAM
	self.hull = { L, 0,  -L * 0.7, B,  -L, B * 0.55,  -L, -B * 0.55,  -L * 0.7, -B }
end

function Ship:steer(crankChange)
	self.heading = Utils.wrapDeg(self.heading + crankChange * Config.SHIP_TURN_SCALE)
end

function Ship:changeSpeed(dir)
	-- dir is +1 (faster) or -1 (slower); called each frame while a button is held.
	self.speed = Utils.clamp(self.speed + dir * Config.SHIP_ACCEL * Config.DT,
		0, Config.SHIP_MAX_SPEED)
end

function Ship:sternPosition()
	local hx, hy = Utils.heading(self.heading)
	return self.x - hx * Config.SHIP_LENGTH, self.y - hy * Config.SHIP_LENGTH
end

function Ship:update()
	local dt = Config.DT
	if self.invuln > 0 then self.invuln = self.invuln - dt end

	local hx, hy = Utils.heading(self.heading)
	self.x = Utils.clamp(self.x + hx * self.speed * dt, 0, Config.WORLD_W)
	self.y = Utils.clamp(self.y + hy * self.speed * dt, 0, Config.WORLD_H)

	-- Emit wake from the stern, spraying backward (opposite the heading).
	if self.speed > 8 then
		local sx, sy = self:sternPosition()
		self.wake:moveTo(sx, sy)
		local back = math.floor(Utils.wrapDeg(self.heading + 180))
		self.wake:setSpread(back - 22, back + 22) -- integers: math.random needs them
		self.wake:add(self.speed > 70 and 2 or 1)
	end
end

function Ship:hit(damage)
	if self.invuln > 0 then return false end
	self.health = self.health - damage
	self.invuln = 1.0
	return true
end

-- Draw in world space (camera draw-offset already applied by the scene).
function Ship:draw()
	-- Blink while invulnerable so a hit reads clearly.
	if self.invuln > 0 and (math.floor(self.invuln * 12) % 2 == 0) then
		return
	end
	local p = rotatePts(self.hull, self.heading, self.x, self.y)
	gfx.setColor(gfx.kColorWhite)
	fillFan(p)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(2)
	strokeLoop(p)

	-- A little mast marker so heading is obvious.
	local hx, hy = Utils.heading(self.heading)
	gfx.fillCircleAtPoint(self.x + hx * 3, self.y + hy * 3, 3)
end
