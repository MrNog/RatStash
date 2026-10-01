local ADDON, ns = ...
local L = ns.L

-- fixed order everything is drawn in; nothing here moves real items
-- gear comes last: it changes the most, and at the bottom it has room to grow
local ORDER = { pin = 1, fresh = 2, set = 3, con = 4, ench = 5, mat = 6, quest = 7, other = 8, junk = 9, gear = 10 }
local CATS = {
	{ "fresh", "Raid loot" }, { "con", "Consumables" }, { "ench", "Enchanting" }, { "mat", "Trade goods" },
	{ "quest", "Quest" }, { "other", "Other" }, { "junk", "Junk" }, { "gear", "Gear" },
}
ns.SMALL_GROUP = 4
local MAT_ORDER = { "Gems", "Ore & bars", "Herbs", "Cloth", "Leather", "Cooking", "Elemental",
	"Engineering", "Recipes", "Other mats" }

function ns.IsMasterLooter()
	local method, partyML, raidML = GetLootMethod()
	if method ~= "master" then return false end
	-- in a raid partyML is 0 for everyone, so the raid index has to be checked first
	if raidML then return UnitIsUnit("raid" .. raidML, "player") end
	return partyML == 0
end

-- inside a block, kinds come in a fixed order so similar things sit together
-- (food, then flasks, potions...; gems, then ores, herbs...; gear in character-sheet order)
local function Ranks(list)
	local t = {}
	for i, v in ipairs(list) do t[v] = i end
	return t
end
local SUB_RANK = Ranks({
	"Food & Drink", "Flask", "Elixir", "Potion", "Bandage", "Scroll", "Item Enhancement", "Consumable", "Other",
	"Simple", "Meta", "Red", "Blue", "Yellow", "Orange", "Purple", "Green", "Prismatic",
	"Metal & Stone", "Herb", "Cloth", "Leather", "Meat", "Elemental", "Enchanting", "Jewelcrafting",
	"Parts", "Devices", "Explosives", "Materials", "Armor Enchantment", "Weapon Enchantment", "Trade Goods",
})
local EQUIP_RANK = Ranks({
	"INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST", "INVTYPE_ROBE",
	"INVTYPE_BODY", "INVTYPE_TABARD", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS",
	"INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_2HWEAPON", "INVTYPE_WEAPON",
	"INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE",
	"INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC",
})
-- gems: best quality first, then around the colour wheel
local GEM_COLOR = Ranks({ "Meta", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Prismatic", "Simple" })
local CLASS = { GetAuctionItemClasses() }
local TYPE_RANK = Ranks({ CLASS[4], CLASS[10], CLASS[6], CLASS[9], CLASS[5] }) -- consumable, gem, trade goods, recipe, glyph

local function KindRank(e)
	return (TYPE_RANK[e.itype] or 50) * 1000 + (EQUIP_RANK[e.equipLoc] or 99) * 10 + (SUB_RANK[e.stype] or 99) / 100
end

-- pinned items go first, or after everything else when the setting says bottom
-- consumables always sit next to the pinned items: just above them at the bottom, just below at the top
local function GroupRank(e)
	local bottom = ns.db.pinAt == "bottom"
	if e.group == "pin" and bottom then return 99 end
	if e.group == "con" then return bottom and 98 or 1.5 end
	return ORDER[e.group]
end

local function Compare(a, b)
	local ga, gb = GroupRank(a), GroupRank(b)
	if ga ~= gb then return ga < gb end
	if a.group == "pin" then
		local pa, pb = ns.PinRank(a.id), ns.PinRank(b.id)
		if pa ~= pb then return pa < pb end
	end
	if (a.set or "") ~= (b.set or "") then return (a.set or "") < (b.set or "") end
	if (a.setOrder or 0) ~= (b.setOrder or 0) then return (a.setOrder or 0) < (b.setOrder or 0) end
	if a.matKind == "Gems" and b.matKind == "Gems" then
		if a.quality ~= b.quality then return a.quality > b.quality end
		local ca, cb = GEM_COLOR[a.stype] or 99, GEM_COLOR[b.stype] or 99
		if ca ~= cb then return ca < cb end
	end
	local ka, kb = KindRank(a), KindRank(b)
	if ka ~= kb then return ka < kb end
	if a.itype ~= b.itype then return a.itype < b.itype end
	if a.stype ~= b.stype then return a.stype < b.stype end
	if a.equipLoc ~= b.equipLoc then return a.equipLoc < b.equipLoc end
	if a.quality ~= b.quality then return a.quality > b.quality end
	if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
	if a.name ~= b.name then return a.name < b.name end
	if a.id ~= b.id then return a.id < b.id end
	if a.count ~= b.count then return a.count > b.count end
	if a.bag ~= b.bag then return a.bag < b.bag end
	if a.slot ~= b.slot then return a.slot < b.slot end
	return (a.split and 1 or 0) > (b.split and 1 or 0)
end

--------------------------------------------------------------------------------
-- virtual stacks: several real slots drawn as one (same rules as AdiBags).
-- Full stacks merge; incomplete ones only when allowed; unstackable copies merge by item id.
-- While trading, the chosen level splits them back apart.
--------------------------------------------------------------------------------

local function StackKey(e, trading)
	local c = ns.db.vs
	-- at a vendor, bank, mailbox or trade identical unstackable items get one slot each so a single
	-- one can be sold or given; stacks stay merged and go one stack at a time
	local level = trading and 2 or 0
	if e.split or e.set then return nil end
	local tag = e.id .. (e.fresh and ":f" or "")
	if e.maxStack > 1 then
		if not c.stack or level >= 4 then return nil end
		if e.count == e.maxStack or (c.incomplete and level < 3) then return "S" .. tag end
		return nil
	end
	if c.others and level < 2 then return "U" .. tag end
end

local function Merge(list, trading)
	local out, seen = {}, {}
	for _, e in ipairs(list) do
		local k = StackKey(e, trading)
		local m = k and seen[k]
		if m then
			m.count = m.count + e.count
			m.slots = m.slots + 1
			m.members[#m.members + 1] = { bag = e.bag, slot = e.slot }
			-- the button acts on one real slot: keep it on an unlocked one (a gem sitting in a socket locks its slot)
			if m.locked and not e.locked then m.bag, m.slot, m.locked = e.bag, e.slot, false end
		else
			if k then
				e.slots = 1
				e.members = { { bag = e.bag, slot = e.slot } }
				seen[k] = e
			end
			out[#out + 1] = e
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- sections: { title, style, small, entries } in draw order, plus the free slot count
--------------------------------------------------------------------------------

local function Copy(r)
	local e = {}
	for k, v in pairs(r) do e[k] = v end
	return e
end

-- a looted stack that joined our own stack is drawn as two buttons on the same slot:
-- the raid part (clicking it splits exactly that many off) and our own part
local function SplitFreshStacks(entries)
	local out = {}
	local want = {}
	for id, f in pairs(ns.char.fresh.stack) do want[id] = { n = f.n, zone = f.zone } end
	table.sort(entries, function(a, b)
		if a.id ~= b.id then return (a.id or 0) < (b.id or 0) end
		return a.count < b.count
	end)
	for _, e in ipairs(entries) do
		local w = e.id and want[e.id]
		if w and w.n > 0 and not e.fresh then
			if w.n >= e.count then
				e.fresh = w.zone
				w.n = w.n - e.count
			else
				local part = Copy(e)
				part.count, part.split, part.fresh = w.n, w.n, w.zone
				e.count = e.count - w.n
				w.n = 0
				out[#out + 1] = part
			end
		end
		out[#out + 1] = e
	end
	return out
end

-- empty slots: every one of them, or folded into one real empty slot (normal bag first) showing the count
local function FreeEntries(empties)
	local out = {}
	if #empties == 0 then return out end
	if ns.db.freeMode == "expand" then
		for _, r in ipairs(empties) do out[#out + 1] = Copy(r) end
		return out
	end
	local first = empties[1]
	for _, r in ipairs(empties) do
		if r.btype == 0 then first = r; break end
	end
	local e = Copy(first)
	e.freeCount = #empties
	out[1] = e
	return out
end

function ns.BuildSections(kind)
	local db = ns.db
	local mode = db.layout[kind]
	local cached = kind == "bank" and not ns.atBank
	local records = cached and ns.CachedBank() or ns.records[kind]
	local setMap, setOrder = {}, {}
	if not cached then setMap, setOrder = ns.SetMap() end
	local trading = ns.IsTrading()

	-- auto sort off: every real slot where it really is, like Bagnon; raid loot still glows
	if not db.sort then
		local grid = {}
		for _, r in ipairs(records) do
			local e = Copy(r)
			e.pinned = e.id and db.pins[e.id] and true or nil
			grid[#grid + 1] = e
		end
		local free = 0
		for _, r in ipairs(records) do if not r.link then free = free + 1 end end
		return { { entries = grid } }, free, cached
	end

	local entries, empties = {}, {}
	for _, r in ipairs(records) do
		if r.link then
			local e = Copy(r)
			local s = setMap[r.key]
			if s then e.set, e.setOrder = s.set, s.order end
			entries[#entries + 1] = e
		else
			empties[#empties + 1] = r
		end
	end
	if kind == "bags" then entries = SplitFreshStacks(entries) end

	for _, e in ipairs(entries) do
		e.pinned = db.pins[e.id] and true or nil
		if e.pinned then e.group = "pin"
		elseif e.fresh then e.group = "fresh"
		elseif e.set then e.group = "set"
		else e.group = e.cat end
	end
	table.sort(entries, Compare)

	local sections = {}
	local function add(title, style, list, small)
		if #list > 0 then
			sections[#sections + 1] = { title = title, style = style, entries = list, small = small }
		end
	end
	local function take(pred)
		local hit, rest = {}, {}
		for _, e in ipairs(entries) do
			if pred(e) then hit[#hit + 1] = e else rest[#rest + 1] = e end
		end
		entries = rest
		return hit
	end

	if kind == "bags" and db.mlGroup and ns.IsMasterLooter() then
		local raid = take(function(e) return e.fresh end)
		-- with Okanvil loaded, reserved loot (hard reserves, reserved BoE/Orb/Pattern/Frag) is kept
		-- apart from loot that is free to roll, using Okanvil's own rule
		local SR = Okanvil and Okanvil.SoftRes
		local reserved, free = {}, {}
		for _, e in ipairs(raid) do
			local ok, why = false, nil
			if SR and SR.Blocked then ok, why = pcall(SR.Blocked, e.link, e.boe) end
			if ok and why then
				e.reserved = why
				reserved[#reserved + 1] = e
			else
				free[#free + 1] = e
			end
		end
		add("[HR] Reserved", "hr", Merge(reserved, trading))
		add("Raid loot", "raid", Merge(free, trading))
	end

	local function setGroups()
		for _, name in ipairs(setOrder) do
			local pieces = take(function(e) return e.set == name and not e.pinned and not e.fresh end)
			add(string.format(L["SET_HEADER"], name), "set", pieces, #pieces <= ns.SMALL_GROUP)
		end
	end

	if mode == "groups" then
		local pinned = take(function(e) return e.pinned end)
		local pinBottom = db.pinAt == "bottom"
		local function consumables()
			local list = Merge(take(function(e) return e.group == "con" end), trading)
			-- Allow Consumables to pack alongside other small blocks if not filling a full row
			add("Consumables", "cat", list, #list <= ns.SMALL_GROUP)
		end
		if not pinBottom then
			add("Pinned", "pin", Merge(pinned, trading), #pinned <= ns.SMALL_GROUP)
			consumables()
		end
		setGroups()
		for _, c in ipairs(CATS) do
			if c[1] == "con" then
				-- drawn next to the pinned items instead
			elseif c[1] == "mat" then
				-- trade goods get one block per kind of material
				for _, kind in ipairs(MAT_ORDER) do
					local list = Merge(take(function(e) return e.group == "mat" and e.matKind == kind end), trading)
					add(kind, "cat", list)
				end
			else
				local list = Merge(take(function(e) return e.group == c[1] end), trading)
				-- Allow Gear to share row if it has empty space remaining
				add(c[2], c[1] == "fresh" and "raid" or "cat", list, #list <= ns.SMALL_GROUP)
			end
		end
		if pinBottom then
			consumables()
			add("Pinned", "pin", Merge(pinned, trading), #pinned <= ns.SMALL_GROUP)
		end
		if #empties > 0 then
			local freeList = FreeEntries(empties)
			-- Fetch configured columns from DB directly to prevent nil reference
			local cols = db.columns[kind] or 10
			sections[#sections + 1] = { title = "Free", style = "cat", entries = freeList, small = (#freeList < cols) }
		end
	else
		if mode == "sets" then setGroups() end
		local grid = Merge(entries, trading)
		for _, e in ipairs(FreeEntries(empties)) do grid[#grid + 1] = e end
		add(nil, nil, grid)
	end

	return sections, #empties, cached
end
