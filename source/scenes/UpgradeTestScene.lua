-- UpgradeTestScene.lua
-- Reached from GameSceneTraining's "Test Upgrade" system-menu item. Lists
-- every entry in Config.UPGRADES (source/scripts/ConfigUpgrades.lua) --
-- unlike UpgradeSelectScene's random draw of 3, the whole pool, and unlike
-- UpgradeSelectScene's pickUpgrades, ignoring each entry's `available`
-- predicate (e.g. "Rapid Autocannon" normally requires the Autofire Cannon
-- already installed) -- this is a dev/test tool, so every upgrade is always
-- reachable here regardless of prerequisites. Up/Down move the highlight, Ⓐ
-- applies the highlighted upgrade (via Config.applyUpgrade, same as
-- UpgradeSelectScene) and returns to GameSceneTraining, Ⓑ cancels back
-- without applying anything. No before/after result screen -- unlike
-- UpgradeSelectScene, this is meant to be reopened repeatedly to stack
-- several picks in a row, so it goes straight back to the sandbox instead of
-- pausing on a summary each time.

import "scripts/Config"
import "scripts/ConfigUpgrades"

local gfx <const> = playdate.graphics
local floor <const> = math.floor

-- Card frame that everything else is laid out inside of.
local CARD_MARGIN <const> = 8
local CARD_BORDER <const> = 2
local CARD_RADIUS <const> = 6
local CARD_PADDING <const> = 8
-- Gap between the title/footer and the menu+description row below/above them.
local ROW_GAP <const> = 6
-- Menu (left) vs. description (right) split of the middle row, and the
-- divider line drawn between them.
local MENU_FRACTION <const> = 3 / 4
local DIVIDER_GAP <const> = 6

---@class UpgradeTestScene : NobleScene
---@field selected integer index into Config.UPGRADES
---@field titleImg _Image "Test Upgrade" heading, see rebuild()
---@field footerImg _Image "Ⓐ apply Ⓑ cancel" footer, see rebuild()
---@field descImg _Image selected upgrade's description, see rebuild()
---@field listTree table playout tree for the upgrade menu, see rebuild()
---@field listImg _Image drawn image of listTree, taller than its on-screen viewport once scrolled, see rebuild()
---@field selectedRect table rect of the highlighted upgrade within listImg, see rebuild()
UpgradeTestScene = class("UpgradeTestScene").extends(NobleScene) or UpgradeTestScene

local scene = nil

-- Builds the menu: a vertical stack of every upgrade, highlighting
-- `selectedIndex`, constrained to `width` (the left column) but with
-- unbounded height -- playout.box defaults maxHeight to Config.SCREEN_H
-- (240), assuming trees are always screen-sized, which the full list isn't.
-- rebuild() lays this out directly (bypassing tree:layout()'s own hardcoded
-- 240 cap) so the whole list exists in the drawn image; :update() then
-- scrolls+clips that (taller-than-its-viewport) image to keep the
-- highlighted upgrade visible.
---@param selectedIndex integer
---@param width number
---@return table playout tree
local function buildListTree(selectedIndex, width)
	local children = {}
	for i, upgrade in ipairs(Config.UPGRADES) do
		local isSelected = i == selectedIndex
		children[#children + 1] = playout.box.new({
			id = "upgrade" .. i,
			padding = 4,
			hAlign = playout.kAlignStart,
			backgroundColor = isSelected and gfx.kColorBlack or nil,
		}, {
			playout.text.new(upgrade.title, {
				color = isSelected and gfx.kColorWhite or gfx.kColorBlack,
			}),
		})
	end

	local root = playout.box.new({
		direction = playout.kDirectionVertical,
		spacing = 4,
		padding = 4,
		hAlign = playout.kAlignStart,
		width = width,
		maxHeight = math.huge,
	}, children)

	return playout.tree.new(root)
end

---@param description string
---@param width number
---@return _Image
local function buildDescriptionImage(description, width)
	return playout.tree.new(playout.box.new({
		width = width,
		padding = 4,
		hAlign = playout.kAlignCenter,
		vAlign = playout.kAlignCenter,
	}, {
		playout.text.new(description, { alignment = kTextAlignment.center }),
	})):draw()
end

---@param ... any
function UpgradeTestScene:init(...)
	UpgradeTestScene.super.init(self, ...)
	self.backgroundColor = gfx.kColorWhite
	self.selected = 1

	-- Built here rather than in :start() -- Noble may call :update() during
	-- the tail of the transition in, before :start() fires (see GameScene's
	-- init/start comments), so the drawn images must already exist by then.
	self.titleImg = playout.tree.new(playout.text.new("Test Upgrade")):draw()
	self.footerImg = playout.tree.new(playout.text.new("Ⓐ apply   Ⓑ cancel")):draw()
	self:rebuild()
end

function UpgradeTestScene:start()
	UpgradeTestScene.super.start(self)
	scene = self
end

function UpgradeTestScene:finish()
	UpgradeTestScene.super.finish(self)
	if scene == self then scene = nil end
end

function UpgradeTestScene:rebuild()
	local contentWidth = Config.SCREEN_W - 2 * (CARD_MARGIN + CARD_PADDING)
	local menuWidth = floor((contentWidth - DIVIDER_GAP) * MENU_FRACTION)
	local descWidth = contentWidth - DIVIDER_GAP - menuWidth

	self.listTree = buildListTree(self.selected, menuWidth)
	-- tree:draw() calls tree:layout() internally, which hardcodes a
	-- maxHeight of Config.SCREEN_H (240) -- fine for screen-sized trees, but
	-- it would silently cut off anything the root box laid out beyond that,
	-- regardless of the root's own (raised) maxHeight above. Laying out here
	-- instead, with an uncapped maxHeight, and handing tree:draw() the
	-- result via tree.rect lets the full list exist in the drawn image.
	self.listTree.rect = self.listTree.root:layout({
		maxWidth = menuWidth,
		maxHeight = math.huge,
		path = "root",
	})
	self.listImg = self.listTree:draw()
	self.selectedRect = self.listTree:get("upgrade" .. self.selected).rect

	self.descImg = buildDescriptionImage(Config.UPGRADES[self.selected].description, descWidth)
end

---@param delta integer
local function moveSelection(delta)
	if not scene then return end
	local count = #Config.UPGRADES
	scene.selected = ((scene.selected - 1 + delta) % count) + 1
	scene:rebuild()
end

UpgradeTestScene.inputHandler = {
	upButtonDown = function() moveSelection(-1) end,
	downButtonDown = function() moveSelection(1) end,
	AButtonDown = function()
		if not scene then return end
		Config.applyUpgrade(Config.UPGRADES[scene.selected])
		Noble.transition(GameSceneTraining)
	end,
	BButtonDown = function()
		if scene then Noble.transition(GameSceneTraining) end
	end,
}

function UpgradeTestScene:update()
	UpgradeTestScene.super.update(self)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)

	local cardX, cardY = CARD_MARGIN, CARD_MARGIN
	local cardW = Config.SCREEN_W - 2 * CARD_MARGIN
	local cardH = Config.SCREEN_H - 2 * CARD_MARGIN
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRoundRect(cardX, cardY, cardW, cardH, CARD_RADIUS)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(CARD_BORDER)
	gfx.drawRoundRect(cardX, cardY, cardW, cardH, CARD_RADIUS)

	local contentX = cardX + CARD_PADDING
	local contentY = cardY + CARD_PADDING
	local contentW = cardW - 2 * CARD_PADDING

	self.titleImg:draw(contentX + (contentW - self.titleImg.width) / 2, contentY)
	local footerY = cardY + cardH - CARD_PADDING - self.footerImg.height
	self.footerImg:draw(contentX + (contentW - self.footerImg.width) / 2, footerY)

	local middleY = contentY + self.titleImg.height + ROW_GAP
	local middleHeight = footerY - ROW_GAP - middleY

	local menuWidth = floor((contentW - DIVIDER_GAP) * MENU_FRACTION)
	local menuX = contentX
	local descX = contentX + menuWidth + DIVIDER_GAP
	local descWidth = contentW - DIVIDER_GAP - menuWidth

	local dividerX = menuX + menuWidth + DIVIDER_GAP / 2
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(1)
	gfx.drawLine(dividerX, middleY, dividerX, middleY + middleHeight)

	local listY
	if self.listImg.height <= middleHeight then
		listY = middleY + (middleHeight - self.listImg.height) / 2
	else
		-- List is taller than its viewport -- scroll it vertically so the
		-- highlighted upgrade stays centered, clamped so we never scroll
		-- past the top (listY > middleY) or bottom
		-- (listY < middleY + middleHeight - listImg.height) edge.
		local selectedCenterY = self.selectedRect.y + self.selectedRect.height / 2
		listY = middleY + middleHeight / 2 - selectedCenterY
		listY = math.max(middleY + middleHeight - self.listImg.height, math.min(middleY, listY))
	end

	gfx.setClipRect(menuX, middleY, menuWidth, middleHeight)
	self.listImg:draw(menuX, listY)
	gfx.clearClipRect()

	self.descImg:draw(descX + (descWidth - self.descImg.width) / 2, middleY + (middleHeight - self.descImg.height) / 2)
end
