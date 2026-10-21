local ADDON, ns = ...

-- RatStash's own settings window: two columns of one-line rows, the setting's name on the left and
-- its control on the right edge. Each call below still carries its setting's one-line description.

local C, rgb
local panel
local refreshers = {}

local COL_W = 340      -- width of one column
local COL_GAP = 36
local MARGIN = 26
local ROW_H = 30
local colX = MARGIN    -- the column the helpers below are drawing into
local stripe = false   -- every other row in a section gets a faint band

local function Changed()
	for _, fn in ipairs(refreshers) do fn() end
	ns.RelayoutAll()
end

-- plain text, no drop shadow (the shadow made small text look bold)
local function Text(parent, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT, size)
	fs:SetShadowOffset(0, 0)
	fs:SetTextColor(rgb(color or C.text))
	return fs
end

local function Section(parent, y, text)
	local fs = Text(parent, 11, C.accentText)
	fs:SetPoint("TOPLEFT", colX, y)
	fs:SetText(text:upper())
	local rule = ns.Rule(parent)
	rule:SetPoint("LEFT", fs, "RIGHT", 8, 0)
	rule:SetWidth(math.max(1, COL_W - fs:GetStringWidth() - 8))
	stripe = false
	return y - 20
end

-- one setting's row: its name on the left; the control goes on the right
local function Row(parent, y, label)
	local row = CreateFrame("Button", nil, parent)
	row:SetPoint("TOPLEFT", colX - 6, y)
	row:SetWidth(COL_W + 12)
	row:SetHeight(ROW_H)
	if stripe then
		local band = row:CreateTexture(nil, "BACKGROUND")
		band:SetTexture(ns.FLAT)
		band:SetVertexColor(1, 1, 1, 0.03)
		band:SetAllPoints(row)
	end
	stripe = not stripe
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetTexture(ns.FLAT)
	hover:SetVertexColor(1, 1, 1, 0.05)
	hover:SetAllPoints(row)
	local fs = Text(row, 13)
	fs:SetPoint("LEFT", 6, 0)
	fs:SetText(label)
	return row
end

-- checkbox: retail's dark box with a bronze edge and a yellow tick; the whole row toggles it
local function Check(parent, y, label, hint, get, set)
	local row = Row(parent, y, label)
	local box, tick = ns.CheckBox(row, 20)
	box:SetPoint("RIGHT", -4, 0)
	row:SetScript("OnClick", function() set(not get()); Changed() end)
	refreshers[#refreshers + 1] = function()
		if get() then tick:Show() else tick:Hide() end
	end
	return y - ROW_H
end

-- a dropdown on the right of its row, showing the current choice
local function Choice(parent, y, label, hint, values, get, set)
	local row = Row(parent, y, label)
	local drop = ns.Dropdown(row, 150, values, get, function(key) set(key); Changed() end)
	drop:SetPoint("RIGHT", -4, 0)
	refreshers[#refreshers + 1] = function() drop:Refresh() end
	return y - ROW_H
end

-- The font draws "-" below the middle of its line, so the signs are gold bars centred in the button.
local function SignButton(parent, plus)
	local b = ns.RedButton(parent, "", 24, 22)
	local bars = { { 8, 2 } }
	if plus then bars[2] = { 2, 8 } end
	for _, size in ipairs(bars) do
		local bar = b:CreateTexture(nil, "OVERLAY")
		bar:SetTexture(ns.FLAT)
		bar:SetVertexColor(1, 0.82, 0)
		bar:SetWidth(size[1]); bar:SetHeight(size[2])
		bar:SetPoint("CENTER", 0, 0)
	end
	return b
end

-- [-] value [+] on the right of its row
local function Stepper(parent, y, label, hint, lo, hi, step, fmt, get, set)
	local row = Row(parent, y, label)
	local plus = SignButton(row, true)
	plus:SetPoint("RIGHT", -4, 0)
	local value = Text(row, 13, C.accentText)
	value:SetWidth(44)
	value:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	local minus = SignButton(row, false)
	minus:SetPoint("RIGHT", value, "LEFT", -4, 0)
	local function bump(d)
		local v = math.floor((get() + d) / step + 0.5) * step
		if v < lo - step / 2 or v > hi + step / 2 then return end
		set(v); Changed()
	end
	minus:SetScript("OnClick", function() bump(-step) end)
	plus:SetScript("OnClick", function() bump(step) end)
	refreshers[#refreshers + 1] = function() value:SetText(fmt:format(get())) end
	return y - ROW_H
end

local LAYOUTS = { { "grid", "One grid" }, { "sets", "Grid + sets" }, { "groups", "Groups" } }

function ns.CreateOptions()
	C, rgb = ns.C, ns.rgb
	local db = ns.db
	panel = CreateFrame("Frame", "RatStashOptions", UIParent)
	panel:Hide()
	panel:SetWidth(MARGIN * 2 + COL_W * 2 + COL_GAP)
	panel:SetFrameStrata("DIALOG")
	panel:SetToplevel(true)
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:SetPoint("CENTER")
	ns.SkinWindow(panel)
	tinsert(UISpecialFrames, "RatStashOptions")
	-- the stash picture behind the settings, as behind the bags
	local art = panel:CreateTexture(nil, "BORDER")
	art:SetPoint("TOPLEFT", ns.INSET, -ns.INSET); art:SetPoint("BOTTOMRIGHT", -ns.INSET, ns.INSET)
	ns.CoverCorners(panel, art)
	local wash = panel:CreateTexture(nil, "ARTWORK")
	wash:SetAllPoints(art)
	local function paintArt() ns.PaintArt(art, wash, panel:GetWidth(), panel:GetHeight()) end

	local head, title = ns.TitleBar(panel, 30)
	head:EnableMouse(true)
	head:RegisterForDrag("LeftButton")
	head:SetScript("OnDragStart", function() panel:StartMoving() end)
	head:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
	title:SetText("RatStash Settings")
	ns.Medallion(panel)

	-- left column: how the windows are laid out, and what items show
	colX = MARGIN
	local y = -58
	y = Section(panel, y, "Layout")
	y = Check(panel, y, "Auto sort", "Fixed order. Off: items show where they really are, like Bagnon.",
		function() return db.sort end, function(v) db.sort = v end)
	y = Choice(panel, y, "Bags layout", "One grid, a group per gear set plus one grid, or a block per kind.",
		LAYOUTS, function() return db.layout.bags end, function(v) db.layout.bags = v end)
	y = Choice(panel, y, "Bank layout", "Same choices, for the bank window.",
		LAYOUTS, function() return db.layout.bank end, function(v) db.layout.bank = v end)
	y = Choice(panel, y, "Pinned items", "Alt-click any item to pin or unpin it.",
		{ { "top", "At the top" }, { "bottom", "At the bottom" } },
		function() return db.pinAt end, function(v) db.pinAt = v end)
	y = Choice(panel, y, "Empty slots", "One slot with the free count (drop items on it), or every empty slot.",
		{ { "stack", "One slot" }, { "expand", "Every slot" } },
		function() return db.freeMode end, function(v) db.freeMode = v end)
	local leftEnd = y

	-- right column: size and look, item badges, virtual stacks
	colX = MARGIN + COL_W + COL_GAP
	y = -58
	y = Section(panel, y, "Size & look")
	y = Stepper(panel, y, "Bags columns", "Items per row in the bags window.", 6, 20, 1, "%d",
		function() return db.columns.bags end, function(v) db.columns.bags = v end)
	y = Stepper(panel, y, "Bank columns", "Items per row in the bank window.", 8, 24, 1, "%d",
		function() return db.columns.bank end, function(v) db.columns.bank = v end)
	y = Stepper(panel, y, "Scale", "Size of both windows.", 0.6, 1.4, 0.05, "%.2f",
		function() return db.scale end, function(v) db.scale = v end)
	y = Check(panel, y, "Background art", "The stash picture behind the items. Off: plain dark.",
		function() return db.bgOn end, function(v) db.bgOn = v end)
	y = Stepper(panel, y, "Art strength", "How much the picture shows through.", 0.1, 1, 0.1, "%.1f",
		function() return db.bgArt end, function(v) db.bgArt = v end)

	y = Section(panel, y - 10, "Items")
	y = Check(panel, y, "Show item level", "Gear shows its item level in the quality color.",
		function() return db.showIlvl end, function(v) db.showIlvl = v end)
	y = Check(panel, y, "Show BoE tag", "Bind-on-equip gear gets a gold BoE tag.",
		function() return db.showBoE end, function(v) db.showBoE = v end)
	y = Check(panel, y, "New items group", "What just came into your bags sits in New for 15 min, or until a /reload.",
		function() return db.newGroup end, function(v) db.newGroup = v end)
	y = Check(panel, y, "Sell greys at vendors", "Opening a vendor sells every grey item and says what it made.",
		function() return db.sellJunk end, function(v) db.sellJunk = v end)
	y = Check(panel, y, "Raid loot group as master looter", "While you are master looter, raid loot gets its own group.",
		function() return db.mlGroup end, function(v) db.mlGroup = v end)

	-- virtual stacks go under the left column, which is shorter
	colX = MARGIN
	local vy = Section(panel, leftEnd - 10, "Virtual stacks")
	vy = Check(panel, vy, "Merge unstackable items", "Identical items that can't stack show as one slot.",
		function() return db.vs.others end, function(v) db.vs.others = v end)
	vy = Check(panel, vy, "Merge stackable items", "Full stacks of the same item show as one slot.",
		function() return db.vs.stack end, function(v) db.vs.stack = v end)
	vy = Check(panel, vy, "... including incomplete stacks", "Partial stacks join the merged slot too.",
		function() return db.vs.incomplete end, function(v) db.vs.incomplete = v end)

	panel:SetHeight(-math.min(y, vy) + 16)
	refreshers[#refreshers + 1] = paintArt
	panel:SetScript("OnShow", function() for _, fn in ipairs(refreshers) do fn() end end)
	panel:SetScript("OnHide", function() ns.CloseDropdowns() end)
end

function ns.OpenOptions()
	if panel:IsShown() then panel:Hide() else panel:Show() end
end
