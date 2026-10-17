local _, ns = ...

--------------------------------------------------------------------------------
-- Is an item meant for the spec you are in? No stat weights: they go wrong the
-- moment you pass a hit or haste cap. The answer comes from, in order:
--   1. the weapon types and hands the spec fights with;
--   2. ClassLoot's per-spec lists, when that addon is installed;
--   3. the stats: a tank, caster or melee stat the spec does not use (Specs.lua),
--      or an Equip/Use line written for another role.
-- An upgrade off your BiS list is then a higher item level than what you wear.
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
ns.SLOT = SLOT

-- item subtype -> the type names Specs.lua's bad lists use
local TYPE = {
	Plate = "Plate", Mail = "Mail", Leather = "Leather", Shields = "Shield",
	Daggers = "Dagger", ["Fist Weapons"] = "Fist", Staves = "Staff", Bows = "Bow", Crossbows = "Crossbow",
	Guns = "Gun", Thrown = "Thrown", Wands = "Wand", Polearms = "Polearm",
	["One-Handed Swords"] = "Sword", ["Two-Handed Swords"] = "2HSword", ["One-Handed Axes"] = "Axe",
	["Two-Handed Axes"] = "2HAxe", ["One-Handed Maces"] = "Mace", ["Two-Handed Maces"] = "2HMace",
}

--------------------------------------------------------------------------------
-- which spec you are in: your biggest talent tree, a tank when its talents (or
-- your presence / bear form) say so
--------------------------------------------------------------------------------

local TANK_TALENTS = {
	DEATHKNIGHT = { ["Anticipation"] = true, ["Frigid Dreadplate"] = true, ["Will of the Necropolis"] = true },
	DRUID = { ["Protector of the Pack"] = true, ["Natural Reaction"] = true },
}
local TANK_SPEC = {
	DeathKnightBloodDps = "DeathKnightBloodTank", DeathKnightFrostDps = "DeathKnightFrostTank",
	DruidFeralDps = "DruidFeralTank",
}

local function HasTankTalents(class)
	local want = TANK_TALENTS[class]
	if not want then return false end
	for tab = 1, GetNumTalentTabs() do
		for i = 1, GetNumTalents(tab) do
			local name, _, _, _, rank = GetTalentInfo(tab, i)
			if name and want[name] and (rank or 0) > 0 then return true end
		end
	end
	return false
end

local function InTankForm(class)
	local form = GetShapeshiftForm() or 0
	if form == 0 then return false end
	local _, name = GetShapeshiftFormInfo(form)
	if class == "DEATHKNIGHT" then return name == GetSpellInfo(48263) end              -- Frost Presence
	if class == "DRUID" then return name == GetSpellInfo(5487) or name == GetSpellInfo(9634) end -- bear
	return false
end

local function Talents(class)
	local top, most = nil, -1
	for i = 1, GetNumTalentTabs() do
		local name, _, points = GetTalentTabInfo(i)
		if name and points > most then top, most = name:lower():match("^(%S+)"), points end
	end
	local spec
	for _, s in ipairs(ns.SPECS) do
		if not spec and s.class == class and top and s.label:lower():match("^(%S+)") == top then spec = s end
	end
	local tank = spec and TANK_SPEC[spec.key]
	if tank and (HasTankTalents(class) or InTankForm(class)) then spec = ns.BYKEY[tank] end
	return spec
end

-- the spec your talents are in right now
function ns.CurrentSpec()
	local _, class = UnitClass("player")
	return Talents(class)
end

--------------------------------------------------------------------------------
-- is the item for that spec
--------------------------------------------------------------------------------

-- ClassLoot (Kaliban's lists, optional) says which specs an item is meant for. Stats alone can't
-- tell: weapon DPS reads well for a rogue even on a caster dagger. An item ClassLoot lists only
-- for other specs is not for you; an item it doesn't know is left to the stats.
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

-- stats that mark an item as tank, caster or melee gear
local ROLE_STATS = {
	ITEM_MOD_STRENGTH_SHORT = "Str", ITEM_MOD_AGILITY_SHORT = "Agi", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ArP", ITEM_MOD_EXPERTISE_RATING_SHORT = "Exp",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Def", ITEM_MOD_DODGE_RATING_SHORT = "Dodge",
	ITEM_MOD_PARRY_RATING_SHORT = "Parry", ITEM_MOD_BLOCK_RATING_SHORT = "Block",
	ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_INTELLECT_SHORT = "Int", ITEM_MOD_SPIRIT_SHORT = "Spi",
	ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
}

-- What an item's Equip / Use / proc lines are for, read once per item:
-- "tank" (when you are hit), "caster" (spells, mana, healing), "melee" (attack power).
local effectTip = CreateFrame("GameTooltip", "RatStashFitTip", nil, "GameTooltipTemplate")
local effectOf = {}
local WORDS = {
	{ "tank", { "struck by", "you are hit", "damage taken", "you take damage", "dodge", "parry", "block", "defense" } },
	{ "caster", { "spell power", "harmful spells", "healing spells", "your spells", "spell critical", "mana",
		"your heals", "healing done" } },
	{ "melee", { "attack power", "melee attacks", "ranged attacks", "melee and ranged" } },
}
local function EffectKind(id)
	if effectOf[id] ~= nil then return effectOf[id] end
	effectTip:SetOwner(UIParent, "ANCHOR_NONE")
	effectTip:SetHyperlink("item:" .. id)
	if effectTip:NumLines() < 2 then effectTip:Hide(); return false end
	local kind = false
	for i = 2, effectTip:NumLines() do
		local fs = _G["RatStashFitTipTextLeft" .. i]
		local t = fs and (fs:GetText() or ""):lower() or ""
		if not kind and (t:find("^equip:") or t:find("^use:") or t:find("^chance on hit:")) then
			for _, w in ipairs(WORDS) do
				for _, word in ipairs(w[2]) do
					if not kind and t:find(word, 1, true) then kind = w[1] end
				end
			end
		end
	end
	effectTip:Hide()
	effectOf[id] = kind
	return kind
end

local function IsTank(spec) return spec.uses.Def or spec.uses.Dodge end

local function StatsFit(id, spec)
	local _, link, _, _, _, _, _, _, equipLoc = GetItemInfo(id)
	local stats = link and GetItemStats(link) or {}
	for k in pairs(stats) do
		local key = ROLE_STATS[k]
		if key and not spec.uses[key] then return false end
	end
	-- bonus armour on a ring, neck or trinket is a tank's
	local jewel = equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_NECK" or equipLoc == "INVTYPE_FINGER"
	local kind = EffectKind(id)
	if not IsTank(spec) and (kind == "tank" or (jewel and stats.RESISTANCE0_NAME)) then return false end
	if kind == "caster" and not spec.uses.SP then return false end
	if kind == "melee" and not spec.uses.AP then return false end
	return true
end

-- melee weapon types and hands a spec actually fights with
local SPEC_WEAPONS = {
	RogueAssassination = { Dagger = true },
	RogueCombat = { Sword = true, Fist = true, Axe = true, Mace = true },
}
local MELEE = {
	Dagger = true, Fist = true, Sword = true, Axe = true, Mace = true, Staff = true, Polearm = true,
	["2HSword"] = true, ["2HAxe"] = true, ["2HMace"] = true,
}
local ONE = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true }
local TWO = { INVTYPE_2HWEAPON = true }
local HANDS = {
	DeathKnightBloodDps = TWO, DeathKnightBloodTank = TWO, DeathKnightFrostDps = ONE,
	PaladinRetribution = TWO, WarriorArms = TWO, WarriorTank = ONE, PaladinTank = ONE,
	ShamanEnhancement = ONE, DruidFeralDps = TWO, DruidFeralTank = TWO,
	RogueAssassination = ONE, RogueCombat = ONE, RogueSubtlety = ONE,
}
local MELEE_LOC = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
	INVTYPE_2HWEAPON = true }

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
	local kind = subType and TYPE[subType]
	if kind then
		for _, b in ipairs(spec.bad) do if b == kind then return false end end
	end
	local hands = HANDS[spec.key]
	if hands and MELEE_LOC[equipLoc] and not hands[equipLoc] then return false end
	local allowed = SPEC_WEAPONS[spec.key]
	if allowed and kind and MELEE[kind] and not allowed[kind] then return false end
	return true
end

function ns.MeantFor(id, spec)
	if not GearFits(id, spec) then return false end
	local cd = ClassLootData()
	local entry = cd and cd[id]
	if not entry then return StatsFit(id, spec) end
	for _, k in ipairs(CLASSLOOT[spec.key] or {}) do
		if entry[k] then return true end
	end
	return false
end

-- For a spec with no BiS list: is the item for you, and how many item levels
-- does it gain over what you wear there (rings, trinkets: the weaker one)?
-- Returns gain (100 for an empty slot), owned; nil when it is not for you.
function ns.IlvlUpgrade(link)
	local _, _, _, ilvl, _, _, _, _, equipLoc = GetItemInfo(link)
	local slots = equipLoc and SLOT[equipLoc]
	if not slots then return end
	local id = tonumber(link:match("item:(%d+)"))
	local owned = GetItemCount(id, true) > 0
	local spec = ns.CurrentSpec()
	if not spec or not ns.MeantFor(id, spec) then return end
	local weakest
	for _, s in ipairs(slots) do
		local l = GetInventoryItemLink("player", s)
		if l and l:match("item:(%d+)") == tostring(id) then owned = true end
		local lvl = l and select(4, GetItemInfo(l)) or 0
		if not weakest or lvl < weakest then weakest = lvl end
	end
	if not weakest or weakest == 0 then return 100, owned end
	if (ilvl or 0) > weakest then return ilvl - weakest, owned end
	return nil, owned
end
