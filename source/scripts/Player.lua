-- Player.lua
-- The player-controlled pirate ship.

import "scripts/Config"
import "scripts/Utils"
import "scripts/Ship"

local gfx <const> = playdate.graphics

class("Player").extends(Ship)

function Player:init(x, y)
	Player.super.init(self, x, y, -90) -- start pointing "north"
	self.speed = 0
	self.health = Config.SHIP_MAX_HEALTH
	self.invuln = 0
	self.length = Config.SHIP_LENGTH
	self.color = gfx.kColorWhite
	self.outlineColor = gfx.kColorBlack
	self.sailTrim = Config.SAIL_TRIM_START
	self.windDirection = 0

	local L, B = Config.SHIP_LENGTH, Config.SHIP_BEAM
	self.hull = { L, 0,  -L * 0.7, B,  -L, B * 0.55,  -L, -B * 0.55,  -L * 0.7, -B }

	self.wake = ParticleCircle(x, y)
	self.wake:setMode(Particles.modes.DECAY)
	self.wake:setSize(2, 4)
	self.wake:setDecay(0.35)
	self.wake:setSpeed(1, 3)
	self.wake:setColor(gfx.kColorBlack)
end

function Player:steer(crankChange)
	self.heading = Utils.wrapDeg(self.heading + crankChange * Config.SHIP_TURN_SCALE)
end

-- Lets out or hauls in the main line; delta is trim units (see
-- Config.SAIL_TRIM_RATE), positive = let out (more slack), negative = haul
-- in. This only ever changes how far the boom is ALLOWED to swing -- see
-- sailAngle() for where it actually ends up.
function Player:adjustSailTrim(delta)
	self.sailTrim = Utils.clamp(self.sailTrim + delta, 0, 1)
end

-- The boom's current world-space angle. The main line doesn't aim the sail
-- at the wind -- it only limits how far the boom can swing out from the
-- centerline. Wherever the wind would push a totally free boom (capped at
-- the rigging limit, since it can't swing forward past abeam) is where the
-- boom sits, right up until the main line is hauled in far enough to start
-- holding it in tighter than that -- only then does trimming in actually
-- move the sail. Shared by the physics and the drawing code so they never
-- disagree on where the sail actually is.
function Player:sailAngle()
	local aft = Utils.wrapDeg(self.heading + 180)
	local freeOffset = Utils.clamp(Utils.angleDiff(aft, self.windDirection),
		-Config.SAIL_MAX_ANGLE, Config.SAIL_MAX_ANGLE)
	local sheetLimit = Config.SAIL_MAX_ANGLE * self.sailTrim
	local sign = freeOffset >= 0 and 1 or -1
	local offset = sign * math.min(math.abs(freeOffset), sheetLimit)
	return Utils.wrapDeg(aft + offset)
end

-- How much of the wind's push the sail catches: zero when the sail lies
-- parallel to the wind (luffing, no surface presented to catch it), peaking
-- as it swings broadside (perpendicular) to the wind.
local function sailPower(sailAngle, windDirection)
	local angleToWind = Utils.angleDiff(sailAngle, windDirection)
	return math.abs(math.sin(Utils.deg2rad(angleToWind)))
end

function Player:update(windDirection, windSpeed)
	local dt = Config.DT
	if self.invuln > 0 then self.invuln = self.invuln - dt end
	self.windDirection = windDirection

	-- Wind only ever adds on top of the guaranteed baseline speed, so a bad
	-- point of sail (or a slack, luffing sail) never stalls the ship or
	-- pushes it backwards -- it just forgoes the bonus. Trim's whole effect
	-- runs through sailAngle() (the main line limits the boom's angle); it's
	-- not double-counted as a separate multiplier here.
	local windBoost = math.max(0, sailPower(self:sailAngle(), windDirection) * windSpeed)
	local targetSpeed = Utils.clamp(Config.SHIP_DEFAULT_SPEED + windBoost, 0, Config.SHIP_MAX_SPEED)
	if self.speed < targetSpeed then
		self.speed = math.min(targetSpeed, self.speed + Config.SHIP_ACCEL * dt)
	else
		self.speed = math.max(targetSpeed, self.speed - Config.SHIP_ACCEL * dt)
	end

	local hx, hy = Utils.heading(self.heading)
	self.x = self.x + hx * self.speed * dt
	self.y = self.y + hy * self.speed * dt

	if self.speed > 8 then
		local sx, sy = self:sternPosition()
		self.wake:moveTo(sx, sy)
		local back = math.floor(Utils.wrapDeg(self.heading + 180))
		self.wake:setSpread(back - 22, back + 22)
		self.wake:add(self.speed > 70 and 2 or 1)
	end
end

function Player:hit(damage)
	if self.invuln > 0 then return false end
	Player.super.hit(self, damage)
	self.invuln = 1.0
	return true
end

function Player:drawSail()
	local hx, hy = Utils.heading(self:sailAngle())
	local tipX, tipY = self.x + hx * Config.SAIL_LENGTH, self.y + hy * Config.SAIL_LENGTH

	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(2)
	gfx.drawLine(self.x, self.y, tipX, tipY)

	-- Main line (mainsheet): runs from the stern to the end of the boom.
	local sx, sy = self:sternPosition()
	gfx.setLineWidth(1)
	gfx.drawLine(sx, sy, tipX, tipY)
end

function Player:draw()
	if self.invuln > 0 and (math.floor(self.invuln * 12) % 2 == 0) then
		return
	end
	self:drawSail()
	Player.super.draw(self)

	local hx, hy = Utils.heading(self.heading)
	gfx.fillCircleAtPoint(self.x + hx * 3, self.y + hy * 3, 3)
end