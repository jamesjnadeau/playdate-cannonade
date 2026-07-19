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
-- playout is a single file dropped in libraries/, used for menu/list UI.
import "libraries/playout"

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
import "scenes/SettingsScene"
import "scenes/GameScene"
import "scenes/GameSceneMain"
import "scenes/GameSceneTest"
import "scenes/EnemySelectScene"
import "scenes/LevelCompleteScene"
import "scenes/WindShiftScene"

-- Lock to a fixed 30fps so our fixed-timestep (Config.DT) matches wall-clock.
playdate.display.setRefreshRate(Config.REFRESH)

-- Boot the engine, starting on the title screen.
Noble.new(TitleScene)
