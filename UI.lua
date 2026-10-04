local _, CK = ...
local L = CK.L

-- Common panel (Claude Design spec, Controller Keyboard.dc.html): input bar,
-- suggestions, the input method's area, channel row, mouse buttons and help
-- band. Coordinates are in px from the panel's top-left corner (y goes down);
-- the width and the method area height come from the active input method.
local TEX = "Interface\\AddOns\\EasyController\\textures\\"
local AREA_Y = 92

local function rgb(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local C = {
    gold = { rgb("FFD100") },
    goldActive = { rgb("FFF1B8") },
    suggSel = { rgb("FFF0C8") },
    sugg = { rgb("C9B37E") },
    help = { rgb("D9D4CB") },
    winTop = { rgb("19160F") }, winBottom = { rgb("0F0D0A") },
    edge = { rgb("5A4D38") }, edgeOut = { rgb("050403") }, edgeIn = { rgb("241D15") },
    well = { rgb("080706") }, wellLine = { rgb("3D3326") },
    pill = { rgb("714E31") }, pillLine = { rgb("D8B27A") }, pillText = { rgb("FFF0C8") },
    btn = { rgb("E8D7A8") },
    btnHover = { rgb("FFE45C") },
    dark = { rgb("1A1206") },
    capsFill = { rgb("E0B400") },
    border = { rgb("8A7045") },
}

---------------------------------------------------------------------------
-- Helpers (shared with the input methods through CK.UIKit)
---------------------------------------------------------------------------
local function texture(parent, file, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if file then t:SetTexture(TEX .. file) end
    return t
end

-- Place `region` at panel-style coordinates inside `parent`
local function place(region, parent, x, y, w, h)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if w then region:SetSize(w, h) end
end

-- Every font string goes through here so the font can be changed live
local fontStrings = {}
local function text(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(CK:GetFontPath(), size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fontStrings[#fontStrings + 1] = { fs = fs, size = size }
    return fs
end

function CK:ApplyFont()
    local path = self:GetFontPath()
    for _, entry in ipairs(fontStrings) do
        entry.fs:SetFont(path, entry.size, "")
    end
    -- The suggestions' widths follow the font
    if self.frame then self:UpdateSuggestions() end
end

-- 9-slice: the `texCorner` px corners of a texW x texH texture are drawn at
-- `corner` px; edges and center stretch. Returns an object with :SetFile().
local function nineSlice(frame, file, texW, texH, texCorner, corner, layer)
    local u, v = texCorner / texW, texCorner / texH
    local cols = { { 0, u }, { u, 1 - u }, { 1 - u, 1 } }
    local rows = { { 0, v }, { v, 1 - v }, { 1 - v, 1 } }
    local parts = {}
    for r = 1, 3 do
        for c = 1, 3 do
            local t = texture(frame, nil, layer)
            t.coords = { cols[c][1], cols[c][2], rows[r][1], rows[r][2] }
            parts[#parts + 1] = t
        end
    end
    local tl, t, tr, l, m, r, bl, b, br = unpack(parts)
    tl:SetPoint("TOPLEFT"); tl:SetSize(corner, corner)
    tr:SetPoint("TOPRIGHT"); tr:SetSize(corner, corner)
    bl:SetPoint("BOTTOMLEFT"); bl:SetSize(corner, corner)
    br:SetPoint("BOTTOMRIGHT"); br:SetSize(corner, corner)
    t:SetPoint("TOPLEFT", tl, "TOPRIGHT"); t:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    b:SetPoint("TOPLEFT", bl, "TOPRIGHT"); b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); l:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    r:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); r:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    m:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); m:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")

    local slice = { parts = parts }
    function slice:SetFile(name)
        for _, p in ipairs(self.parts) do
            p:SetTexture(TEX .. name)
            p:SetTexCoord(unpack(p.coords))
        end
    end
    function slice:SetVertexColor(r, g, b)
        for _, p in ipairs(self.parts) do p:SetVertexColor(r, g, b) end
    end
    function slice:SetShown(shown)
        for _, p in ipairs(self.parts) do p:SetShown(shown) end
    end
    slice:SetFile(file)
    return slice
end

local function solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a)
    return t
end

-- A row's well: a dark fill, a 1 px edge; dimmed with SetVertexColor
local function well(frame)
    local box = CK.ConfigKit.Box(frame, 4, 1, "BORDER")
    box:SetPoints(frame)
    local w = { box = box }
    function w:SetVertexColor(r)
        local k = r or 1
        box:SetColors(C.well, 0.95, { C.wellLine[1] * (0.6 + 0.4 * k), C.wellLine[2] * (0.6 + 0.4 * k),
            C.wellLine[3] * (0.6 + 0.4 * k) }, 1)
    end
    w:SetVertexColor(1)
    return w
end

-- The copper pill of what is chosen (a word, a channel)
local function pill(frame)
    local box = CK.ConfigKit.Box(frame, 4, 1, "ARTWORK")
    box:SetPoints(frame)
    box:SetColors(C.pill, 1, C.pillLine, 1)
    return box
end

CK.UIKit = {
    TEX = TEX, C = C,
    texture = texture, place = place, text = text, nineSlice = nineSlice, solid = solid,
}

---------------------------------------------------------------------------
-- Input methods
---------------------------------------------------------------------------
function CK:GetMethod()
    return CK.Methods[self.db and self.db.settings.inputMethod] or CK.Methods.wheel
end

-- Redraw the active input method and the Shift / 123 state
function CK:UpdateMethod()
    if not self.frame then return end
    self:GetMethod():Update()
    self:UpdateBadge()
end

-- Switch between the daisywheel and the split keyboard, even while open
function CK:SetInputMethod(key)
    if not CK.Methods[key] then return end
    self.db.settings.inputMethod = key
    if not self.frame then return end
    self:GetMethod():Reset()
    self:Layout()
    self:UpdateHelp()
    self:UpdateMethod()
    if self.bindingsActive then self:EnableButtons() end
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local ACTIONS = {
    -- method, label, x and width on the 340 px panel (scaled to the width)
    { "ToggleShift", "SHIFT", 8, 38 },
    { "ToggleSymbols", "SYMBOLS", 49, 38 },
    { "Space", "SPACE", 90, 78 },
    { "Backspace", "BACKSPACE", 171, 58 },
    { "Send", "SEND", 232, 71 },
    { "Close", nil, 306, 26 },
}

local function buildButton(parent, label, onClick)
    local b = CK.NewFrame("Button", nil, parent)
    b.slice = nineSlice(b, "ck_sk_key_normal", 128, 64, 12, 8, "ARTWORK")
    b.label = text(b, 11)
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(label)
    b:SetScript("OnClick", onClick)
    function b:Render()
        if self.active then
            self.slice:SetFile("ck_sk_key_active")
            self.label:SetTextColor(unpack(C.pillText))
        elseif self.hover then
            self.slice:SetFile("ck_sk_key_hover")
            self.label:SetTextColor(unpack(C.btnHover))
        else
            self.slice:SetFile("ck_sk_key_normal")
            self.label:SetTextColor(unpack(C.btn))
        end
    end
    function b:SetActive(active)
        self.active = active
        self:Render()
    end
    b:SetScript("OnEnter", function(s) s.hover = true; s:Render() end)
    b:SetScript("OnLeave", function(s) s.hover = false; s:Render() end)
    b:Render()
    return b
end
CK.UIKit.buildButton = buildButton

function CK:BuildUI()
    if self.frame then return end

    local f = CK.NewFrame("Frame", "ControllerKeyboardFrame", UIParent)
    f:SetSize(340, 484)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    self.frame = f
    self:MakeDragHandle(f)

    -- Background: a dark vertical gradient; the edge: 1 px dark, 2 px
    -- bronze, 1 px dark inside
    local bg = solid(f, "BACKGROUND", C.winBottom[1], C.winBottom[2], C.winBottom[3], 0.96)
    bg:SetAllPoints()
    if CreateColor and bg.SetGradient then
        pcall(bg.SetColorTexture, bg, 1, 1, 1, 1)
        local ok = pcall(bg.SetGradient, bg, "VERTICAL", CreateColor(C.winBottom[1], C.winBottom[2], C.winBottom[3], 0.96),
            CreateColor(C.winTop[1], C.winTop[2], C.winTop[3], 0.96))
        if not ok then bg:SetColorTexture(C.winBottom[1], C.winBottom[2], C.winBottom[3], 0.96) end
    end
    local function frameEdge(color, inset, size)
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil },
            { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
            local t = solid(f, "BORDER", color[1], color[2], color[3], 1)
            local dx = (e[1]:find("LEFT") and inset) or -inset
            local dy = (e[1]:find("TOP") and -inset) or inset
            local dx2 = (e[2]:find("LEFT") and inset) or -inset
            local dy2 = (e[2]:find("TOP") and -inset) or inset
            t:SetPoint(e[1], f, e[1], dx, dy)
            t:SetPoint(e[2], f, e[2], dx2, dy2)
            if e[3] then t:SetWidth(size) else t:SetHeight(size) end
        end
    end
    frameEdge(C.edgeOut, 0, 1)
    frameEdge(C.edge, 1, 2)
    frameEdge(C.edgeIn, 3, 1)

    -- Input bar: channel + text + blinking cursor, mode badge, move grip
    local bar = CK.NewFrame("Frame", nil, f)
    well(bar)
    f.bar = bar

    -- Children of the bars so they draw above the bar textures
    f.preview = text(bar, 13)
    f.preview:SetJustifyH("LEFT")
    f.preview:SetJustifyV("TOP")
    f.preview:SetWordWrap(true)
    if f.preview.SetMaxLines then f.preview:SetMaxLines(2) end

    local badge = CK.NewFrame("Frame", nil, f)
    badge:SetFrameLevel(bar:GetFrameLevel() + 2)
    badge.outline = pill(badge)
    badge.fill = solid(badge, "ARTWORK", C.capsFill[1], C.capsFill[2], C.capsFill[3], 1)
    badge.fill:SetPoint("TOPLEFT", 1, -1)
    badge.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    badge.label = text(badge, 10)
    badge.label:SetPoint("CENTER")
    badge:Hide()
    f.badge = badge

    local grip = CK.NewFrame("Button", nil, f)
    grip:SetFrameLevel(bar:GetFrameLevel() + 2)
    grip.icon = texture(grip, "ck_move", "ARTWORK")
    grip.icon:SetSize(24, 24)
    grip.icon:SetPoint("CENTER")
    grip:SetScript("OnEnter", function(s) s.icon:SetVertexColor(1, 0.9, 0.55) end)
    grip:SetScript("OnLeave", function(s) s.icon:SetVertexColor(1, 1, 1) end)
    self:MakeDragHandle(grip)
    f.grip = grip

    -- Suggestions bar
    local sbar = CK.NewFrame("Frame", nil, f)
    f.sbar = sbar
    f.sbarSlice = well(sbar)
    f.lbGlyph = texture(sbar, nil, "OVERLAY")
    f.rbGlyph = texture(sbar, nil, "OVERLAY")
    f.sugg = {}
    for n = 1, 5 do
        local b = CK.NewFrame("Button", nil, f)
        b:SetFrameLevel(sbar:GetFrameLevel() + 2)
        b.select = pill(b)
        b.label = text(b, 13)
        b.label:SetPoint("LEFT", 2, 0)
        b.label:SetPoint("RIGHT", -2, 0)
        b.label:SetWordWrap(false)
        b:SetScript("OnClick", function() CK:AcceptSuggestion(n) end)
        b:Hide()
        f.sugg[n] = b
    end
    -- Measures a suggestion's whole width (never drawn)
    f.suggMeasure = text(f, 13)
    f.suggMeasure:SetWordWrap(false)
    f.suggMeasure:SetAlpha(0)

    -- Input methods, each in its own area (only the active one is shown)
    for _, method in pairs(CK.Methods) do
        method.area = CK.NewFrame("Frame", nil, f)
        method.area:SetSize(method.areaWidth, method.height)
        method:Build(method.area)
        method.area:Hide()
    end

    -- Channel row, under the input method: D-pad down to reach it, then < >,
    -- or hover with the mouse (no click, the game would close the chat)
    local cbar = CK.NewFrame("Frame", nil, f)
    f.cbar = cbar
    f.cbarSlice = well(cbar)
    f.chanLeft = texture(cbar, nil, "OVERLAY")
    f.chanRight = texture(cbar, nil, "OVERLAY")
    f.channels = {}
    for i, ch in ipairs(CK.CHANNEL_LIST) do
        local b = CK.NewFrame("Button", nil, f)
        b:SetFrameLevel(cbar:GetFrameLevel() + 2)
        b.select = pill(b)
        b.label = text(b, 12)
        b.label:SetPoint("CENTER", 0, 0)
        b.label:SetText(ch.label)
        b:SetScript("OnEnter", function(s)
            if not CK.mouseOnChannels then
                CK.mouseOnChannels = true
                CK:NoteChannelsFrom()
            end
            CK.channelsLeft = nil
            CK:SetChannel(i)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            local name = L.CHANNEL_NAMES[i]
            if not CK:ChannelAvailable(i) then name = name .. " (" .. L.CHANNEL_UNAVAILABLE .. ")" end
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
            -- Off the row (not onto a neighbour): the next visit notes again
            local token = {}
            CK.channelsLeft = token
            C_Timer.After(0.3, function()
                if CK.channelsLeft == token then CK.mouseOnChannels = nil end
            end)
        end)
        b:SetScript("OnClick", function() CK:SetChannel(i) end)
        f.channels[i] = b
    end

    -- "Quests" chip at the end of the channel row (quest links module)
    local chip = CK.NewFrame("Button", nil, f)
    chip:SetFrameLevel(cbar:GetFrameLevel() + 2)
    chip.select = pill(chip)
    chip.icon = texture(chip, nil, "OVERLAY")
    chip.icon:SetSize(18, 18)
    chip.icon:SetPoint("CENTER")
    -- The game's own quest "!" icon
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestNormal") then
        chip.icon:SetAtlas("QuestNormal")
    else
        chip.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
    chip:SetScript("OnEnter", function(s)
        if CK.mouseOnChannels then CK:RestoreChannelsFrom() end
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.QUESTS_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chip:SetScript("OnClick", function()
        if CK.mouseOnChannels then CK:RestoreChannelsFrom() end
        CK:OpenQuestList()
    end)
    f.questChip = chip

    -- Mouse / Steam Controller actions
    f.actions = {}
    for _, a in ipairs(ACTIONS) do
        local method = a[1]
        f.actions[method] = buildButton(f, a[2] and L[a[2]] or "X", function() CK[method](CK) end)
    end

    -- Help band: gamepad glyphs. In its own frame so it follows the layout
    local helpFrame = CK.NewFrame("Frame", nil, f)
    f.help = helpFrame
    f.helpBand = solid(helpFrame, "BACKGROUND", 0, 0, 0, 0.35)
    f.helpFilet1 = texture(helpFrame, "ck_filet", "BORDER")
    f.helpFilet2 = texture(helpFrame, "ck_filet", "BORDER")
    f.helpEntries = {}
    for n = 1, 8 do
        local g = texture(helpFrame, nil, "ARTWORK")
        local label = text(helpFrame, 11)
        label:SetPoint("LEFT", g, "RIGHT", 3, 0)
        label:SetTextColor(unpack(C.help))
        f.helpEntries[n] = { tex = g, label = label }
    end

    -- Blinking cursor (0.53 s on / off)
    f:HookScript("OnShow", function()
        CK.cursorOn, CK.cursorTime = true, GetTime()
    end)

    self:SetupInput(f)
    f:HookScript("OnUpdate", function()
        local now = GetTime()
        if now - (CK.cursorTime or 0) >= 0.53 then
            CK.cursorTime = now
            CK.cursorOn = not CK.cursorOn
            CK:UpdatePreview()
        end
    end)
    self:Layout()
    self:UpdateHelp()
    self:RestorePosition()
    self:UpdateLock()
    self:UpdateRows()
    self:UpdateMethod()

    -- Debug: report when something else than CK:Close hides the keyboard
    f:HookScript("OnHide", function()
        if CK.db.settings.debug and not CK.closing then
            CK:Print("hidden by: %s", debugstack(3, 4, 0) or "?")
        end
    end)
end

---------------------------------------------------------------------------
-- Layout: follows the active method's size and the mouse buttons option
---------------------------------------------------------------------------
function CK:Layout()
    local f = self.frame
    if not f then return end
    local method = self:GetMethod()
    local w, mh = method.width, method.height
    f:SetWidth(w)

    place(f.bar, f, 8, 8, w - 16, 44)
    place(f.preview, f, 16, 14, w - 122, 32)
    place(f.badge, f, w - 100, 21, 58, 18)
    place(f.grip, f, w - 38, 17, 26, 26)

    place(f.sbar, f, 8, 58, w - 16, 28)
    place(f.lbGlyph, f, 12, 61, 22, 22)
    place(f.rbGlyph, f, w - 34, 61, 22, 22)
    f.suggWidth = w - 76
    self:LayoutSuggestions()

    for _, m in pairs(CK.Methods) do m.area:SetShown(m == method) end
    place(method.area, f, (w - method.areaWidth) / 2, AREA_Y, method.areaWidth, mh)

    local cy = AREA_Y + mh + 4
    place(f.cbar, f, 8, cy, w - 16, 26)
    place(f.chanLeft, f, 12, cy + 2, 22, 22)
    place(f.chanRight, f, w - 34, cy + 2, 22, 22)
    local withChip = self.db.settings.modules.questLinks
    local cstep = (w - 76) / (#f.channels + (withChip and 1 or 0))
    for i, b in ipairs(f.channels) do
        place(b, f, 38 + cstep * (i - 1), cy + 1, cstep - 1, 24)
    end
    place(f.questChip, f, 38 + cstep * #f.channels, cy + 1, cstep - 1, 24)
    f.questChip:SetShown(withChip)

    -- Mouse buttons row is optional: when hidden, the help band moves up
    local show = self.db.settings.showActions
    local ay = cy + 30
    local sx = (w - 16) / 324
    for _, a in ipairs(ACTIONS) do
        local b = f.actions[a[1]]
        place(b, f, 8 + (a[3] - 8) * sx, ay, a[4] * sx, 26)
        b:SetShown(show)
    end

    local hy = show and (ay + 28) or (cy + 26)
    place(f.help, f, 0, hy, w, 48)
    place(f.helpBand, f.help, 0, 4, w, 40)
    place(f.helpFilet1, f.help, 0, 0, w, 8)
    place(f.helpFilet2, f.help, 0, 40, w, 8)
    local col = (w - 20) / 4
    for n, e in ipairs(f.helpEntries) do
        place(e.tex, f.help, 10 + ((n - 1) % 4) * col, 8 + math.floor((n - 1) / 4) * 17, 16, 16)
    end
    f:SetHeight(hy + 50)
    self:PositionSendButton()
end

-- Kept for the options / older callers: the mouse buttons row changed
function CK:ApplyLayout()
    self:Layout()
end

-- Help band: the method's own buttons, then the D-pad (common to all)
function CK:UpdateHelp()
    local f = self.frame
    if not f then return end
    local list = self:GetMethod():Help()
    list[#list + 1] = { "DPAD_DOWN", L.HELP_CHANNEL }
    list[#list + 1] = { "DPAD_LR", L.HELP_PICK }
    for n, e in ipairs(f.helpEntries) do
        local h = list[n]
        e.key = h and h[1]
        e.tex:SetShown(h ~= nil)
        e.label:SetShown(h ~= nil)
        if h then
            self:SetGlyph(e.tex, h[1])
            e.label:SetText(h[2])
        end
    end
end

-- Refresh the gamepad glyphs (after changing the glyph style)
function CK:UpdateGlyphs()
    local f = self.frame
    if not f then return end
    self:UpdateRows()
    for _, e in ipairs(f.helpEntries) do
        if e.key then self:SetGlyph(e.tex, e.key) end
    end
end

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------
-- Dragging `handle` moves the whole keyboard (only while unlocked)
function CK:MakeDragHandle(handle)
    local f = self.frame
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not CK.db.settings.locked then f:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        CK:SavePosition()
        CK:PositionSendButton()
    end)
    if handle ~= f then
        handle:HookScript("OnEnter", function(h)
            if CK.db.settings.locked then return end
            GameTooltip:SetOwner(h, "ANCHOR_TOP")
            GameTooltip:SetText(L.DRAG_HINT, 1, 1, 1)
            GameTooltip:Show()
        end)
        handle:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
end

-- The move grip is only shown while the position is unlocked (/ec lock)
function CK:UpdateLock()
    if self.frame then
        self.frame.grip:SetShown(not self.db.settings.locked)
    end
end

function CK:SavePosition()
    local point, _, relPoint, x, y = self.frame:GetPoint()
    self.db.pos = { point, relPoint, x, y }
end

function CK:RestorePosition()
    local f = self.frame
    f:ClearAllPoints()
    local pos = self.db.pos
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    elseif ChatFrame1 then
        f:SetPoint("BOTTOMLEFT", ChatFrame1, "BOTTOMRIGHT", 40, -30)
    else
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
    end
    f:SetScale(self.db.settings.scale)
    self:PositionSendButton()
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
function CK:DisplayChar(ch)
    if self.state.shift or self.state.caps then
        return CK.Upper(ch)
    end
    return ch
end

function CK:UpdatePreview()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    -- "||" is an escaped pipe: gold "|" then end of color
    local cursor = self.cursorOn and "|cffffd100|||r" or " "
    f.preview:SetText((self.previewBody or "") .. cursor)
end

-- Mode badge (MAJ / 123 outlined, caps lock filled) and mouse buttons state
function CK:UpdateBadge()
    local f = self.frame
    local state = self.state
    local badge = f.badge
    local label
    if state.caps then
        label = L.BADGE_CAPS
    elseif state.shift then
        label = L.BADGE_SHIFT
    elseif state.layer == "symbols" then
        label = L.SYMBOLS
    end
    badge:SetShown(label ~= nil)
    if label then
        badge.label:SetText(label)
        badge.outline:SetShown(not state.caps)
        badge.fill:SetShown(state.caps)
        if state.caps then
            badge.label:SetTextColor(unpack(C.dark))
            badge.label:SetShadowColor(0, 0, 0, 0)
        else
            badge.label:SetTextColor(unpack(C.gold))
            badge.label:SetShadowColor(0, 0, 0, 0.9)
        end
    end

    local symbols = f.actions.ToggleSymbols
    symbols.label:SetText(state.layer == "symbols" and L.LETTERS or L.SYMBOLS)
    symbols:SetActive(state.layer == "symbols")
    f.actions.ToggleShift:SetActive(state.shift or state.caps)
end

-- Active row: full light and < > glyphs at its ends. The other one is
-- dimmed and shows the D-pad direction that activates it.
function CK:UpdateRows()
    local f = self.frame
    if not (f and f.channels) then return end
    local channels = self.state.activeRow == "channels"
    local on, off = 1, 0.55

    local c = channels and on or off
    f.cbarSlice:SetVertexColor(c, c, c)
    for _, b in ipairs(f.channels) do b:SetAlpha(channels and 1 or 0.6) end
    f.questChip:SetAlpha(channels and 1 or 0.6)
    f.questChip.select:SetShown(channels and self.state.questChip or false)
    self:SetGlyph(f.chanLeft, channels and "DPAD_LEFT" or "DPAD_DOWN")
    self:SetGlyph(f.chanRight, "DPAD_RIGHT")
    f.chanRight:SetShown(channels)

    local sg = channels and off or on
    f.sbarSlice:SetVertexColor(sg, sg, sg)
    for _, b in ipairs(f.sugg) do b:SetAlpha(channels and 0.6 or 1) end
    self:SetGlyph(f.lbGlyph, channels and "DPAD_UP" or "DPAD_LEFT")
    self:SetGlyph(f.rbGlyph, "DPAD_RIGHT")
    f.rbGlyph:SetShown(not channels)
    -- A field of the game (Fields.lua): the channels do nothing there
    if self.field then
        for _, b in ipairs(f.channels) do b:SetAlpha(0.25) end
        f.questChip:SetAlpha(0.25)
        f.chanLeft:Hide()
    else
        f.chanLeft:Show()
    end
end

function CK:UpdateChannels()
    local f = self.frame
    if not (f and f.channels) then return end
    local current = self:CurrentChannelIndex()
    for i, b in ipairs(f.channels) do
        local ch = CK.CHANNEL_LIST[i]
        local info = ChatTypeInfo and ChatTypeInfo[ch.color]
        local r, g, bl = 1, 1, 1
        if info then r, g, bl = info.r, info.g, info.b end
        local available = self:ChannelAvailable(i)
        b.select:SetShown(i == current and not self.state.questChip)
        b.label:SetTextColor(r, g, bl)
        b.label:SetAlpha(available and 1 or 0.3)
    end
end

-- Each suggestion as wide as its word (the room left shared out), so a word
-- is never cut: the ones that don't fit whole are left out. A word too long
-- for the whole row (a quest's name) is the only one cut.
local SUGG_X, SUGG_PAD, SUGG_GAP = 38, 14, 4

function CK:LayoutSuggestions()
    local f = self.frame
    if not (f and f.suggWidth and self.state) then return end
    local list, total = self.state.suggestions, f.suggWidth
    local quests = self.InQuestList and self:InQuestList()
    local widths, sum, count = {}, 0, 0
    for i = 1, math.min(#list, #f.sugg) do
        f.suggMeasure:SetText(list[i])
        local textWidth = f.suggMeasure:GetStringWidth()
        local need = math.ceil(type(textWidth) == "number" and textWidth or 0) + SUGG_PAD
        -- The quests' list pages through every quest: never shortened
        if count > 0 and not quests and sum + need + SUGG_GAP * count > total then break end
        widths[i], sum, count = need, sum + need, i
    end
    if not quests then
        for i = #list, count + 1, -1 do list[i] = nil end
        if (self.state.selected or 1) > math.max(count, 1) then self.state.selected = 1 end
    end
    if count == 0 then return end
    local room = total - SUGG_GAP * (count - 1)
    local x = SUGG_X
    for i = 1, count do
        local width = sum <= room and widths[i] + (room - sum) / count or widths[i] * room / sum
        place(f.sugg[i], f, x, 59, width, 26)
        x = x + width + SUGG_GAP
    end
end

function CK:UpdateSuggestions()
    local f = self.frame
    self:LayoutSuggestions()
    local list = self.state.suggestions
    for i, b in ipairs(f.sugg) do
        local word = list[i]
        if word then
            local selected = i == self.state.selected
            b.label:SetText(word)
            b.select:SetShown(selected)
            b.label:SetTextColor(unpack(selected and C.suggSel or C.sugg))
            b:Show()
        else
            b:Hide()
        end
    end
end
