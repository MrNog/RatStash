local ADDON, ns = ...

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


-- retail's search field: a dark field with a bronze edge and a magnifying glass on the left.
-- The edge is a three-slice whose caps are a fifth of the art's height wide; the edge brightens
-- while the field has focus.
local SEARCH_U = { left = { 0.03125, 0.15625 }, middle = { 0.40625, 0.4375 }, right = { 0.21875, 0.34375 } }
local SEARCH_V = { 0.015625, 0.171875 }

function ns.SearchInput(parent, name, width, height)
	local e = CreateFrame("EditBox", name, parent)
	e:SetWidth(width); e:SetHeight(height)
	e:SetAutoFocus(false)
	e:SetTextInsets(20, 20, 0, 0)
	ns.Font(e, 12)
	e:SetTextColor(rgb(C.text))
	local pieces = {}
	for _, part in ipairs({ "left", "middle", "right" }) do
		local tex = e:CreateTexture(nil, "BACKGROUND")
		tex:SetTexture([[Interface\AddOns\RatStash\Media\UI\controls]])
		tex:SetTexCoord(SEARCH_U[part][1], SEARCH_U[part][2], SEARCH_V[1], SEARCH_V[2])
		pieces[part] = tex
	end
	local cap = height * 0.4
	pieces.left:SetPoint("TOPLEFT"); pieces.left:SetPoint("BOTTOMLEFT"); pieces.left:SetWidth(cap)
	pieces.right:SetPoint("TOPRIGHT"); pieces.right:SetPoint("BOTTOMRIGHT"); pieces.right:SetWidth(cap)
	pieces.middle:SetPoint("TOPLEFT", pieces.left, "TOPRIGHT")
	pieces.middle:SetPoint("BOTTOMRIGHT", pieces.right, "BOTTOMLEFT")
	local glass = e:CreateTexture(nil, "ARTWORK")
	glass:SetWidth(12); glass:SetHeight(12)
	glass:SetPoint("LEFT", 6, 0)
	glass:SetTexture([[Interface\AddOns\RatStash\Media\UI\controls]])
	glass:SetTexCoord(0.625, 0.8125, 0.203125, 0.296875)
	glass:SetVertexColor(0.6, 0.6, 0.6)
	local function lit(on)
		local shade = on and 1.25 or 1
		for _, tex in pairs(pieces) do tex:SetVertexColor(shade, shade, shade) end
		glass:SetVertexColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.6)
	end
	e:HookScript("OnEditFocusGained", function() lit(true) end)
	e:HookScript("OnEditFocusLost", function() lit(false) end)
	return e
end

-- retail's round clear button for a search field, shown by the caller while there is text
function ns.SearchClearButton(search)
	local b = CreateFrame("Button", nil, search)
	b:SetWidth(14); b:SetHeight(14)
	b:SetPoint("RIGHT", -5, 0)
	b:SetNormalTexture([[Interface\AddOns\RatStash\Media\UI\controls]])
	b:GetNormalTexture():SetTexCoord(0.03125, 0.1875, 0.3515625, 0.4296875)
	b:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7)
	b:SetScript("OnEnter", function(self) self:GetNormalTexture():SetVertexColor(1, 1, 1) end)
	b:SetScript("OnLeave", function(self) self:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7) end)
	return b
end

--------------------------------------------------------------------------------
-- retail-style pieces shared with RatTree: the red close X, buttons drawn to match it,
-- icon buttons in a gold talent frame, and the round medallion over a window's corner
--------------------------------------------------------------------------------

local UI = [[Interface\AddOns\RatStash\Media\UI\]]

-- 3.3.5a's IsEnabled returns 1 or 0, and 0 is truthy in Lua.
local function isDisabled(b)
	local enabled = b:IsEnabled()
	return not enabled or enabled == 0
end

-- the close button: retail's red X, all four states from one sheet
function ns.CloseButton(parent)
	local b = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
	b:SetWidth(24); b:SetHeight(24)
	-- 3.3.5a's close button has no disabled texture, so each state is set before it is cut
	local function dress(state, l, r, t, bottom, blend)
		b["Set" .. state .. "Texture"](b, UI .. "redbutton2x")
		local tex = b["Get" .. state .. "Texture"](b)
		tex:SetTexCoord(l, r, t, bottom)
		if blend then tex:SetBlendMode(blend) end
	end
	dress("Normal", 39 / 256, 75 / 256, 1 / 128, 39 / 128)
	dress("Pushed", 39 / 256, 75 / 256, 81 / 128, 119 / 128)
	dress("Disabled", 39 / 256, 75 / 256, 41 / 128, 79 / 128)
	dress("Highlight", 115 / 256, 151 / 256, 1 / 128, 39 / 128, "ADD")
	return b
end

-- a text button drawn to match the X: silver octagon frame, thin black line, red body. A three-slice
-- whose caps keep the frame's corners at any width.
local PLATE_W, PLATE_H, CAP_W = 128, 64, 32
local PLATE_U = {
	left = { 0, CAP_W / PLATE_W },
	middle = { CAP_W / PLATE_W, (PLATE_W - CAP_W) / PLATE_W },
	right = { (PLATE_W - CAP_W) / PLATE_W, 1 },
}

local function threeSlice(b, layer)
	local pieces = {}
	for _, part in ipairs({ "left", "middle", "right" }) do
		local tex = b:CreateTexture(nil, layer)
		tex:SetTexture(UI .. "redplate")
		tex:SetTexCoord(PLATE_U[part][1], PLATE_U[part][2], 0, 1)
		pieces[part] = tex
	end
	pieces.left:SetPoint("TOPLEFT"); pieces.left:SetPoint("BOTTOMLEFT")
	pieces.right:SetPoint("TOPRIGHT"); pieces.right:SetPoint("BOTTOMRIGHT")
	pieces.middle:SetPoint("TOPLEFT", pieces.left, "TOPRIGHT")
	pieces.middle:SetPoint("BOTTOMRIGHT", pieces.right, "BOTTOMLEFT")
	return pieces
end

local function plateResize(b)
	local cap = CAP_W * (b:GetHeight() or PLATE_H) / PLATE_H
	for _, pieces in ipairs({ b.plate, b.glow }) do
		pieces.left:SetWidth(cap)
		pieces.right:SetWidth(cap)
	end
end

-- pressed reads darker, disabled grey
local function platePaint(b, pressed)
	local off = isDisabled(b)
	local shade = off and 0.6 or (pressed and 0.75 or 1)
	for _, tex in pairs(b.plate) do
		tex:SetDesaturated(off)
		tex:SetVertexColor(shade, shade, shade)
	end
end

function ns.RedButton(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width); b:SetHeight(height or 22)
	b.plate = threeSlice(b, "BACKGROUND")
	b.glow = threeSlice(b, "HIGHLIGHT")
	for _, tex in pairs(b.glow) do
		tex:SetBlendMode("ADD")
		tex:SetAlpha(0.25)
	end
	local fs = b:CreateFontString(nil, "OVERLAY")
	b:SetFontString(fs)
	b:SetNormalFontObject(GameFontNormalSmall)
	b:SetHighlightFontObject(GameFontHighlightSmall)
	b:SetDisabledFontObject(GameFontDisableSmall)
	b:SetPushedTextOffset(1, -1)
	b:SetText(text or "")
	b.text = fs
	b:HookScript("OnEnable", function(self) platePaint(self) end)
	b:HookScript("OnDisable", function(self) platePaint(self) end)
	b:HookScript("OnMouseDown", function(self) platePaint(self, not isDisabled(self)) end)
	b:HookScript("OnMouseUp", function(self) platePaint(self) end)
	b:HookScript("OnLeave", function(self) platePaint(self) end)
	b:HookScript("OnSizeChanged", plateResize)
	plateResize(b)
	platePaint(b)
	return b
end

-- an icon in the gold octagon frame of a talent icon. The frame's opening is 75% of it, so the icon
-- is drawn at 80%: its edge tucks under the metal and its corners stay inside the cut ones.
local FRAME_GOLD = { 0, 80 / 256, 0, 80 / 128 }
local FRAME_GREY = { 128 / 256, 208 / 256, 0, 80 / 128 }

function ns.FramedIconButton(parent, texture, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(size); b:SetHeight(size)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(size * 0.8); icon:SetHeight(size * 0.8)
	icon:SetPoint("CENTER")
	icon:SetTexture(texture)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local frame = b:CreateTexture(nil, "OVERLAY")
	frame:SetAllPoints(b)
	frame:SetTexture(UI .. "iconframes")
	frame:SetTexCoord(unpack(FRAME_GOLD))
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	hl:SetBlendMode("ADD")
	hl:SetAllPoints(icon)
	b.icon, b.frame = icon, frame
	return b
end

-- a framed icon button that cannot act right now: grey frame, grey icon
function ns.SetFramedIconUsable(b, usable)
	b.frame:SetTexCoord(unpack(usable and FRAME_GOLD or FRAME_GREY))
	b.icon:SetDesaturated(not usable)
	b.icon:SetVertexColor(usable and 1 or 0.6, usable and 1 or 0.6, usable and 1 or 0.6)
end

-- RatStash's app icon over a window's top-left corner: the stash rat, cut round, inside a gold ring.
-- The picture is 92% of the ring, so no sliver of it shows past the ring's edge.
function ns.Medallion(parent, size)
	size = size or 60
	local m = CreateFrame("Frame", nil, parent)
	m:SetWidth(size); m:SetHeight(size)
	m:SetPoint("CENTER", parent, "TOPLEFT", 10, -8)
	m:SetFrameLevel(parent:GetFrameLevel() + 10)
	local icon = m:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(size * 0.92); icon:SetHeight(size * 0.92)
	icon:SetPoint("CENTER")
	icon:SetTexture(UI .. "medallion")
	local ring = m:CreateTexture(nil, "OVERLAY")
	ring:SetAllPoints(m)
	ring:SetTexture(UI .. "ring")
	ring:SetVertexColor(0.886, 0.722, 0.263)
	return m
end

-- Cut corners, as Ratree's window. 3.3.5a cannot mask a frame, so Media\UI\chamfer (a white
-- cut-corner fill and a cut-corner line) is sliced nine ways behind the window and tinted.
ns.WIN_FILL = { 0.043, 0.043, 0.047 }
ns.WIN_EDGE = { 0.235, 0.204, 0.157 }
-- content sits INSET in from the edge; a COVER-sized triangle in the fill colour cuts the
-- corners of square art inside the window parallel to the cut
ns.INSET, ns.COVER = 6, 6.5
local CH_U = { 0, 24 / 128, 40 / 128, 64 / 128 }
local CORNER = 12

local function ninePieces(host, frame, layer, ox, color)
	local xs = { { "LEFT", 0 }, { "LEFT", CORNER }, { "RIGHT", -CORNER }, { "RIGHT", 0 } }
	local ys = { { "TOP", 0 }, { "TOP", -CORNER }, { "BOTTOM", CORNER }, { "BOTTOM", 0 } }
	for row = 1, 3 do
		for col = 1, 3 do
			local tex = host:CreateTexture(nil, layer)
			tex:SetTexture(UI .. "chamfer")
			tex:SetTexCoord(ox + CH_U[col], ox + CH_U[col + 1], CH_U[row], CH_U[row + 1])
			local x1, y1, x2, y2 = xs[col], ys[row], xs[col + 1], ys[row + 1]
			tex:SetPoint("TOPLEFT", frame, y1[1] .. x1[1], x1[2], y1[2])
			tex:SetPoint("BOTTOMRIGHT", frame, y2[1] .. x2[1], x2[2], y2[2])
			tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
		end
	end
end

-- A window's cut-corner fill and edge. The line is drawn on its own frame above the art and
-- the title bar (children draw over their parent), below the medallion.
function ns.SkinWindow(f)
	f:SetBackdrop(nil)
	ninePieces(f, f, "BACKGROUND", 0, ns.WIN_FILL)
	local edge = CreateFrame("Frame", nil, f)
	edge:SetAllPoints(f)
	edge:SetFrameLevel(f:GetFrameLevel() + 8)
	ninePieces(edge, f, "OVERLAY", 0.5, ns.WIN_EDGE)
	return f
end

local COVER_TC = { TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
	BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 } }
function ns.CoverCorners(host, region, corners)
	local F = ns.WIN_FILL
	for _, c in ipairs(corners or { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
		local tex = host:CreateTexture(nil, "OVERLAY")
		tex:SetTexture(UI .. "cutcover")
		tex:SetTexCoord(unpack(COVER_TC[c]))
		tex:SetWidth(ns.COVER); tex:SetHeight(ns.COVER)
		tex:SetPoint(c, region, c, 0, 0)
		tex:SetVertexColor(F[1], F[2], F[3], 1)
	end
end

-- the thin title bar along a window's top, as Ratree's: a dark gradient inside the cut frame, its
-- top corners cut, a hairline under it, the title centred in small gold, and the red X at its
-- right end. Returns the bar and the title.
function ns.TitleBar(parent, height)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(height)
	bar:SetPoint("TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", 0, 0)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(FLAT)
	bg:SetGradientAlpha("VERTICAL", 0.082, 0.075, 0.059, 1, 0.141, 0.125, 0.102, 1)
	bg:SetPoint("TOPLEFT", ns.INSET, -ns.INSET)
	bg:SetPoint("BOTTOMRIGHT", -ns.INSET, 0)
	ns.CoverCorners(bar, bg, { "TOPLEFT", "TOPRIGHT" })
	local rule = bar:CreateTexture(nil, "BORDER")
	rule:SetTexture(FLAT)
	rule:SetVertexColor(ns.WIN_EDGE[1], ns.WIN_EDGE[2], ns.WIN_EDGE[3])
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT")
	local title = ns.Font(bar:CreateFontString(nil, "OVERLAY"), 12)
	title:SetTextColor(0.878, 0.761, 0.478)
	title:SetPoint("CENTER", bg, "CENTER")
	local close = ns.CloseButton(bar)
	close:SetWidth(20); close:SetHeight(20)   -- clear of the bar's top and its hairline
	close:SetPoint("RIGHT", bg, "RIGHT", -3, 0)
	close:SetScript("OnClick", function() parent:Hide() end)
	bar.close = close
	return bar, title
end

-- retail's dropdown: a slim dark text holder with the current choice in white, and a small square
-- button with a yellow down arrow at its right end. A click opens a dark list under it: rows light up
-- on hover and the current choice carries a tick.
local DROP = [[Interface\AddOns\RatStash\Media\UI\dropdown]]

-- The text holder is cut 16/14/16/18 px and drawn at 0.8 (3.3.5a has no slice-margin API).
local HOLDER_U = { 0, 0.125, 0.296875, 0.421875 }
local HOLDER_V = { 0.625, 0.6796875, 0.71484375, 0.78515625 }
local EDGE_X = { { "LEFT", -6.4 }, { "LEFT", 6.4 }, { "RIGHT", -6.4 }, { "RIGHT", 6.4 } }
local EDGE_Y = { { "TOP", 5.6 }, { "TOP", -5.6 }, { "BOTTOM", 7.2 }, { "BOTTOM", -7.2 } }
-- the arrow button, 27x27, in four states
local ARROW = {
	normal = { 0, 27 / 128, 202 / 256, 229 / 256 },
	hover = { 28 / 128, 55 / 128, 202 / 256, 229 / 256 },
	pressed = { 56 / 128, 83 / 128, 202 / 256, 229 / 256 },
	open = { 0, 27 / 128, 229 / 256, 1 },
}

local LIST_BACKDROP = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 5, right = 5, top = 5, bottom = 5 },
}
local ROW_H, INSET_X, INSET_Y, CHECK_W = 21, 12, 10, 16

local openList -- the one list open at a time

local function closeList()
	if openList then openList:Hide() end
	openList = nil
end
ns.CloseDropdowns = closeList

local function dressHolder(b)
	for row = 1, 3 do
		for col = 1, 3 do
			local piece = b:CreateTexture(nil, "BACKGROUND")
			piece:SetTexture(DROP)
			piece:SetTexCoord(HOLDER_U[col], HOLDER_U[col + 1], HOLDER_V[row], HOLDER_V[row + 1])
			local x1, y1, x2, y2 = EDGE_X[col], EDGE_Y[row], EDGE_X[col + 1], EDGE_Y[row + 1]
			piece:SetPoint("TOPLEFT", b, y1[1] .. x1[1], x1[2], y1[2])
			piece:SetPoint("BOTTOMRIGHT", b, y2[1] .. x2[1], x2[2], y2[2])
		end
	end
end

local function syncArrow(b)
	local state = (b.list:IsShown() and "open") or (b.pressed and "pressed") or (b.hovered and "hover") or "normal"
	b.arrow:SetTexCoord(unpack(ARROW[state]))
end

-- values: { { key, label }, ... }; get() returns the current key, set(key) chooses one
function ns.Dropdown(parent, width, values, get, set)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width); b:SetHeight(24)
	dressHolder(b)
	local arrow = b:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture(DROP)
	arrow:SetWidth(20); arrow:SetHeight(20)
	-- centred in the 24px holder, inside its right edge
	arrow:SetPoint("RIGHT", b, "RIGHT", -2, 0)
	b.arrow = arrow
	local label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetJustifyH("LEFT")
	label:SetPoint("LEFT", b, "LEFT", 8, 0)
	label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)

	-- the list: a dark tooltip box under the holder, one row per value
	local list = CreateFrame("Frame", nil, b)
	list:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -2, -2)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:EnableMouse(true)
	list:SetBackdrop(LIST_BACKDROP)
	list:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	list:SetBackdropBorderColor(0.5, 0.5, 0.5)
	-- the tooltip background is itself see-through; a solid fill keeps what is under the list hidden
	local fill = list:CreateTexture(nil, "BACKGROUND")
	fill:SetTexture(FLAT)
	fill:SetVertexColor(0.04, 0.04, 0.045, 1)
	fill:SetPoint("TOPLEFT", 4, -4)
	fill:SetPoint("BOTTOMRIGHT", -4, 4)
	list:Hide()
	b.list = list
	local rows, widest = {}, 0
	for i, pair in ipairs(values) do
		local row = CreateFrame("Button", nil, list)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", list, "TOPLEFT", INSET_X, -INSET_Y - (i - 1) * ROW_H)
		row:SetPoint("RIGHT", list, "RIGHT", -INSET_X, 0)
		local glow = row:CreateTexture(nil, "HIGHLIGHT")
		glow:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
		glow:SetBlendMode("ADD")
		glow:SetAllPoints(row)
		row.check = row:CreateTexture(nil, "ARTWORK")
		row.check:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
		row.check:SetWidth(CHECK_W); row.check:SetHeight(CHECK_W)
		row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
		local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		text:SetPoint("LEFT", row, "LEFT", CHECK_W + 2, 0)
		text:SetText(pair[2])
		widest = math.max(widest, text:GetStringWidth())
		row:SetScript("OnClick", function()
			PlaySound("igMainMenuOptionCheckBoxOn")
			closeList()
			set(pair[1])
		end)
		row.key = pair[1]
		rows[i] = row
	end
	list:SetWidth(math.max(width + 4, widest + CHECK_W + 2 + INSET_X * 2 + 8))
	list:SetHeight(#values * ROW_H + INSET_Y * 2)
	list:SetScript("OnShow", function() syncArrow(b) end)
	list:SetScript("OnHide", function() syncArrow(b) end)

	b:SetScript("OnEnter", function(self) self.hovered = true; syncArrow(self) end)
	b:SetScript("OnLeave", function(self) self.hovered = false; syncArrow(self) end)
	b:SetScript("OnMouseDown", function(self) self.pressed = true; syncArrow(self) end)
	b:SetScript("OnMouseUp", function(self) self.pressed = false; syncArrow(self) end)
	b:SetScript("OnClick", function()
		if list:IsShown() then
			closeList()
			return
		end
		closeList()
		for _, row in ipairs(rows) do
			if row.key == get() then row.check:Show() else row.check:Hide() end
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
		list:Show()
		openList = list
	end)
	b:SetScript("OnHide", closeList)

	-- shows the current choice; the caller runs it after every change
	function b:Refresh()
		for _, pair in ipairs(values) do
			if pair[1] == get() then label:SetText(pair[2]) end
		end
	end
	syncArrow(b)
	return b
end

-- retail's options checkbox: a dark rounded box with a bronze edge, and a yellow tick when on
local CHECK_BOX = { 0.5, 0.734375, 0.015625, 0.12890625 }
local CHECK_MARK = { 0.03125, 0.265625, 0.203125, 0.31640625 }

-- returns the box texture and the tick, both size x size, the tick hidden
function ns.CheckBox(parent, size)
	local box = parent:CreateTexture(nil, "ARTWORK")
	box:SetWidth(size); box:SetHeight(size)
	box:SetTexture(UI .. "controls")
	box:SetTexCoord(unpack(CHECK_BOX))
	local tick = parent:CreateTexture(nil, "OVERLAY")
	tick:SetAllPoints(box)
	tick:SetTexture(UI .. "controls")
	tick:SetTexCoord(unpack(CHECK_MARK))
	tick:Hide()
	return box, tick
end
