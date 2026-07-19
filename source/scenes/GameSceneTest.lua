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

-- Wind-change countdown bar: full width when the timer resets, draining to
-- nothing right as the next wind change fires.
function GameSceneTest:drawHUD()
	GameScene.drawHUD(self)

	local frac = Utils.clamp(self.windChangeTimer / self.windChangeIntervalDuration, 0, 1)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(0, Config.SCREEN_H - 2, Config.SCREEN_W * frac, 2)
end

function GameSceneTest:gameOverPrompt()
	return "Ⓑ to return to menu"
end
