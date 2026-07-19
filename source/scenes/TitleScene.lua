-- TitleScene.lua
-- Start screen: Up/Down pick a scene, A confirms.

import "scripts/Config"

local gfx <const> = playdate.graphics

TitleScene = {}
class("TitleScene").extends(NobleScene)

local scene = nil

-- Menu labels, in order. Kept as plain display strings -- the scene classes
-- themselves are only referenced inside confirmSelection() below, which runs
-- long after every scene file has finished loading, so load order here
-- doesn't matter.
local MENU_ITEMS = { "Play", "Test Enemies", "Instructions" }

function TitleScene:init(...)
	TitleScene.super.init(self, ...)
	self.backgroundColor = gfx.kColorWhite
	self.t = 0
	self.selected = 2
end

function TitleScene:start()
	TitleScene.super.start(self)
	scene = self
end

function TitleScene:finish()
	TitleScene.super.finish(self)
	scene = nil
end

local function confirmSelection()
	if not scene then return end
	if scene.selected == 1 then
		Noble.transition(GameSceneMain)
	elseif scene.selected == 2 then
		Noble.transition(GameSceneTest)
	else
		Noble.transition(InstructionsScene)
	end
end

TitleScene.inputHandler = {
	upButtonDown = function()
		if not scene then return end
		scene.selected = scene.selected - 1
		if scene.selected < 1 then scene.selected = #MENU_ITEMS end
	end,
	downButtonDown = function()
		if not scene then return end
		scene.selected = scene.selected + 1
		if scene.selected > #MENU_ITEMS then scene.selected = 1 end
	end,
	AButtonDown = function() confirmSelection() end,
}

function TitleScene:update()
	TitleScene.super.update(self)
	self.t = self.t + Config.DT

	local cx = Config.SCREEN_W / 2

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.drawTextAligned("* Mermaid Madness *", cx, 40, kTextAlignment.center)
	gfx.drawTextAligned("a Playdate pirate voyage", cx, 62, kTextAlignment.center)

	local menuTop = 158
	for i, label in ipairs(MENU_ITEMS) do
		local text = (i == self.selected) and ("> " .. label .. " <") or label
		gfx.drawTextAligned(text, cx, menuTop + (i - 1) * 16, kTextAlignment.center)
	end

	-- Blinking prompt.
	if math.floor(self.t * 2) % 2 == 0 then
		gfx.drawTextAligned("Ⓐ to select", cx, menuTop + #MENU_ITEMS * 16 + 10, kTextAlignment.center)
	end
end
