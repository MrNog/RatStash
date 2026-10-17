local _, ns = ...
local C, rgb = ns.C, ns.rgb

--------------------------------------------------------------------------------
-- loot radar: a panel (radar button on the bag window, or /rst radar) listing each boss of the raid
-- you are in with the drops that are an upgrade for you (ns.RadarJudge: your Bistooltip list, else
-- the upgrade %). An upgrade showing up in
-- a loot window, a roll or a raid warning pops a toast with a sound.
-- Boss loot comes from RaidLoot.lua, the BiS lists from BisData.lua: RatStash needs no other addon.
--------------------------------------------------------------------------------

local ZONES = {
	["Icecrown Citadel"] = "icc", ["Trial of the Crusader"] = "toc", ["Ulduar"] = "ulduar",
	["Naxxramas"] = "naxx", ["The Obsidian Sanctum"] = "os", ["The Eye of Eternity"] = "eoe",
	["Vault of Archavon"] = "voa", ["Onyxia's Lair"] = "ony", ["The Ruby Sanctum"] = "rs",
}
local RAID_NAME = {}
for name, key in pairs(ZONES) do RAID_NAME[key] = name end

-- GetInstanceDifficulty() inside a raid: 1 = 10, 2 = 25, 3 = 10 heroic, 4 = 25 heroic
local MODES = { "10n", "25n", "10h", "25h" }
-- order of the raid picker, newest first
local RAID_ORDER = { "icc", "rs", "toc", "ulduar", "naxx", "voa", "os", "eoe", "ony" }

local MODE_LABEL = { ["10n"] = "10", ["25n"] = "25", ["10h"] = "10 HC", ["25h"] = "25 HC" }

local ROW_H, ITEM_H, WIDTH = 22, 26, 300

-- Okanvil's table stands in until RaidLoot.lua is loaded (a new file needs a full restart)
local function Loot() return ns.RAIDLOOT or OkanvilRaidLoot end

-- the difficulties a raid's loot table has, in MODES order (VoA has no heroic, ToC/ICC/RS do)
local modesCache = {}
local function ModesOf(raid)
	if modesCache[raid] then return modesCache[raid] end
	local has = {}
	for _, boss in ipairs((Loot() or {})[raid] or {}) do
		for _, it in ipairs(boss.items) do
			for m in (it.m or ""):gmatch("[^,]+") do has[m] = true end
		end
	end
	local out = {}
	for _, m in ipairs(MODES) do if has[m] then out[#out + 1] = m end end
	if #out == 0 then out = { "10n", "25n" } end
	modesCache[raid] = out
	return out
end

local function Here()
	local key = ZONES[GetRealZoneText() or ""]
	local _, kind = IsInInstance()
	if not key or kind ~= "raid" then return end
	return key, MODES[GetInstanceDifficulty()] or "10n"
end

-- The boss whose room you are in, from Okanvil's notes (subzone, or the target in one-room raids
-- like ToC). Note names and loot-table names differ ("Deathbringer Saurfang" / "Saurfang",
-- "Rotface & Festergut" covers two), so they are compared squashed to letters.
local NOTE_ALIAS = { ["Val'kyr Twins"] = "twinvalkyrs" }
local function Squash(s) return (s or ""):lower():gsub("[^%a]", "") end

local function HereNote()
	local N = Okanvil and Okanvil.Notes
	if not (N and N.NoteForHere and N.BossOf) then return end
	local ok, key = pcall(N.NoteForHere)
	if not ok or not key then return end
	local base = N.BossOf(key) or key
	return NOTE_ALIAS[base] or Squash(base)
end

local function IsHere(note, bossName)
	if not note then return false end
	local b = Squash(bossName)
	return b ~= "" and (note:find(b, 1, true) or b:find(note, 1, true)) ~= nil
end

local function DropsIn(item, mode)
	return (item.m or ""):find(mode, 1, true) ~= nil
end

--------------------------------------------------------------------------------
-- item cache: GetItemInfo is empty until the client has seen an item. A hidden tooltip asks
-- the server, a few per second so the server does not throttle us.
--------------------------------------------------------------------------------

local askTip = CreateFrame("GameTooltip", "RatStashRadarTip", nil, "GameTooltipTemplate")
local queue, queued = {}, {}
local asker = CreateFrame("Frame")
asker:Hide()
local since = 0
asker:SetScript("OnUpdate", function(self, elapsed)
	since = since + elapsed
	if since < 0.25 then return end
	since = 0
	local id = table.remove(queue, 1)
	if not id then
		self:Hide()
		if ns.radar and ns.radar:IsShown() then ns.radar:Refresh() end
		local retry = ns.radarRetry
		ns.radarRetry = nil
		for _, link in ipairs(retry or {}) do ns.RadarCheck(link) end
		return
	end
	if not GetItemInfo(id) then
		askTip:SetOwner(UIParent, "ANCHOR_NONE")
		askTip:SetHyperlink("item:" .. id)
		askTip:Hide()
	end
	if #queue % 8 == 0 and ns.radar and ns.radar:IsShown() then ns.radar:Refresh() end
end)

local function Ask(id)
	if queued[id] or GetItemInfo(id) then return end
	queued[id] = true
	queue[#queue + 1] = id
	asker:Show()
end

--------------------------------------------------------------------------------
-- per boss: the upgrades in this difficulty, best first
--------------------------------------------------------------------------------

-- the judge lives in Bis.lua: your BiS list, or item level when your spec has none
local function Judge(link, raid)
	return ns.RadarJudge(link, raid)
end

local function Upgrades(boss, raid, mode, all)
	local out, pending = {}, 0
	for _, it in ipairs(boss.items) do
		if DropsIn(it, mode) then
			local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(it.id)
			if not name then
				Ask(it.id)
				pending = pending + 1
			else
				local show, pct, owned, rank, vs = Judge(link, raid)
				-- "All": everything on your list (or, with no list, everything your spec can score)
				if show or (all and (rank or pct)) then
					out[#out + 1] = { link = link, name = name, quality = quality, icon = icon,
						slot = it.slot, pct = pct, owned = owned, rank = rank, up = show, vs = vs }
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if (a.rank or 99) ~= (b.rank or 99) then return (a.rank or 99) < (b.rank or 99) end
		return (a.pct or -999) > (b.pct or -999)
	end)
	return out, pending
end

--------------------------------------------------------------------------------
-- panel
--------------------------------------------------------------------------------

local function PctColor(pct)
	if pct >= 20 then return 1.000, 0.502, 0.000 end
	if pct >= 10 then return 0.639, 0.208, 0.933 end
	if pct >= 5 then return 0.000, 0.439, 1.000 end
	return 0.486, 0.988, 0.541
end

local function Text(parent, size, color)
	local fs = ns.Font(parent:CreateFontString(nil, "OVERLAY"), size)
	fs:SetTextColor(rgb(color or C.text))
	return fs
end

local function NewBossRow(p)
	local r = CreateFrame("Button", nil, p.body)
	r:SetHeight(ROW_H)
	local hl = r:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(ns.FLAT); hl:SetAllPoints(); hl:SetVertexColor(1, 1, 1, 0.05)
	r.caret = Text(r, 11, C.textDim); r.caret:SetPoint("LEFT", 6, 0)
	r.count = Text(r, 11, C.accentText); r.count:SetPoint("RIGHT", -8, 0)
	r.name = Text(r, 12); r.name:SetPoint("LEFT", 18, 0); r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
	r.name:SetJustifyH("LEFT")
	r.mark = r:CreateTexture(nil, "ARTWORK")
	r.mark:SetTexture(ns.FLAT); r.mark:SetVertexColor(rgb(C.accent))
	r.mark:SetWidth(2); r.mark:SetPoint("TOPLEFT", 1, -3); r.mark:SetPoint("BOTTOMLEFT", 1, 3)
	r:SetScript("OnClick", function(self)
		p.open[self.boss] = not self.isOpen
		p:Refresh()
	end)
	return r
end

local function NewItemRow(p)
	local r = CreateFrame("Button", nil, p.body)
	r:SetHeight(ITEM_H)
	ns.Skin(r, C.surface, 1)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetWidth(20); r.icon:SetHeight(20); r.icon:SetPoint("LEFT", 4, 0)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.pct = Text(r, 12); r.pct:SetPoint("RIGHT", -6, 0)
	r.name = Text(r, 11); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetPoint("RIGHT", r.pct, "LEFT", -6, 0); r.name:SetJustifyH("LEFT")
	r:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r:SetScript("OnClick", function(self)
		if IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(self.link)
		elseif IsModifiedClick("DRESSUP") then DressUpItemLink(self.link) end
	end)
	return r
end

local function Refresh(p)
	local loot = Loot()
	local bosses = loot and p.raid and loot[p.raid]
	p.title:SetText((RAID_NAME[p.raid] or "Loot radar") .. " |cff8a8d93v|r")
	p.modeText:SetText(MODE_LABEL[p.mode] or "")
	p.modeBtn:SetWidth(p.modeText:GetStringWidth() + 8)
	for _, r in ipairs(p.bossRows) do r:Hide() end
	for _, r in ipairs(p.itemRows) do r:Hide() end
	if not bosses then
		p.status:SetText("No loot table for this raid.")
		p:SetHeight(64)
		return
	end
	local note = Here() == p.raid and HereNote() or nil
	local y, nb, ni, waiting = -4, 0, 0, 0
	for _, boss in ipairs(bosses) do
		local here = IsHere(note, boss.boss)
		local ups, pending = Upgrades(boss, p.raid, p.mode, p.all)
		waiting = waiting + pending
		nb = nb + 1
		local r = p.bossRows[nb] or NewBossRow(p)
		p.bossRows[nb] = r
		r.boss = boss.boss
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, y); r:SetPoint("TOPRIGHT", 0, y)
		r.name:SetText(here and (boss.boss .. "  |cffe0b84c(here)|r") or boss.boss)
		if here then r.mark:Show() else r.mark:Hide() end
		-- the boss you are at opens by itself until you click it shut
		local want = p.open[boss.boss]
		if want == nil then want = here end
		local open = want and #ups > 0
		r.isOpen = open
		r.caret:SetText(#ups > 0 and (open and "-" or "+") or "")
		local fresh = 0
		for _, u in ipairs(ups) do
			if not u.owned and u.up then fresh = fresh + 1 end
		end
		if fresh > 0 then
			r.count:SetText(fresh .. (fresh > 1 and " upgrades" or " upgrade"))
			r.count:SetTextColor(rgb(C.accentText)); r.name:SetTextColor(rgb(C.text))
		else
			r.count:SetText("-")
			r.count:SetTextColor(rgb(C.textDim)); r.name:SetTextColor(rgb(C.textDim))
		end
		r:Show()
		y = y - ROW_H
		if open then
			for _, u in ipairs(ups) do
				ni = ni + 1
				local it = p.itemRows[ni] or NewItemRow(p)
				p.itemRows[ni] = it
				it.link = u.link
				it:ClearAllPoints()
				it:SetPoint("TOPLEFT", 18, y - 1); it:SetPoint("TOPRIGHT", -6, y - 1)
				it.icon:SetTexture(u.icon)
				local qr, qg, qb = GetItemQualityColor(u.quality or 4)
				local tag = u.rank and (u.rank == 1 and "|cffe0b84cBiS|r  " or ("|cffe0b84c#" .. u.rank .. "|r  ")) or ""
				it.name:SetText(tag .. u.name .. "  |cff8a8d93" .. (u.slot or "") .. "|r")
				it.name:SetTextColor(qr, qg, qb)
				if u.owned then
					it.pct:SetText("have"); it.pct:SetTextColor(rgb(C.textDim))
					it:SetAlpha(0.55)
				else
					-- ranked by a BiS list: show what it was measured against, not the stat %
					if u.rank then
						it.pct:SetText(u.vs and ("vs " .. u.vs) or "")
					else
						it.pct:SetText(u.pct and ("+" .. u.pct .. " ilvl") or "")
					end
					if u.up then
						it.pct:SetTextColor(0.486, 0.988, 0.541); it:SetAlpha(1)
					else
						it.pct:SetTextColor(rgb(C.danger)); it:SetAlpha(0.7)
					end
				end
				it:Show()
				y = y - ITEM_H - 2
			end
			y = y - 4
		end
	end
	p.status:SetText(waiting > 0 and ("Loading " .. waiting .. " items...") or "")
	p.body:SetHeight(-y)
	p:SetHeight(-y + 52)
end

local function CreatePanel()
	local p = CreateFrame("Frame", "RatStashRadar", UIParent)
	p:SetWidth(WIDTH); p:SetHeight(120)
	p:SetFrameStrata("DIALOG")   -- above the bags (HIGH), so it can never open underneath them
	p:SetClampedToScreen(true)
	tinsert(UISpecialFrames, "RatStashRadar")
	ns.Skin(p, C.panelD, 0.95)
	p:EnableMouse(true)
	p:SetMovable(true)
	p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", function(self) self:StartMoving() end)
	p:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	-- the title picks the raid, the size next to it cycles the difficulties that raid has
	local titleBtn = CreateFrame("Button", nil, p)
	titleBtn:SetPoint("TOPLEFT", 6, -4); titleBtn:SetHeight(20)
	p.title = Text(titleBtn, 13, C.accentText)
	p.title:SetPoint("LEFT", 4, 0)
	titleBtn:SetScript("OnUpdate", function(self) self:SetWidth(p.title:GetStringWidth() + 8) end)
	local thl = titleBtn:CreateTexture(nil, "HIGHLIGHT")
	thl:SetTexture(ns.FLAT); thl:SetAllPoints(); thl:SetVertexColor(1, 1, 1, 0.06)
	titleBtn:SetScript("OnClick", function()
		if p.menu:IsShown() then p.menu:Hide() else p.menu:Show() end
	end)
	p.modeBtn = CreateFrame("Button", nil, p)
	p.modeBtn:SetPoint("LEFT", titleBtn, "RIGHT", 2, 0); p.modeBtn:SetHeight(20)
	p.modeText = Text(p.modeBtn, 13, C.textDim)
	p.modeText:SetPoint("CENTER")
	local mhl = p.modeBtn:CreateTexture(nil, "HIGHLIGHT")
	mhl:SetTexture(ns.FLAT); mhl:SetAllPoints(); mhl:SetVertexColor(1, 1, 1, 0.06)
	p.modeBtn:SetScript("OnClick", function()
		local modes = ModesOf(p.raid)
		local nxt = modes[1]
		for i, m in ipairs(modes) do if m == p.mode then nxt = modes[i % #modes + 1] end end
		p.mode = nxt
		p:Refresh()
	end)
	for _, b in ipairs({ titleBtn, p.modeBtn }) do
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self == titleBtn and "Pick a raid" or "Next size / difficulty", 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	-- raid list under the title
	local menu = CreateFrame("Frame", nil, p)
	menu:SetPoint("TOPLEFT", titleBtn, "BOTTOMLEFT", 0, -2)
	menu:SetWidth(180); menu:SetHeight(#RAID_ORDER * 20 + 4)
	menu:SetFrameLevel(p:GetFrameLevel() + 20)
	ns.Skin(menu, C.panel, 1)
	menu:EnableMouse(true)
	for i, key in ipairs(RAID_ORDER) do
		local b = CreateFrame("Button", nil, menu)
		b:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20); b:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * 20)
		b:SetHeight(20)
		local fs = Text(b, 12); fs:SetPoint("LEFT", 8, 0); fs:SetText(RAID_NAME[key])
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetTexture(ns.FLAT); hl:SetAllPoints(); hl:SetVertexColor(1, 1, 1, 0.08)
		b:SetScript("OnClick", function()
			local modes = ModesOf(key)
			local keep
			for _, m in ipairs(modes) do if m == p.mode then keep = m end end
			p.raid, p.mode = key, keep or modes[#modes > 1 and 2 or 1]
			p.open = {}
			menu:Hide()
			p:Refresh()
		end)
	end
	menu:Hide()
	p.menu = menu
	p:HookScript("OnHide", function() menu:Hide() end)
	local close = ns.FlatButton(p, "X", 18, 16)
	close:SetPoint("TOPRIGHT", -6, -6)
	close:SetScript("OnClick", function() p:Hide() end)
	-- "All": every drop meant for your spec with its %, not only the upgrades
	local all = ns.FlatButton(p, "All", 34, 16)
	all:SetPoint("RIGHT", close, "LEFT", -6, 0)
	all:SetScript("OnClick", function()
		p.all = not p.all
		all.text:SetTextColor(rgb(p.all and C.accentText or C.text))
		p:Refresh()
	end)
	all:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Show all loot for your spec", 1, 1, 1)
		GameTooltip:AddLine("Also items that score below your gear, in red.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	all:HookScript("OnLeave", function() GameTooltip:Hide() end)
	local rule = ns.Rule(p)
	rule:SetPoint("TOPLEFT", 1, -28); rule:SetPoint("TOPRIGHT", -1, -28)
	p.body = CreateFrame("Frame", nil, p)
	p.body:SetPoint("TOPLEFT", 1, -30); p.body:SetPoint("TOPRIGHT", -1, -30)
	p.body:SetHeight(1)
	p.status = Text(p, 10, C.textDim)
	p.status:SetPoint("BOTTOMLEFT", 10, 7)
	p.bossRows, p.itemRows, p.open = {}, {}, {}
	p.Refresh = Refresh
	p:Hide()
	return p
end

-- /rst radar [raid] [10|25][h]; no raid = the one you are in (ICC 25 outside a raid)
function ns.RadarCommand(args)
	local p = ns.radar
	if p:IsShown() and (args or "") == "" then return p:Hide() end
	local raid, size, hc = (args or ""):match("^%s*(%a*)%s*(%d*)%s*(h?)")
	local hereRaid, hereMode = Here()
	raid = (raid ~= "" and raid) or hereRaid or "icc"
	local mode = hereMode or "25n"
	if size == "10" or size == "25" then mode = size .. (hc == "h" and "h" or "n") end
	if not (Loot() and Loot()[raid]) then
		return ns.Print("raids: icc toc ulduar naxx os eoe voa ony rs   e.g. /rst radar icc 25h")
	end
	p.raid, p.mode = raid, mode
	p:ClearAllPoints()
	local bags = ns.windows.bags
	if bags and bags:IsShown() then
		-- beside the bags on the side with room; with too little on the left the screen
		-- clamp pushed it back on-screen under the bag window
		local room = (bags:GetLeft() or 0) * bags:GetEffectiveScale() / p:GetEffectiveScale()
		if room >= p:GetWidth() + 8 then
			p:SetPoint("TOPRIGHT", bags, "TOPLEFT", -6, 0)
		else
			p:SetPoint("TOPLEFT", bags, "TOPRIGHT", 6, 0)
		end
	else
		p:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
	end
	p:Refresh()
	p:Show()
end

--------------------------------------------------------------------------------
-- drop toast
--------------------------------------------------------------------------------

local toast
local seen = {}

local function CreateToast()
	local t = CreateFrame("Button", nil, UIParent)
	t:SetWidth(320); t:SetHeight(52)
	-- a little above the middle of the screen by default; drag to move
	local pos = ns.db.pos.toast or { "CENTER", "CENTER", 0, 120 }
	t:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	t:SetMovable(true)
	t:SetClampedToScreen(true)
	t:RegisterForDrag("LeftButton")
	t:RegisterForClicks("RightButtonUp")
	t:SetScript("OnDragStart", function(self) self:StartMoving() end)
	t:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		ns.db.pos.toast = { p, rp, x, y }
	end)
	t:SetFrameStrata("HIGH")
	ns.Skin(t, C.panelD, 0.95)
	t:SetBackdropBorderColor(rgb(C.accent))
	t.icon = t:CreateTexture(nil, "ARTWORK")
	t.icon:SetWidth(40); t.icon:SetHeight(40); t.icon:SetPoint("LEFT", 6, 0)
	t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	t.top = Text(t, 10, C.accentText); t.top:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 8, -1)
	t.top:SetText("UPGRADE DROPPED")
	t.name = Text(t, 13); t.name:SetPoint("LEFT", t.icon, "RIGHT", 8, -2)
	t.name:SetPoint("RIGHT", -8, -2); t.name:SetJustifyH("LEFT")
	t.meta = Text(t, 10, C.textDim); t.meta:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 8, 1)
	t:SetScript("OnEnter", function(self)
		self.hold = true
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:AddLine("Drag to move, right click to close.", 0.54, 0.55, 0.58)
		GameTooltip:Show()
	end)
	t:SetScript("OnLeave", function(self) self.hold = nil; GameTooltip:Hide() end)
	t:SetScript("OnClick", function(self) self:Hide() end) -- right click closes
	t:SetScript("OnUpdate", function(self, elapsed)
		if self.hold then return end
		self.left = self.left - elapsed
		if self.left <= 0 then self:Hide()
		elseif self.left < 1 then self:SetAlpha(self.left) end
	end)
	t:Hide()
	return t
end

local function BossOf(id)
	local raid = Here()
	local bosses = Loot() and raid and Loot()[raid]
	for _, boss in ipairs(bosses or {}) do
		for _, it in ipairs(boss.items) do if it.id == id then return boss.boss end end
	end
end

local function Check(link, test)
	if not (link and ns.db.radar) then return end
	local id = tonumber(link:match("item:(%d+)"))
	if not id or (not test and seen[id] and GetTime() - seen[id] < 600) then return end
	local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(link)
	if not name then
		-- not cached yet: ask the server and look again once the queue is through
		ns.radarRetry = ns.radarRetry or {}
		ns.radarRetry[#ns.radarRetry + 1] = link
		return Ask(id)
	end
	local show, pct, owned, rank, vs = Judge(link, Here() or "icc")
	if not test and (not show or owned) then return end
	seen[id] = GetTime()
	toast = toast or CreateToast()
	toast.link = link
	toast.icon:SetTexture(icon)
	local qr, qg, qb = GetItemQualityColor(quality or 4)
	toast.name:SetText(name); toast.name:SetTextColor(qr, qg, qb)
	local r, g, b = PctColor(math.max(pct or 1, 1))
	local boss = BossOf(id)
	local bits = {}
	if rank then bits[#bits + 1] = "|cffe0b84c" .. (rank == 1 and "BiS" or ("BiS #" .. rank)) .. "|r" end
	if rank then
		if vs then bits[#bits + 1] = "|cff8a8d93vs " .. vs .. "|r" end
	elseif pct then
		bits[#bits + 1] = string.format("|cff%02x%02x%02x+%d ilvl|r", r * 255, g * 255, b * 255, pct)
	end
	if boss then bits[#bits + 1] = boss end
	toast.meta:SetText(table.concat(bits, "  "))
	toast.left = 10
	toast:SetAlpha(1)
	toast:Show()
	if ns.db.radarSound then ns.PlayRadarSound(ns.db.radarSoundName) end
end

ns.RadarCheck = Check

-- "Rat" is our own clip (squeaks and a spill of coins); anything else is a built-in PlaySound name.
-- A saved "Voice" (no longer offered) plays the rat too.
local RAT = [[Interface\AddOns\RatStash\Media\rat.wav]]
function ns.PlayRadarSound(key)
	if not key or key == "Rat" or key == "Voice" then PlaySoundFile(RAT) else PlaySound(key) end
end

-- /rst toast: the toast and sound with your best upgrade in the raid the radar shows
function ns.RadarTest()
	local p = ns.radar
	local raid, mode = Here()
	raid, mode = raid or p.raid or "icc", mode or p.mode or "25n"
	local pick
	for _, boss in ipairs((Loot() or {})[raid] or {}) do
		for _, u in ipairs((Upgrades(boss, raid, mode, true))) do
			if not pick or (u.up and not pick.up) then pick = u end
		end
	end
	if not pick then return ns.Print("no items for your spec in " .. (RAID_NAME[raid] or raid) .. " yet, try again in a moment") end
	Check(pick.link, true)
end

local function CheckText(msg)
	for link in (msg or ""):gmatch("|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r") do Check(link) end
end

--------------------------------------------------------------------------------
-- wiring
--------------------------------------------------------------------------------

ns.On("PLAYER_LOGIN", function() ns.radar = CreatePanel() end)

ns.On("START_LOOT_ROLL", function(rollID) Check(GetLootRollItemLink(rollID)) end)
ns.On("LOOT_OPENED", function()
	for i = 1, GetNumLootItems() do Check(GetLootSlotLink(i)) end
end)
ns.On("CHAT_MSG_RAID_WARNING", CheckText)
ns.On("CHAT_MSG_RAID_LEADER", CheckText)

-- walking into the next boss room moves the "(here)" mark
local function Moved() if ns.radar and ns.radar:IsShown() then ns.radar:Refresh() end end
ns.On("ZONE_CHANGED", Moved)
ns.On("ZONE_CHANGED_INDOORS", Moved)
ns.On("ZONE_CHANGED_NEW_AREA", Moved)
ns.On("PLAYER_TARGET_CHANGED", Moved)
