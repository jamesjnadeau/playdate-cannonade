-- GameSceneMain.lua
-- The real game: enemies spawn automatically on a shrinking timer, capped
-- per level, and clearing a level's kill target hands off to
-- LevelCompleteScene for the next one.

import "scripts/Config"
import "scripts/Utils"
import "scenes/GameScene"

local gfx <const> = playdate.graphics

class("GameSceneMain").extends(GameScene)

local function lerp(a, b, t) return a + (b - a) * t end

GameSceneMain.inputHandler = GameScene.buildSharedInputHandler(GameScene.current)
GameSceneMain.inputHandler.AButtonDown = function()
	local s = GameScene.current()
	if s and s.gameOver then Noble.transition(GameSceneMain) end
end

function GameSceneMain:resetGame(sceneProperties)
	GameSceneMain.super.resetGame(self, sceneProperties)
	sceneProperties = sceneProperties or {}
	self.spawnTimer = Config.SPAWN_INTERVAL_START
	self.level = sceneProperties.level or 1
	self.score = sceneProperties.totalDefeated or 0 -- cumulative across all levels this run
	self.levelKills = 0                             -- kills toward clearing the current level
	self.levelSpawned = 0                           -- enemies spawned so far this level
	self.levelTarget = self.level * Config.LEVEL_ENEMY_STEP
	self.levelComplete = false
end

function GameSceneMain:currentSpawnInterval()
	local t = Utils.clamp(self.elapsed / Config.SPAWN_RAMP_SECONDS, 0, 1)
	return lerp(Config.SPAWN_INTERVAL_START, Config.SPAWN_INTERVAL_FLOOR, t)
end

-- Spawn on a shrinking interval, same as the base scene's manual spawnEnemy
-- but capped so at most levelTarget enemies ever spawn this level.
function GameSceneMain:updateSpawning(dt)
	self.spawnTimer = self.spawnTimer - dt
	if self.spawnTimer <= 0 then
		self:spawnEnemy()
		self.spawnTimer = self:currentSpawnInterval()
	end
end

function GameSceneMain:spawnEnemy()
	if self.levelSpawned >= self.levelTarget then return false end
	if GameSceneMain.super.spawnEnemy(self) then
		self.levelSpawned = self.levelSpawned + 1
		return true
	end
	return false
end

function GameSceneMain:enemyDefeated()
	GameSceneMain.super.enemyDefeated(self)
	self.levelKills = self.levelKills + 1
end

-- Level clears once enough enemies have been defeated; hand off to the
-- interstitial scene, which restarts GameSceneMain at the next level with
-- health reset (Player:init always sets full health).
function GameSceneMain:tickGame()
	if self.levelComplete then return end
	GameSceneMain.super.tickGame(self)
	if self.levelKills >= self.levelTarget then
		self.levelComplete = true
		Noble.transition(LevelCompleteScene, nil, nil, nil, {
			completedLevel = self.level,
			totalDefeated = self.score,
		})
	end
end

function GameSceneMain:drawModeStatus()
	gfx.drawText("LV " .. self.level .. "  " .. self.levelKills .. "/" .. self.levelTarget, Config.SCREEN_W - 90, 6)
end
