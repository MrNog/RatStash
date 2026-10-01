local ADDON, ns = ...
local L = ns.L

-- Okanvil's look (flat panels, 1px hairlines, gold accent on neutral dark), copied so RatStash
-- matches it without needing Okanvil installed. Values are the same tokens as Okanvil.Colors.
local FLAT = [[Interface\ChatFrame\ChatFrameBackground]]
ns.FLAT = FLAT

local C = {
	accent     = { 0.75, 0.58, 0.23 },
	accentHi   = { 0.88, 0.72, 0.38 },
	accentText = { 1.0, 0.82, 0.0 },
	panel      = { 0.150, 0.157, 0.176 },
	panelD     = { 0.078, 0.082, 0.090 },
	panelHi    = { 0.180, 0.188, 0.212 },
	surface    = { 0.125, 0.133, 0.145 },
	border     = { 0.184, 0.192, 0.216 },
	borderHi   = { 0.34, 0.30, 0.18 },
	text       = { 0.863, 0.867, 0.871 },
	textDim    = { 0.541, 0.553, 0.576 },
	ok         = { 0.486, 0.988, 0.541 },
	danger     = { 0.85, 0.30, 0.32 },
	dark       = { 0.078, 0.082, 0.090 },
}
ns.C = C

local function rgb(t, a) return t[1], t[2], t[3], a or 1 end
ns.rgb = rgb

function ns.Font(fs, size, flags)
	fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

function ns.Skin(frame, fill, alpha)
	frame:SetBackdrop({
		bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	frame:SetBackdropColor(rgb(fill or C.panelD, alpha or 0.95))
	frame:SetBackdropBorderColor(rgb(C.border))
	return frame
end

-- a 1px horizontal hairline
function ns.Rule(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(FLAT)
	t:SetVertexColor(rgb(C.border))
	t:SetHeight(1)
	return t
end

local function HoverBorder(b)
	b:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(rgb(C.borderHi)) end)
	b:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(rgb(self.edge or C.border)) end)
end

-- flat text button; "gold" = the filled accent style used for the one main action
function ns.FlatButton(parent, text, width, height, gold)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width); b:SetHeight(height or 20)
	ns.Skin(b, gold and C.accent or C.surface, 1)
	if gold then b.edge = C.accent; b:SetBackdropBorderColor(rgb(C.accent)) end
	local fs = ns.Font(b:CreateFontString(nil, "OVERLAY"), 11)
	fs:SetPoint("CENTER")
	fs:SetText(text)
	if gold then fs:SetTextColor(rgb(C.dark)); fs:SetShadowOffset(0, 0) else fs:SetTextColor(rgb(C.text)) end
	b.text = fs
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(FLAT)
	hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1)
	hl:SetVertexColor(1, 1, 1, gold and 0.15 or 0.06)
	HoverBorder(b)
	return b
end

-- flat square button with an icon inside a hairline frame
function ns.FlatIconButton(parent, texture, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(size); b:SetHeight(size)
	ns.Skin(b, C.surface, 1)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 2, -2); icon:SetPoint("BOTTOMRIGHT", -2, 2)
	icon:SetTexture(texture)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(FLAT)
	hl:SetAllPoints(icon)
	hl:SetVertexColor(1, 1, 1, 0.12)
	HoverBorder(b)
	return b
end

-- flat edit box; the gold border shows while it has focus
function ns.FlatInput(parent, name, width, height)
	local e = CreateFrame("EditBox", name, parent)
	e:SetWidth(width); e:SetHeight(height)
	e:SetAutoFocus(false)
	e:SetTextInsets(6, 6, 0, 0)
	ns.Font(e, 12)
	e:SetTextColor(rgb(C.text))
	ns.Skin(e, C.panelD, 1)
	e:HookScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(rgb(C.accent)) end)
	e:HookScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(rgb(C.border)) end)
	return e
end
