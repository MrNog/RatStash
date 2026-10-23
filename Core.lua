local ADDON, ns = ...

ns.BAGS = { 0, 1, 2, 3, 4 }
ns.BANK = { -1, 5, 6, 7, 8, 9, 10, 11 }

-- layout: "grid" = one grid, "sets" = set groups + one grid, "groups" = AdiBags-style blocks
ns.DEFAULTS = {
	layout = { bags = "sets", bank = "groups" },
	columns = { bags = 10, bank = 14 },
	scale = 1,
	bgOn = true,
	bgArt = 0.5,
	freeMode = "stack",
	mlGroup = true,
	sort = true,
	pinAt = "top",
	showIlvl = true,
	showBoE = true,
	newGroup = false,  -- items that just arrived get their own group for a while (opt-in)
	sellJunk = true,   -- greys are sold when a vendor opens
	vs = { others = true, stack = true, incomplete = false },
	pins = { [6948] = true }, -- Hearthstone; unpinning stores false so it stays unpinned
	pos = {},
}

ns.CHAR_DEFAULTS = {
	bank = nil,
	fresh = { stack = {}, slot = {} },
}

local function copyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			copyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffe8c35aRatStash|r: " .. tostring(msg))
end

-- event fan-out: several files can listen to the same event
local handlers = {}
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do fn(...) end
end)
function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		ev:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

-- coalesce bursts of BAG_UPDATE into one scan + layout per window, a tenth of a second later
local dirty = {}
local driver = CreateFrame("Frame")
local wait, retryAt = 0, nil
driver:SetScript("OnUpdate", function(_, elapsed)
	wait = wait + elapsed
	if wait < 0.1 then return end
	wait = 0
	if retryAt and GetTime() >= retryAt then
		retryAt = nil
		dirty.bags, dirty.bank = true, true
	end
	if dirty.bags then
		dirty.bags = nil
		ns.ScanBags()
		if ns.windows.bags then ns.windows.bags:Update() end
	end
	if dirty.bank then
		dirty.bank = nil
		if ns.atBank then ns.ScanBank() end
		if ns.windows.bank then ns.windows.bank:Update() end
	end
	-- GetItemInfo can be empty for items the client hasn't cached yet; look again shortly
	if ns.missingInfo and not retryAt then
		ns.missingInfo = nil
		retryAt = GetTime() + 1
	end
end)

function ns.Dirty(kind)
	if kind then dirty[kind] = true else dirty.bags, dirty.bank = true, true end
end

ns.windows = {}

ns.On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	ns.firstRun = RatStashDB == nil
	RatStashDB = RatStashDB or {}
	RatStashCharDB = RatStashCharDB or {}
	copyDefaults(ns.DEFAULTS, RatStashDB)
	copyDefaults(ns.CHAR_DEFAULTS, RatStashCharDB)
	ns.db = RatStashDB
	ns.char = RatStashCharDB
end)

ns.On("PLAYER_LOGIN", function()
	ns.windows.bags = ns.CreateWindow("bags")
	ns.windows.bank = ns.CreateWindow("bank")
	ns.HookBlizzardBags()
	ns.CreateOptions()
	ns.Dirty()
	-- a first install opens the settings once, so the layout is chosen, not found
	if ns.firstRun then
		local t, f = 0, CreateFrame("Frame")
		f:SetScript("OnUpdate", function(self, e)
			t = t + e
			if t < 5 then return end
			self:SetScript("OnUpdate", nil)
			if InCombatLockdown() or StaticPopup_Visible("RATSTASH_BAG_CONFLICT") then return end
			ns.Print("welcome -- pick your layout here. /rst options opens it again.")
			ns.OpenOptions()
		end)
	end
end)

--------------------------------------------------------------------------------
-- Blizzard bag hooks: every way the game opens bags now opens our windows
--------------------------------------------------------------------------------

function ns.ShowBags() ns.windows.bags:Show() end
function ns.HideBags() ns.windows.bags:Hide() end
function ns.ToggleBags()
	local w = ns.windows.bags
	if w:IsShown() then w:Hide() else w:Show() end
end

function ns.ToggleBank()
	local w = ns.windows.bank
	if w:IsShown() then
		w:Hide()
	elseif ns.atBank or ns.char.bank then
		w:Show()
	else
		ns.Print("Visit a bank once so RatStash can show it offline.")
	end
end

function ns.HookBlizzardBags()
	OpenBackpack = function() ns.ShowBags() end
	ToggleBackpack = function() ns.ToggleBags() end

	local origToggleBag = ToggleBag
	ToggleBag = function(id)
		if id == KEYRING_CONTAINER then return origToggleBag(id) end
		if id and id > NUM_BAG_SLOTS then ns.ToggleBank() else ns.ToggleBags() end
	end

	OpenAllBags = function(force)
		if force then ns.ShowBags() else ns.ToggleBags() end
	end
	hooksecurefunc("CloseAllBags", ns.HideBags)
	hooksecurefunc("CloseBackpack", ns.HideBags)

	-- the bank opens our window instead of Blizzard's
	BankFrame:UnregisterEvent("BANKFRAME_OPENED")
	BankFrame:UnregisterEvent("BANKFRAME_CLOSED")
end

ns.On("BANKFRAME_OPENED", function()
	ns.atBank = true
	ns.ScanBank()
	ns.windows.bank:Show()
	ns.ShowBags()
	ns.Dirty()
end)

ns.On("BANKFRAME_CLOSED", function()
	ns.atBank = false
	ns.windows.bank:Hide()
	ns.HideBags()
	ns.Dirty()
end)

--------------------------------------------------------------------------------
-- events that change what is drawn
--------------------------------------------------------------------------------

ns.On("BAG_UPDATE", function(bag)
	if bag and bag > NUM_BAG_SLOTS then ns.Dirty("bank")
	elseif bag and bag >= 0 then ns.Dirty("bags") end
end)
ns.On("PLAYERBANKSLOTS_CHANGED", function() ns.Dirty("bank") end)
ns.On("PLAYERBANKBAGSLOTS_CHANGED", function() ns.Dirty("bank") end)
ns.On("ITEM_LOCK_CHANGED", function() ns.Dirty() end)
ns.On("BAG_UPDATE_COOLDOWN", function() ns.Dirty("bags") end)
ns.On("EQUIPMENT_SETS_CHANGED", function() ns.Dirty() end)
ns.On("PLAYER_EQUIPMENT_CHANGED", function() ns.WipeTooltipCache(); ns.Dirty() end)
ns.On("PARTY_LOOT_METHOD_CHANGED", function() ns.Dirty("bags") end)
ns.On("RAID_ROSTER_UPDATE", function() ns.Dirty("bags") end)

-- A vendor opens: every grey with a sell price goes, one a tenth of a second
-- (a burst of sells can be dropped by the server), and one line says what it made.
do
	local queue, total, sold, wait = {}, 0, 0, 0
	local seller = CreateFrame("Frame")
	seller:Hide()
	seller:SetScript("OnUpdate", function(self, e)
		wait = wait - e
		if wait > 0 then return end
		wait = 0.1
		local job = table.remove(queue, 1)
		if not job or not MerchantFrame:IsShown() then
			self:Hide()
			if sold > 0 then
				ns.Print(("sold %d grey item%s for %s."):format(sold, sold == 1 and "" or "s",
					GetCoinTextureString and GetCoinTextureString(total) or (total .. "c")))
			end
			return
		end
		local _, count, locked, quality, _, _, link = GetContainerItemInfo(job.bag, job.slot)
		if link and quality == 0 and not locked then
			UseContainerItem(job.bag, job.slot)
			sold, total = sold + 1, total + job.price * (count or 1)
		end
	end)
	ns.On("MERCHANT_SHOW", function()
		if not ns.db.sellJunk then return end
		wipe(queue); total, sold, wait = 0, 0, 0
		for _, bag in ipairs(ns.BAGS) do
			for slot = 1, (GetContainerNumSlots(bag) or 0) do
				local _, _, locked, quality, _, _, link = GetContainerItemInfo(bag, slot)
				local price = link and select(11, GetItemInfo(link)) or 0
				if link and quality == 0 and not locked and price > 0 then
					queue[#queue + 1] = { bag = bag, slot = slot, price = price }
				end
			end
		end
		if #queue > 0 then seller:Show() end
	end)
end

-- virtual stacks split apart while one of these windows is open (the bank counts too, see ns.IsTrading)
local tradeOpen = {}
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED",
	"AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" }) do
	local base, opening = e:match("^(.-)_(%u+)$")
	opening = (opening == "SHOW")
	ns.On(e, function()
		tradeOpen[base] = opening or nil
		ns.Dirty()
	end)
end
function ns.IsTrading()
	return ns.atBank or next(tradeOpen) ~= nil
end

-- an award is announced in raid chat; a win of loot already in your bags moves
-- no item, so look again then
for _, e in ipairs({ "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" }) do
	ns.On(e, function()
		if ns.HasRaidLoot() then ns.Dirty("bags") end
	end)
end

-- a focused search box eats movement keys: drop focus on combat and on any world click
ns.On("PLAYER_REGEN_DISABLED", function()
	for _, w in pairs(ns.windows) do w.search:ClearFocus() end
end)
WorldFrame:HookScript("OnMouseDown", function()
	for _, w in pairs(ns.windows) do w.search:ClearFocus() end
end)

--------------------------------------------------------------------------------
-- slash
--------------------------------------------------------------------------------

SLASH_RATSTASH1 = "/ratstash"
SLASH_RATSTASH2 = "/rst"
SlashCmdList.RATSTASH = function(msg)
	msg = (msg or ""):lower():trim()
	if msg == "bank" then
		ns.ToggleBank()
	elseif msg == "options" or msg == "config" then
		ns.OpenOptions()
	elseif msg == "keep" then
		ns.KeepRaidLoot()
	else
		ns.ToggleBags()
	end
end
