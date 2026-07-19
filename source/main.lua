-- main.lua
-- Tridentade — a top-down pirate sailing game for Playdate.
-- Built on Noble Engine (scenes/input/transitions) + pdParticles (wake/explosions).

import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/sprites"

-- Engine + libraries.
-- Noble expects to live at libraries/noble relative to this file.
import "libraries/noble/Noble"
-- pdParticles is a single file dropped in libraries/.
import "libraries/pdParticles"

-- Game code.
import "scripts/Config"
import "scripts/ConfigEnemy"
import "scripts/Utils"
import "scripts/Ship"
import "scripts/Enemy"
import "scripts/EnemySwordfish"
import "scripts/Tridentball"
import "scenes/TitleScene"
import "scenes/InstructionsScene"
import "scenes/GameScene"
import "scenes/GameSceneMain"
import "scenes/GameSceneTest"
import "scenes/LevelCompleteScene"
import "scenes/WindShiftScene"

-- Lock to a fixed 30fps so our fixed-timestep (Config.DT) matches wall-clock.
playdate.display.setRefreshRate(Config.REFRESH)

-- HUD visibility toggles, exposed via the system (pause) menu.
local systemMenu = playdate.getSystemMenu()
systemMenu:addCheckmarkMenuItem("Wind Speed", Config.HUD_SHOW_WIND_SPEED, function(value)
	Config.HUD_SHOW_WIND_SPEED = value
end)
systemMenu:addCheckmarkMenuItem("Wind Direction", Config.HUD_SHOW_WIND_DIRECTION, function(value)
	Config.HUD_SHOW_WIND_DIRECTION = value
end)
systemMenu:addCheckmarkMenuItem("Player Speed", Config.HUD_SHOW_PLAYER_SPEED, function(value)
	Config.HUD_SHOW_PLAYER_SPEED = value
end)

-- Boot the engine, starting on the title screen.
Noble.new(TitleScene)
