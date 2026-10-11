local _, ns = ...

--------------------------------------------------------------------------------
-- BiS lists (BisData.lua, copied from Bistooltip): the hand-made top 6 per slot for each spec and phase.
-- The radar asks ns.RadarJudge whether a drop is for you: it must be on your spec's list for
-- the raid's phase, and rank above what you wear in that slot. Lists hold one id per item
-- (mostly the 25 heroic one), so items are matched by name: the 10, 25 and heroic copies
-- share it. Horde ToC ids go through the list's own horde -> alliance table.
--------------------------------------------------------------------------------

-- RatStash spec key -> Bistooltip spec name (class name comes from CLASS)
local SPEC = {
	WarriorArms = "Arms", WarriorFury = "Fury", WarriorTank = "Protection",
	PaladinHoly = "Holy", PaladinTank = "Protection", PaladinRetribution = "Retribution",
	HunterBeastMastery = "Beast mastery", HunterMarksman = "Marksmanship", HunterSurvival = "Survival",
	RogueAssassination = "Assassination", RogueCombat = "Combat",
	PriestDiscipline = "Discipline", PriestHoly = "Holy", PriestShadow = "Shadow",
	DeathKnightBloodDps = "Blood dps", DeathKnightBloodTank = "Blood tank", DeathKnightFrostDps = "Frost",
	DeathKnightFrostTank = "Blood tank", DeathKnightUnholyDps = "Unholy",
	ShamanElemental = "Elemental", ShamanEnhancement = "Enhancement", ShamanRestoration = "Restoration",
	MageArcane = "Arcane", MageFire = "Fire", MageFrost = "Frost",
	WarlockAffliction = "Affliction", WarlockDemonology = "Demonology", WarlockDestruction = "Destruction",
	DruidBalance = "Balance", DruidFeralDps = "Feral dps", DruidFeralTank = "Feral tank",
	DruidRestoration = "Restoration",
}
local CLASS = {
	WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
	DEATHKNIGHT = "Death knight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

-- the list a raid's loot is judged by; a missing phase falls through to the next one
local PHASE = {
	icc = { "T10", "RS", "T9" }, rs = { "RS", "T10" }, toc = { "T9", "T10" },
	ulduar = { "T8", "T9", "T10" }, naxx = { "T7", "PR", "T9" }, os = { "T7", "PR", "T9" },
	eoe = { "T7", "PR", "T9" }, voa = { "T10", "T9", "T8", "T7" }, ony = { "T9", "T10" },
}

-- inventory slots each Bistooltip row stands for
local ROW_SLOTS = {
	Head = { 1 }, Neck = { 2 }, Shoulder = { 3 }, Back = { 15 }, Chest = { 5 }, Wrist = { 9 },
	Hands = { 10 }, Waist = { 6 }, Legs = { 7 }, Feet = { 8 }, Finger = { 11, 12 },
	Trinket = { 13, 14 }, Weapon = { 16 }, ["Off hand"] = { 17 }, Ranged = { 18 }, Relic = { 18 },
}

-- id -> name for every raid drop, so a list id names its 10/25/heroic copies without a server query,
-- and id -> how high its version is (10 < 25 = 10 heroic < 25 heroic)
local VERSION = { ["10n"] = 1, ["25n"] = 2, ["10h"] = 2, ["25h"] = 3 }
local lootName, lootVersion
local function NameOf(id)
	if not lootName then
		lootName, lootVersion = {}, {}
		for _, bosses in pairs(ns.RAIDLOOT or OkanvilRaidLoot or {}) do
			for _, boss in ipairs(bosses) do
				for _, it in ipairs(boss.items) do
					lootName[it.id] = it.name
					lootVersion[it.id] = VERSION[(it.m or ""):match("^[^,]+")] or 0
				end
			end
		end
	end
	return lootName[id] or GetItemInfo(id)
end

-- Bistooltip sometimes orders two versions of one item backwards (Assassination's neck has the
-- normal Sindragosa's Cruel Claw at #1, the heroic at #4). A higher version is never worse, so
-- within a name the places are handed out again, best place to the highest version.
local function FixVersions(r)
	local groups = {}
	for id, n in pairs(r.rank) do
		local name = NameOf(id)
		if name then
			groups[name] = groups[name] or {}
			table.insert(groups[name], { id = id, n = n, v = lootVersion[id] or 0 })
		end
	end
	for _, g in pairs(groups) do
		if #g > 1 then
			local places = {}
			for i, e in ipairs(g) do places[i] = e.n end
			table.sort(places)
			table.sort(g, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.n < b.n end)
			for i, e in ipairs(g) do r.rank[e.id] = places[i] end
		end
	end
end

local function AliId(id)
	return (ns.BIS_HORDE_TO_ALI and ns.BIS_HORDE_TO_ALI[id]) or id
end

-- rows of the list for this spec + raid:
--   { { name = "Finger", top = id, rank = { [id] = n }, byName = { [name] = best n } }, ... }
-- A list can hold several versions of one item (Bone Colossus heroic #2, normal #4), so the exact
-- id's rank and the name's best rank are kept apart.
local cache = {}
local function Rows(spec, raid)
	local lists = ns.BIS
	local cls = lists and lists[CLASS[spec.class]]
	local bySpec = cls and SPEC[spec.key] and cls[SPEC[spec.key]]
	if not bySpec then return end
	local phase
	for _, p in ipairs(PHASE[raid] or { "T10" }) do
		if bySpec[p] and #bySpec[p] > 0 then phase = p; break end
	end
	if not phase then return end
	local key = spec.key .. phase
	if cache[key] then return cache[key], phase end
	local rows = {}
	for _, row in ipairs(bySpec[phase]) do
		local r = { name = row.slot, rank = {}, byName = {}, top = row[1] }
		for n = 1, 6 do
			local id = row[n]
			if id and id > 0 then
				r.rank[id] = r.rank[id] or n
				local name = NameOf(id)
				if name and not r.byName[name] then r.byName[name] = n end
			end
		end
		FixVersions(r)
		rows[#rows + 1] = r
	end
	cache[key] = rows
	return rows, phase
end

-- exact = this version's place on the list; byName = the best place of any version of it
local function RankIn(row, id, name)
	local ali = AliId(id)
	local aliName = ali ~= id and NameOf(ali)
	local exact = row.rank[ali] or row.rank[id]
	local byName = (name and row.byName[name]) or (aliName and row.byName[aliName]) or exact
	return exact or byName, exact, byName
end

local function Ilvl(link) return select(4, GetItemInfo(link)) or 0 end

-- Does the drop beat the piece you wear, both on this list row? At the same item level the
-- list's order of the items decides (normal Bone Colossus over normal Seal of Many Mouths, as
-- their heroics are ordered). Across item levels the exact version's place decides; a version
-- the list doesn't name sits half a place under the version it does.
local function Beats(row, link, id, wornLink, wid)
	local _, dExact, dName = RankIn(row, id, GetItemInfo(link))
	local _, wExact, wName = RankIn(row, wid, GetItemInfo(wornLink))
	local dl, wl = Ilvl(link), Ilvl(wornLink)
	if dl == wl then return dName < wName end
	local d, w = dExact or (dName + 0.5), wExact or (wName + 0.5)
	if d ~= w then return d < w end
	return dl > wl
end

-- Set pieces: the tooltip's "Shadowblade's Battlegear (4/5)" line names the set and how many you
-- wear. Dropping a piece out of exactly 2 or 4 loses a bonus, so a piece outside the set can't
-- replace it; at 3 or 5 one can go. Equipped results are cached until your gear changes.
local scan = CreateFrame("GameTooltip", "RatStashSetScan", nil, "GameTooltipTemplate")
local wornSet, itemSet = {}, {}

local function ReadSet()
	for i = 2, scan:NumLines() do
		local fs = _G["RatStashSetScanTextLeft" .. i]
		if fs then
			local name, n = (fs:GetText() or ""):match("^(.-) %((%d+)/%d+%)$")
			if name then return name, tonumber(n) end
		end
	end
	return false
end

local function WornSet(slot)
	if wornSet[slot] == nil then
		scan:SetOwner(UIParent, "ANCHOR_NONE")
		scan:SetInventoryItem("player", slot)
		local name, n = ReadSet()
		wornSet[slot] = name and { name = name, n = n } or false
		scan:Hide()
	end
	return wornSet[slot]
end

-- the set an item belongs to, false for none, nil while the client hasn't cached the item
local function SetOf(id)
	if not id then return nil end
	if itemSet[id] == nil then
		scan:SetOwner(UIParent, "ANCHOR_NONE")
		scan:SetHyperlink("item:" .. id)
		if scan:NumLines() > 1 then itemSet[id] = ReadSet() or false end
		scan:Hide()
	end
	return itemSet[id]
end

ns.On("PLAYER_EQUIPMENT_CHANGED", function() wipe(wornSet) end)

local TIER_ROWS = { Head = true, Shoulder = true, Chest = true, Hands = true, Legs = true }

-- Would putting this item in place of the set piece you wear in `slot` cost you a bonus your
-- spec plays with? The BiS list says how many set pieces the spec wants: Assassination puts tier
-- at #1 in four slots, Combat in two. A slot whose BiS is the set piece is kept; elsewhere the
-- piece can go as long as you keep that many. Without the answer (items not cached yet), the
-- plain rule: dropping out of exactly 2 or 4 loses a bonus.
local function BreaksSet(id, slot, row, rows)
	local worn = WornSet(slot)
	if not worn or SetOf(id) == worn.name then return false end
	local here = SetOf(row.top)
	if here == worn.name then return true end
	local wanted, unknown = 0, here == nil
	for _, r in ipairs(rows) do
		if TIER_ROWS[r.name] then
			local s = SetOf(r.top)
			if s == nil then unknown = true elseif s == worn.name then wanted = wanted + 1 end
		end
	end
	if unknown then return worn.n == 2 or worn.n == 4 end
	return worn.n - 1 < wanted
end

-- how a drop ranks for you. Returns show, pct, owned, rank:
--   rank = its place on your list (1 = BiS); show = it ranks above the piece you wear there
--   (on rings and trinkets: the weaker of the two), or is a higher item level copy of it.
--   A 5th value says what it was measured against: "#6" (your piece's rank), "264" (your
--   piece's item level, when it isn't on the list), "empty", or "tier" (kept for a set bonus).
-- Without a list for your spec this falls back to the upgrade % alone.
function ns.RadarJudge(link, raid)
	local spec = ns.CurrentSpec()
	local pct, owned = ns.BestUpgrade(link)
	local rows = spec and Rows(spec, raid)
	if not rows then
		return pct ~= nil and pct >= (ns.db.radarMin or 1), pct, owned
	end
	local id = tonumber(link:match("item:(%d+)"))
	local name = GetItemInfo(link)
	owned = GetItemCount(id, true) > 0
	local best, show, vs, vsBeaten
	for _, row in ipairs(rows) do
		local r = RankIn(row, id, name)
		if r then
			best = (best and math.min(best, r)) or r
			-- An upgrade if it beats the piece in ANY of the row's slots (rings and trinkets: you
			-- swap out the weaker one). Against a listed piece the list rank decides, a higher
			-- item level copy of the same rank too. A piece not on the list says nothing about
			-- rank, it is often gear from a later phase (an ICC belt while looking at Naxx), so
			-- item level decides. Not the stat %: it can't value a trinket's proc.
			for _, s in ipairs(ROW_SLOTS[row.name] or {}) do
				local l = GetInventoryItemLink("player", s)
				local beats, label
				if not l then
					beats, label = true, "empty"
				elseif BreaksSet(id, s, row, rows) then
					-- keeps your tier bonus: this slot is not up for replacing
					label = "tier"
				else
					local wid = tonumber(l:match("item:(%d+)"))
					local wr = wid and RankIn(row, wid, GetItemInfo(l))
					if wr then
						beats, label = Beats(row, link, id, l, wid), "#" .. wr
					else
						beats, label = Ilvl(link) > Ilvl(l), tostring(Ilvl(l))
					end
				end
				-- report the slot it beats; failing that, the last one it lost to
				if beats then show = true end
				if beats or not vsBeaten then vs, vsBeaten = label, beats end
			end
		end
	end
	-- not on your list: no % either, so "All" shows the list and nothing the stat score guessed
	if not best then return false, nil, owned end
	return show == true, pct, owned, best, vs
end
