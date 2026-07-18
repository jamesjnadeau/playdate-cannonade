-- GameScene.lua
-- Base class for the sailing/combat scenes (GameSceneMain, GameSceneTest).
-- Holds everything they share: ship/wind/cannon physics, enemy and
-- cannonball collision handling, and all rendering. Subclasses hook in
-- their own enemy-spawning policy and extra HUD text; see updateSpawning()
-- and drawModeStatus() below. This class is never instantiated directly.

import "scripts/Config"
import "scripts/Utils"
import "scripts/Player"
import "scripts/Enemy"
import "scripts/Cannonball"

local gfx <const> = playdate.graphics

GameScene = {}
class("GameScene").extends(NobleScene)

-- File-local handle to the live scene so the (class-level) inputHandler
-- callbacks -- in this class and in subclasses -- can talk to the current
-- instance. GameScene.current() is the accessor subclasses should use.
local scene = nil

function GameScene.current()
	return scene
end

-- Remove every particle system the library is tracking. Guarded so a version
-- mismatch in the library's global API can't hard-crash the scene (worst case:
-- a small leak of spent systems across restarts).
local function clearAllParticles()
	if Particles then
		if Particles.removeAll then
			Particles:removeAll()
		elseif Particles.clearAll then
			Particles:clearAll()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

-- Build all game state in init() (runs before the scene's first update()).
-- Noble may call update() during the tail of a scene transition, before
-- start() fires, so nothing here may be left until start().
function GameScene:init(sceneProperties)
	GameScene.super.init(self, sceneProperties)
	self.backgroundColor = gfx.kColorWhite
	scene = self
	self:resetGame(sceneProperties)
end

function GameScene:start()
	GameScene.super.start(self)
	scene = self
	Noble.Input.setCrankIndicatorStatus(true) -- prompt the player to use the crank
end

function GameScene:finish()
	GameScene.super.finish(self)
	clearAllParticles() -- drop every particle system this scene created
	if scene == self then scene = nil end
end

-- Generic state every variant needs. Subclasses that track anything extra
-- (level progress, spawn timers, ...) should override this, call
-- GameScene.super.resetGame(self, sceneProperties) first, then add their own.
function GameScene:resetGame(sceneProperties)
	sceneProperties = sceneProperties or {}
	clearAllParticles()
	self.ship = Player(Config.WORLD_W / 2, Config.WORLD_H / 2)
	self.enemies = {}
	self.cannonballs = {}
	self.explosions = {}
	self.elapsed = 0
	self.score = 0
	self.gameOver = false

	self.windDirection = math.random() * 360
	self.windSpeed = Config.WIND_SPEED

	-- Input state
	self.trimInput = 0         -- -1 / 0 / +1 sail trim adjustment from Up/Down
	self.chargingSide = nil
	self.charge = 0
	self.target = nil
end

-- ---------------------------------------------------------------------------
-- Input (class-level handlers; callbacks defer to the current instance)
-- ---------------------------------------------------------------------------

-- The steering/trim/cannon bindings every variant shares. Each subclass
-- builds its own inputHandler from this (input tables don't merge through
-- inheritance the way methods do) and adds its own A/B bindings on top.
-- `getScene` should return the currently-active instance -- pass
-- GameScene.current.
function GameScene.buildSharedInputHandler(getScene)
	return {
		-- Crank steers the helm.
		cranked = function(change, _)
			local s = getScene()
			if s and not s.gameOver then s.ship:steer(change) end
		end,
		-- Up/Down set a persistent sail-trim flag; the tick applies it each
		-- frame. Up lets the sail out, Down trims it in.
		upButtonDown = function()
			local s = getScene()
			if s then s.trimInput = 1 end
		end,
		upButtonUp = function()
			local s = getScene()
			if s and s.trimInput == 1 then s.trimInput = 0 end
		end,
		downButtonDown = function()
			local s = getScene()
			if s then s.trimInput = -1 end
		end,
		downButtonUp = function()
			local s = getScene()
			if s and s.trimInput == -1 then s.trimInput = 0 end
		end,
		-- Left/Right begin charging a broadside; release fires.
		leftButtonDown = function()
			local s = getScene()
			if s and not s.gameOver then s:beginCharge("port") end
		end,
		leftButtonUp = function()
			local s = getScene()
			if s then s:releaseCharge("port") end
		end,
		rightButtonDown = function()
			local s = getScene()
			if s and not s.gameOver then s:beginCharge("starboard") end
		end,
		rightButtonUp = function()
			local s = getScene()
			if s then s:releaseCharge("starboard") end
		end,
	}
end

-- ---------------------------------------------------------------------------
-- Cannon: charging + auto-target
-- ---------------------------------------------------------------------------

function GameScene:beginCharge(side)
	self.chargingSide = side
	self.charge = 0
	self.target = self:pickTarget(side)
end

-- Choose the nearest enemy on the given side, within targeting range.
function GameScene:pickTarget(side)
	local ship = self.ship
	local fx, fy = Utils.heading(ship.heading)
	local best, bestD2 = nil, Config.TARGET_RANGE * Config.TARGET_RANGE
	for _, e in ipairs(self.enemies) do
		local dx, dy = e.x - ship.x, e.y - ship.y
		local cross = fx * dy - fy * dx      -- >0 starboard, <0 port
		local onSide = (side == "starboard" and cross > 0) or (side == "port" and cross < 0)
		if onSide then
			local d2 = dx * dx + dy * dy
			if d2 < bestD2 then
				bestD2 = d2
				best = e
			end
		end
	end
	return best
end

function GameScene:releaseCharge(side)
	if self.chargingSide ~= side then return end
	if not self.gameOver then
		local ship = self.ship
		local dir
		local target = self.target or self:pickTarget(side)
		if target then
			dir = Utils.angleTo(ship.x, ship.y, target.x, target.y)
		else
			-- Nothing to lock onto: fire a broadside straight out that side.
			dir = Utils.wrapDeg(ship.heading + (side == "starboard" and 90 or -90))
		end
		-- Charging steadies the aim: accuracy ramps up to 99% at full charge,
		-- so an undercharged shot can still stray wide of the target.
		dir = Utils.wrapDeg(dir + (math.random() * 2 - 1) * self:currentAimSpread())
		local speed = Config.CANNON_SPEED
		local hx, hy = Utils.heading(dir)
		local bx = ship.x + hx * (Config.SHIP_LENGTH + 4)
		local by = ship.y + hy * (Config.SHIP_LENGTH + 4)
		self.cannonballs[#self.cannonballs + 1] = Cannonball(bx, by, dir, speed)
	end

	self.chargingSide = nil
	self.charge = 0
	self.target = nil
end

-- Degrees of random aim error at the current charge: full spread at 0 charge,
-- narrowing to (1 - CANNON_MAX_ACCURACY) worth of spread once fully charged.
function GameScene:currentAimSpread()
	local accuracy = Config.CANNON_MAX_ACCURACY * self.charge
	return Config.CANNON_MAX_SPREAD * (1 - accuracy)
end

-- ---------------------------------------------------------------------------
-- Enemies
-- ---------------------------------------------------------------------------

-- Spawns one enemy at a random position around the ship. Returns whether it
-- actually spawned one (false if already at MAX_ENEMIES). Subclasses that
-- gate spawning further (e.g. a per-level cap) should override this, check
-- their own condition, then delegate to GameScene.super.spawnEnemy(self).
function GameScene:spawnEnemy()
	if #self.enemies >= Config.MAX_ENEMIES then return false end
	local ship = self.ship
	local ang = math.random() * 360
	local ax, ay = Utils.heading(ang)
	local dist = 250 + math.random() * 120 -- just beyond the screen's corner
	local ex = Utils.clamp(ship.x + ax * dist, 0, Config.WORLD_W)
	local ey = Utils.clamp(ship.y + ay * dist, 0, Config.WORLD_H)
	local facing = Utils.angleTo(ex, ey, ship.x, ship.y)
	self.enemies[#self.enemies + 1] = Enemy(ex, ey, facing)
	return true
end

-- Hook for automatic spawning; called once per tick. The base scene never
-- spawns on its own (GameSceneTest relies on this); GameSceneMain overrides
-- it to spawn on a timer.
function GameScene:updateSpawning(dt) end

function GameScene:addExplosion(ship)
	self.explosions[#self.explosions + 1] = ship:explode()
end

-- Call whenever an enemy is destroyed, however it died (rammed or cannoned).
-- Subclasses that track further progress (level kills, ...) should override
-- this and call GameScene.super.enemyDefeated(self) first.
function GameScene:enemyDefeated()
	self.score = self.score + 1
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function GameScene:update()
	GameScene.super.update(self)

	if not self.gameOver then
		self:tickGame()
	end

	self:render()
end

function GameScene:tickGame()
	local dt = Config.DT
	self.elapsed = self.elapsed + dt

	-- Wind wanders slowly rather than sitting still all run.
	self.windDirection = Utils.wrapDeg(
		self.windDirection + (math.random() * 2 - 1) * Config.WIND_DIRECTION_DRIFT_RATE * dt)

	-- Apply sail trim (held Up/Down) and cannon charge (held Left/Right).
	if self.trimInput ~= 0 then
		self.ship:adjustSailTrim(self.trimInput * Config.SAIL_TRIM_RATE * dt)
	end
	if self.chargingSide then
		self.target = self:pickTarget(self.chargingSide)
		if self.target then
			self.charge = math.min(1, self.charge + Config.CHARGE_RATE * dt)
		else
			-- Nothing in range on this side: charge can't steady an aim that
			-- has nothing to lock onto.
			self.charge = 0
		end
	end

	self.ship:update(self.windDirection, self.windSpeed)

	self:updateSpawning(dt)

	-- Enemies chase; check ramming.
	local ship = self.ship
	for i = #self.enemies, 1, -1 do
		local e = self.enemies[i]
		e:update(ship.x, ship.y)
		if Utils.dist(e.x, e.y, ship.x, ship.y) < (Config.SHIP_COLLIDE_RADIUS + e.radius) then
			self:addExplosion(e)
			table.remove(self.enemies, i)
			self:enemyDefeated()
			if ship:hit(Config.ENEMY_DAMAGE) and ship.health <= 0 then
				self.gameOver = true
			end
		end
	end

	-- Cannonballs move and hit.
	for i = #self.cannonballs, 1, -1 do
		local b = self.cannonballs[i]
		b:update()
		local hit = false
		for j = #self.enemies, 1, -1 do
			local e = self.enemies[j]
			if Utils.dist(b.x, b.y, e.x, e.y) < (b.radius + e.radius) then
				self:addExplosion(e)
				table.remove(self.enemies, j)
				self:enemyDefeated()
				hit = true
				break
			end
		end
		if hit or b.dead then
			table.remove(self.cannonballs, i)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

function GameScene:cameraOrigin()
	local camX = Utils.clamp(self.ship.x - Config.SCREEN_W / 2, 0, Config.WORLD_W - Config.SCREEN_W)
	local camY = Utils.clamp(self.ship.y - Config.SCREEN_H / 2, 0, Config.WORLD_H - Config.SCREEN_H)
	return math.floor(camX), math.floor(camY)
end

function GameScene:render()
	local camX, camY = self:cameraOrigin()

	-- ---- World space (camera offset applied) ----
	gfx.setDrawOffset(-camX, -camY)

	self:drawWater(camX, camY)

	-- Wake sits under the hulls.
	self.ship.wake:update()

	for _, e in ipairs(self.enemies) do e:draw() end
	for _, b in ipairs(self.cannonballs) do b:draw() end
	self.ship:draw()

	-- Explosions on top, then prune spent systems (age cap as a safety net).
	for i = #self.explosions, 1, -1 do
		local ex = self.explosions[i]
		ex.sys:update()
		ex.age = ex.age + 1
		if #ex.sys:getParticles() == 0 or ex.age > ex.maxAge then
			ex.sys:remove()
			table.remove(self.explosions, i)
		end
	end

	-- ---- Screen space (HUD) ----
	gfx.setDrawOffset(0, 0)
	self:drawTargetingLine(camX, camY)
	self:drawOffscreenArrows(camX, camY)
	self:drawHUD()
	self:drawModeStatus()
	self:drawWindIndicator()
	if self.gameOver then self:drawGameOver() end
end

function GameScene:drawWater(camX, camY)
	local g = Config.WATER_GRID
	local startX = math.floor(camX / g) * g
	local startY = math.floor(camY / g) * g
	gfx.setColor(gfx.kColorBlack)
	for gx = startX, camX + Config.SCREEN_W + g, g do
		for gy = startY, camY + Config.SCREEN_H + g, g do
			-- Little staggered wavelets for a sea texture.
			gfx.fillRect(gx, gy, 2, 1)
			gfx.fillRect(gx + g / 2, gy + g / 2, 2, 1)
		end
	end

	-- Map boundary so the edge of the world is legible.
	gfx.setLineWidth(4)
	gfx.drawRect(0, 0, Config.WORLD_W, Config.WORLD_H)
end

function GameScene:drawTargetingLine(camX, camY)
	if not self.chargingSide then return end
	if not self.target then
		self:drawNoTargetMark(camX, camY, self.chargingSide)
		return
	end
	local sx = self.ship.x - camX
	local sy = self.ship.y - camY
	local tx = self.target.x - camX
	local ty = self.target.y - camY
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(1)
	Utils.drawDottedLine(sx, sy, tx, ty, 4, 4)
	-- Reticle around the locked target.
	gfx.drawCircleAtPoint(tx, ty, self.target.radius + 6)
	gfx.drawCircleAtPoint(tx, ty, self.target.radius + 2)

	self:drawAimLines(sx, sy, tx, ty)
end

-- Lazily-built image for the "nothing in range" indicator; text images are
-- cheap to cache since the string never changes.
local noTargetMarkImage = nil
local function getNoTargetMarkImage()
	if not noTargetMarkImage then
		noTargetMarkImage = gfx.imageWithText("?", 40, 40)
	end
	return noTargetMarkImage
end

-- Shown on whichever side the player is charging when no enemy is in range
-- on that side, at Config.NO_TARGET_MARK_OFFSET from the ship and scaled to
-- Config.NO_TARGET_MARK_SIZE.
function GameScene:drawNoTargetMark(camX, camY, side)
	local ship = self.ship
	local perp = Utils.wrapDeg(ship.heading + (side == "starboard" and 90 or -90))
	local hx, hy = Utils.heading(perp)
	local wx = ship.x + hx * Config.NO_TARGET_MARK_OFFSET
	local wy = ship.y + hy * Config.NO_TARGET_MARK_OFFSET
	local sx = wx - camX
	local sy = wy - camY

	local img = getNoTargetMarkImage()
	local iw, ih = img:getSize()
	local scale = Config.NO_TARGET_MARK_SIZE / ih
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	img:drawScaled(sx - (iw * scale) / 2, sy - (ih * scale) / 2, scale)
end

-- Two short lines near the ship show live aim spread: wide apart while
-- undercharged, converging onto the dotted target line as charge (and thus
-- accuracy) builds toward CANNON_MAX_ACCURACY.
function GameScene:drawAimLines(sx, sy, tx, ty)
	local dir = Utils.angleTo(sx, sy, tx, ty)
	local spread = self:currentAimSpread()
	gfx.setLineWidth(Config.AIM_LINE_WIDTH)
	for _, sign in ipairs({ -1, 1 }) do
		local hx, hy = Utils.heading(dir + sign * spread)
		gfx.drawLine(sx, sy, sx + hx * Config.AIM_LINE_LENGTH, sy + hy * Config.AIM_LINE_LENGTH)
	end
	gfx.setLineWidth(1)
end

function GameScene:drawOffscreenArrows(camX, camY)
	local margin = 14
	local cx, cy = Config.SCREEN_W / 2, Config.SCREEN_H / 2
	gfx.setColor(gfx.kColorBlack)
	for _, e in ipairs(self.enemies) do
		local sx = e.x - camX
		local sy = e.y - camY
		if sx < 0 or sx > Config.SCREEN_W or sy < 0 or sy > Config.SCREEN_H then
			local ang = Utils.angleTo(cx, cy, sx, sy)
			local px = Utils.clamp(sx, margin, Config.SCREEN_W - margin)
			local py = Utils.clamp(sy, margin, Config.SCREEN_H - margin)
			self:drawArrow(px, py, ang, 9)
		end
	end
end

function GameScene:drawArrow(px, py, angleDeg, size)
	local hx, hy = Utils.heading(angleDeg)
	-- perpendicular
	local rx, ry = -hy, hx
	local tipx, tipy = px + hx * size, py + hy * size
	local b1x, b1y = px - hx * size * 0.4 + rx * size * 0.6, py - hy * size * 0.4 + ry * size * 0.6
	local b2x, b2y = px - hx * size * 0.4 - rx * size * 0.6, py - hy * size * 0.4 - ry * size * 0.6
	gfx.fillTriangle(tipx, tipy, b1x, b1y, b2x, b2y)
end

function GameScene:drawHUD()
	gfx.setImageDrawMode(gfx.kDrawModeCopy)

	-- Health pips (top-left)
	for i = 1, Config.SHIP_MAX_HEALTH do
		local x = 6 + (i - 1) * 12
		gfx.setColor(gfx.kColorBlack)
		if i <= self.ship.health then
			gfx.fillRect(x, 6, 9, 9)
		else
			gfx.drawRect(x, 6, 9, 9)
		end
	end

	-- Speed gauge (bottom-left)
	local gw, gh = 90, 8
	local gx, gy = 6, Config.SCREEN_H - 16
	gfx.drawText("SPEED", gx, gy - 16)
	gfx.drawRect(gx, gy, gw, gh)
	local fill = (self.ship.speed / Config.SHIP_MAX_SPEED) * (gw - 2)
	gfx.fillRect(gx + 1, gy + 1, fill, gh - 2)
end

-- Hook for whatever status text belongs in the top-right (level progress,
-- test-mode hints, ...). The base scene shows nothing.
function GameScene:drawModeStatus() end

-- Bottom-right compass showing which way the wind currently blows.
function GameScene:drawWindIndicator()
	local cx, cy = Config.SCREEN_W - 26, Config.SCREEN_H - 30
	gfx.setColor(gfx.kColorBlack)
	gfx.drawText("WIND", Config.SCREEN_W - 46, Config.SCREEN_H - 50)
	gfx.drawCircleAtPoint(cx, cy, Config.WIND_INDICATOR_CIRCLE_SIZE)
	self:drawArrow(cx, cy, self.windDirection, Config.WIND_INDICATOR_SIZE)
end

function GameScene:drawGameOver()
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(60, 80, Config.SCREEN_W - 120, 80)
	gfx.setColor(gfx.kColorWhite)
	gfx.drawRect(62, 82, Config.SCREEN_W - 124, 76)
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	gfx.drawTextAligned("SUNK!", Config.SCREEN_W / 2, 96, kTextAlignment.center)
	gfx.drawTextAligned("Plunder: " .. self.score, Config.SCREEN_W / 2, 116, kTextAlignment.center)
	gfx.drawTextAligned(self:gameOverPrompt(), Config.SCREEN_W / 2, 134, kTextAlignment.center)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- What to tell the player to do once sunk; each mode's A/B bindings mean
-- something different, so this can't be one fixed string.
function GameScene:gameOverPrompt()
	return "Ⓐ to set sail again"
end
