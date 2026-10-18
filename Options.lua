local ADDON, ns = ...

-- RatStash's own settings window, in the same flat style as the bag windows: two columns

local C, rgb
local panel
local refreshers = {}

local COL_W = 340      -- width of one column
local COL_GAP = 36
local MARGIN = 18
local colX = MARGIN    -- the column the helpers below are drawing into

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
	return y - 22
end

local function Hint(parent, anchor, text)
	local fs = Text(parent, 10, C.textDim)
	fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
	fs:SetWidth(COL_W)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

-- flat checkbox: a hairline square that fills gold when on; the label is clickable too
local function Check(parent, y, label, hint, get, set)
	local b = CreateFrame("Button", nil, parent)
	b:SetPoint("TOPLEFT", colX, y)
	b:SetHeight(16)
	b:SetWidth(COL_W)
	local box = CreateFrame("Frame", nil, b)
	box:SetWidth(14); box:SetHeight(14)
	box:SetPoint("LEFT")
	ns.Skin(box, C.panelD, 1)
	local fill = box:CreateTexture(nil, "OVERLAY")
	fill:SetTexture(ns.FLAT)
	fill:SetPoint("TOPLEFT", 3, -3); fill:SetPoint("BOTTOMRIGHT", -3, 3)
	fill:SetVertexColor(rgb(C.accent))
	local fs = Text(b, 12)
	fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
	fs:SetText(label)
	b:SetScript("OnClick", function() set(not get()); Changed() end)
	b:SetScript("OnEnter", function() box:SetBackdropBorderColor(rgb(C.borderHi)) end)
	b:SetScript("OnLeave", function() box:SetBackdropBorderColor(rgb(C.border)) end)
	Hint(parent, fs, hint)
	refreshers[#refreshers + 1] = function()
		if get() then fill:Show() else fill:Hide() end
	end
	return y - 42
end

-- a row of flat buttons, the chosen one filled gold
local function Choice(parent, y, label, hint, values, get, set)
	local fs = Text(parent, 12)
	fs:SetPoint("TOPLEFT", colX, y)
	fs:SetText(label)
	local buttons = {}
	local w = math.floor((COL_W - 4 * (#values - 1)) / #values)
	for i, pair in ipairs(values) do
		local b = ns.FlatButton(parent, pair[2], w, 20)
		b.text:SetShadowOffset(0, 0)
		b:SetPoint("TOPLEFT", colX + (i - 1) * (w + 4), y - 18)
		b:SetScript("OnClick", function() set(pair[1]); Changed() end)
		buttons[i] = b
	end
	Hint(parent, buttons[1], hint)
	refreshers[#refreshers + 1] = function()
		for i, pair in ipairs(values) do
			local b, on = buttons[i], get() == pair[1]
			b.edge = on and C.accent or C.border
			b:SetBackdropColor(rgb(on and C.accent or C.surface))
			b:SetBackdropBorderColor(rgb(b.edge))
			b.text:SetTextColor(rgb(on and C.dark or C.text))
		end
	end
	return y - 60
end

-- label, value and [-] [+]
local function Stepper(parent, y, label, hint, lo, hi, step, fmt, get, set)
	local fs = Text(parent, 12)
	fs:SetPoint("TOPLEFT", colX, y - 3)
	fs:SetText(label)
	local plus = ns.FlatButton(parent, "+", 22, 20)
	plus:SetPoint("TOPRIGHT", parent, "TOPLEFT", colX + COL_W, y)
	local value = Text(parent, 12, C.accentText)
	value:SetWidth(44)
	value:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	local minus = ns.FlatButton(parent, "-", 22, 20)
	minus:SetPoint("RIGHT", value, "LEFT", -4, 0)
	local function bump(d)
		local v = math.floor((get() + d) / step + 0.5) * step
		if v < lo - step / 2 or v > hi + step / 2 then return end
		set(v); Changed()
	end
	minus:SetScript("OnClick", function() bump(-step) end)
	plus:SetScript("OnClick", function() bump(step) end)
	Hint(parent, fs, hint)
	refreshers[#refreshers + 1] = function() value:SetText(fmt:format(get())) end
	return y - 42
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
	ns.Skin(panel, C.panelD, 0.97)
	tinsert(UISpecialFrames, "RatStashOptions")

	local head = CreateFrame("Frame", nil, panel)
	head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1)
	head:SetHeight(32)
	head:EnableMouse(true)
	head:RegisterForDrag("LeftButton")
	head:SetScript("OnDragStart", function() panel:StartMoving() end)
	head:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
	local title = Text(head, 14, C.accentText)
	title:SetPoint("LEFT", MARGIN - 1, 0)
	title:SetText("RatStash settings")
	local rule = ns.Rule(head)
	rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
	local close = ns.FlatButton(head, "X", 22, 20)
	close:SetPoint("RIGHT", -8, 0)
	close:SetScript("OnClick", function() panel:Hide() end)

	-- left column: how the windows are laid out, and what items show
	colX = MARGIN
	local y = -46
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
	y = -46
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

	y = Section(panel, y - 6, "Items")
	y = Check(panel, y, "Show item level", "Gear shows its item level in the quality color.",
		function() return db.showIlvl end, function(v) db.showIlvl = v end)
	y = Check(panel, y, "Show BoE tag", "Bind-on-equip gear gets a gold BoE tag.",
		function() return db.showBoE end, function(v) db.showBoE = v end)
	y = Check(panel, y, "Raid loot group as master looter", "While you are master looter, raid loot gets its own group.",
		function() return db.mlGroup end, function(v) db.mlGroup = v end)

	-- virtual stacks go under the left column, which is shorter
	colX = MARGIN
	local vy = Section(panel, leftEnd - 6, "Virtual stacks")
	vy = Check(panel, vy, "Merge unstackable items", "Identical items that can't stack show as one slot.",
		function() return db.vs.others end, function(v) db.vs.others = v end)
	vy = Check(panel, vy, "Merge stackable items", "Full stacks of the same item show as one slot.",
		function() return db.vs.stack end, function(v) db.vs.stack = v end)
	vy = Check(panel, vy, "... including incomplete stacks", "Partial stacks join the merged slot too.",
		function() return db.vs.incomplete end, function(v) db.vs.incomplete = v end)

	panel:SetHeight(-math.min(y, vy) + 10)
	panel:SetScript("OnShow", function() for _, fn in ipairs(refreshers) do fn() end end)
end

function ns.OpenOptions()
	if panel:IsShown() then panel:Hide() else panel:Show() end
end
