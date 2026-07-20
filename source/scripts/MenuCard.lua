-- MenuCard.lua
-- Shared chrome for "pick one from a list, see its description" screens: a
-- card frame (rounded rect, white background, black border) housing a fixed
-- title at top, a fixed footer at bottom, and a middle row split into a
-- scrollable left-column menu (3/4 width, highlighting the selected item)
-- and a right-column description of that item (1/4 width), with a divider
-- line between them. Used by UpgradeTestScene and UpgradeSelectScene's
-- "select" phase -- pulled out here since both need the identical layout
-- math and the identical playout.lua workaround (see MenuCard.build's
-- comment on the tree:layout() maxHeight cap).

---@class MenuCard
MenuCard = {}

local gfx <const> = playdate.graphics
local floor <const> = math.floor

MenuCard.CARD_MARGIN = 8
MenuCard.CARD_BORDER = 2
MenuCard.CARD_RADIUS = 6
MenuCard.CARD_PADDING = 8
-- Gap between the title/footer and the menu+description row below/above them.
MenuCard.ROW_GAP = 6
-- Menu (left) vs. description (right) split of the middle row, and the
-- divider line drawn between them.
MenuCard.MENU_FRACTION = 3 / 4
MenuCard.DIVIDER_GAP = 6

---@class MenuCard.Layout
---@field titleImg _Image
---@field footerImg _Image
---@field descImg _Image
---@field listTree table playout tree for the menu
---@field listImg _Image drawn image of listTree, may be taller than its on-screen viewport once scrolled
---@field selectedRect table rect of the highlighted item within listImg

-- Builds everything MenuCard.draw() needs to render one frame. Call again
-- (a fresh MenuCard.Layout, not a mutation of the last one) whenever the
-- selection changes.
---@param titleText string
---@param footerText string
---@param items { title: string, description: string }[]
---@param selectedIndex integer
---@param font any? font override (see e.g. UpgradeSelectScene's MENU_FONT), or nil for the current global font
---@return MenuCard.Layout
function MenuCard.build(titleText, footerText, items, selectedIndex, font)
	local contentWidth = Config.SCREEN_W - 2 * (MenuCard.CARD_MARGIN + MenuCard.CARD_PADDING)
	local menuWidth = floor((contentWidth - MenuCard.DIVIDER_GAP) * MenuCard.MENU_FRACTION)
	local descWidth = contentWidth - MenuCard.DIVIDER_GAP - menuWidth

	---@type MenuCard.Layout
	local layout = {}

	layout.titleImg = playout.tree.new(playout.text.new(titleText, { font = font })):draw()
	layout.footerImg = playout.tree.new(playout.text.new(footerText, { font = font })):draw()

	local children = {}
	for i, item in ipairs(items) do
		local isSelected = i == selectedIndex
		children[#children + 1] = playout.box.new({
			id = "item" .. i,
			padding = 4,
			hAlign = playout.kAlignStart,
			backgroundColor = isSelected and gfx.kColorBlack or nil,
		}, {
			playout.text.new(item.title, {
				color = isSelected and gfx.kColorWhite or gfx.kColorBlack,
			}),
		})
	end
	local listRoot = playout.box.new({
		direction = playout.kDirectionVertical,
		spacing = 4,
		padding = 4,
		hAlign = playout.kAlignStart,
		width = menuWidth,
		maxHeight = math.huge,
		font = font,
	}, children)
	layout.listTree = playout.tree.new(listRoot)
	-- tree:draw() calls tree:layout() internally, which hardcodes a maxHeight
	-- of Config.SCREEN_H (240) -- fine for screen-sized trees, but it would
	-- silently cut off anything the root box laid out beyond that, regardless
	-- of the root's own (raised) maxHeight above. Laying out here instead,
	-- with an uncapped maxHeight, and handing tree:draw() the result via
	-- tree.rect lets the full list exist in the drawn image; MenuCard.draw()
	-- then scrolls+clips it to keep the selection visible.
	layout.listTree.rect = listRoot:layout({
		maxWidth = menuWidth,
		maxHeight = math.huge,
		path = "root",
	})
	layout.listImg = layout.listTree:draw()
	layout.selectedRect = layout.listTree:get("item" .. selectedIndex).rect

	layout.descImg = playout.tree.new(playout.box.new({
		width = descWidth,
		padding = 4,
		hAlign = playout.kAlignCenter,
		vAlign = playout.kAlignCenter,
		font = font,
	}, {
		playout.text.new(items[selectedIndex].description, { alignment = kTextAlignment.center }),
	})):draw()

	return layout
end

-- Draws a MenuCard.Layout built by MenuCard.build() to the screen.
---@param layout MenuCard.Layout
function MenuCard.draw(layout)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)

	local cardX, cardY = MenuCard.CARD_MARGIN, MenuCard.CARD_MARGIN
	local cardW = Config.SCREEN_W - 2 * MenuCard.CARD_MARGIN
	local cardH = Config.SCREEN_H - 2 * MenuCard.CARD_MARGIN
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRoundRect(cardX, cardY, cardW, cardH, MenuCard.CARD_RADIUS)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(MenuCard.CARD_BORDER)
	gfx.drawRoundRect(cardX, cardY, cardW, cardH, MenuCard.CARD_RADIUS)

	local contentX = cardX + MenuCard.CARD_PADDING
	local contentY = cardY + MenuCard.CARD_PADDING
	local contentW = cardW - 2 * MenuCard.CARD_PADDING

	layout.titleImg:draw(contentX + (contentW - layout.titleImg.width) / 2, contentY)
	local footerY = cardY + cardH - MenuCard.CARD_PADDING - layout.footerImg.height
	layout.footerImg:draw(contentX + (contentW - layout.footerImg.width) / 2, footerY)

	local middleY = contentY + layout.titleImg.height + MenuCard.ROW_GAP
	local middleHeight = footerY - MenuCard.ROW_GAP - middleY

	local menuWidth = floor((contentW - MenuCard.DIVIDER_GAP) * MenuCard.MENU_FRACTION)
	local menuX = contentX
	local descX = contentX + menuWidth + MenuCard.DIVIDER_GAP
	local descWidth = contentW - MenuCard.DIVIDER_GAP - menuWidth

	local dividerX = menuX + menuWidth + MenuCard.DIVIDER_GAP / 2
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(1)
	gfx.drawLine(dividerX, middleY, dividerX, middleY + middleHeight)

	local listY
	if layout.listImg.height <= middleHeight then
		listY = middleY + (middleHeight - layout.listImg.height) / 2
	else
		-- List is taller than its viewport -- scroll it vertically so the
		-- highlighted item stays centered, clamped so we never scroll past
		-- the top (listY > middleY) or bottom
		-- (listY < middleY + middleHeight - listImg.height) edge.
		local selectedCenterY = layout.selectedRect.y + layout.selectedRect.height / 2
		listY = middleY + middleHeight / 2 - selectedCenterY
		listY = math.max(middleY + middleHeight - layout.listImg.height, math.min(middleY, listY))
	end

	gfx.setClipRect(menuX, middleY, menuWidth, middleHeight)
	layout.listImg:draw(menuX, listY)
	gfx.clearClipRect()

	layout.descImg:draw(descX + (descWidth - layout.descImg.width) / 2, middleY + (middleHeight - layout.descImg.height) / 2)
end
