local ADDON, ns = ...
local L = ns.L

local SIZE, GAP = 37, 4
local STEP = SIZE + GAP
local PAD = 10
local TOP_H = 24
local BAGBAR_H = 40
local FOOT_H = 22
local HEADER_H = 16
local SECTION_GAP = 12
local LOOKAHEAD = 3 -- how far ahead a small block may be pulled up to fill a gap
local EMPTY_TEX = [[Interface\AddOns\RatStash\Media\empty-slot]]
local BG_TEX = [[Interface\AddOns\RatStash\Media\bag-bg]]
local BG_ASPECT = 1 -- width / height of bag-bg

local STYLE_COLOR = {
	set = { 0.78, 0.6, 1 },
	raid = { 0.486, 0.988, 0.541 },
	hr = { 0.85, 0.30, 0.32 },
	pin = { 0.43, 0.7, 1 },
	cat = { 0.88, 0.72, 0.38 },
}

--------------------------------------------------------------------------------
-- item buttons (Blizzard ContainerFrameItemButtonTemplate: the game handles click, use,
-- drag, sell and split for us as long as button:GetParent():GetID() is the bag)
--------------------------------------------------------------------------------

local function Tooltip_Anchor(self)
	if self:GetRight() >= GetScreenWidth() / 2 then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
end

local function Item_OnEnter(self)
	local e = self.entry
	if not e then return end
	if self.cached then
		if not e.link then return end
		Tooltip_Anchor(self)
		GameTooltip:SetHyperlink(e.link)
	elseif e.bag == BANK_CONTAINER then
		Tooltip_Anchor(self)
		if not GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(e.slot)) then
			if not e.freeCount then GameTooltip:Hide(); return end
		end
		CursorUpdate(self)
	else
		ContainerFrameItemButton_OnEnter(self)
	end
	if e.freeCount then
		if not GameTooltip:IsShown() then Tooltip_Anchor(self) end
		GameTooltip:SetText(string.format(L["FREE_SLOTS_FMT"], e.freeCount), 1, 1, 1)
		GameTooltip:AddLine(L["DROP_ITEM_FREE_SLOT"], 0.7, 0.7, 0.7)
	end
	if e.fresh then
		GameTooltip:AddLine(string.format(L["RAID_LOOT_LINE"], e.fresh), 0.24, 0.86, 0.52)
		if e.split then GameTooltip:AddLine(string.format(L["CLICK_SPLIT_STACK"], e.split), 0.24, 0.86, 0.52) end
		if e.reserved then GameTooltip:AddLine("Okanvil: " .. e.reserved, 1, 0.33, 0.33) end
	end
	if e.slots and e.slots > 1 then
		GameTooltip:AddLine(string.format(L["MERGED_BAG_SLOTS"], e.slots), 0.43, 0.7, 1)
	end
	if e.pinned then
		GameTooltip:AddLine(L["PINNED_TOOLTIP"], 0.43, 0.7, 1)
	end
	GameTooltip:Show()
end

local function Item_OnLeave()
	GameTooltip:Hide()
	ResetCursor()
end

-- The template's own OnClick must stay in place: a handler set by an addon is
-- insecure, and UseContainerItem called from it is blocked, so right-click
-- would stop using items. Our extras run around it instead. PreClick decides
-- (the cursor is still empty then), Blizzard's OnClick runs, and PostClick
-- undoes its pickup where we wanted something else.
local function Item_PreClick(self, button)
	self.clickAction = nil
	local e = self.entry
	if not e then return end
	local held = CursorHasItem()
	if self.cached then
		self.clickAction = "cached"
	elseif IsAltKeyDown() and e.id and button == "LeftButton" and not held then
		self.clickAction = "pin"
	elseif e.split and button == "LeftButton" and not IsModifiedClick() and not held then
		self.clickAction = "split"
	end
end

local function Item_PostClick(self)
	local action, e = self.clickAction, self.entry
	self.clickAction = nil
	if not (action and e) then return end
	if action == "cached" then
		-- an offline bank slot: nothing real to pick up, only links to chat
		if CursorHasItem() then ClearCursor() end
		if e.link and IsModifiedClick() then HandleModifiedItemClick(e.link) end
	elseif action == "pin" then
		if CursorHasItem() then ClearCursor() end
		ns.TogglePin(e.id)
	elseif action == "split" then
		if CursorHasItem() then ClearCursor() end
		SplitContainerItem(e.bag, e.slot, e.split)
	end
end

local function Item_OnDragStart(self, ...)
	if self.cached or not self.origDrag then return end
	self.origDrag(self, ...)
end

local function Item_OnReceiveDrag(self, ...)
	if self.cached or not self.origReceive then return end
	self.origReceive(self, ...)
end

local function NewItemButton(win, i)
	local b = CreateFrame("Button", win:GetName() .. "Item" .. i, nil, "ContainerFrameItemButtonTemplate")
	b:SetFrameStrata(win:GetFrameStrata())
	local name = b:GetName()
	b.icon = _G[name .. "IconTexture"]
	b.cooldown = _G[name .. "Cooldown"]
	b.questTex = _G[name .. "IconQuestTexture"]

	b.origDrag = b:GetScript("OnDragStart")
	b.origReceive = b:GetScript("OnReceiveDrag")
	b:SetScript("OnEvent", nil)
	b:SetScript("PreClick", Item_PreClick)
	b:SetScript("PostClick", Item_PostClick)
	b:SetScript("OnDragStart", Item_OnDragStart)
	b:SetScript("OnReceiveDrag", Item_OnReceiveDrag)
	b:SetScript("OnEnter", Item_OnEnter)
	b:SetScript("OnLeave", Item_OnLeave)
	b.UpdateTooltip = Item_OnEnter

	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
	border:SetBlendMode("ADD")
	border:SetWidth(67); border:SetHeight(67)
	border:SetPoint("CENTER", b)
	border:Hide()
	b.border = border

	local glow = b:CreateTexture(nil, "OVERLAY")
	glow:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(0.24, 0.95, 0.52)
	glow:SetWidth(72); glow:SetHeight(72)
	glow:SetPoint("CENTER", b)
	glow:Hide()
	b.glow = glow

	local ilvl = b:CreateFontString(nil, "OVERLAY")
	ilvl:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
	ilvl:SetShadowColor(0, 0, 0, 1)
	ilvl:SetShadowOffset(1, -1)
	ilvl:SetPoint("BOTTOM", 0, 2)
	b.ilvl = ilvl

	local boe = b:CreateFontString(nil, "OVERLAY")
	boe:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
	boe:SetShadowColor(0, 0, 0, 1)
	boe:SetShadowOffset(1, -1)
	boe:SetPoint("TOPLEFT", 2, -2)
	boe:SetTextColor(1, 0.82, 0.29)
	boe:SetText("BoE")
	b.boe = boe

	local timer = b:CreateFontString(nil, "OVERLAY")
	timer:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
	timer:SetPoint("TOPRIGHT", -2, -2)
	timer:SetTextColor(0.24, 0.95, 0.52)
	b.timer = timer

	return b
end

local function Matches(e, q)
	if not e.link then return false end
	if e.name:lower():find(q, 1, true) then return true end
	if e.itype:lower():find(q, 1, true) or e.stype:lower():find(q, 1, true) then return true end
	if e.set and e.set:lower():find(q, 1, true) then return true end
	if q == "boe" and e.boe then return true end
	return false
end

--------------------------------------------------------------------------------
-- window
--------------------------------------------------------------------------------

local W = {}

function W:ItemButton(i)
	local b = self.buttons[i]
	if not b then
		b = NewItemButton(self, i)
		self.buttons[i] = b
	end
	return b
end

function W:Header(i)
	local fs = self.headers[i]
	if not fs then
		fs = ns.Font(self.content:CreateFontString(nil, "OVERLAY"), 11)
		fs:SetJustifyH("LEFT")
		fs.rule = ns.Rule(self.content)
		self.headers[i] = fs
	end
	fs:Show()
	return fs
end

function W:SetEntry(b, e, cached)
	b.entry = e
	b.cached = cached
	b:SetParent(self.dummy[e.bag])
	b:SetID(e.slot)
	b:SetFrameLevel(self.content:GetFrameLevel() + 2)

	local db = ns.db
	if e.link then
		SetItemButtonTexture(b, e.tex)
		SetItemButtonCount(b, (e.maxStack == 1 and e.slots and e.slots > 1) and e.slots or e.count)
		SetItemButtonDesaturated(b, e.locked)
		if e.quality and e.quality > 1 then
			local r, g, bl = GetItemQualityColor(e.quality)
			b.border:SetVertexColor(r, g, bl, 0.6)
			b.border:Show()
		else
			b.border:Hide()
		end
		if db.showIlvl and e.showIlvl then
			local r, g, bl = GetItemQualityColor(e.quality or 1)
			b.ilvl:SetText(e.ilvl)
			b.ilvl:SetTextColor(r, g, bl)
			b.ilvl:Show()
		else
			b.ilvl:Hide()
		end
		if db.showBoE and e.boe then b.boe:Show() else b.boe:Hide() end
		if e.fresh then b.glow:Show() else b.glow:Hide() end
		if e.timer then b.timer:SetText(e.timer); b.timer:Show() else b.timer:Hide() end
	else
		SetItemButtonTexture(b, EMPTY_TEX)
		SetItemButtonCount(b, e.freeCount or 0)
		SetItemButtonDesaturated(b, false)
		b.border:Hide(); b.glow:Hide(); b.ilvl:Hide(); b.boe:Hide(); b.timer:Hide()
	end
	if b.questTex then b.questTex:Hide() end

	if e.link and not cached then
		ContainerFrame_UpdateCooldown(e.bag, b)
	else
		CooldownFrame_SetTimer(b.cooldown, 0, 0, 0)
	end
end

function W:ApplyFilter()
	local q = self.search:GetText():lower():trim()
	local hover = self.hoverBag
	for _, b in ipairs(self.buttons) do
		local e = b:IsShown() and b.entry
		if e then
			local dim = (q ~= "" and not Matches(e, q)) or (hover and e.bag ~= hover)
			b:SetAlpha(dim and 0.25 or 1)
		end
	end
end

-- while the mouse is on the window items are not reshuffled (selling or moving several items
-- in a row would otherwise make the next target jump). Buttons still show what their slot holds.
function W:Update()
	if not self:IsShown() then return end
	if self.laidOut and MouseIsOver(self) and not self.cached then
		self:RefreshInPlace()
		self.pending = true
		return
	end
	self:Layout()
end

-- A merged slot re-adds its real slots, so using one of its stacks shows at once.
-- If the slot the button points at runs out, it moves to one that still has the item.
function W:RefreshMerged(b, e)
	local total, slots, repOk, first, free = 0, 0, false, nil, nil
	for _, m in ipairs(e.members) do
		local _, count, lk, _, _, _, link = GetContainerItemInfo(m.bag, m.slot)
		if link and ns.ItemID(link) == e.id then
			total, slots = total + (count or 0), slots + 1
			first = first or m
			free = free or (not lk and m)
			if m.bag == e.bag and m.slot == e.slot and not lk then repOk = true end
		end
	end
	if not first then
		self:SetEntry(b, { bag = e.bag, slot = e.slot, key = e.key }, false)
		return
	end
	-- gray only when every slot is locked; otherwise point the button at one that can be picked up
	local locked = not free
	if not repOk then
		local to = free or first
		e.bag, e.slot = to.bag, to.slot
		b:SetParent(self.dummy[e.bag])
		b:SetID(e.slot)
	end
	e.count, e.slots, e.locked = total, slots, locked
	SetItemButtonCount(b, (e.maxStack == 1 and slots > 1) and slots or total)
	SetItemButtonDesaturated(b, locked)
	ContainerFrame_UpdateCooldown(e.bag, b)
end

function W:RefreshInPlace()
	for _, b in ipairs(self.buttons) do
		local e = b:IsShown() and b.entry
		if e and e.members and #e.members > 1 then
			self:RefreshMerged(b, e)
		elseif e and not e.freeCount then
			local tex, count, locked, _, _, _, link = GetContainerItemInfo(e.bag, e.slot)
			if link ~= e.link then
				local live = { bag = e.bag, slot = e.slot, key = e.key }
				if link then
					live.link, live.tex, live.count, live.locked, live.maxStack = link, tex, count, locked, 1
				end
				self:SetEntry(b, live, false)
			elseif not e.split and not (e.slots and e.slots > 1) then
				e.count, e.locked = count, locked
				SetItemButtonCount(b, count)
				SetItemButtonDesaturated(b, locked)
				ContainerFrame_UpdateCooldown(e.bag, b)
			else
				SetItemButtonDesaturated(b, locked)
			end
		end
	end
end

function W:Layout()
	self.pending = nil
	self.laidOut = true
	if self.matsBtn then self.matsBtn:SetAlpha(ns.atBank and 1 or 0.45) end
	local sections, free, cached = ns.BuildSections(self.kind)
	self.cached = cached
	local cols = ns.db.columns[self.kind]
	local totalW = cols * STEP - GAP
	local packed = ns.db.layout[self.kind] == "groups"
	local content = self.content

	-- measure every block first: columns, width (a short block is at least as wide as its title), height
	if not self.measure then
		self.measure = ns.Font(content:CreateFontString(nil, "OVERLAY"), 11)
		self.measure:Hide()
	end
	for _, sec in ipairs(sections) do
		local n = #sec.entries
		-- Treat any block with fewer slots than window columns as compact
		sec.small = packed and n < cols and not sec.stay
		sec.wcols = sec.small and math.max(1, math.min(n, cols)) or cols
		sec.w = sec.wcols * STEP - GAP
		if sec.title and sec.small then
			self.measure:SetText((L[sec.title] or sec.title):upper())
			local titleW = self.measure:GetStringWidth() + 4
			if titleW > sec.w then
				sec.w = titleW
				sec.wcols = math.max(sec.wcols, math.ceil((titleW + GAP) / STEP))
			end
		end
		sec.h = (sec.title and HEADER_H or 0) + math.max(1, math.ceil(n / sec.wcols)) * STEP - GAP
		-- Allow Consumables, Gear and Free sections to move and pack tightly into row gaps
		sec.movable = sec.small and not sec.stay
	end

	local x, y, rowH = 0, 0, 0
	local bi, hi = 0, 0

	local function place(sec)
		local th = sec.title and HEADER_H or 0
		if x > 0 and (x + sec.w > totalW) then
			y = y + rowH + 10
			x = 0
			rowH = 0
		end

		if sec.title then
			hi = hi + 1
			local fs = self:Header(hi)
			fs:SetText((L[sec.title] or sec.title):upper())
			local c = STYLE_COLOR[sec.style] or STYLE_COLOR.cat
			fs:SetTextColor(c[1], c[2], c[3])
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
			fs.rule:ClearAllPoints()
			if sec.small and (x + sec.w + 40 < totalW) then
				fs.rule:Hide()
			else
				local ruleW = totalW - x - fs:GetStringWidth() - 8
				fs.rule:SetPoint("LEFT", fs, "RIGHT", 8, 0)
				fs.rule:SetWidth(math.max(1, ruleW))
				if ruleW > 0 then fs.rule:Show() else fs.rule:Hide() end
			end
		end

		for i, e in ipairs(sec.entries) do
			bi = bi + 1
			local b = self:ItemButton(bi)
			local col = (i - 1) % sec.wcols
			local row = math.floor((i - 1) / sec.wcols)
			self:SetEntry(b, e, cached)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", content, "TOPLEFT", x + col * STEP, -(y + th + row * STEP))
			b:Show()
		end

		rowH = math.max(rowH, sec.h)
		if sec.small then
			x = x + sec.w + SECTION_GAP
		else
			y = y + rowH + 10
			x = 0
			rowH = 0
		end
	end

	local queue = {}
	for i, sec in ipairs(sections) do queue[i] = sec end

	while #queue > 0 do
		local sec = table.remove(queue, 1)
		place(sec)

		local spaceLeft = totalW - x
		local placedExtra = true
		while placedExtra and spaceLeft >= (STEP * 2) do
			placedExtra = false
			for i = 1, #queue do
				local candidate = queue[i]
				if candidate.movable and candidate.w <= spaceLeft then
					table.remove(queue, i)
					place(candidate)
					spaceLeft = totalW - x
					placedExtra = true
					break
				end
			end
		end
	end

	y = y + rowH

	for i = bi + 1, #self.buttons do
		local b = self.buttons[i]
		b:Hide()
		b.entry = nil
	end
	for i = hi + 1, #self.headers do self.headers[i]:Hide(); self.headers[i].rule:Hide() end

	content:SetWidth(totalW)
	content:SetHeight(math.max(y, SIZE))

	self.freeText:SetText(string.format(L["FREE_SUMMARY"], free))
	if self.kind == "bags" then
		if ns.HasRaidLoot() then self.keep:Show() else self.keep:Hide() end
	else
		if cached then self.offline:Show(); self.stack:Hide() else self.offline:Hide(); self.stack:Show() end
	end
	self:UpdateBagBar()
	self:ApplyFilter()
	self:Resize(totalW, math.max(y, SIZE))
end

function W:Resize(cw, ch)
	local barH = self.bagbar:IsShown() and BAGBAR_H or 0
	self.content:ClearAllPoints()
	self.content:SetPoint("TOPLEFT", PAD, -(PAD + TOP_H + barH + 8))
	-- Lower minimum width to prevent empty space when column count is below 11.
	-- 295px perfectly fits: Title + 100px Search + Action Buttons + Padding.
	local minW = self.kind == "bags" and 295 or 240
	local w = math.max(cw + PAD * 2, minW)
	self:SetWidth(w)
	local h = PAD + TOP_H + barH + 8 + ch + 8 + FOOT_H + PAD - 4
	self:SetHeight(h)
	self:UpdateArt(w, h)
end

-- Show the part of the picture that has the window's shape, so it is never stretched. Short rows end
-- on the left, so the free space is on the right: a narrow window keeps the RIGHT edge of the art,
-- a wide one keeps the middle band.
function W:UpdateArt(w, h)
	local a = ns.db.bgOn and (ns.db.bgArt or 0) or 0
	if a <= 0 then self.art:Hide(); self.wash:Hide(); return end
	local want = w / h
	if want < BG_ASPECT then
		local span = want / BG_ASPECT
		self.art:SetTexCoord(1 - span, 1, 0, 1)
	else
		local span = BG_ASPECT / want
		self.art:SetTexCoord(0, 1, 0.5 - span / 2, 0.5 + span / 2)
	end
	self.art:Show()
	-- darker on the left where the icons are, lighter on the right where the art is;
	-- stronger art = thinner wash
	local d = ns.C.panelD
	self.wash:SetGradientAlpha("HORIZONTAL", d[1], d[2], d[3], 0.95 - a * 0.25, d[1], d[2], d[3], 0.85 - a * 0.65)
	self.wash:Show()
end

--------------------------------------------------------------------------------
-- bag slot bar (drag a bag onto a slot to swap it; empty bank slots can be bought)
--------------------------------------------------------------------------------

StaticPopupDialogs.RATSTASH_BUY_BANK_SLOT = {
	text = CONFIRM_BUY_BANK_SLOT,
	button1 = YES,
	button2 = NO,
	OnAccept = function() PurchaseSlot() end,
	OnShow = function(self) MoneyFrame_Update(self:GetName() .. "MoneyFrame", GetBankSlotCost(GetNumBankSlots())) end,
	hasMoneyFrame = 1,
	timeout = 0,
	hideOnEscape = 1,
}

local function IsPurchasable(bag)
	if bag <= NUM_BAG_SLOTS then return false end
	local owned = ns.atBank and GetNumBankSlots() or (ns.char.bank and ns.char.bank.numSlots or 0)
	return (bag - NUM_BAG_SLOTS) > owned
end

local function Bag_OnClick(self)
	local bag, win = self:GetID(), self.win
	if win.cached then return end
	if IsPurchasable(bag) then
		StaticPopup_Show("RATSTASH_BUY_BANK_SLOT")
	elseif CursorHasItem() then
		if bag == BACKPACK_CONTAINER then
			PutItemInBackpack()
		elseif bag ~= BANK_CONTAINER then
			PutItemInBag(ContainerIDToInventoryID(bag))
		end
	end
end

local function Bag_OnDragStart(self)
	local bag = self:GetID()
	if self.win.cached or bag == BACKPACK_CONTAINER or bag == BANK_CONTAINER then return end
	PickupBagFromSlot(ContainerIDToInventoryID(bag))
end

local function Bag_OnEnter(self)
	local bag = self:GetID()
	Tooltip_Anchor(self)
	if bag == BACKPACK_CONTAINER then
		GameTooltip:SetText(BACKPACK_TOOLTIP, 1, 1, 1)
	elseif bag == BANK_CONTAINER then
		GameTooltip:SetText("Bank", 1, 1, 1)
	elseif IsPurchasable(bag) then
		GameTooltip:SetText(BANK_BAG_PURCHASE, 1, 1, 1)
		if ns.atBank then SetTooltipMoney(GameTooltip, GetBankSlotCost(GetNumBankSlots())) end
	elseif self.win.cached then
		local info = ns.char.bank and ns.char.bank.bags[bag]
		if info and info.link then GameTooltip:SetHyperlink(info.link) else GameTooltip:SetText(BANK_BAG, 1, 1, 1) end
	elseif not GameTooltip:SetInventoryItem("player", ContainerIDToInventoryID(bag)) then
		GameTooltip:SetText(EQUIP_CONTAINER, 1, 1, 1)
	end
	if bag ~= BACKPACK_CONTAINER and bag ~= BANK_CONTAINER and not self.win.cached then
		GameTooltip:AddLine(L["DRAG_BAG_SWAP"], 0.7, 0.7, 0.7)
	end
	GameTooltip:Show()
	self.win.hoverBag = bag
	self.win:ApplyFilter()
end

local function Bag_OnLeave(self)
	GameTooltip:Hide()
	self.win.hoverBag = nil
	self.win:ApplyFilter()
end

function W:CreateBagBar()
	local bar = CreateFrame("Frame", nil, self)
	bar:SetHeight(BAGBAR_H)
	bar:SetPoint("TOPLEFT", PAD, -(PAD + TOP_H + 4))
	bar:SetPoint("TOPRIGHT", -PAD, -(PAD + TOP_H + 4))
	bar:Hide()
	self.bagbar = bar
	self.bagButtons = {}
	local ids = self.kind == "bags" and ns.BAGS or ns.BANK
	for i, bag in ipairs(ids) do
		local b = CreateFrame("Button", self:GetName() .. "Bag" .. i, bar, "ItemButtonTemplate")
		b.win = self
		b:SetID(bag)
		b:SetScale(0.85)
		b:SetPoint("LEFT", (i - 1) * 40 / 0.85, 0)
		b:RegisterForClicks("AnyUp")
		b:RegisterForDrag("LeftButton")
		b:SetScript("OnClick", Bag_OnClick)
		b:SetScript("OnReceiveDrag", Bag_OnClick)
		b:SetScript("OnDragStart", Bag_OnDragStart)
		b:SetScript("OnEnter", Bag_OnEnter)
		b:SetScript("OnLeave", Bag_OnLeave)
		self.bagButtons[i] = b
	end
end

function W:UpdateBagBar()
	if not self.bagbar:IsShown() then return end
	for _, b in ipairs(self.bagButtons) do
		local bag = b:GetID()
		local tex, size
		if bag == BACKPACK_CONTAINER or bag == BANK_CONTAINER then
			tex = [[Interface\Buttons\Button-Backpack-Up]]
		elseif self.cached then
			local info = ns.char.bank and ns.char.bank.bags[bag]
			tex = info and info.link and GetItemIcon(info.link)
		else
			tex = GetInventoryItemTexture("player", ContainerIDToInventoryID(bag))
		end
		if self.cached then
			local info = ns.char.bank and ns.char.bank.bags[bag]
			size = info and info.size or 0
		else
			size = GetContainerNumSlots(bag) or 0
		end
		SetItemButtonTexture(b, tex or [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]])
		SetItemButtonCount(b, size)
		if IsPurchasable(bag) then
			SetItemButtonTextureVertexColor(b, 1, 0.1, 0.1)
		else
			SetItemButtonTextureVertexColor(b, 1, 1, 1)
		end
	end
end

--------------------------------------------------------------------------------
-- construction
--------------------------------------------------------------------------------

local function IconButton(parent, texture, tipText, onClick)
	local b = ns.FlatIconButton(parent, texture, 20)
	b:SetScript("OnClick", onClick)
	b:HookScript("OnEnter", function(self)
		Tooltip_Anchor(self)
		GameTooltip:SetText(tipText, 1, 1, 1)
		GameTooltip:Show()
	end)
	b:HookScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

local DEFAULT_POS = {
	bags = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -60, 110 },
	bank = { "TOPLEFT", "UIParent", "TOPLEFT", 60, -120 },
}

function ns.CreateWindow(kind)
	local name = kind == "bags" and "RatStashBags" or "RatStashBank"
	local f = CreateFrame("Frame", name, UIParent)
	for k, v in pairs(W) do f[k] = v end
	f.kind = kind
	f.buttons, f.headers = {}, {}
	f:Hide()
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:SetScale(ns.db.scale)
	ns.Skin(f, ns.C.panelD, 0.95)
	-- the stash art behind the items, under a dark wash so icons and numbers stay readable
	local art = f:CreateTexture(nil, "BORDER")
	art:SetPoint("TOPLEFT", 1, -1); art:SetPoint("BOTTOMRIGHT", -1, 1)
	art:SetTexture(BG_TEX)
	local wash = f:CreateTexture(nil, "ARTWORK")
	wash:SetAllPoints(art)
	wash:SetTexture(ns.FLAT)
	f.art, f.wash = art, wash
	local headRule = ns.Rule(f)
	headRule:SetPoint("TOPLEFT", 1, -(PAD + TOP_H + 1))
	headRule:SetPoint("TOPRIGHT", -1, -(PAD + TOP_H + 1))
	local footRule = ns.Rule(f)
	footRule:SetPoint("BOTTOMLEFT", 1, PAD + FOOT_H - 2)
	footRule:SetPoint("BOTTOMRIGHT", -1, PAD + FOOT_H - 2)
	tinsert(UISpecialFrames, name)

	local pos = ns.db.pos[kind] or DEFAULT_POS[kind]
	f:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])

	-- the title row drags the window
	local drag = CreateFrame("Frame", nil, f)
	drag:SetPoint("TOPLEFT", PAD, -PAD)
	drag:SetPoint("TOPRIGHT", -PAD, -PAD)
	drag:SetHeight(TOP_H)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function() f:StartMoving() end)
	drag:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local p, _, rp, x, y = f:GetPoint()
		ns.db.pos[kind] = { p, "UIParent", rp, x, y }
	end)

	-- Concise window title without redundant player name
	local title = ns.Font(drag:CreateFontString(nil, "OVERLAY"), 14)
	title:SetTextColor(ns.rgb(ns.C.accentText))
	title:SetPoint("LEFT", 0, 0)
	title:SetText(kind == "bags" and L["BAGS_TITLE"] or L["BANK_TITLE"])

	local close = ns.FlatButton(f, "X", 22, 20)
	close:SetPoint("TOPRIGHT", -PAD, -PAD - 2)
	close:SetScript("OnClick", function() f:Hide() end)

	local opts = IconButton(f, [[Interface\Icons\INV_Misc_Gear_01]], L["OPTIONS_TIP"], function() ns.OpenOptions() end)
	opts:SetPoint("RIGHT", close, "LEFT", -4, 0)
	local bagsBtn = IconButton(f, [[Interface\Icons\INV_Misc_Bag_08]], L["SHOW_BAG_SLOTS"], function()
		if f.bagbar:IsShown() then f.bagbar:Hide() else f.bagbar:Show() end
		f:Layout()
	end)
	bagsBtn:SetPoint("RIGHT", opts, "LEFT", -4, 0)
	local anchor = bagsBtn
	if kind == "bags" then
		local bankBtn = IconButton(f, [[Interface\Icons\INV_Misc_Coin_01]], L["BANK_OFFLINE_TIP"], ns.ToggleBank)
		bankBtn:SetPoint("RIGHT", bagsBtn, "LEFT", -4, 0)
		
		local mats = IconButton(f, [[Interface\Icons\INV_Ore_Saronite_01]], L["SEND_MATS_TO_BANK"], ns.SendMatsToBank)
		mats:HookScript("OnEnter", function()
			GameTooltip:AddLine(L["SEND_MATS_DESC"], 0.7, 0.7, 0.7, true)
			if not ns.atBank then GameTooltip:AddLine(L["OPEN_BANK_FIRST"], 1, 0.82, 0) end
			GameTooltip:Show()
		end)
		mats:SetPoint("RIGHT", bankBtn, "LEFT", -4, 0)
		f.bankBtn = bankBtn
		f.matsBtn = mats
		anchor = mats
	end

	-- Compact search box width (100px) to allow narrower window configurations
	local search = ns.FlatInput(f, name .. "Search", 100, 20)
	search:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
	search:SetScript("OnEscapePressed", search.ClearFocus)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	local hint = ns.Font(search:CreateFontString(nil, "OVERLAY"), 11)
	hint:SetTextColor(ns.rgb(ns.C.textDim))
	hint:SetPoint("LEFT", 6, 0)
	hint:SetText(SEARCH)
	local function updateHint()
		if search:GetText() == "" and not search:HasFocus() then hint:Show() else hint:Hide() end
	end
	search:SetScript("OnTextChanged", function() updateHint(); f:ApplyFilter() end)
	search:HookScript("OnEditFocusGained", updateHint)
	search:HookScript("OnEditFocusLost", updateHint)
	f.search = search

	title:SetPoint("RIGHT", search, "LEFT", -10, 0)
	title:SetJustifyH("LEFT")

	-- the drag area stops before the search box so it never sits on top of the buttons
	drag:ClearAllPoints()
	drag:SetPoint("TOPLEFT", PAD, -PAD)
	drag:SetPoint("RIGHT", search, "LEFT", -10, 0)
	drag:SetHeight(TOP_H)
	local top = drag:GetFrameLevel() + 2
	for _, b in ipairs({ opts, bagsBtn, anchor, close, f.bankBtn }) do b:SetFrameLevel(top) end
	search:SetFrameLevel(top)

	f:CreateBagBar()

	local content = CreateFrame("Frame", nil, f)
	content:SetWidth(SIZE); content:SetHeight(SIZE)
	f.content = content
	-- Blizzard's item code reads the bag id from the button's parent
	f.dummy = setmetatable({}, { __index = function(t, bag)
		local d = CreateFrame("Frame", nil, content)
		d:SetID(bag)
		d:SetAllPoints(content)
		t[bag] = d
		return d
	end })

	local freeText = ns.Font(f:CreateFontString(nil, "OVERLAY"), 11)
	freeText:SetPoint("BOTTOMLEFT", PAD + 2, PAD + 3)
	freeText:SetTextColor(ns.rgb(ns.C.textDim))
	f.freeText = freeText

	if kind == "bags" then
		local keep = ns.FlatButton(f, L["KEEP_RAID_LOOT"], 110, 18, true)
		keep:SetPoint("LEFT", freeText, "RIGHT", 12, 0)
		keep:SetScript("OnClick", function()
			ns.KeepRaidLoot()
			ns.ScanBags()
			f:Layout()
		end)
		keep:HookScript("OnEnter", function(self)
			Tooltip_Anchor(self)
			GameTooltip:SetText(L["KEEP_RAID_LOOT"], 1, 1, 1)
			GameTooltip:AddLine(L["KEEP_RAID_LOOT_DESC"], 0.7, 0.7, 0.7, true)
			GameTooltip:Show()
		end)
		keep:HookScript("OnLeave", function() GameTooltip:Hide() end)
		keep:Hide()
		f.keep = keep
        -- ...
	else
		local offline = ns.Font(f:CreateFontString(nil, "OVERLAY"), 11)
		offline:SetTextColor(ns.rgb(ns.C.textDim))
		offline:SetPoint("BOTTOMRIGHT", -PAD - 2, PAD + 3)
		offline:SetText(L["OFFLINE_BANK_NOTE"])
		offline:Hide()
		f.offline = offline

		local stack = ns.FlatButton(f, L["STACK_TO_BANK"], 110, 18, true)
		stack:SetPoint("LEFT", freeText, "RIGHT", 12, 0)
		stack:SetScript("OnClick", ns.StackToBank)
		stack:HookScript("OnEnter", function(self)
			Tooltip_Anchor(self)
			GameTooltip:SetText(L["STACK_TO_BANK"], 1, 1, 1)
			GameTooltip:AddLine(L["STACK_TO_BANK_DESC"], 0.7, 0.7, 0.7, true)
			GameTooltip:Show()
		end)
		stack:HookScript("OnLeave", function() GameTooltip:Hide() end)
		f.stack = stack
	end

	f:SetScript("OnShow", function(self)
		PlaySound("igBackPackOpen")
		self:Layout()
	end)
	f:SetScript("OnHide", function(self)
		PlaySound("igBackPackClose")
		self.search:ClearFocus()
		self.hoverBag = nil
		if self.kind == "bank" and ns.atBank then CloseBankFrame() end
	end)
	-- a layout skipped while the mouse was on the window happens as soon as it leaves
	f:SetScript("OnUpdate", function(self)
		if self.pending and not MouseIsOver(self) then self:Layout() end
	end)

	f:Resize(SIZE, SIZE)
	return f
end

function ns.TogglePin(id)
	local db = ns.db
	if db.pins[id] then
		db.pins[id] = false
	else
		-- remember the order things were pinned in; that is the order they are shown in
		db.pinSeq = (db.pinSeq or 0) + 1
		db.pins[id] = db.pinSeq
	end
	ns.RelayoutAll()
end

local HEARTHSTONE = 6948

-- Hearthstone always first, then pinned items in the order they were pinned
function ns.PinRank(id)
	if id == HEARTHSTONE then return -1 end
	local v = ns.db.pins[id]
	return type(v) == "number" and v or 0
end

function ns.RelayoutAll()
	for _, w in pairs(ns.windows) do
		w:SetScale(ns.db.scale)
		if w:IsShown() then w:Layout() end
	end
end

--------------------------------------------------------------------------------
-- Stack to bank: one move at a time, waiting for the game to unlock both slots before the next.
-- A move tops up a bank stack of the same item (splitting off exactly the room left) or, when
-- every bank stack is full, puts the stack in a free bank slot.
--------------------------------------------------------------------------------

local mover = CreateFrame("Frame")
mover:Hide()
local moved, waitFor, idle = 0, nil, 0

local function Slot(bag, slot)
	local _, count, locked, _, _, _, link = GetContainerItemInfo(bag, slot)
	return link, count or 0, locked
end

local function MaxStack(link)
	return select(8, GetItemInfo(link)) or 1
end

local function KeepInBags(bag, slot, id)
	local fresh = ns.char.fresh
	return ns.db.pins[id] or fresh.stack[id] or fresh.slot[bag .. ":" .. slot]
end

local AH_CLASS = { GetAuctionItemClasses() }
local TRADE_GOODS, GEMS = AH_CLASS[6], AH_CLASS[10]

-- crafting materials: trade goods (dusts and essences included) and gems
local function IsMat(link)
	local _, _, quality, _, _, itype = GetItemInfo(link)
	return quality ~= 0 and (itype == TRADE_GOODS or itype == GEMS)
end

-- mode "stack": items the bank already holds, onto their bank stacks
-- mode "mats":  every material, topping up bank stacks first, then free bank slots;
--               only pins keep a material in the bags (raid loot marks do not)
local function Wanted(mode, bag, slot, id, link, inBank)
	if mode == "mats" then
		return IsMat(link) and not ns.db.pins[id]
	end
	return inBank[id] and MaxStack(link) > 1 and not KeepInBags(bag, slot, id)
end

local mode = "stack"

local function NextMove()
	local inBank, partial, free = {}, {}, nil
	for _, bag in ipairs(ns.BANK) do
		local _, btype = GetContainerNumFreeSlots(bag)
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link, count, locked = Slot(bag, slot)
			if link then
				local id = ns.ItemID(link)
				inBank[id] = true
				local max = MaxStack(link)
				if max > 1 and count < max and not locked and not partial[id] then
					partial[id] = { bag = bag, slot = slot, room = max - count }
				end
			elseif not free and (btype or 0) == 0 then
				free = { bag = bag, slot = slot }
			end
		end
	end
	for _, bag in ipairs(ns.BAGS) do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link, count, locked = Slot(bag, slot)
			local id = ns.ItemID(link)
			if id and not locked and Wanted(mode, bag, slot, id, link, inBank) then
				local t = partial[id]
				if t then return bag, slot, t.bag, t.slot, math.min(count, t.room), count end
				if free then return bag, slot, free.bag, free.slot, count, count end
			end
		end
	end
end

local function Stop()
	mover:Hide()
	waitFor = nil
	if moved > 0 then
		local what = moved .. (moved == 1 and L["STACK_SINGLE"] or L["STACK_MULTI"])
		ns.Print(mode == "mats" and string.format(L["SENT_MATS_REPORT"], what)
			or string.format(L["STACKED_REPORT"], what))
	elseif mode == "mats" then
		ns.Print(L["NO_MATS_OR_FULL"])
	end
	ns.Dirty()
end

mover:SetScript("OnUpdate", function(_, elapsed)
	idle = idle + elapsed
	if idle < 0.15 then return end
	idle = 0
	if not ns.atBank or moved >= 300 then return Stop() end
	if CursorHasItem() then return end
	if waitFor then
		local _, _, l1 = Slot(waitFor[1], waitFor[2])
		local _, _, l2 = Slot(waitFor[3], waitFor[4])
		if l1 or l2 then return end
		waitFor = nil
	end
	local sb, ss, tb, ts, amount, count = NextMove()
	if not sb then return Stop() end
	if amount < count then
		SplitContainerItem(sb, ss, amount)
	else
		PickupContainerItem(sb, ss)
	end
	PickupContainerItem(tb, ts)
	-- if the drop was refused, put the item back where it came from
	if CursorHasItem() then ClearCursor() return Stop() end
	moved = moved + 1
	waitFor = { sb, ss, tb, ts }
end)

local function StartMover(m)
	if not ns.atBank or mover:IsShown() then return end
	if CursorHasItem() then ClearCursor() end
	mode = m
	moved, waitFor, idle = 0, nil, 0
	mover:Show()
end

function ns.StackToBank() StartMover("stack") end

function ns.SendMatsToBank()
	if not ns.atBank then
		ns.Print("Open the bank first, then send the materials.")
		return
	end
	StartMover("mats")
end
