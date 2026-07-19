-- Ship.lua
-- Base class for all ships (player and enemy).

import "scripts/Config"
import "scripts/Utils"

local gfx <const> = playdate.graphics

class("Ship").extends()

-- Default explosion look for every ship; subclasses can overwrite the whole
-- table (Enemy.explosionConfig = {...}) or set self.explosionConfig in init()
-- to override just this instance.
Ship.explosionConfig = Config.EXPLOSION

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

local function strokeLoop(p)
	local n = #p // 2
	for i = 1, n do
		local j = (i % n) + 1
		gfx.drawLine(p[i * 2 - 1], p[i * 2], p[j * 2 - 1], p[j * 2])
	end
end

function Ship:init(x, y, heading)
	self.x = x
	self.y = y 
	self.heading = heading or 0
	self.alive = true
end

function Ship:sternPosition()
	local hx, hy = Utils.heading(self.heading)
	return self.x - hx * self.length, self.y - hy * self.length
end

-- The widest point of the hull (where the beam points sit in self.hull),
-- 0.7 * length back from the bow -- see the hull point tables in
-- Player:init/Enemy:init. An optional sideOffset shifts the point
-- perpendicular to the heading (positive = to port), landing it on the
-- port/starboard edge of the hull instead of the centerline.
function Ship:beamPosition(sideOffset)
	sideOffset = sideOffset or 0
	local hx, hy = Utils.heading(self.heading)
	local bx = self.x - hx * self.length * 0.7
	local by = self.y - hy * self.length * 0.7
	return bx - hy * sideOffset, by + hx * sideOffset
end

function Ship:update()
	-- Subclasses should override this method.
end

-- Eases self.speed toward targetSpeed at accel px/s^2, then applies water
-- friction: a continuous drag that bleeds off Config.SHIP_WATER_FRICTION of
-- the current speed every second, shared by every ship (see Player:update,
-- Enemy:update). Any speed above Config.SHIP_MAX_SPEED (e.g. from a wind
-- boost) also bleeds off extra drag at Config.SHIP_OVERSPEED_FRICTION per
-- pixel/second over the max.
function Ship:updateSpeed(targetSpeed, accel, dt)
	if self.speed < targetSpeed then
		self.speed = math.min(targetSpeed, self.speed + accel * dt)
	else
		self.speed = math.max(targetSpeed, self.speed - accel * dt)
	end
	self.speed = math.max(0, self.speed - self.speed * Config.SHIP_WATER_FRICTION * dt)
	local overspeed = self.speed - Config.SHIP_MAX_SPEED
	if overspeed > 0 then
		self.speed = self.speed - overspeed * Config.SHIP_OVERSPEED_FRICTION * dt
	end
end

function Ship:hit(damage)
	self.health = self.health - damage
	if self.health <= 0 then
		self.alive = false
	end
end

function Ship:explosionOrigin()
	return self.x, self.y
end

-- Spawns this ship's explosion particle system and returns the record the
-- scene tracks to update/prune it: { sys, age, maxAge }. windDirection, if
-- given, bends the spread arc toward the way the wind is blowing (debris and
-- smoke drift downwind) -- see Config.EXPLOSION_WIND_INFLUENCE.
function Ship:explode(windDirection)
	local cfg = self.explosionConfig
	local x, y = self:explosionOrigin()
	local sys = ParticleCircle(x, y)
	sys:setMode(cfg.mode)
	if cfg.mode == Particles.modes.DECAY then
		sys:setDecay(cfg.decay)
	end
	sys:setSize(cfg.size[1], cfg.size[2])
	sys:setSpeed(cfg.speed[1], cfg.speed[2])

	local spreadMin, spreadMax = cfg.spread[1], cfg.spread[2]
	if windDirection then
		local width = spreadMax - spreadMin
		local center = math.floor(Utils.wrapDeg((spreadMin + spreadMax) / 2
			+ Utils.angleDiff((spreadMin + spreadMax) / 2, windDirection) * Config.EXPLOSION_WIND_INFLUENCE))
		spreadMin, spreadMax = center - width / 2, center + width / 2
	end
	sys:setSpread(spreadMin, spreadMax)

	sys:setLifespan(cfg.lifespan[1], cfg.lifespan[2])
	sys:setColor(cfg.color)
	sys:add(cfg.count)
	return { sys = sys, age = 0, maxAge = cfg.maxAge }
end

function Ship:draw()
	if not self.alive then return end
	local p = rotatePts(self.hull, self.heading, self.x, self.y)
	gfx.setColor(self.color)
	fillFan(p)
	if self.outlineColor then
		gfx.setColor(self.outlineColor)
		gfx.setLineWidth(2)
		strokeLoop(p) 
	end
end