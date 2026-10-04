local ADDON, ns = ...

-- records per window: one per real bag slot, empty slots included
ns.records = { bags = {}, bank = {} }

local CLASS = { GetAuctionItemClasses() }
local WEAPON, ARMOR, CONTAINER, CONSUMABLE, GLYPH, TRADE, RECIPE, GEM, QUEST =
	CLASS[1], CLASS[2], CLASS[3], CLASS[4], CLASS[5], CLASS[6], CLASS[9], CLASS[10], CLASS[12]

-- enchant scrolls, armor kits, spellthreads and the like get their own block
local ENCHANT_SUB = { ["Item Enhancement"] = true, ["Armor Enchantment"] = true, ["Weapon Enchantment"] = true }

local NO_ILVL = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true }

local function ItemID(link)
	return link and tonumber(link:match("item:(%d+)"))
end
ns.ItemID = ItemID

--------------------------------------------------------------------------------
-- tooltip scan: bind state and the BoP trade timer only exist as tooltip text
--------------------------------------------------------------------------------

local tip = CreateFrame("GameTooltip", "RatStashScanTip", nil, "GameTooltipTemplate")
local tipCache = {}

function ns.WipeTooltipCache() wipe(tipCache) end

-- "You may trade this item ... for the next %s." -> "(.+)"
local TRADE_PATTERN = BIND_TRADE_TIME_REMAINING and
	BIND_TRADE_TIME_REMAINING:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)")

local function ShortTime(s)
	local h = s:match("(%d+) [Hh]our")
	local m = s:match("(%d+) [Mm]in")
	if h then return h .. "h" .. (m or "") end
	if m then return m .. "m" end
	return "trade"
end

local function SetTipTo(bag, slot)
	tip:SetOwner(WorldFrame, "ANCHOR_NONE")
	tip:ClearLines()
	if bag == BANK_CONTAINER then
		tip:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))
	else
		tip:SetBagItem(bag, slot)
	end
end

-- returns isBoE, tradeTimeText; cached per slot+link, the timer is re-read every time
local function ScanTooltip(r, wantTimer)
	local key = r.key .. r.link
	local c = tipCache[key]
	if c and not wantTimer then return c.boe, nil end
	SetTipTo(r.bag, r.slot)
	local boe, timer = false, nil
	for i = 2, tip:NumLines() do
		local fs = _G["RatStashScanTipTextLeft" .. i]
		local text = fs and fs:GetText()
		if text then
			if text == ITEM_BIND_ON_EQUIP then boe = true end
			if TRADE_PATTERN and wantTimer then
				local t = text:match(TRADE_PATTERN)
				if t then timer = ShortTime(t) end
			end
		end
	end
	tip:Hide()
	tipCache[key] = { boe = boe }
	return boe, timer
end

--------------------------------------------------------------------------------
-- item records
--------------------------------------------------------------------------------

-- trade goods split by the kind the game gives each material (its subtype)
local MAT_BY_SUB = {
	["Metal & Stone"] = "Ore & bars", ["Herb"] = "Herbs", ["Cloth"] = "Cloth", ["Leather"] = "Leather",
	["Meat"] = "Cooking", ["Elemental"] = "Elemental", ["Enchanting"] = "Enchanting",
	["Jewelcrafting"] = "Gems", ["Parts"] = "Engineering", ["Devices"] = "Engineering", ["Explosives"] = "Engineering",
}
-- materials the game files under a generic subtype, placed by hand; profession tools the game
-- files as weapons go here too, so they sit with their profession instead of in Gear
local MAT_BY_ID = {
	[43007] = "Cooking",     -- Northern Spices
	[6219]  = "Engineering", -- Arclight Spanner
}
local function MatKind(r)
	if MAT_BY_ID[r.id] then return MAT_BY_ID[r.id] end
	if r.itype == GEM then return "Gems" end
	if r.itype == RECIPE then return "Recipes" end
	return MAT_BY_SUB[r.stype] or "Other mats"
end

local function Category(r, bag, slot)
	if r.quality == 0 then return "junk" end
	if r.itype == QUEST then return "quest" end
	if MAT_BY_ID[r.id] then return "mat" end
	if bag and GetContainerItemQuestInfo then
		local isQuest = GetContainerItemQuestInfo(bag, slot)
		if isQuest then return "quest" end
	end
	if (r.itype == WEAPON or r.itype == ARMOR) and r.equipLoc ~= "" then return "gear" end
	if ENCHANT_SUB[r.stype] then return "ench" end
	if r.itype == CONSUMABLE then return "con" end
	if r.itype == TRADE or r.itype == GEM or r.itype == RECIPE then return "mat" end
	return "other"
end

local function Fill(r, link, count, locked, live)
	local name, _, quality, ilvl, _, itype, stype, maxStack, equipLoc, tex = GetItemInfo(link)
	if not name then ns.missingInfo = true end
	r.link = link
	r.id = ItemID(link)
	r.name = name or link:match("%[(.-)%]") or "?"
	r.tex = tex or GetItemIcon(link)
	r.count = count or 1
	r.locked = locked
	r.quality = quality or 1
	r.ilvl = ilvl or 0
	r.itype, r.stype = itype or "", stype or ""
	r.maxStack = maxStack or 1
	r.equipLoc = equipLoc or ""
	r.cat = Category(r, live and r.bag, r.slot)
	if r.cat == "mat" then
		r.matKind = MatKind(r)
		-- dusts, essences and shards sit with the enchant scrolls
		if r.matKind == "Enchanting" then r.cat = "ench" end
	end
	r.isGear = r.cat == "gear" or ((itype == WEAPON or itype == ARMOR) and r.equipLoc ~= "" and not MAT_BY_ID[r.id])
	r.showIlvl = r.isGear and not NO_ILVL[r.equipLoc] and r.ilvl > 1
	if live and r.isGear then r.boe = ScanTooltip(r, false) end
end

local function ScanLive(ids)
	local list = {}
	for _, bag in ipairs(ids) do
		local size = GetContainerNumSlots(bag) or 0
		local _, btype = GetContainerNumFreeSlots(bag)
		for slot = 1, size do
			local _, count, locked, _, _, _, link = GetContainerItemInfo(bag, slot)
			local r = { bag = bag, slot = slot, key = bag .. ":" .. slot, btype = btype or 0 }
			if link then Fill(r, link, count, locked, true) end
			list[#list + 1] = r
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- gear sets: which bag slots hold a piece of which saved Equipment Manager set
--------------------------------------------------------------------------------

local IGNORE_LOC = { [0] = true, [1] = true, [-1] = true }

function ns.SetMap()
	local map, order = {}, {}
	for i = 1, GetNumEquipmentSets() do
		local name = GetEquipmentSetInfo(i)
		if name then
			order[#order + 1] = name
			local locs = GetEquipmentSetLocations(name)
			for invSlot = 1, 19 do
				local loc = locs and locs[invSlot]
				if loc and not IGNORE_LOC[loc] then
					local player, bank, bags, slot, bag = EquipmentManager_UnpackLocation(loc)
					local key
					if bags and bag and slot then
						key = bag .. ":" .. slot
					elseif bank and not player and slot then
						for b = 1, NUM_BANKGENERIC_SLOTS do
							if BankButtonIDToInvSlotID(b) == slot then key = BANK_CONTAINER .. ":" .. b end
						end
					end
					if key and not map[key] then map[key] = { set = name, order = invSlot } end
				end
			end
		end
	end
	return map, order
end

--------------------------------------------------------------------------------
-- raid loot: remember what we looted inside a raid so it stays apart from our own items.
-- Stackables are tracked as a count per item id; unstackables by the bag slot they landed in.
--------------------------------------------------------------------------------

local FRESH_TTL = 12 * 3600
local pending = {}
local prevLinks, newAt = {}, {}

local function ToPattern(fmt)
	fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	fmt = fmt:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
	return "^" .. fmt .. "$"
end
local LOOT_MULTI = ToPattern(LOOT_ITEM_SELF_MULTIPLE)
local LOOT_ONE = ToPattern(LOOT_ITEM_SELF)

local function RaidLabel()
	local name, _, _, _, maxPlayers = GetInstanceInfo()
	name = name or GetRealZoneText() or "?"
	if maxPlayers and maxPlayers > 0 then return name .. " " .. maxPlayers end
	return name
end

-- Only rare (blue) and better counts as raid loot; trash greys, whites and greens
-- just go into your bags. The link's color covers items not cached yet.
local RARE = 3
local LINK_QUALITY = { ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }

local function Quality(link)
	local q = select(3, GetItemInfo(link))
	if q then return q end
	local hex = link:match("|cff(%x%x%x%x%x%x)")
	return hex and LINK_QUALITY[hex:lower()] or 0
end

ns.On("CHAT_MSG_LOOT", function(msg)
	local inInstance, kind = IsInInstance()
	if not inInstance or kind ~= "raid" then return end
	local link, n = msg:match(LOOT_MULTI)
	if not link then link = msg:match(LOOT_ONE); n = 1 end
	local id = ItemID(link)
	if not id or Quality(link) < RARE then return end
	pending[#pending + 1] = { id = id, link = link, n = tonumber(n) or 1, zone = RaidLabel(), t = time(), giveUp = GetTime() + 10 }
	ns.Dirty("bags")
end)

function ns.KeepRaidLoot()
	wipe(ns.char.fresh.stack)
	wipe(ns.char.fresh.slot)
	wipe(pending)
	ns.Dirty("bags")
end

function ns.HasRaidLoot()
	return next(ns.char.fresh.stack) ~= nil or next(ns.char.fresh.slot) ~= nil
end

local function UpdateFresh(list)
	local fresh, now = ns.char.fresh, time()
	local byKey, totals = {}, {}
	for _, r in ipairs(list) do
		if r.link then
			byKey[r.key] = r
			totals[r.id] = (totals[r.id] or 0) + r.count
			if prevLinks[r.key] ~= r.link then newAt[r.key] = GetTime() end
		end
	end
	wipe(prevLinks)
	for key, r in pairs(byKey) do prevLinks[key] = r.link end

	-- unstackables: follow the item if it moved, forget it once it left the bags
	local moved = {}
	for key, f in pairs(fresh.slot) do
		if now - f.t > FRESH_TTL or not (byKey[key] and byKey[key].link == f.link) then
			fresh.slot[key] = nil
			if now - f.t <= FRESH_TTL then moved[#moved + 1] = f end
		end
	end
	for _, f in ipairs(moved) do
		for k2, r in pairs(byKey) do
			if r.link == f.link and not fresh.slot[k2] then fresh.slot[k2] = f; break end
		end
	end
	-- stackables: never more than we still hold
	for id, f in pairs(fresh.stack) do
		f.n = math.min(f.n, totals[id] or 0)
		if f.n <= 0 or now - f.t > FRESH_TTL then fresh.stack[id] = nil end
	end

	for i = #pending, 1, -1 do
		local p = pending[i]
		local maxStack = select(8, GetItemInfo(p.link))
		if maxStack and maxStack > 1 then
			local f = fresh.stack[p.id]
			if f then f.n = f.n + p.n; f.t = p.t else fresh.stack[p.id] = { n = p.n, zone = p.zone, t = p.t } end
			table.remove(pending, i)
		elseif maxStack then
			-- prefer a slot that just changed; after the give-up time take any unmarked copy
			local late = GetTime() > p.giveUp
			for key, r in pairs(byKey) do
				if p.n > 0 and r.id == p.id and not fresh.slot[key]
					and (late or (newAt[key] and GetTime() - newAt[key] < 5)) then
					fresh.slot[key] = { link = r.link, zone = p.zone, t = p.t }
					p.n = p.n - 1
				end
			end
			if p.n <= 0 or late then table.remove(pending, i) end
		elseif GetTime() > p.giveUp then
			table.remove(pending, i)
		end
	end

	for key, f in pairs(fresh.slot) do
		local r = byKey[key]
		if r then
			r.fresh = f.zone
			local _, timer = ScanTooltip(r, true)
			r.timer = timer
		end
	end
end

--------------------------------------------------------------------------------
-- scans
--------------------------------------------------------------------------------

function ns.ScanBags()
	local list = ScanLive(ns.BAGS)
	UpdateFresh(list)
	ns.records.bags = list
	ns.UpdateNew("bags")
end

-- live bank scan, also saved per character so the bank can be browsed anywhere
function ns.ScanBank()
	local list = ScanLive(ns.BANK)
	ns.records.bank = list
	ns.UpdateNew("bank")
	local cache = { items = {}, bags = {}, numSlots = GetNumBankSlots() }
	for _, r in ipairs(list) do
		if r.link then cache.items[r.key] = { link = r.link, count = r.count } end
	end
	for _, bag in ipairs(ns.BANK) do
		local info = { size = GetContainerNumSlots(bag) or 0 }
		if bag ~= BANK_CONTAINER then
			info.link = GetInventoryItemLink("player", ContainerIDToInventoryID(bag))
		end
		cache.bags[bag] = info
	end
	ns.char.bank = cache
end

-- offline bank from the saved copy
function ns.CachedBank()
	local cache, list = ns.char.bank, {}
	if not cache then return list end
	for _, bag in ipairs(ns.BANK) do
		local info = cache.bags[bag]
		for slot = 1, (info and info.size or 0) do
			local key = bag .. ":" .. slot
			local r = { bag = bag, slot = slot, key = key, btype = 0, cached = true }
			local it = cache.items[key]
			if it then Fill(r, it.link, it.count, false, false) end
			list[#list + 1] = r
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- new items: the total count of each item in a container (bags or bank) is
-- remembered between scans, and anything that grew is new until the N button
-- on the window resets it
--------------------------------------------------------------------------------

local function CountIn(kind, id)
	if kind == "bank" then
		return (GetItemCount(id, true) or 0) - (GetItemCount(id) or 0)
	end
	return GetItemCount(id) or 0
end

local swapFrozen = false

function ns.UpdateNew(kind)
	if swapFrozen then return end
	if kind == "bank" and not ns.atBank then return end
	local st = ns.char.new[kind]
	local counts = st.counts
	local seen = {}
	for _, r in ipairs(ns.records[kind]) do
		if r.id then seen[r.id] = true end
	end
	if kind == "bags" then
		for slot = 0, 23 do
			local id = GetInventoryItemID("player", slot)
			if id then seen[id] = true end
		end
		for slot = 68, 74 do
			local id = GetInventoryItemID("player", slot)
			if id then seen[id] = true end
		end
	end
	for id in pairs(seen) do
		if counts[id] == nil then counts[id] = 0 end
	end
	local marked = false
	for id, old in pairs(counts) do
		local n = CountIn(kind, id)
		counts[id] = n
		if st.init and old < n and not st.items[id] then
			st.items[id] = true
			marked = true
		end
	end
	st.init = true
	if marked then ns.Dirty(kind) end
end

function ns.HasNew(kind)
	return next(ns.char.new[kind].items) ~= nil
end

function ns.ResetNew(kind)
	local st = ns.char.new[kind]
	wipe(st.counts)
	wipe(st.items)
	st.init = nil
	ns.Dirty(kind)
end

ns.On("EQUIPMENT_SWAP_PENDING", function() swapFrozen = true end)
ns.On("EQUIPMENT_SWAP_FINISHED", function()
	swapFrozen = false
	ns.UpdateNew("bags")
	if ns.atBank then ns.UpdateNew("bank") end
end)
