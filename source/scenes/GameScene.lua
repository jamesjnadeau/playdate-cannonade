-- GameScene.lua
-- Base class for the sailing/combat scenes (GameSceneMain, GameSceneTest).
-- Holds everything they share: ship/wind/trident physics, enemy and
-- tridentball collision handling, and all rendering. Subclasses hook in
-- their own enemy-spawning policy and extra HUD text; see updateSpawning()
-- and drawModeStatus() below. This class is never instantiated directly.

import "scripts/Config"
import "scripts/ConfigEnemy"
import "scripts/Utils"
import "scripts/Player"
import "scripts/Enemy"
import "scripts/EnemySwordfish"
import "scripts/Tridentball"

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
	self.ship = Player(0, 0)
	self.enemies = {}
	self.tridentballs = {}
	self.explosions = {}
	self.elapsed = 0
	self.score = 0
	self.gameOver = false

	local wind = self:windTuning()
	self.windSpeedChangeRateMin = wind.speedChangeRateMin
	self.windSpeedChangeRateMax = wind.speedChangeRateMax
	self.windChangeIntervalMin = wind.changeIntervalMin
	self.windChangeIntervalMax = wind.changeIntervalMax

	self.windDirection = math.random() * 360
	self.windDirectionTarget = self.windDirection
	self.windDirectionChangeRate = Config.WIND_DIRECTION_CHANGE_RATE_MIN
	self.windSpeed = Config.WIND_SPEED_MIN + math.random() * (Config.WIND_SPEED_MAX - Config.WIND_SPEED_MIN)
	self.windSpeedTarget = self.windSpeed
	self.windSpeedChangeRate = self.windSpeedChangeRateMin
	self.windChangeIntervalDuration = self.windChangeIntervalMin
		+ math.random() * (self.windChangeIntervalMax - self.windChangeIntervalMin)
	self.windChangeTimer = self.windChangeIntervalDuration

	-- Counts up (0 -> windEaseDuration) while the wind is easing toward its
	-- current targets, i.e. exactly while windChangeTimer is paused. Lets the
	-- HUD show progress toward the countdown resuming. Both start at 0 since
	-- the wind begins already settled.
	self.windEaseTimer = 0
	self.windEaseDuration = 0
	self.windSettled = true

	-- Input state
	self.trimInput = 0         -- -1 / 0 / +1 sail trim adjustment from Up/Down
	self.chargingSide = nil
	self.charge = 0
	self.target = nil
end

-- Wind speed's easing rate and how often it changes, in {speedChangeRateMin,
-- speedChangeRateMax, changeIntervalMin, changeIntervalMax}. Plain Config
-- defaults here; GameSceneMain overrides this to scale both with level, the
-- same way it scales levelTarget off Config.LEVEL_ENEMY_STEP.
function GameScene:windTuning()
	return {
		speedChangeRateMin = Config.WIND_SPEED_CHANGE_RATE_MIN,
		speedChangeRateMax = Config.WIND_SPEED_CHANGE_RATE_MAX,
		changeIntervalMin = Config.WIND_CHANGE_INTERVAL_MIN,
		changeIntervalMax = Config.WIND_CHANGE_INTERVAL_MAX,
	}
end

-- ---------------------------------------------------------------------------
-- Input (class-level handlers; callbacks defer to the current instance)
-- ---------------------------------------------------------------------------

-- The steering/trim/trident bindings every variant shares. Each subclass
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
-- Trident: charging + auto-target
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
		local speed = Config.TRIDENT_SPEED
		local hx, hy = Utils.heading(dir)
		local bx = ship.x + hx * (Config.SHIP_LENGTH + 4)
		local by = ship.y + hy * (Config.SHIP_LENGTH + 4)
		self.tridentballs[#self.tridentballs + 1] = Tridentball(bx, by, dir, speed)
	end

	self.chargingSide = nil
	self.charge = 0
	self.target = nil
end

-- Degrees of random aim error at the current charge: full spread at 0 charge,
-- narrowing to (1 - TRIDENT_MAX_ACCURACY) worth of spread once fully charged.
function GameScene:currentAimSpread()
	local accuracy = Config.TRIDENT_MAX_ACCURACY * self.charge
	return Config.TRIDENT_MAX_SPREAD * (1 - accuracy)
end

-- ---------------------------------------------------------------------------
-- Enemies
-- ---------------------------------------------------------------------------

-- Enemy classes eligible for random spawning, gated by level via each
-- class's minLevel (Enemy.minLevel / EnemySwordfish.minLevel, driven by
-- Config.ENEMY_MIN_LEVEL / Config.ENEMY_SWORDFISH_MIN_LEVEL). Add new enemy
-- types here to fold them into spawnEnemy's random pick below.
GameScene.enemyTypes = { Enemy, EnemySwordfish }

-- Spawns one enemy at a random position around the ship, picking uniformly
-- among GameScene.enemyTypes entries unlocked at self.level (self.level is
-- nil for scenes without level progression, e.g. GameSceneTest -- treated as
-- level 1). Returns whether it actually spawned one (false if already at
-- MAX_ENEMIES). Subclasses that gate spawning further (e.g. a per-level cap)
-- should override this, check their own condition, then delegate to
-- GameScene.super.spawnEnemy(self).
function GameScene:spawnEnemy()
	if #self.enemies >= Config.MAX_ENEMIES then return false end
	local ship = self.ship
	local ang = math.random() * 360
	local ax, ay = Utils.heading(ang)
	local dist = 250 + math.random() * 120 -- just beyond the screen's corner
	local ex = ship.x + ax * dist
	local ey = ship.y + ay * dist
	local facing = Utils.angleTo(ex, ey, ship.x, ship.y)

	local level = self.level or 1
	local eligible = {}
	for _, EnemyType in ipairs(GameScene.enemyTypes) do
		if level >= EnemyType.minLevel then
			eligible[#eligible + 1] = EnemyType
		end
	end
	local EnemyType = eligible[math.random(#eligible)]
	self.enemies[#self.enemies + 1] = EnemyType(ex, ey, facing)
	return true
end

-- Hook for automatic spawning; called once per tick. The base scene never
-- spawns on its own (GameSceneTest relies on this); GameSceneMain overrides
-- it to spawn on a timer.
function GameScene:updateSpawning(dt) end

function GameScene:addExplosion(ship)
	self.explosions[#self.explosions + 1] = ship:explode(self.windDirection)
end

-- Call whenever an enemy is destroyed, however it died (rammed or tridented).
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

	-- Wind wanders rather than sitting still all run: every so often it picks
	-- a new target speed and direction, then eases both toward those targets
	-- at a random rate until the next change. The countdown to the next
	-- change is paused while the current one is still easing in, so changes
	-- can't stack up faster than the ship can visibly react to them.
	local windSettled = self.windSpeed == self.windSpeedTarget
		and self.windDirection == self.windDirectionTarget
	self.windSettled = windSettled
	if windSettled then
		self.windChangeTimer = self.windChangeTimer - dt
	else
		self.windEaseTimer = math.min(self.windEaseDuration, self.windEaseTimer + dt)
	end
	if windSettled and self.windChangeTimer <= 0 then
		self.windSpeedTarget = Config.WIND_SPEED_MIN
			+ math.random() * (Config.WIND_SPEED_MAX - Config.WIND_SPEED_MIN)
		self.windSpeedChangeRate = self.windSpeedChangeRateMin
			+ math.random() * (self.windSpeedChangeRateMax - self.windSpeedChangeRateMin)

		local shift = Config.WIND_DIRECTION_CHANGE_MIN
			+ math.random() * (Config.WIND_DIRECTION_CHANGE_MAX - Config.WIND_DIRECTION_CHANGE_MIN)
		if math.random() < 0.5 then shift = -shift end
		self.windDirectionTarget = Utils.wrapDeg(self.windDirection + shift)
		self.windDirectionChangeRate = Config.WIND_DIRECTION_CHANGE_RATE_MIN
			+ math.random() * (Config.WIND_DIRECTION_CHANGE_RATE_MAX - Config.WIND_DIRECTION_CHANGE_RATE_MIN)

		self.windChangeIntervalDuration = self.windChangeIntervalMin
			+ math.random() * (self.windChangeIntervalMax - self.windChangeIntervalMin)
		self.windChangeTimer = self.windChangeIntervalDuration

		-- The countdown (windChangeTimer) freezes until speed and direction
		-- both catch up to their new targets; estimate how long that'll take
		-- from each one's distance-to-target and easing rate so the HUD can
		-- show that wait filling up (see windEaseTimer above).
		local speedEaseTime = math.abs(self.windSpeedTarget - self.windSpeed) / self.windSpeedChangeRate
		local dirEaseTime = math.abs(Utils.angleDiff(self.windDirection, self.windDirectionTarget)) / self.windDirectionChangeRate
		self.windEaseDuration = math.max(speedEaseTime, dirEaseTime)
		self.windEaseTimer = 0
	end

	if self.windSpeed < self.windSpeedTarget then
		self.windSpeed = math.min(self.windSpeedTarget, self.windSpeed + self.windSpeedChangeRate * dt)
	elseif self.windSpeed > self.windSpeedTarget then
		self.windSpeed = math.max(self.windSpeedTarget, self.windSpeed - self.windSpeedChangeRate * dt)
	end

	local dirDiff = Utils.angleDiff(self.windDirection, self.windDirectionTarget)
	local maxDirStep = self.windDirectionChangeRate * dt
	if dirDiff >= -maxDirStep and dirDiff <= maxDirStep then
		-- Snap to the exact target (like the speed clamp above) so windSettled's
		-- == check can actually become true instead of chasing float rounding forever.
		self.windDirection = self.windDirectionTarget
	else
		local dirStep = Utils.clamp(dirDiff, -maxDirStep, maxDirStep)
		self.windDirection = Utils.wrapDeg(self.windDirection + dirStep)
	end

	-- Apply sail trim (held Up/Down) and trident charge (held Left/Right).
	if self.trimInput ~= 0 then
		self.ship:adjustSailTrim(self.trimInput * Config.SAIL_TRIM_RATE * dt)
	end
	if self.chargingSide then
		self.target = self:pickTarget(self.chargingSide)
		if self.target then
			self.charge = math.min(1, self.charge + Config.TRIDENT_CHARGE_RATE * dt)
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
		e:update(ship.x, ship.y, self.windDirection, self.windSpeed)
		if Utils.dist(e.x, e.y, ship.x, ship.y) < (Config.SHIP_COLLIDE_RADIUS + e.radius) then
			self:addExplosion(e)
			table.remove(self.enemies, i)
			self:enemyDefeated()
			if ship:hit(e.damage) and ship.health <= 0 then
				self.gameOver = true
			end
		end
	end

	-- Tridentballs move and hit.
	for i = #self.tridentballs, 1, -1 do
		local b = self.tridentballs[i]
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
			table.remove(self.tridentballs, i)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

-- The world is infinite and player-centered: the camera always keeps the
-- ship dead-center on screen rather than clamping to any world bound.
function GameScene:cameraOrigin()
	local camX = self.ship.x - Config.SCREEN_W / 2
	local camY = self.ship.y - Config.SCREEN_H / 2
	return math.floor(camX), math.floor(camY)
end

function GameScene:render()
	local camX, camY = self:cameraOrigin()

	-- ---- World space (camera offset applied) ----
	gfx.setDrawOffset(-camX, -camY)

	self:drawWater(camX, camY)

	-- Wake sits under the hulls.
	self.ship:drawWake()

	for _, e in ipairs(self.enemies) do e:draw() end
	for _, b in ipairs(self.tridentballs) do b:draw() end
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

-- Integer hash (mix-then-fold) used to pick each wavelet's segment count.
-- Grid indices (not raw world coordinates) go in: world coordinates are
-- multiples of WATER_GRID / WATER_GRID/2, and a plain weighted sum of those
-- collapses to the same residue for every wavelet once the range divides
-- the grid spacing -- this scrambles the bits first so it doesn't.
local function waterHash(a, b, c)
	local h = a * 374761393 + b * 668265263 + c * 1136930381
	h = (h ~ (h >> 13)) * 1274126177
	h = h ~ (h >> 16)
	return h
end

function GameScene:drawWater(camX, camY)
	local g = Config.WATER_GRID
	local startX = math.floor(camX / g) * g
	local startY = math.floor(camY / g) * g
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(Config.WATER_WAVELET_WIDTH)

	-- Wavelets are short wave-shaped lines spanning perpendicular to the wind
	-- (real sea waves crest across the wind, not along it), with their
	-- undulation bulging along the wind axis.
	local hx, hy = Utils.heading(self.windDirection)
	local px, py = -hy, hx
	for gx = startX, camX + Config.SCREEN_W + g, g do
		local ix = math.floor(gx / g)
		for gy = startY, camY + Config.SCREEN_H + g, g do
			local iy = math.floor(gy / g)
			self:drawWavelet(gx, gy, px, py, hx, hy, ix, iy, 0)
			self:drawWavelet(gx + g / 2, gy + g / 2, px, py, hx, hy, ix, iy, 1)
		end
	end
end

-- Draws one wave-shaped wavelet centered at (cx, cy): a polyline spanning a
-- length (px) along the (px, py) axis, undulating by
-- Config.WATER_WAVELET_AMPLITUDE along the (wx, wy) axis. Length and zigzag
-- count are picked from their own [MIN, MAX] range via waterHash(ix, iy,
-- variant), so they vary per wavelet but stay stable frame to frame instead
-- of flickering. Segment count is derived from zigzags (segments-per-zigzag,
-- also hashed) rather than picked independently, so every up/down cycle
-- always gets enough points to read as a curve instead of a jagged zigzag.
-- Config.WATER_WAVELET_SPAWN_CHANCE rolls (with the same stable hash)
-- whether this slot draws anything at all.
function GameScene:drawWavelet(cx, cy, px, py, wx, wy, ix, iy, variant)
	local spawnRoll = (waterHash(ix, iy, variant + 3000) % 10000) / 10000
	if spawnRoll >= Config.WATER_WAVELET_SPAWN_CHANCE then return end

	local lenMin, lenMax = Config.WATER_WAVELET_LENGTH_MIN, Config.WATER_WAVELET_LENGTH_MAX
	local lenT = (waterHash(ix, iy, variant + 1000) % 1009) / 1009
	local length = lenMin + lenT * (lenMax - lenMin)

	local zigMin, zigMax = Config.WATER_WAVELET_ZIGZAGS_MIN, Config.WATER_WAVELET_ZIGZAGS_MAX
	local zigzags = zigMin + (waterHash(ix, iy, variant + 2000) % (zigMax - zigMin + 1))

	local spzMin, spzMax = Config.WATER_WAVELET_SEGMENTS_PER_ZIGZAG_MIN, Config.WATER_WAVELET_SEGMENTS_PER_ZIGZAG_MAX
	local segmentsPerZigzag = spzMin + (waterHash(ix, iy, variant + 4000) % (spzMax - spzMin + 1))
	local segments = zigzags * segmentsPerZigzag

	local halfLen = length / 2
	local amplitude = Config.WATER_WAVELET_AMPLITUDE
	local prevX, prevY = cx - px * halfLen, cy - py * halfLen
	for i = 1, segments do
		local t = -halfLen + length * i / segments
		local wave = amplitude * math.sin(2 * math.pi * zigzags * i / segments)
		local x = cx + px * t + wx * wave
		local y = cy + py * t + wy * wave
		gfx.drawLine(prevX, prevY, x, y)
		prevX, prevY = x, y
	end
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
-- accuracy) builds toward TRIDENT_MAX_ACCURACY.
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

-- Off-screen enemies are bucketed by on-screen direction so a cluster of
-- enemies coming from the same side draws as one (larger) arrow with a count
-- badge instead of a stack of overlapping ones. Each group also surfaces the
-- most urgent teleport countdown among its members (see Enemy:updateLeash),
-- so the player gets advance warning before an enemy relocates.
function GameScene:drawOffscreenArrows(camX, camY)
	local margin = Config.OFFSCREEN_INDICATOR_MARGIN
	local groupWindow = Config.OFFSCREEN_INDICATOR_GROUP_ANGLE
	local size = Config.OFFSCREEN_INDICATOR_SIZE
	local cx, cy = Config.SCREEN_W / 2, Config.SCREEN_H / 2
	local reach = Config.SCREEN_W + Config.SCREEN_H -- far enough to always clamp onto an edge

	local groups = {}
	for _, e in ipairs(self.enemies) do
		local sx = e.x - camX
		local sy = e.y - camY
		if sx < 0 or sx > Config.SCREEN_W or sy < 0 or sy > Config.SCREEN_H then
			local ang = Utils.angleTo(cx, cy, sx, sy)
			local hx, hy = Utils.heading(ang)

			local group = nil
			for _, g in ipairs(groups) do
				if math.abs(Utils.angleDiff(g.angle, ang)) <= groupWindow / 2 then
					group = g
					break
				end
			end
			if not group then
				group = { sumX = 0, sumY = 0, count = 0, angle = ang, warning = nil }
				groups[#groups + 1] = group
			end

			group.sumX = group.sumX + hx
			group.sumY = group.sumY + hy
			group.count = group.count + 1
			group.angle = Utils.angleTo(0, 0, group.sumX, group.sumY)
			if e.teleportWarning and (not group.warning or e.teleportWarning < group.warning) then
				group.warning = e.teleportWarning
			end
		end
	end

	gfx.setColor(gfx.kColorBlack)
	for _, g in ipairs(groups) do
		local hx, hy = Utils.heading(g.angle)
		local px = Utils.clamp(cx + hx * reach, margin, Config.SCREEN_W - margin)
		local py = Utils.clamp(cy + hy * reach, margin, Config.SCREEN_H - margin)
		self:drawArrow(px, py, g.angle, size)
		if g.count > 1 then
			gfx.drawTextAligned(tostring(g.count), px, py - size - 12, kTextAlignment.center)
		end
		if g.warning then
			gfx.drawTextAligned(tostring(math.ceil(g.warning)), px, py + size + 2, kTextAlignment.center)
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
		local x = Config.HUD_HEART_MARGIN_X + (i - 1) * Config.HUD_HEART_SPACING
		local heart = (i <= self.ship.health) and "❤️" or "🤍"
		gfx.drawText(heart, x, Config.HUD_HEART_MARGIN_Y)
	end

	-- Speed gauge (bottom-left)
	if Config.HUD_SHOW_PLAYER_SPEED then
		local gw, gh = 90, 8
		local gx, gy = 6, Config.SCREEN_H - 16
		gfx.drawText(string.format("%d px/s", math.floor(self.ship.speed + 0.5)), gx + 10, gy - 16)
	end
end

-- Hook for whatever status text belongs in the top-right (level progress,
-- test-mode hints, ...). The base scene shows nothing.
function GameScene:drawModeStatus() end

-- Bottom-right compass showing which way the wind currently blows.
function GameScene:drawWindIndicator()
	local cx, cy = Config.SCREEN_W - 26, Config.SCREEN_H - 30
	gfx.setColor(gfx.kColorBlack)
	if Config.HUD_SHOW_WIND_SPEED then
		gfx.drawTextAligned(string.format("%d px/s", math.floor(self.windSpeed + 0.5)),
			cx - Config.WIND_INDICATOR_CIRCLE_SIZE - 4, cy - 8, kTextAlignment.right)
	end
	if Config.HUD_SHOW_WIND_DIRECTION then
		gfx.drawCircleAtPoint(cx, cy, Config.WIND_INDICATOR_CIRCLE_SIZE)
		self:drawArrow(cx, cy, self.windDirection, Config.WIND_INDICATOR_SIZE)
	end
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
