-- LevelCompleteScene.lua
-- Interstitial shown after clearing a level: reports the running defeated
-- total, then hands off to GameSceneMain for the next level with health reset.
-- If the next level also lands a wind escalation step (see
-- GameSceneMain.windStepForLevel), routes through WindShiftScene first.

import "scripts/Config"

local gfx <const> = playdate.graphics

LevelCompleteScene = {}
class("LevelCompleteScene").extends(NobleScene)

local scene = nil

function LevelCompleteScene:init(sceneProperties)
	LevelCompleteScene.super.init(self, sceneProperties)
	self.backgroundColor = gfx.kColorWhite
	sceneProperties = sceneProperties or {}
	self.completedLevel = sceneProperties.completedLevel or 1
	self.totalDefeated = sceneProperties.totalDefeated or 0
end

function LevelCompleteScene:start()
	LevelCompleteScene.super.start(self)
	scene = self
end

function LevelCompleteScene:finish()
	LevelCompleteScene.super.finish(self)
	if scene == self then scene = nil end
end

LevelCompleteScene.inputHandler = {
	AButtonDown = function()
		if scene then
			local nextLevel = scene.completedLevel + 1
			local windStepped = GameSceneMain.windStepForLevel(nextLevel)
				> GameSceneMain.windStepForLevel(scene.completedLevel)
			local nextScene = windStepped and WindShiftScene or GameSceneMain
			Noble.transition(nextScene, nil, nil, nil, {
				level = nextLevel,
				totalDefeated = scene.totalDefeated,
			})
		end
	end,
}

function LevelCompleteScene:update()
	LevelCompleteScene.super.update(self)
	local cx = Config.SCREEN_W / 2

	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.drawTextAligned("LEVEL " .. self.completedLevel .. " CLEARED!", cx, 80, kTextAlignment.center)
	gfx.drawTextAligned("Enemies defeated: " .. self.totalDefeated, cx, 110, kTextAlignment.center)
	gfx.drawTextAligned("Next: Level " .. (self.completedLevel + 1), cx, 130, kTextAlignment.center)
	gfx.drawTextAligned("Ⓐ to continue", cx, 160, kTextAlignment.center)
end
