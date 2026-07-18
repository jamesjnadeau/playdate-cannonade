-- GameSceneTest.lua
-- A sandbox for testing ship/wind/combat feel: no automatic spawning or
-- level progression. Press A to spawn one enemy, B to return to the title
-- screen.

import "scripts/Config"
import "scenes/GameScene"

local gfx <const> = playdate.graphics

class("GameSceneTest").extends(GameScene)

GameSceneTest.inputHandler = GameScene.buildSharedInputHandler(GameScene.current)
GameSceneTest.inputHandler.AButtonDown = function()
	local s = GameScene.current()
	if s then s:spawnEnemy() end
end
GameSceneTest.inputHandler.BButtonDown = function()
	if GameScene.current() then Noble.transition(TitleScene) end
end

function GameSceneTest:drawModeStatus()
	gfx.drawText("TEST  " .. #self.enemies .. " up", Config.SCREEN_W - 90, 6)
end

function GameSceneTest:gameOverPrompt()
	return "Ⓑ to return to menu"
end
