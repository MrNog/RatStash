"""Build RatStash/Weights.lua from Pawn 1.3.12 (Wowhead WotLK scales) + wowsims/wotlk default EP weights.
usage: python -I gen_weights.py <dl_dir> <out_lua>"""
import re, sys, os

dl, out = sys.argv[1], sys.argv[2]
pawn_src = open(os.path.join(dl, "Wowhead.lua"), encoding="utf-8-sig").read()

# Pawn stat key -> RatSets key
PAWN = {
    "Strength": "Str", "Agility": "Agi", "Stamina": "Sta", "Intellect": "Int", "Spirit": "Spi",
    "SpellPower": "SP", "Ap": "AP", "FeralAp": "FAP", "HitRating": "Hit", "CritRating": "Crit",
    "HasteRating": "Haste", "ExpertiseRating": "Exp", "ArmorPenetration": "ArP", "Mp5": "MP5",
    "DefenseRating": "Def", "DodgeRating": "Dodge", "ParryRating": "Parry", "BlockRating": "Block",
    "BlockValue": "BlockV", "Armor": "Armor", "BonusArmor": "Armor", "MeleeDps": "MeleeDPS",
    "RangedDps": "RangedDPS", "MetaSocketEffect": "Meta",
}

pawn = {}
for m in re.finditer(r'"(\w+)",\s*PawnWowheadScale_\w+,\s*"[0-9a-f]+",\s*\{(.*?)\}', pawn_src, re.S):
    name, body = m.group(1), m.group(2)
    w, bad = {}, []
    for k, v in re.findall(r'\["(\w+)"\]\s*=\s*([-\d.]+)', body):
        v = float(v)
        if k.startswith("Is") and v <= -1000:
            bad.append(k[2:])
        elif k in PAWN:
            w[PAWN[k]] = w.get(PAWN[k], 0) + v
    pawn[name] = (w, bad)

def sims(spec):
    src = open(os.path.join(dl, spec + ".ts"), encoding="utf-8").read()
    block = re.search(r"epWeights:(.*?)\}\),", src, re.S).group(1)
    raw = {k: float(v) for k, v in re.findall(r"Stat(\w+)\]:\s*([-\d.]+)", block)}
    # a WotLK rating point gives melee and spell at once, so the two halves add up
    j = lambda *ks: sum(raw.get(k, 0) for k in ks)
    w = {
        "Str": j("Strength"), "Agi": j("Agility"), "Sta": j("Stamina"), "Int": j("Intellect"),
        "Spi": j("Spirit"), "SP": j("SpellPower"), "AP": j("AttackPower", "RangedAttackPower"),
        "Hit": j("MeleeHit", "SpellHit"), "Crit": j("MeleeCrit", "SpellCrit"),
        "Haste": j("MeleeHaste", "SpellHaste"), "Exp": j("Expertise"), "ArP": j("ArmorPenetration"),
        "MP5": j("MP5"), "Def": j("Defense"), "Dodge": j("Dodge"), "Parry": j("Parry"),
        "Block": j("Block"), "BlockV": j("BlockValue"), "Armor": j("Armor"),
        "MeleeDPS": j("MainHandDps"), "OffDPS": j("OffHandDps"), "RangedDPS": j("RangedDps"),
    }
    return {k: round(v, 4) for k, v in w.items() if v}

# spec key, class, label, source, wowsims sim, set-name words
SPECS = [
    ("WarriorArms", "WARRIOR", "Arms", "pawn", None, ["arms"]),
    ("WarriorFury", "WARRIOR", "Fury", "pawn", None, ["fury", "dps"]),
    ("WarriorTank", "WARRIOR", "Protection", "sims", "protection_warrior", ["prot", "tank"]),
    ("PaladinHoly", "PALADIN", "Holy", "guide", None, ["holy", "heal", "val"]),
    ("PaladinTank", "PALADIN", "Protection", "sims", "protection_paladin", ["prot", "tank"]),
    ("PaladinRetribution", "PALADIN", "Retribution", "sims", "retribution_paladin", ["ret", "dps"]),
    ("HunterBeastMastery", "HUNTER", "Beast Mastery", "pawn", None, ["bm", "beast"]),
    ("HunterMarksman", "HUNTER", "Marksmanship", "pawn", None, ["mm", "marks"]),
    ("HunterSurvival", "HUNTER", "Survival", "pawn", None, ["sv", "surv"]),
    ("RogueAssassination", "ROGUE", "Assassination", "pawn", None, ["assa", "mut"]),
    ("RogueCombat", "ROGUE", "Combat", "pawn", None, ["combat"]),
    ("RogueSubtlety", "ROGUE", "Subtlety", "pawn", None, ["sub"]),
    ("PriestDiscipline", "PRIEST", "Discipline", "pawn", None, ["disc"]),
    ("PriestHoly", "PRIEST", "Holy", "pawn", None, ["holy", "heal"]),
    ("PriestShadow", "PRIEST", "Shadow", "sims", "shadow_priest", ["shadow", "sp", "dps"]),
    ("DeathKnightBloodDps", "DEATHKNIGHT", "Blood (DPS)", "pawn", None, ["blood"]),
    ("DeathKnightBloodTank", "DEATHKNIGHT", "Blood (Tank)", "sims", "tank_deathknight", ["tank", "prot"]),
    ("DeathKnightFrostDps", "DEATHKNIGHT", "Frost (DPS)", "pawn", None, ["frost"]),
    ("DeathKnightFrostTank", "DEATHKNIGHT", "Frost (Tank)", "sims", "tank_deathknight", ["frost tank"]),
    ("DeathKnightUnholyDps", "DEATHKNIGHT", "Unholy", "pawn", None, ["unholy", "uh", "dps"]),
    ("ShamanElemental", "SHAMAN", "Elemental", "sims", "elemental_shaman", ["ele"]),
    ("ShamanEnhancement", "SHAMAN", "Enhancement", "sims", "enhancement_shaman", ["enh", "dps"]),
    ("ShamanRestoration", "SHAMAN", "Restoration", "pawn", None, ["resto", "heal"]),
    ("MageArcane", "MAGE", "Arcane", "pawn", None, ["arcane"]),
    ("MageFire", "MAGE", "Fire", "pawn", None, ["fire"]),
    ("MageFrost", "MAGE", "Frost", "pawn", None, ["frost"]),
    ("WarlockAffliction", "WARLOCK", "Affliction", "pawn", None, ["affli", "aff"]),
    ("WarlockDemonology", "WARLOCK", "Demonology", "pawn", None, ["demo"]),
    ("WarlockDestruction", "WARLOCK", "Destruction", "pawn", None, ["destro"]),
    ("DruidBalance", "DRUID", "Balance", "sims", "balance_druid", ["balance", "boomy", "moonkin"]),
    ("DruidFeralDps", "DRUID", "Feral (Cat)", "sims", "feral_druid", ["cat", "feral", "dps"]),
    ("DruidFeralTank", "DRUID", "Feral (Bear)", "sims", "feral_tank_druid", ["bear", "tank"]),
    ("DruidRestoration", "DRUID", "Restoration", "pawn", None, ["resto", "heal", "tree"]),
]

# hand-set weights following a guide's stat order (Pawn's 2010 file rates MP5 above Haste)
GUIDE = {
    # Wowhead WotLK Classic Holy Paladin: Intellect > Haste > MP5 > Spell Power > Crit
    "PaladinHoly": {"Int": 100, "Haste": 80, "MP5": 60, "SP": 55, "Crit": 45, "Sta": 0.1, "Meta": 3600},
}

def lua_tbl(d):
    return "{ " + ", ".join(f"{k} = {v:g}" for k, v in sorted(d.items())) + " }"

lines = [
    "-- Generated by scripts/gen_weights.py, do not edit by hand.",
    "-- Stat weights per spec: \"sims\" = wowsims/wotlk default EP weights (simulated),",
    "-- \"pawn\" = the Wowhead WotLK scales Pawn 1.3 shipped, \"guide\" = set by hand to a guide's stat order.",
    "-- Only the ratio between stats matters.",
    "-- bad = item types the spec never uses; such items get no score.",
    "local _, ns = ...",
    "",
    "ns.SPECS = {",
]
for key, cls, label, src, sim, words in SPECS:
    pw, bad = pawn[key]
    w = sims(sim) if src == "sims" else GUIDE[key] if src == "guide" else pw
    if src == "sims" and "Meta" in pw:
        # meta value in the sim's own units, through the stat both scales rate highest
        ref = max((k for k in pw if k in w and k not in ("Meta", "MeleeDPS", "RangedDPS")), key=lambda k: pw[k])
        w["Meta"] = round(pw["Meta"] / pw[ref] * w[ref], 2)
    lines.append(f'\t{{ key = "{key}", class = "{cls}", label = "{label}", src = "{src}",')
    lines.append(f"\t\tw = {lua_tbl(w)},")
    lines.append("\t\tbad = { " + ", ".join(f'"{b}"' for b in bad) + " },")
    lines.append("\t\twords = { " + ", ".join(f'"{x}"' for x in words) + " } },")
lines.append("}")
open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print("specs:", len(SPECS))
