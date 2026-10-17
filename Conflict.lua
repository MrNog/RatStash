local ADDON, ns = ...

-- Two bag addons both open on B. After login, if another one is running, the
-- player picks one: the other is turned off and the UI reloads. No way to
-- dismiss it, so the choice can't be skipped.

local OTHERS = { "AdiBags", "Bagnon", "Combuctor", "ArkInventory", "OneBag3", "BaudBag", "Baggins", "TBag",
	"cargBags_Nivaya" }

local function elvBags()
	local E = ElvUI and ElvUI[1]
	return E and E.private and E.private.bags and E.private.bags.enable and E
end

local function rivals()
	local names = {}
	if elvBags() then names[#names + 1] = "ElvUI bags" end
	for _, a in ipairs(OTHERS) do
		if IsAddOnLoaded(a) then names[#names + 1] = a end
	end
	return names
end

local function keepRatStash()
	local E = elvBags()
	if E then E.private.bags.enable = false end
	for _, a in ipairs(OTHERS) do
		if IsAddOnLoaded(a) then DisableAddOn(a) end
	end
	ReloadUI()
end

local function keepOther()
	DisableAddOn(ADDON)
	ReloadUI()
end

StaticPopupDialogs.RATSTASH_BAG_CONFLICT = {
	text = "|cffe8c35aRatStash|r and %s are both on, and both open on B.\n\nPick one. The other is turned off and the UI reloads.",
	button1 = "RatStash",
	button2 = "Keep the other",
	OnAccept = keepRatStash,
	OnCancel = function(_, _, reason)
		if reason == "clicked" then keepOther() end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = false,
	showAlert = 1,
}

local function ask()
	local names = rivals()
	if #names == 0 then return end
	if InCombatLockdown() then
		ns.On("PLAYER_REGEN_ENABLED", function() if not StaticPopup_Visible("RATSTASH_BAG_CONFLICT") then ask() end end)
		return
	end
	StaticPopup_Show("RATSTASH_BAG_CONFLICT", table.concat(names, ", "))
end

-- ElvUI reads its settings during login: look a few seconds after
ns.On("PLAYER_LOGIN", function()
	local t, f = 0, CreateFrame("Frame")
	f:SetScript("OnUpdate", function(self, elapsed)
		t = t + elapsed
		if t < 3 then return end
		self:SetScript("OnUpdate", nil)
		ask()
	end)
end)
