-- EnemyBlueWhale.lua
-- An ambush Enemy variant that never chases: instead of Enemy:update's
-- continuous homing turn, it cycles through five states (see
-- EnemyBlueWhale:update) --
--   "submerged": invisible and harmless (self.radius pinned to 0, so neither
--     ramming nor tridents/Storm Cloud/lightning can touch it), for
--     Config.ENEMY_BLUE_WHALE_SUBMERGE_TIME seconds
--   "warning":   still invisible, but draws a dithered circle at the spot
--     it's about to surface that darkens over Config.ENEMY_BLUE_WHALE_WARN_TIME
--     seconds as the surfacing gets closer -- see EnemyBlueWhale:drawWarningCircle
--   "breaching": teleports to that spot (so the animation plays in the right
--     place) and plays the rising/splash portion of the whaleLoopFrames
--     animation over Config.ENEMY_BLUE_WHALE_BREACH_TIME seconds -- still
--     harmless, so the telegraph circle and the hit never visually overlap
--   "surfaced":  throws anything within Config.ENEMY_BLUE_WHALE_ATTACK_RADIUS
--     outward (see EnemyBlueWhale:onRamHit), then sits there holding the
--     animation's peak splash frame, visible and vulnerable (like any other
--     enemy) for Config.ENEMY_BLUE_WHALE_SURFACE_TIME seconds
--   "diving":    plays the sinking portion of the same animation over
--     Config.ENEMY_BLUE_WHALE_DIVE_TIME seconds, harmless again, before going
--     back to "submerged" --
-- at which point it retargets wherever the player is at that moment and
-- repeats. All tuning lives in Config.ENEMY_BLUE_WHALE_* (see ConfigEnemy.lua).
--
-- Drawn as an animated sprite (see EnemyBlueWhale:currentLoopFrame/:draw)
-- during "breaching"/"surfaced"/"diving" -- this never goes through
-- Ship:draw/buildBodyImage the way every other Enemy subclass does, since
-- the body isn't a single rigid pose that just rotates with heading, it
-- changes over time. drawBodyLocal/bodyRadius (below) are kept only as the
-- static reference pose EnemySelectScene's preview pane bakes via
-- Ship:buildBodyImage (see EnemySelectScene.lua) -- same split
-- EnemySeaSerpent.lua uses for the same reason.

import "scripts/config/Config"
import "scripts/config/ConfigEnemy"
import "scripts/utilities/Utils"
import "scripts/enemies/Enemy"

local gfx <const> = playdate.graphics

-- Sprite for drawBodyLocal -- see tools/render-blue-whale.sh for how this was
-- derived from art-src/blue_whale.png (background removal, trim, and a 90
-- rotation so the nose points along local +x, this game's heading-0
-- convention). Baked at exactly 2x Config.ENEMY_BLUE_WHALE_LENGTH x 2x BEAM's
-- current defaults (80x36) so the drawScaled call in drawBodyLocal is an
-- identity scale unless those Config values are actually customized away
-- from that default -- same reasoning as StormCloud.lua's cloudImage sitting
-- at exactly Config.STORM_CLOUD_WIDTH x HEIGHT.
local whaleImage = gfx.image.new("assets/images/blue-whale")
assert(whaleImage, "missing assets/images/blue-whale")
local whaleImageWidth, whaleImageHeight = whaleImage:getSize()

-- Live breach/dive animation -- see tools/render-blue-whale-loop.sh for how
-- this was derived from art-src/blue-whale.mp4 (per-frame background
-- removal into real alpha, no rotate -- the splash pose isn't a "nose
-- forward" shape like whaleImage above, so it's just rotated by self.heading
-- like everything else at draw time). WHALE_LOOP_FPS must match that
-- script's --fps. whalePauseFrame is the frame (1-based) landing at
-- Config.ENEMY_BLUE_WHALE_BREACH_TIME seconds in -- the render script pins
-- BREACH_TIME and --fps together so this lands exactly on the source video's
-- full-splash peak (2.0s in) rather than some frame either side of it.
local WHALE_LOOP_FPS = 10
local whaleLoopFrames = gfx.imagetable.new("assets/images/blue-whale-loop")
assert(whaleLoopFrames, "missing assets/images/blue-whale-loop")
local whaleLoopFrameCount = whaleLoopFrames:getLength()
local whalePauseFrame = math.floor(Config.ENEMY_BLUE_WHALE_BREACH_TIME * WHALE_LOOP_FPS + 0.5) + 1

---@class EnemyBlueWhale : Enemy
---@field state string "submerged" | "warning" | "breaching" | "surfaced" | "diving" -- see EnemyBlueWhale:update
---@field stateTimer number seconds remaining in the current state
---@field targetX number world-space x it will next surface at (or last surfaced at)
---@field targetY number world-space y it will next surface at (or last surfaced at)
---@field justSurfaced boolean true for the single tick it transitions into "surfaced", see EnemyBlueWhale:collidesWithShip
EnemyBlueWhale = class("EnemyBlueWhale").extends(Enemy) or EnemyBlueWhale

-- Unlocked starting this level (see Config.ENEMY_BLUE_WHALE_MIN_LEVEL /
-- Enemy.minLevel / GameScene:spawnEnemy).
EnemyBlueWhale.minLevel = Config.ENEMY_BLUE_WHALE_MIN_LEVEL

-- See Enemy.displayName.
EnemyBlueWhale.displayName = "Blue Whale"

---@param x number
---@param y number
---@param heading? number
function EnemyBlueWhale:init(x, y, heading)
	EnemyBlueWhale.super.init(self, x, y, heading)

	self.length = Config.ENEMY_BLUE_WHALE_LENGTH
	self.healthBarOffset = Config.ENEMY_BLUE_WHALE_HEALTH_BAR_OFFSET
	self.color = Config.ENEMY_BLUE_WHALE_COLOR
	self.outlineColor = Config.ENEMY_BLUE_WHALE_OUTLINE_COLOR
	self.health = Config.ENEMY_BLUE_WHALE_HEALTH
	self.maxHealth = self.health
	self.damage = Config.ENEMY_BLUE_WHALE_DAMAGE
	self.speed = 0

	-- Starts submerged (invisible, uncollidable) rather than mid-attack, same
	-- as it'll be after every future breathing spell -- see :update.
	self.radius = 0
	self.state = "submerged"
	self.stateTimer = Config.ENEMY_BLUE_WHALE_SUBMERGE_TIME
	self.targetX, self.targetY = x, y
	self.justSurfaced = false
end

-- See Enemy:previewStats -- it doesn't chase, so moveSpeed/accel/turnRate
-- (inherited but unused by :update below) would be misleading; report 0s
-- instead of whatever Enemy:init happened to default them to.
---@return number moveSpeed
---@return number accel
---@return number turnRate
function EnemyBlueWhale:previewStats()
	return 0, 0, 0
end

-- Ambush state machine -- replaces Enemy:update's continuous homing turn
-- entirely, since a blue whale never steers toward the player, only ever
-- appears where it last decided to. self.radius (the shared collision field
-- that Enemy:collidesWithShip, the tridentball loop, Storm Cloud's damage
-- loop, and auto-lightning targeting all read) doubles as the
-- submerged/surfaced visibility switch: 0 while hidden, the real collision
-- radius only while "surfaced".
---@param targetX number
---@param targetY number
---@param windDirection? number
---@param windSpeed? number
function EnemyBlueWhale:update(targetX, targetY, windDirection, windSpeed)
	local dt = Config.DT
	self.justSurfaced = false
	self.stateTimer = self.stateTimer - dt

	if self.state == "submerged" then
		self.radius = 0
		if self.stateTimer <= 0 then
			-- Retarget wherever the player actually is right now, and face
			-- that way so the surfaced body reads as having swum toward it.
			self.heading = Utils.angleTo(self.x, self.y, targetX, targetY)
			self.targetX, self.targetY = targetX, targetY
			self.state = "warning"
			self.stateTimer = Config.ENEMY_BLUE_WHALE_WARN_TIME
		end
	elseif self.state == "warning" then
		self.radius = 0
		if self.stateTimer <= 0 then
			-- Teleport here (rather than at the breaching->surfaced transition
			-- below, where the old instant-pop version did it) so the rising
			-- animation plays at the actual surfacing spot for the whole of
			-- "breaching" instead of wherever the whale last was.
			self.x, self.y = self.targetX, self.targetY
			self.state = "breaching"
			self.stateTimer = Config.ENEMY_BLUE_WHALE_BREACH_TIME
		end
	elseif self.state == "breaching" then
		self.radius = 0
		if self.stateTimer <= 0 then
			self.state = "surfaced"
			self.stateTimer = Config.ENEMY_BLUE_WHALE_SURFACE_TIME
			self.radius = Config.ENEMY_BLUE_WHALE_RADIUS
			self.justSurfaced = true
		end
	elseif self.state == "surfaced" then
		self.radius = Config.ENEMY_BLUE_WHALE_RADIUS
		if self.stateTimer <= 0 then
			self.state = "diving"
			self.stateTimer = Config.ENEMY_BLUE_WHALE_DIVE_TIME
			self.radius = 0
		end
	elseif self.state == "diving" then
		self.radius = 0
		if self.stateTimer <= 0 then
			self.state = "submerged"
			self.stateTimer = Config.ENEMY_BLUE_WHALE_SUBMERGE_TIME
		end
	end

	self:updateLeash(targetX, targetY, dt)
end

-- Ramming hit test -- see Enemy:collidesWithShip. On the single tick it just
-- surfaced (self.justSurfaced), the whole Config.ENEMY_BLUE_WHALE_ATTACK_RADIUS
-- burst counts as a hit regardless of self.radius, so anything caught in the
-- telegraphed zone gets thrown even if it isn't touching the (smaller) body
-- collision circle; every other tick this just falls back to the normal
-- circle-circle check against self.radius (0 while hidden, so always false).
---@param shipX number
---@param shipY number
---@param shipRadius number
---@return boolean
function EnemyBlueWhale:collidesWithShip(shipX, shipY, shipRadius)
	if self.justSurfaced then
		return Utils.dist(self.x, self.y, shipX, shipY) < (shipRadius + Config.ENEMY_BLUE_WHALE_ATTACK_RADIUS)
	end
	return EnemyBlueWhale.super.collidesWithShip(self, shipX, shipY, shipRadius)
end

-- Throws the player outward from wherever the whale is (its surfacing point,
-- on the burst tick; its resting position for an ordinary touch while
-- breathing) -- see Enemy:onRamHit and Player:applyKnockback, which turns
-- Config.ENEMY_BLUE_WHALE_KNOCKBACK_DISTANCE into the actual push.
---@param ship Player
function EnemyBlueWhale:onRamHit(ship)
	local outward = Utils.angleTo(self.x, self.y, ship.x, ship.y)
	ship:applyKnockback(outward, Config.ENEMY_BLUE_WHALE_KNOCKBACK_DISTANCE)
end

-- Bounding radius of the whaleImage sprite (a LENGTH*2 x BEAM*2 box centered
-- on the ship) -- see Ship:bodyRadius/buildBodyImage. L*1.3 is a safe
-- overestimate (sqrt(L^2+B^2) is the box's actual half-diagonal), kept from
-- the old ellipse+tail-fluke shape this sprite replaced. Only feeds
-- EnemySelectScene's static preview bake (see the module comment at the top
-- of this file) -- the live in-game draw never calls buildBodyImage.
---@return number
function EnemyBlueWhale:bodyRadius()
	return Config.ENEMY_BLUE_WHALE_LENGTH * 1.3
end

-- whaleImage (see the top of this file), scaled to 2x LENGTH by 2x BEAM and
-- centered at (cx, cy), drawn in local space (heading 0 = pointing along +x)
-- for Ship:buildBodyImage to bake into EnemySelectScene's static preview
-- pose. LENGTH/BEAM scale independently (drawScaled's separate x/y scale
-- factors), same as StormCloud:draw, so the two Config values don't need to
-- share the source art's aspect ratio -- this is how the whale's size stays
-- customizable despite drawing a fixed-aspect sprite instead of a hand-built
-- shape. Not used by the live in-game draw -- see the module comment at the
-- top of this file.
---@param cx number
---@param cy number
function EnemyBlueWhale:drawBodyLocal(cx, cy)
	local L, B = Config.ENEMY_BLUE_WHALE_LENGTH, Config.ENEMY_BLUE_WHALE_BEAM
	local sx, sy = (L * 2) / whaleImageWidth, (B * 2) / whaleImageHeight
	whaleImage:drawScaled(cx - L, cy - B, sx, sy)
end

-- Grey dithered circle at (targetX, targetY), the spot this whale is about
-- to surface -- radius Config.ENEMY_BLUE_WHALE_ATTACK_RADIUS, the same value
-- the surfacing burst actually checks against (see :collidesWithShip), so
-- the telegraph honestly previews the danger zone rather than approximating
-- it. Starts barely-visible grey and darkens toward solid black as stateTimer
-- counts down to 0 -- same dithered-fill idiom as StormCloud's resting-gray
-- look (gfx.kDitherTypeBayer4x4), just animated frame to frame instead of
-- baked once, since the coverage itself changes every tick here. Passed
-- straight to setDitherPattern as alpha -- empirically (on this SDK, with a
-- black draw color) alpha near 1 reads as the lighter end and alpha near 0 as
-- the darker/more-opaque end, the opposite of the alpha=0-transparent/
-- alpha=1-opaque description in the SDK docs, so this counts DOWN from ~1 to
-- 0 rather than up, to get lighter-at-first/darker-as-it-approaches-surfacing.
function EnemyBlueWhale:drawWarningCircle()
	local coverage = Utils.clamp(self.stateTimer / Config.ENEMY_BLUE_WHALE_WARN_TIME, 0, 1)
	if coverage <= 0 then return end

	gfx.setColor(gfx.kColorBlack)
	gfx.setDitherPattern(coverage, gfx.image.kDitherTypeBayer4x4)
	gfx.fillCircleAtPoint(self.targetX, self.targetY, Config.ENEMY_BLUE_WHALE_ATTACK_RADIUS)
	gfx.setColor(gfx.kColorBlack) -- clear the dither pattern so it doesn't leak into later world-space draws
end

-- Frame (1-based index into whaleLoopFrames) for the current tick --
-- "breaching" plays 1..whalePauseFrame as stateTimer counts down from
-- Config.ENEMY_BLUE_WHALE_BREACH_TIME, "diving" plays whalePauseFrame..end as
-- stateTimer counts down from Config.ENEMY_BLUE_WHALE_DIVE_TIME, and
-- "surfaced" just holds whalePauseFrame. Deriving the frame from the state
-- timer (rather than a separate elapsed-time counter) means retuning
-- BREACH_TIME/DIVE_TIME away from the asset's natural length just holds on
-- the first/last frame of that phase instead of running off the end of the
-- imagetable.
---@return integer
function EnemyBlueWhale:currentLoopFrame()
	if self.state == "breaching" then
		local elapsed = Config.ENEMY_BLUE_WHALE_BREACH_TIME - self.stateTimer
		return Utils.clamp(1 + math.floor(elapsed * WHALE_LOOP_FPS), 1, whalePauseFrame)
	elseif self.state == "diving" then
		local elapsed = Config.ENEMY_BLUE_WHALE_DIVE_TIME - self.stateTimer
		return Utils.clamp(whalePauseFrame + math.floor(elapsed * WHALE_LOOP_FPS), whalePauseFrame, whaleLoopFrameCount)
	end
	return whalePauseFrame
end

-- Nothing drawn while "submerged" (fully hidden); the darkening telegraph
-- circle while "warning" (see drawWarningCircle); otherwise ("breaching",
-- "surfaced", "diving") the current whaleLoopFrames frame, rotated to
-- self.heading same as Ship:draw's cached-image path, plus the health bar
-- while "surfaced" (see Enemy:drawHealthBar) -- this never calls Ship:draw,
-- see the module comment at the top of this file.
function EnemyBlueWhale:draw()
	if self.state == "warning" then
		self:drawWarningCircle()
		return
	end
	if self.state == "submerged" then
		return
	end

	whaleLoopFrames:getImage(self:currentLoopFrame()):drawRotated(self.x, self.y, self.heading)
	if self.state == "surfaced" and self.health < self.maxHealth then
		self:drawHealthBar()
	end
end
