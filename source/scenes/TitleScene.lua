-- TitleScene.lua
-- Simple start screen. Press A to sail into GameScene.

import "scripts/Config"

local gfx <const> = playdate.graphics

TitleScene = {}
class("TitleScene").extends(NobleScene)

local scene = nil

function TitleScene:init(...)
	TitleScene.super.init(self, ...)
	self.backgroundColor = gfx.kColorWhite
	self.t = 0
end

function TitleScene:start()
	TitleScene.super.start(self)
	scene = self
end

function TitleScene:finish()
	TitleScene.super.finish(self)
	scene = nil
end

TitleScene.inputHandler = {
	AButtonDown = function()
		if scene then Noble.transition(GameScene) end
	end,
}

function TitleScene:update()
	TitleScene.super.update(self)
	self.t = self.t + Config.DT

	local cx = Config.SCREEN_W / 2

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.drawTextAligned("* CANNONADE *", cx, 40, kTextAlignment.center)
	gfx.drawTextAligned("a Playdate pirate voyage", cx, 62, kTextAlignment.center)

	gfx.drawTextAligned("Crank to steer the helm", cx, 104, kTextAlignment.center)
	gfx.drawTextAligned("Up/Down to trim the sails", cx, 122, kTextAlignment.center)
	gfx.drawTextAligned("Left/Right to charge a broadside", cx, 140, kTextAlignment.center)

	-- Blinking prompt.
	if math.floor(self.t * 2) % 2 == 0 then
		gfx.drawTextAligned("Press Ⓐ to set sail", cx, 186, kTextAlignment.center)
	end
end
