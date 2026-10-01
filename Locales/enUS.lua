local addonName, addonTable = ...

-- Метатаблица возвращает исходный ключ, если перевод отсутствует вовсе
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end
})
addonTable.L = L

-- ========================================================
-- СУМКА И БАНК (КАТЕГОРИИ И ЭЛЕМЕНТЫ)
-- ========================================================
L["BAG_TITLE"]           = "%s's Bags"
L["BANK_TITLE"]          = "Bank"
L["SEARCH_PLACEHOLDER"]  = "Search"
L["FREE_SLOTS"]          = "%d Free"
L["PINNED"]              = "PINNED"
L["CONSUMABLES"]         = "CONSUMABLES"
L["OTHER_MATS"]          = "OTHER MATS"
L["QUEST"]               = "QUEST"
L["OTHER"]               = "OTHER"
L["GEAR"]                = "GEAR"
L["JUNK"]                = "JUNK"
L["FREE"]                = "FREE"

-- ========================================================
-- ОКНО НАСТРОЕК (CONFIG / OPTIONS)
-- ========================================================
L["CONFIG_TITLE"]        = "RatStash Settings"
L["GENERAL_SETTINGS"]    = "General"
L["SHOW_BAG_BAR"]        = "Show Bag Bar"
L["SHOW_BAG_BAR_DESC"]   = "Toggle display of the individual bag slots."
L["SHOW_JUNK_ICON"]      = "Show Vendor Trash Icon"
L["SHOW_ILVL"]           = "Show Item Level"
L["SCALE"]               = "Window Scale"
L["SECTION_SORTING"]     = "Section Order"
L["RESET_DEFAULTS"]      = "Reset to Defaults"
