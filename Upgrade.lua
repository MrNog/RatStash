local _, ns = ...

--------------------------------------------------------------------------------
-- upgrade %: item tooltips get one line per gear set you carry (a piece in your bags, or the set you
-- are wearing): how much better or worse the item scores than that set's piece.
-- Score = each stat times the set's spec weight (Weights.lua), summed. A set's spec comes from its
-- name ("Holy", "Ret", "Val"...) or your biggest talent tree; /rst spec changes it.
--------------------------------------------------------------------------------

ns.BYKEY = {}
for _, s in ipairs(ns.SPECS) do ns.BYKEY[s.key] = s end

local SLOT = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
	INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
	INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

local STAT = {
	ITEM_MOD_STRENGTH_SHORT = "Str", ITEM_MOD_AGILITY_SHORT = "Agi", ITEM_MOD_STAMINA_SHORT = "Sta",
	ITEM_MOD_INTELLECT_SHORT = "Int", ITEM_MOD_SPIRIT_SHORT = "Spi", ITEM_MOD_SPELL_POWER_SHORT = "SP",
	ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "FAP",
	ITEM_MOD_HIT_RATING_SHORT = "Hit", ITEM_MOD_CRIT_RATING_SHORT = "Crit", ITEM_MOD_HASTE_RATING_SHORT = "Haste",
	ITEM_MOD_EXPERTISE_RATING_SHORT = "Exp", ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ArP",
	ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Def", ITEM_MOD_DODGE_RATING_SHORT = "Dodge",
	ITEM_MOD_PARRY_RATING_SHORT = "Parry", ITEM_MOD_BLOCK_RATING_SHORT = "Block",
	ITEM_MOD_BLOCK_VALUE_SHORT = "BlockV", RESISTANCE0_NAME = "Armor", EMPTY_SOCKET_META = "Meta",
}

-- item subtype -> the type names the weight tables use in their bad lists
local TYPE = {
	Plate = "Plate", Mail = "Mail", Leather = "Leather", Shields = "Shield",
	Daggers = "Dagger", ["Fist Weapons"] = "Fist", Staves = "Staff", Bows = "Bow", Crossbows = "Crossbow",
	Guns = "Gun", Thrown = "Thrown", Wands = "Wand", Polearms = "Polearm",
	["One-Handed Swords"] = "Sword", ["Two-Handed Swords"] = "2HSword", ["One-Handed Axes"] = "Axe",
	["Two-Handed Axes"] = "2HAxe", ["One-Handed Maces"] = "Mace", ["Two-Handed Maces"] = "2HMace",
}

-- nil when the spec never uses this kind of item
local function Score(link, spec, slot)
	local _, _, _, _, _, _, subType = GetItemInfo(link)
	local kind = subType and TYPE[subType]
	if kind then
		for _, b in ipairs(spec.bad) do if b == kind then return end end
	end
	local w, score = spec.w, 0
	for k, v in pairs(GetItemStats(link) or {}) do
		local key = STAT[k]
		if k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
			if slot == 18 then key = "RangedDPS"
			elseif slot == 17 and w.OffDPS then key = "OffDPS"
			else key = "MeleeDPS" end
		end
		if key and w[key] then score = score + v * w[key] end
	end
	return score
end

--------------------------------------------------------------------------------
-- which spec scores a set
--------------------------------------------------------------------------------

local function Words(setName, class)
	local low, best, bestLen = setName:lower(), nil, 0
	for _, s in ipairs(ns.SPECS) do
		if s.class == class then
			for _, word in ipairs(s.words) do
				if #word > bestLen and low:find(word, 1, true) then best, bestLen = s, #word end
			end
		end
	end
	return best
end

local function Talents(class)
	local top, most = nil, -1
	for i = 1, GetNumTalentTabs() do
		local name, _, points = GetTalentTabInfo(i)
		if name and points > most then top, most = name:lower():match("^(%S+)"), points end
	end
	for _, s in ipairs(ns.SPECS) do
		if s.class == class and top and s.label:lower():match("^(%S+)") == top then return s end
	end
end

local function SpecFor(setName)
	local saved = ns.char and ns.char.setSpec[setName]
	if saved and ns.BYKEY[saved] then return ns.BYKEY[saved] end
	local _, class = UnitClass("player")
	return Words(setName, class) or Talents(class)
end

--------------------------------------------------------------------------------
-- which sets count: a piece in the bags, or every piece worn right now
--------------------------------------------------------------------------------

local function Carried(name)
	local locs = GetEquipmentSetLocations(name)
	local pieces, worn, inBags = 0, 0, false
	for invSlot = 1, 19 do
		local loc = locs and locs[invSlot]
		if loc and loc > 1 then
			pieces = pieces + 1
			local player, bank, bags = EquipmentManager_UnpackLocation(loc)
			if bags and not bank then inBags = true
			elseif player and not bank then worn = worn + 1 end
		end
	end
	return inBags or (pieces > 0 and worn == pieces)
end

--------------------------------------------------------------------------------
-- tooltip
--------------------------------------------------------------------------------

-- the set's piece for this slot; for rings/trinkets the weaker one, that is the one you would swap out
local function SetPiece(ids, slots, spec)
	local score, slot
	for _, s in ipairs(slots) do
		local sid = ids[s]
		if sid and sid > 1 then
			local _, l = GetItemInfo(sid)
			local sc = l and Score(l, spec, s)
			if sc and (not score or sc < score) then score, slot = sc, s end
		end
	end
	return score, slot
end

local function Compare(link)
	local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
	local slots = equipLoc and SLOT[equipLoc]
	if not slots then return end
	local id = tonumber(link:match("item:(%d+)"))
	local out = {}
	for i = 1, GetNumEquipmentSets() do
		local name, icon = GetEquipmentSetInfo(i)
		local ids = name and Carried(name) and GetEquipmentSetItemIDs(name)
		local spec = ids and SpecFor(name)
		if spec then
			if icon and not icon:find("\\", 1, true) then icon = "Interface\\Icons\\" .. icon end
			local e = { name = name, icon = icon, spec = spec }
			for _, s in ipairs(slots) do if ids[s] == id then e.inSet = true end end
			local oldScore, slot = SetPiece(ids, slots, spec)
			local new = Score(link, spec, slot or slots[1])
			if new and oldScore and oldScore > 0 then e.pct = (new - oldScore) / oldScore * 100 end
			out[#out + 1] = e
		end
	end
	return out
end

-- ClassLoot (Kaliban's lists, optional) says which specs an item is meant for. Stats alone can't
-- tell: weapon DPS scores high for a rogue even on a caster dagger. An item ClassLoot lists only
-- for other specs is not an upgrade; an item it doesn't know at all is left to the score.
local CLASSLOOT = {
	WarriorArms = { "WarriorDPS", "WarriorArms" }, WarriorFury = { "WarriorDPS", "WarriorFury" },
	WarriorTank = { "WarriorProt", "WarriorTanking" },
	PaladinHoly = { "PaladinHoly", "PaladinHealing" }, PaladinTank = { "PaladinProt" },
	PaladinRetribution = { "PaladinRet", "PaladinDPS" },
	HunterBeastMastery = { "Hunter" }, HunterMarksman = { "Hunter" }, HunterSurvival = { "Hunter" },
	RogueAssassination = { "Rogue" }, RogueCombat = { "Rogue" }, RogueSubtlety = { "Rogue" },
	PriestDiscipline = { "PriestHeal", "Priest" }, PriestHoly = { "PriestHeal", "Priest" },
	PriestShadow = { "PriestDPS", "Priest" },
	DeathKnightBloodDps = { "DeathknightDPS" }, DeathKnightFrostDps = { "DeathknightDPS" },
	DeathKnightUnholyDps = { "DeathknightDPS" },
	DeathKnightBloodTank = { "DeathknightTank" }, DeathKnightFrostTank = { "DeathknightTank" },
	ShamanElemental = { "ShamanElemental", "ShamanDPS" }, ShamanEnhancement = { "ShamanEnhance", "ShamanDPS" },
	ShamanRestoration = { "ShamanResto", "ShamanHealing" },
	MageArcane = { "Mage" }, MageFire = { "Mage" }, MageFrost = { "Mage" },
	WarlockAffliction = { "Warlock" }, WarlockDemonology = { "Warlock" }, WarlockDestruction = { "Warlock" },
	DruidBalance = { "DruidBalance" }, DruidFeralDps = { "DruidFeral" }, DruidFeralTank = { "DruidFeral" },
	DruidRestoration = { "DruidResto", "DruidHealing" },
}

local function ClassLootData()
	local ace = LibStub and LibStub("AceAddon-3.0", true)
	local cl = ace and ace:GetAddon("ClassLoot", true)
	return cl and cl.CD
end

-- stats that mark an item as tank, caster or melee gear; a spec that weighs none of them doesn't want it
local ROLE_STATS = {
	ITEM_MOD_STRENGTH_SHORT = "Str", ITEM_MOD_AGILITY_SHORT = "Agi", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ArP", ITEM_MOD_EXPERTISE_RATING_SHORT = "Exp",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Def", ITEM_MOD_DODGE_RATING_SHORT = "Dodge",
	ITEM_MOD_PARRY_RATING_SHORT = "Parry", ITEM_MOD_BLOCK_RATING_SHORT = "Block",
	ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_INTELLECT_SHORT = "Int", ITEM_MOD_SPIRIT_SHORT = "Spi",
	ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
}

local function StatsFit(id, spec)
	local _, link = GetItemInfo(id)
	for k in pairs(link and GetItemStats(link) or {}) do
		local key = ROLE_STATS[k]
		if key and not spec.w[key] then return false end
	end
	return true
end

-- melee weapon types a spec actually fights with, where its class can hold more than it uses:
-- Mutilate needs daggers, Combat wants anything but. Ranged slots are not affected.
local SPEC_WEAPONS = {
	RogueAssassination = { Dagger = true },
	RogueCombat = { Sword = true, Fist = true, Axe = true, Mace = true },
}
local MELEE = {
	Dagger = true, Fist = true, Sword = true, Axe = true, Mace = true, Staff = true, Polearm = true,
	["2HSword"] = true, ["2HAxe"] = true, ["2HMace"] = true,
}

-- at 80 every class wears one armor type; a holy paladin has no use for a cloth Int chest
local CLASS_ARMOR = {
	WARRIOR = "Plate", PALADIN = "Plate", DEATHKNIGHT = "Plate", HUNTER = "Mail", SHAMAN = "Mail",
	ROGUE = "Leather", DRUID = "Leather", PRIEST = "Cloth", MAGE = "Cloth", WARLOCK = "Cloth",
}
local ARMOR_SLOT = {
	INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
	INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}

local function GearFits(id, spec)
	local _, _, _, _, _, _, subType, _, equipLoc = GetItemInfo(id)
	if ARMOR_SLOT[equipLoc] and subType ~= CLASS_ARMOR[spec.class] then return false end
	local allowed = SPEC_WEAPONS[spec.key]
	if not allowed then return true end
	local kind = subType and TYPE[subType]
	return not (kind and MELEE[kind]) or allowed[kind] == true
end

local function MeantFor(id, spec)
	if not GearFits(id, spec) then return false end
	local cd = ClassLootData()
	local entry = cd and cd[id]
	if not entry then return StatsFit(id, spec) end
	for _, k in ipairs(CLASSLOOT[spec.key] or {}) do
		if entry[k] then return true end
	end
	return false
end

ns.SLOT = SLOT

-- the spec your talents are in right now
function ns.CurrentSpec()
	local _, class = UnitClass("player")
	return Talents(class)
end

-- the best upgrade % this item is over what you have, for the loot radar.
-- Uses your carried gear sets like the tooltip; with none, scores against what you are wearing
-- with your talent spec. Returns nil when the item is not gear your spec uses,
-- or pct, owned (owned = already in a set, bags or worn).
function ns.BestUpgrade(link)
	local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
	local slots = equipLoc and SLOT[equipLoc]
	if not slots then return end
	local id = tonumber(link:match("item:(%d+)"))
	local owned = GetItemCount(id, true) > 0
	-- judged for the spec your talents are in right now; sets for your other spec don't count
	local _, class = UnitClass("player")
	local spec = Talents(class)
	if not spec or not MeantFor(id, spec) then return end
	local best, matched
	for _, e in ipairs(Compare(link) or {}) do
		if e.inSet then owned = true end
		if e.spec.key == spec.key then
			matched = true
			if e.pct and (not best or e.pct > best) then best = e.pct end
		end
	end
	if matched then return best, owned end
	local oldScore, oldSlot
	for _, s in ipairs(slots) do
		local l = GetInventoryItemLink("player", s)
		local sc = l and Score(l, spec, s)
		if l and l:match("item:(%d+)") == tostring(id) then owned = true end
		if sc and (not oldScore or sc < oldScore) then oldScore, oldSlot = sc, s end
	end
	local new = Score(link, spec, oldSlot or slots[1])
	if not new then return end
	if not oldScore or oldScore <= 0 then return 100, owned end -- empty slot: anything helps
	return (new - oldScore) / oldScore * 100, owned
end

local DIM = "|cff8a8d93"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"

-- bigger upgrades climb the parse colours (blue, purple, orange) so a real upgrade stands out
local function PctText(pct)
	local txt = string.format("%+.1f%%", pct)
	if pct >= 20 then return txt, 1.000, 0.502, 0.000 end
	if pct >= 10 then return txt, 0.639, 0.208, 0.933 end
	if pct >= 5 then return txt, 0.000, 0.439, 1.000 end
	if pct >= 1 then return txt, 0.486, 0.988, 0.541 end
	if pct > -1 then return "same", 0.541, 0.553, 0.576 end
	return txt, 0.85, 0.30, 0.32
end

local function AddLines(tip)
	if tip.rstUpgradeDone or not (ns.db and ns.db.showUpgrade) then return end
	local _, link = tip:GetItem()
	local sets = link and Compare(link)
	if not sets then return end
	tip.rstUpgradeDone = true
	local first = true
	for _, e in ipairs(sets) do
		local txt, r, g, b
		if e.inSet then txt, r, g, b = CHECK, 1, 1, 1
		elseif e.pct then txt, r, g, b = PctText(e.pct) end
		if txt then
			if first then
				tip:AddLine(" ")
				tip:AddLine("Upgrade for your sets", 1, 0.82, 0)
				first = false
			end
			local left = e.name .. "  " .. DIM .. e.spec.label .. "|r"
			if e.icon then left = "|T" .. e.icon .. ":14:14:0:0|t " .. left end
			tip:AddDoubleLine(left, txt, 0.863, 0.867, 0.871, r, g, b)
		end
	end
end

for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
	tip:HookScript("OnTooltipSetItem", AddLines)
	tip:HookScript("OnTooltipCleared", function(self) self.rstUpgradeDone = nil end)
end

--------------------------------------------------------------------------------
-- /rst spec: list sets and their spec, or change one
--------------------------------------------------------------------------------

function ns.SetSpecCommand(args)
	local set, want = (args or ""):match("^%s*(%S+)%s+(.-)%s*$")
	local _, class = UnitClass("player")
	if not set then
		for i = 1, GetNumEquipmentSets() do
			local name = GetEquipmentSetInfo(i)
			local s = SpecFor(name)
			local how = ns.char.setSpec[name] and "" or " |cff808080(auto)|r"
			ns.Print(name .. " = " .. (s and s.label or "?") .. how)
		end
		local labels = {}
		for _, s in ipairs(ns.SPECS) do if s.class == class then labels[#labels + 1] = s.label end end
		ns.Print("change: /rst spec <set> <spec>   specs: " .. table.concat(labels, ", "))
		ns.Print("back to auto: /rst spec <set> auto")
		return
	end
	local real
	for i = 1, GetNumEquipmentSets() do
		local name = GetEquipmentSetInfo(i)
		if name:lower() == set:lower() then real = name end
	end
	if not real then return ns.Print("no gear set called " .. set) end
	want = want:lower()
	if want == "auto" then
		ns.char.setSpec[real] = nil
		local s = SpecFor(real)
		return ns.Print(real .. " = auto (" .. (s and s.label or "?") .. ")")
	end
	for _, s in ipairs(ns.SPECS) do
		if s.class == class and s.label:lower():sub(1, #want) == want then
			ns.char.setSpec[real] = s.key
			return ns.Print(real .. " = " .. s.label)
		end
	end
	ns.Print("no " .. class:lower() .. " spec starting with " .. want)
end
