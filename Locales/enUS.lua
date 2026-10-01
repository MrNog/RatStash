local ADDON, ns = ...

local L = setmetatable({}, {
	__index = function(_, k)
		return k
	end
})
ns.L = L

-- ========================================================
-- Window Headers & Controls (Frame.lua)
-- ========================================================
L["BAGS_TITLE"] = "Bags"
L["BANK_TITLE"] = "Bank"
L["FREE_SLOTS_FMT"] = "%s free slots"
L["DROP_ITEM_FREE_SLOT"] = "Drop an item here to put it in a free slot."
L["RAID_LOOT_LINE"] = "Raid loot · %s"
L["CLICK_SPLIT_STACK"] = "Click to take these %s off the stack."
L["MERGED_BAG_SLOTS"] = "Merged: %s bag slots"
L["PINNED_TOOLTIP"] = "Pinned · Alt-click to unpin"
L["FREE_SUMMARY"] = "%d free"
L["OFFLINE_BANK_NOTE"] = "Offline copy · visit a bank to use it"
L["KEEP_RAID_LOOT"] = "Keep raid loot"
L["KEEP_RAID_LOOT_DESC"] = "Treat everything looted in this raid as your own items."
L["STACK_TO_BANK"] = "Stack to bank"
L["STACK_TO_BANK_DESC"] = "Moves stackable items you already keep in the bank onto their bank stacks. Pinned items and raid loot stay in your bags."
L["OPTIONS_TIP"] = "Options"
L["SHOW_BAG_SLOTS"] = "Show bag slots"
L["BANK_OFFLINE_TIP"] = "Bank (works offline)"
L["SEND_MATS_TO_BANK"] = "Send mats to bank"
L["SEND_MATS_DESC"] = "Trade goods, dusts and gems go to the bank, onto their stacks first. Pinned items stay."
L["OPEN_BANK_FIRST"] = "Open the bank first."
L["DRAG_BAG_SWAP"] = "Drag a bag here to swap it."

-- ========================================================
-- Categories & Sections (Layout.lua)
-- ========================================================
L["Pinned"] = "Pinned"
L["Consumables"] = "Consumables"
L["Raid loot"] = "Raid loot"
L["[HR] Reserved"] = "[HR] Reserved"
L["Enchanting"] = "Enchanting"
L["Trade goods"] = "Trade goods"
L["Quest"] = "Quest"
L["Other"] = "Other"
L["Junk"] = "Junk"
L["Gear"] = "Gear"
L["Free"] = "Free"
L["SET_HEADER"] = "Set: %s"

-- Sub-categories (Materials)
L["Gems"] = "Gems"
L["Ore & bars"] = "Ore & bars"
L["Herbs"] = "Herbs"
L["Cloth"] = "Cloth"
L["Leather"] = "Leather"
L["Cooking"] = "Cooking"
L["Elemental"] = "Elemental"
L["Engineering"] = "Engineering"
L["Recipes"] = "Recipes"
L["Other mats"] = "Other mats"

-- ========================================================
-- Options Menu (Options.lua)
-- ========================================================
L["OPT_TITLE"] = "RatStash settings"
L["SEC_LAYOUT"] = "Layout"
L["AUTO_SORT"] = "Auto sort"
L["AUTO_SORT_DESC"] = "Fixed order. Off: items show where they really are, like Bagnon."
L["BAGS_LAYOUT"] = "Bags layout"
L["BAGS_LAYOUT_DESC"] = "One grid, a group per gear set plus one grid, or a block per kind."
L["BANK_LAYOUT"] = "Bank layout"
L["BANK_LAYOUT_DESC"] = "Same choices, for the bank window."
L["PINNED_ITEMS"] = "Pinned items"
L["PINNED_ITEMS_DESC"] = "Alt-click any item to pin or unpin it."
L["EMPTY_SLOTS"] = "Empty slots"
L["EMPTY_SLOTS_DESC"] = "One slot with the free count (drop items on it), or every empty slot."

L["ONE_GRID"] = "One grid"
L["GRID_SETS"] = "Grid + sets"
L["GROUPS"] = "Groups"
L["AT_THE_TOP"] = "At the top"
L["AT_THE_BOTTOM"] = "At the bottom"
L["ONE_SLOT"] = "One slot"
L["EVERY_SLOT"] = "Every slot"

L["SEC_SIZE_LOOK"] = "Size & look"
L["BAGS_COLUMNS"] = "Bags columns"
L["BAGS_COLUMNS_DESC"] = "Items per row in the bags window."
L["BANK_COLUMNS"] = "Bank columns"
L["BANK_COLUMNS_DESC"] = "Items per row in the bank window."
L["SCALE"] = "Scale"
L["SCALE_DESC"] = "Size of both windows."
L["BG_ART"] = "Background art"
L["BG_ART_DESC"] = "The stash picture behind the items. Off: plain dark."
L["ART_STRENGTH"] = "Art strength"
L["ART_STRENGTH_DESC"] = "How much the picture shows through."

L["SEC_ITEMS"] = "Items"
L["SHOW_ILVL"] = "Show item level"
L["SHOW_ILVL_DESC"] = "Gear shows its item level in the quality color."
L["SHOW_BOE"] = "Show BoE tag"
L["SHOW_BOE_DESC"] = "Bind-on-equip gear gets a gold BoE tag."
L["ML_GROUP"] = "Raid loot group as master looter"
L["ML_GROUP_DESC"] = "While you are master looter, raid loot gets its own group."

L["SEC_VIRTUAL_STACKS"] = "Virtual stacks"
L["MERGE_UNSTACKABLE"] = "Merge unstackable items"
L["MERGE_UNSTACKABLE_DESC"] = "Identical items that can't stack show as one slot."
L["MERGE_STACKABLE"] = "Merge stackable items"
L["MERGE_STACKABLE_DESC"] = "Full stacks of the same item show as one slot."
L["MERGE_INCOMPLETE"] = "... including incomplete stacks"
L["MERGE_INCOMPLETE_DESC"] = "Partial stacks join the merged slot too."

-- Chat / System (Core.lua)
L["BANK_OFFLINE_NOTICE"] = "Visit a bank once so RatStash can show it offline."
L["SENT_MATS_REPORT"] = "Sent %s of materials to the bank."
L["STACKED_REPORT"] = "Stacked %s into the bank."
L["NO_MATS_OR_FULL"] = "No materials to send, or the bank is full."
L["STACK_SINGLE"] = " stack"
L["STACK_MULTI"] = " stacks"
