local _, CK = ...
local L = CK.L

-- The 2.0 configuration panel's parts (Claude Design handoff, "Easy
-- Controller - Composants"): its colours and type, rounded boxes, gamepad
-- glyphs, the help bar's hints, the detail panel and the lists picker. The
-- pages (ConfigWindow.lua, Options.lua, MapWindow.lua, MyWheels.lua) are
-- made of them. Sizes are the handoff's, in UI pixels at scale 1.
local K = {}
CK.ConfigKit = K

local TEX = "Interface\\AddOns\\EasyController\\textures\\"
K.TEX = TEX

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

K.C = {
    title = hex("F2C43C"), focus = hex("FFD24A"), dimGold = hex("C9A25A"), focusText = hex("FFF3D0"),
    cream = hex("EFE4C8"), cream2 = hex("D8CCB0"), tab = hex("E6DCC4"), rail = hex("CBBD9C"),
    help = hex("B9AB8C"), grey = hex("9D917A"), disabled = hex("6F6452"),
    bronze = hex("7A5D36"), line1 = hex("5A4630"), line2 = hex("4A3A26"), line3 = hex("3A2C1D"),
    control = hex("6B5235"), boxEdge = hex("7A6448"), boxOff = hex("4A3C2A"), arrowOff = hex("5A4C3A"),
    bg = hex("16110C"), controlBg = hex("0F0B07"), boxBg = hex("0B0805"), pressed = hex("2A1F12"),
    slot = hex("D9A93A"), yours = hex("5FC0D0"), info = hex("9FD8E2"), fill = hex("8A6A2A"),
    danger = hex("FF7A5C"), dangerBg = hex("4A140E"), dangerText = hex("FFE0D6"), warn = hex("F0A090"),
    eventOff = hex("7A6E5A"), inner = hex("2A1F14"), white = { 1, 1, 1 }, black = { 0, 0, 0 },
    -- The Gamepad screen's states, the wizard's steps, the wheels' dots
    gameFn = hex("8A8070"), off = hex("5A4C3A"), iconBg = hex("3E3A33"), iconFg = hex("CFC6B2"),
    doneBg = hex("2A3A1C"), done = hex("7AA04A"), nowBg = hex("3A2C12"), legendRing = hex("7A7060"),
    legendFree = hex("7A6A52"), legendGame = hex("4A463E"), legendSlot = hex("3A3020"), legendYours = hex("1C3236"),
    spell = hex("2F4A73"), item = hex("6B4A1C"), macro = hex("4F3466"), game = hex("4A463E"), bar = hex("5A4422"),
    emptyDot = hex("6B5A44"), panel = hex("120D08"),
    inkTitle = hex("3D2515"), ink = hex("493421"), inkInfo = hex("29494D"),
}
local C = K.C

---------------------------------------------------------------------------
-- Type: Friz Quadrata (or the font picked in Home > Look) for titles and
-- labels, the chat's font for help texts, counters and the crumb
---------------------------------------------------------------------------
function K.Text(parent, size, color, layer)
    local fs = CK.UIKit.text(parent, size, layer)
    fs:SetWordWrap(false)
    fs:SetJustifyH("LEFT")
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

local function chatFont()
    return (ChatFontNormal and ChatFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\ARIALN.TTF"
end

function K.ChatText(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(chatFont(), size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetJustifyH("LEFT")
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

-- Upper case, accented letters too (string.upper leaves UTF-8 alone): the
-- Latin-1 ones, U+00E0-U+00FE but the division sign
function K.Upper(text)
    return (text:upper():gsub("\195([\160-\190])", function(c)
        if c == "\183" then return nil end
        return "\195" .. string.char(c:byte() - 32)
    end))
end

-- A solid colour texture
function K.Solid(parent, color, alpha, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    return t
end

---------------------------------------------------------------------------
-- Rounded boxes: nine-slices of the ck_box textures (32 texels for 16 px,
-- corners of 4 px), tinted
---------------------------------------------------------------------------
function K.Slice(parent, file, layer, sub)
    local s = { parts = {} }
    local u = 8 / 32
    local cuts = { { 0, u }, { u, 1 - u }, { 1 - u, 1 } }
    for r = 1, 3 do
        for c = 1, 3 do
            local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
            t:SetTexture(TEX .. file)
            t:SetTexCoord(cuts[c][1], cuts[c][2], cuts[r][1], cuts[r][2])
            s.parts[#s.parts + 1] = t
        end
    end
    local tl, t, tr, l, m, rt, bl, b, br = unpack(s.parts)
    function s:SetPoints(region, inset)
        inset = inset or 0
        for _, p in ipairs(self.parts) do p:ClearAllPoints() end
        tl:SetPoint("TOPLEFT", region, "TOPLEFT", inset, -inset)
        tr:SetPoint("TOPRIGHT", region, "TOPRIGHT", -inset, -inset)
        bl:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", inset, inset)
        br:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -inset, inset)
        for _, corner in ipairs({ tl, tr, bl, br }) do corner:SetSize(4, 4) end
        t:SetPoint("TOPLEFT", tl, "TOPRIGHT"); t:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
        b:SetPoint("TOPLEFT", bl, "TOPRIGHT"); b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
        l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); l:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
        rt:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); rt:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
        m:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); m:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    end
    function s:SetColor(color, alpha)
        for _, p in ipairs(self.parts) do p:SetVertexColor(color[1], color[2], color[3], alpha or 1) end
    end
    function s:SetShown(shown)
        for _, p in ipairs(self.parts) do p:SetShown(shown) end
    end
    s:SetPoints(parent)
    return s
end

-- A filled box with an edge: radius 3 (edge 2) or 4 (edge 1 or 2)
function K.Box(parent, radius, edge, layer, sub)
    local box = { fill = K.Slice(parent, format("ck_box%d", radius), layer, sub) }
    if edge then box.line = K.Slice(parent, format("ck_box%d_line%d", radius, edge), layer, (sub or 0) + 1) end
    function box:SetPoints(region, inset)
        self.fill:SetPoints(region, inset)
        if self.line then self.line:SetPoints(region, inset) end
    end
    -- No colour: that part stays hidden (an edge alone, a fill alone)
    function box:SetColors(fill, fillAlpha, line, lineAlpha)
        self.noFill, self.noLine = fill == nil, line == nil
        self.fill:SetShown(fill ~= nil and not self.hidden)
        if fill then self.fill:SetColor(fill, fillAlpha) end
        if self.line then
            self.line:SetShown(line ~= nil and not self.hidden)
            if line then self.line:SetColor(line, lineAlpha) end
        end
    end
    function box:SetShown(shown)
        self.hidden = not shown
        self.fill:SetShown(shown and not self.noFill)
        if self.line then self.line:SetShown(shown and not self.noLine) end
    end
    return box
end

-- The window and placement banners share a tiled slate body and a forged
-- nine-slice frame, so narrow banners keep the same unstretched corners.
function K.Panel(f)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(TEX .. "ck_panel_bg", "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetAllPoints()
    local under = K.Solid(f, C.bg, 1, "BACKGROUND", -8)
    under:SetAllPoints()
    under:SetDrawLayer("BACKGROUND", -8)
    bg:SetDrawLayer("BACKGROUND", -7)
    CK.UIKit.nineSlice(f, "ck_reforged_frame", 128, 128, 16, 12, "BORDER")
end

---------------------------------------------------------------------------
-- Glyphs: the gamepad's buttons (Glyphs.lua: the game's atlases or ours),
-- a grey pill with its name for the others (Select, Start, the paddles)
---------------------------------------------------------------------------
local IMAGE = {
    A = true, B = true, X = true, Y = true, LB = true, RB = true, LT = true, RT = true, LS = true, RS = true,
    DPAD = true, DPAD_LR = true, DPAD_UP = true, DPAD_LEFT = true, DPAD_RIGHT = true, DPAD_DOWN = true,
}
K.IMAGE = IMAGE
-- The mapping's inputs, as glyph keys
K.INPUT_GLYPH = {
    L3 = "LS", R3 = "RS", UP = "DPAD_UP", DOWN = "DPAD_DOWN", LEFT = "DPAD_LEFT", RIGHT = "DPAD_RIGHT",
}
local CHIP_TEXT = { SELECT = "Select", START = "Start" }
local CHIP_PS = { SELECT = "Create", START = "Options" }
local CHIP_SWITCH = { SELECT = "-", START = "+" }

function K.ChipText(key)
    local style = CK.db and CK.db.settings.glyphStyle
    if style == "playstation" and CHIP_PS[key] then return CHIP_PS[key] end
    if style == "switch" and CHIP_SWITCH[key] then return CHIP_SWITCH[key] end
    return CHIP_TEXT[key] or key
end

function K.Glyph(parent, size)
    local g = CK.NewFrame("Frame", nil, parent)
    g:SetSize(size, size)
    g.size = size
    g.tex = g:CreateTexture(nil, "ARTWORK")
    g.tex:SetAllPoints()
    -- The pill: three pieces of ck_chip (rounded ends, a middle that stretches)
    local h = math.floor(size * 0.72 + 0.5)
    g.chip = {}
    for i, cut in ipairs({ { 0, 22 / 64 }, { 22 / 64, 42 / 64 }, { 42 / 64, 1 } }) do
        local t = g:CreateTexture(nil, "ARTWORK")
        t:SetTexture(TEX .. "ck_chip")
        t:SetTexCoord(cut[1], cut[2], 10 / 64, 54 / 64)
        t:SetHeight(h)
        g.chip[i] = t
    end
    g.chip[1]:SetPoint("LEFT")
    g.chip[1]:SetWidth(h / 2)
    g.chip[3]:SetPoint("RIGHT")
    g.chip[3]:SetWidth(h / 2)
    g.chip[2]:SetPoint("LEFT", g.chip[1], "RIGHT")
    g.chip[2]:SetPoint("RIGHT", g.chip[3], "LEFT")
    g.label = K.ChatText(g, math.max(9, math.floor(size * 0.38)), C.white)
    g.label:SetPoint("CENTER", 0, 0)
    g.label:SetJustifyH("CENTER")
    function g:Set(key)
        local image = IMAGE[key]
        self.tex:SetShown(image)
        for _, t in ipairs(self.chip) do t:SetShown(not image) end
        self.label:SetShown(not image)
        if image then
            CK:SetGlyph(self.tex, key)
            self:SetWidth(self.size)
        else
            self.label:SetText(K.ChipText(key))
            self:SetWidth(math.max(self.size * 0.75, self.label:GetStringWidth() + h * 0.6))
        end
        self:Show()
    end
    return g
end

-- A row of glyphs ("RT + A"): keys, "+" for a plus sign; returns its width
function K.GlyphRow(parent, size)
    local row = CK.NewFrame("Frame", nil, parent)
    row:SetSize(1, size)
    row.items = {}
    function row:Set(keys)
        local x = 0
        for i, key in ipairs(keys or {}) do
            local item = self.items[i]
            if not item then
                item = { glyph = K.Glyph(self, size), plus = K.Text(self, 16, C.cream) }
                item.plus:SetText("+")
                self.items[i] = item
            end
            item.glyph:ClearAllPoints()
            item.plus:ClearAllPoints()
            if key == "+" then
                item.glyph:Hide()
                item.plus:Show()
                item.plus:SetPoint("LEFT", x + 2, 0)
                x = x + item.plus:GetStringWidth() + 4
            else
                item.plus:Hide()
                item.glyph:Set(K.INPUT_GLYPH[key] or key)
                item.glyph:SetPoint("LEFT", x, 0)
                x = x + item.glyph:GetWidth() + 1
            end
        end
        for i = #(keys or {}) + 1, #self.items do
            self.items[i].glyph:Hide()
            self.items[i].plus:Hide()
        end
        self:SetWidth(math.max(1, x))
        return x
    end
    return row
end

-- A help bar hint: its glyph(s), then a short verb; a click presses its key
function K.Hint(parent)
    local h = CK.NewFrame("Button", nil, parent)
    h:SetHeight(24)
    h.glyphs = K.GlyphRow(h, 20)
    h.glyphs:SetPoint("LEFT")
    h.verb = K.Text(h, 12, C.cream)
    h:SetScript("OnClick", function(self) if self.press then CK.Config:ClickHint(self.press) end end)
    function h:Set(hint, maxWidth)
        local w = self.glyphs:Set(hint.keys)
        self.verb:ClearAllPoints()
        self.verb:SetPoint("LEFT", w + 6, 0)
        self.verb:SetWidth(0); self.verb:SetHeight(0)
        self.verb:SetWordWrap(false)
        self.verb:SetText(hint.verb or "")
        local natural = self.verb:GetStringWidth()
        local available = maxWidth and math.max(1, maxWidth - w - 6) or natural
        self.verb:SetWidth(math.min(natural, available))
        self.verb:SetWordWrap(maxWidth ~= nil); self.verb:SetMaxLines(2)
        self.verb:SetHeight(26)
        self.press = hint.press
        self.minWidth = w + 7
        self:SetWidth(w + 6 + math.min(natural, available))
        self:SetHeight(maxWidth and natural > available and 28 or 24)
        self:Show()
    end
    return h
end

---------------------------------------------------------------------------
-- A round icon (spell, item, macro...) cut by a circle
---------------------------------------------------------------------------
local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- A square icon with the corners of the game's gamepad bar (its SquareMask)
function K.SquareIcon(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    if hasAtlas("SquareMask") then
        local mask = parent:CreateMaskTexture()
        mask:SetAllPoints(t)
        mask:SetAtlas("SquareMask")
        t:AddMaskTexture(mask)
    end
    return t
end

function K.RoundIcon(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(t)
    if hasAtlas("CircleMask") then
        mask:SetAtlas("CircleMask")
    else
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    t:AddMaskTexture(mask)
    return t
end

---------------------------------------------------------------------------
-- The detail panel (right): what has the focus, explained. From the top:
-- the glyphs of a combination (Gamepad), a title, a state tag (a dot and a
-- word), the help text, a cyan info line; a legend at the bottom (Gamepad)
---------------------------------------------------------------------------
-- Measure after setting the width, with no previous height limiting the result.
local function fitText(label, text, width)
    label:SetWidth(width)
    label:SetHeight(0)
    label:SetText(text or "")
    local height = math.ceil(label:GetStringHeight())
    label:SetHeight(height)
    return height
end

function K.Detail(parent, width, comboSize)
    local d = CK.NewFrame("Frame", nil, parent)
    d:SetWidth(width)
    d.parchment = CK.UIKit.nineSlice(d, "ck_reforged_parchment", 256, 256, 16, 12, "BACKGROUND")
    if hasAtlas("common-insideframe") then
        -- The native inset rim includes transparent paper-facing shadows;
        -- SetAtlas retains its client-provided slice margins and resolution.
        d.rim = d:CreateTexture(nil, "BORDER")
        d.rim:SetAllPoints()
        d.rim:SetAtlas("common-insideframe", false)
    end
    local inner = width - 28
    d.viewport = CK.NewFrame("ScrollFrame", nil, d)
    d.viewport:SetPoint("TOPLEFT", 14, -14)
    d.viewport:EnableMouseWheel(true)
    d.scrollChild = CK.NewFrame("Frame", nil, d.viewport)
    d.scrollChild:SetWidth(inner)
    d.viewport:SetScrollChild(d.scrollChild)
    local child = d.scrollChild
    d.combo = K.GlyphRow(child, comboSize or 26)
    d.icon = K.SquareIcon(child, 50, "ARTWORK")
    d.title = K.Text(child, 16, C.inkTitle)
    d.title:SetSpacing(3)
    d.dot = child:CreateTexture(nil, "ARTWORK")
    d.dot:SetTexture(TEX .. "ck_dot"); d.dot:SetSize(10, 10)
    d.tag = K.ChatText(child, 13, C.ink)
    d.body = K.ChatText(child, 13, C.ink)
    d.body:SetSpacing(4)
    d.extra = K.ChatText(child, 13, C.inkInfo)
    d.extra:SetSpacing(4)
    for _, label in ipairs({ d.title, d.tag, d.body, d.extra }) do
        label:SetWordWrap(true); label:SetNonSpaceWrap(true); label:SetJustifyV("TOP")
        label:SetShadowColor(0, 0, 0, 0)
    end
    d.scrollHint = K.ChatText(d, 11, C.ink)
    d.scrollHint:SetShadowColor(0, 0, 0, 0)
    d.scrollHint:SetWidth(inner); d.scrollHint:SetJustifyH("CENTER")
    d.actionButton = K.Button(d, 14)
    d.actionButton:SetPoint("BOTTOMLEFT", 14, 14)
    d.actionButton:SetPoint("BOTTOMRIGHT", -14, 14)
    d.actionButton:SetHeight(34)
    function d:Activate()
        local action = self.actionDef
        if not action or action.disabled then return end
        self.actionButton:Pulse()
        action.func()
    end
    d.actionButton:SetScript("OnClick", function() d:Activate() end)
    function d:CanScroll() return (self.maxScroll or 0) > 0 end
    function d:Scroll(delta)
        local offset = math.max(0, math.min(self.maxScroll or 0, self.viewport:GetVerticalScroll() + delta * 40))
        self.viewport:SetVerticalScroll(offset)
        self.scrollHint:SetText(self:CanScroll() and format("%d%%", math.floor(offset / self.maxScroll * 100 + 0.5)) or "")
    end
    d.viewport:SetScript("OnMouseWheel", function(_, delta) d:Scroll(-delta) end)
    function d:Set(content)
        content = content or {}
        local centered, y = content.centered, 0
        local function place(region, height, gap, x)
            if y > 0 then y = y + (gap or 9) end
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", child, "TOPLEFT", x or (centered and (inner - region:GetWidth()) / 2 or 0), -y)
            y = y + height
        end
        self.title:SetJustifyH(centered and "CENTER" or "LEFT")
        self.tag:SetJustifyH(centered and "CENTER" or "LEFT")
        self.body:SetJustifyH(centered and "CENTER" or "LEFT")
        self.extra:SetJustifyH(centered and "CENTER" or "LEFT")
        self.combo:SetShown(content.combo ~= nil)
        if content.combo then self.combo:Set(content.combo) end
        self.icon:SetShown(content.icon ~= nil)
        if content.icon then CK.Paddles.SetIcon(self.icon, content.icon) end
        if not centered and content.combo then place(self.combo, self.combo:GetHeight()) end
        if content.icon then place(self.icon, self.icon:GetHeight()) end
        place(self.title, fitText(self.title, content.title, inner))
        if centered and content.combo then place(self.combo, self.combo:GetHeight(), 7) end
        self.dot:SetShown(content.tag ~= nil and not centered)
        self.tag:SetShown(content.tag ~= nil)
        if content.tag then
            place(self.tag, fitText(self.tag, content.tag, centered and inner or inner - 18), 7, centered and 0 or 18)
            if not centered then
                local tc = content.tagColor or C.grey
                self.dot:SetVertexColor(tc[1], tc[2], tc[3])
                self.dot:ClearAllPoints(); self.dot:SetPoint("TOPLEFT", self.tag, "TOPLEFT", -18, -2)
            end
        end
        self.body:SetShown(content.body ~= nil and content.body ~= "")
        if self.body:IsShown() then place(self.body, fitText(self.body, content.body, inner)) end
        self.extra:SetShown(content.extra ~= nil and content.extra ~= "")
        if self.extra:IsShown() then place(self.extra, fitText(self.extra, content.extra, inner)) end
        self.actionDef = content.action
        self.actionButton:SetShown(content.action ~= nil)
        if content.action then
            self.actionButton.label:SetText(content.action.label)
            self.actionButton:SetState({ disabled = content.action.disabled, focus = content.action.focus })
        end
        if self.legend then self.legend:SetShown(content.legend and true or false) end
        -- The action and existing Gamepad legend stay outside the scroll child.
        local footer = content.action and 60 or 14
        if self.legend and content.legend then footer = math.max(footer, self.legend:GetHeight() + 26) end
        self.scrollHint:ClearAllPoints(); self.scrollHint:SetPoint("BOTTOMLEFT", 14, footer)
        self.viewport:SetSize(inner, math.max(1, self:GetHeight() - 14 - footer - 18))
        child:SetHeight(math.max(1, y))
        self.maxScroll = math.max(0, y - self.viewport:GetHeight())
        self.scrollHint:SetShown(self:CanScroll())
        local key = table.concat({ content.title or "", content.tag or "", content.body or "", content.extra or "",
            tostring(content.icon), table.concat(content.combo or {}, "+"), tostring(centered) }, "\031")
        if self.contentKey ~= key then self.viewport:SetVerticalScroll(0) end
        self.contentKey = key
        self:Scroll(0)
    end
    return d
end

---------------------------------------------------------------------------
-- The lists picker: in place of the detail panel, the same width. A kicker
-- and a title, its lists' tabs (LB / RB), then the entries with their
-- sections. def = { kicker, title, lists = { { label, entries = function()
-- return { { header } or { action, name, icon, sub } } end } }, onChoose =
-- function(entry), onBack = function(), marked = function(entry) (a cyan
-- diamond: already there), rows = 10 }
---------------------------------------------------------------------------
local PICK_ROW, PICK_HEAD = 48, 30

function K.Picker(parent, width)
    local p = CK.NewFrame("Frame", nil, parent)
    p:SetWidth(width)
    p:EnableMouseWheel(true)
    p.box = K.Box(p, 4, 1, "BACKGROUND", 1)
    p.box:SetPoints(p)
    p.box:SetColors(C.black, 0.72, C.line1, 1)
    p.kicker = K.ChatText(p, 12, C.grey)
    p.kicker:SetPoint("TOPLEFT", 12, -12)
    p.kicker:SetWidth(width - 24)
    p.title = K.Text(p, 17, C.title)
    p.title:SetPoint("TOPLEFT", p.kicker, "BOTTOMLEFT", 0, -3)
    p.title:SetWidth(width - 24)
    p.title:SetWordWrap(true); p.title:SetMaxLines(2); p.title:SetNonSpaceWrap(true)
    p.tabs = {}
    p.rows = {}
    p:SetScript("OnMouseWheel", function(self, delta) self:Move(-delta * 3) end)
    p:SetScript("OnHide", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    p:Hide()

    local function tab(i)
        local t = p.tabs[i]
        if t then return t end
        t = K.Button(p, 13, "nav")
        t:SetScript("OnClick", function() t:Pulse(); p:SetList(i) end)
        t:SetHeight(34)
        p.tabs[i] = t
        return t
    end

    local function row(i)
        local r = p.rows[i]
        if r then return r end
        r = CK.NewFrame("Button", nil, p)
        r:SetSize(width - 24, PICK_ROW)
        r.sel = CK.UIKit.nineSlice(r, "ck_select", 128, 32, 10, 10, "ARTWORK")
        r.iconRing = K.Solid(r, C.control, 1, "ARTWORK", 1)
        r.icon = K.RoundIcon(r, 24, "ARTWORK")
        r.icon:SetDrawLayer("ARTWORK", 2)
        r.icon:SetPoint("LEFT", 6, 0)
        r.mark = r:CreateTexture(nil, "OVERLAY")
        r.mark:SetTexture(TEX .. "ck_diamond")
        r.mark:SetSize(8, 8)
        r.mark:SetVertexColor(C.yours[1], C.yours[2], C.yours[3])
        r.mark:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMLEFT", -3, -1)
        r.iconRing:Hide()
        r.label = K.Text(r, 15, C.cream)
        r.label:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.label:SetPoint("RIGHT", -6, 0)
        r.label:SetWidth(width - 68); r.label:SetHeight(36)
        r.label:SetWordWrap(true); r.label:SetNonSpaceWrap(true); r.label:SetMaxLines(2)
        r.label:SetSpacing(2)
        r.head = K.Text(r, 14, C.title)
        r.head:SetPoint("BOTTOMLEFT", 4, 3)
        r.head:SetWidth(width - 32); r.head:SetHeight(28)
        r.head:SetWordWrap(true); r.head:SetMaxLines(2)
        r:SetScript("OnClick", function(self)
            if self.index then
                p.index = self.index
                p:Choose()
                CK.Config:Render()
            end
        end)
        r:SetScript("OnEnter", function(self)
            if self.index and p.index ~= self.index then
                p.index = self.index
                p:Render()
            end
            if self.index then p:ShowEntryTooltip() end
        end)
        p.rows[i] = r
        return r
    end

    function p:Open(def)
        self.def = def
        self.list = def.list or 1
        self:Show()
        self:LoadList()
    end

    function p:Close()
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        self.def = nil
        self:Hide()
    end

    function p:IsOpen() return self.def ~= nil end

    function p:ShowEntryTooltip()
        local e = self.index and self.entries[self.index]
        if not GameTooltip then return end
        if not e or e.header then
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(e.name or "", 1, 1, 1, true)
        if e.sub then GameTooltip:AddLine(e.sub, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end

    function p:Layout()
        local kicker, title = self.def.kicker, self.def.title
        if type(kicker) == "function" then kicker = kicker() end
        if type(title) == "function" then title = title() end
        self.kicker:SetText(K.Upper(kicker or ""))
        local titleHeight = fitText(self.title, title, width - 24)
        self.rowTop = 12 + self.kicker:GetStringHeight() + 3 + titleHeight + 8
        self.tabTop = self.rowTop
        if #self.def.lists > 1 then self.rowTop = self.rowTop + 40 end
        self.visibleRows = math.max(1, math.min(self.def.rows or 10, math.floor((self:GetHeight() - self.rowTop - 12) / PICK_ROW)))
    end

    function p:LoadList()
        local list = self.def.lists[self.list]
        self.entries = list and list.entries() or {}
        self.offset, self.index = 0, nil
        local current = self.def.current
        for i, e in ipairs(self.entries) do
            if not e.header and (not self.index or e.action == current) then
                self.index = i
                if e.action == current then break end
            end
        end
        self:Move(0)
    end

    function p:SetList(i)
        local n = #self.def.lists
        self.list = (i - 1) % n + 1
        self:LoadList()
    end

    -- Keep the entry (and the section title above it) in the window, with
    -- one entry of context at the edges
    function p:Move(delta)
        local entries, i = self.entries or {}, self.index
        if not i then self:Render(); self:ShowEntryTooltip(); return end
        local step = delta < 0 and -1 or 1
        for _ = 1, math.abs(delta) do
            local j = i + step
            while entries[j] and entries[j].header do j = j + step end
            if entries[j] then i = j end
        end
        self.index = i
        self:Layout()
        local max = self.visibleRows
        if i - 1 <= self.offset then self.offset = math.max(0, i - 2) end
        if self.offset > 0 and entries[self.offset] and entries[self.offset].header then
            self.offset = self.offset - 1
        end
        if i + 1 > self.offset + max then self.offset = math.min(#entries - max, i + 1 - max) end
        self.offset = math.max(0, self.offset)
        self:Render()
        self:ShowEntryTooltip()
    end

    -- The previous / next section
    function p:Jump(step)
        local entries, headers = self.entries or {}, {}
        for i, e in ipairs(entries) do
            if e.header then headers[#headers + 1] = i end
        end
        if #headers < 2 then return self:Move(step * (self.visibleRows or self.def.rows or 10)) end
        local current = 0
        for n, h in ipairs(headers) do
            if h < (self.index or 0) then current = n end
        end
        local target = headers[current + step]
        if not target then return end
        self.index = target
        self:Move(1)
    end

    function p:Choose()
        local e = self.def and self.index and self.entries[self.index]
        if e and not e.header and self.def.onChoose then self.def.onChoose(e) end
    end

    function p:Press(name)
        if name == "UP" or name == "DOWN" then
            self:Move(name == "UP" and -1 or 1)
        elseif name == "LEFT" or name == "RIGHT" then
            self:Jump(name == "LEFT" and -1 or 1)
        elseif name == "LB" or name == "RB" then
            if #self.def.lists > 1 then
                self:SetList(self.list + (name == "LB" and -1 or 1))
                local t = self.tabs[self.list]
                if t then t:Pulse() end
            end
        elseif name == "A" then
            self:Choose()
        elseif name == "B" then
            if self.def.onBack then self.def.onBack() end
        end
        return true
    end

    function p:Hints()
        local hints = { K.H({ "DPAD" }, L.V_MOVE), K.H({ "A" }, self.def.chooseVerb or L.V_CHOOSE, "A") }
        if #self.def.lists > 1 then hints[#hints + 1] = K.H({ "LB", "RB" }, L.V_LIST, "RB") end
        hints[#hints + 1] = K.H({ "B" }, L.V_BACK, "B")
        return hints
    end

    function p:Render()
        local def = self.def
        if not def then return end
        self:Layout()
        -- The lists' tabs share the width
        local n = #def.lists
        local tw = (width - 24 - (n - 1) * 4) / n
        for i = 1, math.max(n, #self.tabs) do
            local t = tab(i)
            t:SetShown(n > 1 and i <= n)
            if i <= n then
                t:SetWidth(tw)
                t.label:SetWidth(tw - 12); t.label:SetHeight(30)
                t.label:SetWordWrap(true); t.label:SetMaxLines(2)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self, "TOPLEFT", 12 + (i - 1) * (tw + 4), -self.tabTop)
                t.label:SetText(def.lists[i].label)
                t:SetState({ active = i == self.list })
            end
        end
        local top = -self.rowTop
        local max = self.visibleRows
        if self.index then
            self.offset = math.max(0, math.min(self.offset, self.index - 1))
            if self.index > self.offset + max then self.offset = self.index - max end
        end
        local y = top
        local shown = 0
        for i = 1, max + 1 do
            local e = self.entries[self.offset + i]
            local r = row(i)
            r.index = nil
            if e and shown < max then
                shown = shown + 1
                local h = e.header and PICK_HEAD or PICK_ROW
                r:SetHeight(h)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", self, "TOPLEFT", 12, y)
                y = y - h
                r.head:SetShown(e.header ~= nil)
                r.label:SetShown(not e.header)
                r.icon:SetShown(not e.header)
                r.mark:SetShown(not e.header and def.marked and def.marked(e) or false)
                r.sel:SetShown(not e.header and self.offset + i == self.index)
                if e.header then
                    r.head:SetText(e.header)
                else
                    r.index = self.offset + i
                    CK.Paddles.SetIcon(r.icon, e.icon or 134400)
                    r.label:SetText(e.name .. (e.sub and ("  |cff9d9a8c" .. e.sub .. "|r") or ""))
                end
                r:Show()
            else
                r:Hide()
            end
        end
        for i = max + 2, #self.rows do self.rows[i]:Hide() end
        if #self.entries == 0 then
            local r = row(1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", self, "TOPLEFT", 12, top)
            r:Show()
            r.head:Show()
            r.head:SetText(L.MAP_NOTHING)
            r.label:Hide()
            r.icon:Hide()
            r.mark:Hide()
            r.sel:SetShown(false)
        end
    end
    return p
end

-- A help bar hint: { keys, verb, press (the key a click presses) }
function K.H(keys, verb, press)
    return { keys = keys, verb = verb, press = press or keys[1] }
end

---------------------------------------------------------------------------
-- A button of the ck_btn textures. States: active (the focus, the open
-- tab), armed (a destructive one asking again: red), disabled (faded); the
-- mouse lights it up
---------------------------------------------------------------------------
function K.Button(parent, size, skin)
    local b = CK.NewFrame("Button", nil, parent)
    local role = skin == "role"
    local prefix = role and "ck_reforged_role" or "ck_btn"
    local native = (role or skin == "nav") and hasAtlas("common-button-list-" .. (role and "large" or "small"))
    if native then
        -- SetAtlas loads the client's slice metadata, including the asymmetric
        -- selected ornament. Do not replace it with a symmetric nine-slice.
        b.nativeBase = b:CreateTexture(nil, "ARTWORK")
        b.nativeBase:SetAllPoints()
        b.nativeSelected = b:CreateTexture(nil, "ARTWORK", nil, 1)
        b.nativeSelected:SetAllPoints()
        b.slice = { parts = { b.nativeBase, b.nativeSelected } }
        function b.slice:SetShown(shown)
            b.nativeBase:SetShown(shown)
            if not shown then b.nativeSelected:Hide() end
        end
    else
        b.slice = CK.UIKit.nineSlice(b, prefix .. "_normal", role and 512 or 128, role and 128 or 32,
            role and 12 or 6, role and 8 or 6, "ARTWORK")
    end
    b.armedBox = K.Box(b, 4, 2, "ARTWORK", 2)
    b.armedBox:SetPoints(b)
    b.armedBox:SetColors(C.dangerBg, 1, C.danger, 1)
    b.armedBox:SetShown(false)
    b.label = K.Text(b, size or 15, C.tab)
    b.label:SetPoint("LEFT", 6, 0)
    b.label:SetPoint("RIGHT", -6, 0)
    b.label:SetJustifyH("CENTER")
    b.state = {}
    function b:SetState(state)
        self.state = state or {}
        if self.state.disabled then self:ClearPress() else self:Render() end
    end
    function b:Render()
        local st = self.state
        self.armedBox:SetShown(st.armed and true or false)
        self.slice:SetShown(not st.armed)
        if st.armed then
            self.label:SetTextColor(unpack(C.dangerText))
        else
            local on = not st.disabled and (st.active or st.focus)
            if native then
                local family = "common-button-list-" .. (role and "large" or (self:GetHeight() <= 34 and "small" or "mid"))
                local lit = not st.disabled and (self.hover or (not role and on))
                local atlas = family .. (lit and "-hover" or "")
                if self.nativeAtlas ~= atlas then self.nativeBase:SetAtlas(atlas, false); self.nativeAtlas = atlas end
                self.nativeSelected:SetShown(role and on and true or false)
                if role and self.selectedAtlas ~= family .. "-selected" then
                    self.nativeSelected:SetAtlas(family .. "-selected", false); self.selectedAtlas = family .. "-selected"
                end
                -- This family has no pressed artwork: dim only while the real
                -- mouse press or controller activation pulse is active.
                local brightness = self:IsPressed() and 0.70 or 1
                self.nativeBase:SetVertexColor(brightness, brightness, brightness)
                self.nativeSelected:SetVertexColor(brightness, brightness, brightness)
            else
                self.slice:SetFile(self:IsPressed() and prefix .. "_pressed" or (on and prefix .. "_active"
                    or (self.hover and not st.disabled and prefix .. "_hover" or prefix .. "_normal")))
            end
            self.label:SetTextColor(unpack(st.disabled and C.disabled or (on and C.focus or C.tab)))
        end
        self:SetAlpha(st.disabled and 0.45 or 1)
    end
    b:SetScript("OnEnter", function(self)
        self.hover = true
        self:Render()
    end)
    b:SetScript("OnLeave", function(self)
        self.hover = false
        self:Render()
    end)
    CK.UIKit.pressFeedback(b)
    if native then b:HookScript("OnSizeChanged", function(self) self:Render() end) end
    b:Render()
    return b
end

-- Buttons side by side in a row frame, each sized by its share ("flex") of
-- the row's width, with a gap between them
function K.LayoutRow(row, buttons, flexes, gap)
    local total = 0
    for i = 1, #buttons do total = total + (flexes[i] or 1) end
    local room, x = row:GetWidth() - gap * (#buttons - 1), 0
    for i, b in ipairs(buttons) do
        local w = room * (flexes[i] or 1) / total
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        b:SetSize(w, row:GetHeight())
        x = x + w + gap
    end
end

---------------------------------------------------------------------------
-- A round slot (ck_slot): the Gamepad screen's buttons (44, icon 32), the
-- wheel editor's slots (52, icon 38). An icon cut round on its dark disc,
-- a "+", stripes (unavailable), a coloured ring (a slot of the game's bar,
-- yours), a cyan diamond (yours), the focus glow, the target's dashed ring.
---------------------------------------------------------------------------
function K.Slot(parent, size, iconSize, square)
    -- Square (the D-pad's, like the game's gamepad bar) or round
    local sq = square and "_sq" or ""
    local s = CK.NewFrame("Button", nil, parent)
    s:SetSize(size, size)
    s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetTexture(TEX .. "ck_slot" .. sq)
    s.bg:SetAllPoints()
    s.disc = s:CreateTexture(nil, "ARTWORK", nil, 0)
    s.disc:SetTexture(TEX .. (square and "ck_sqr" or "ck_dot"))
    s.disc:SetSize(iconSize, iconSize)
    s.disc:SetPoint("CENTER")
    s.icon = (square and K.SquareIcon or K.RoundIcon)(s, iconSize, "ARTWORK")
    s.icon:SetDrawLayer("ARTWORK", 1)
    s.icon:SetPoint("CENTER")
    s.hatch = s:CreateTexture(nil, "ARTWORK", nil, 2)
    s.hatch:SetTexture(TEX .. "ck_hatch" .. sq)
    s.hatch:SetSize(iconSize, iconSize)
    s.hatch:SetPoint("CENTER")
    s.plus = K.Text(s, size >= 52 and 20 or 18, C.dimGold, "OVERLAY")
    s.plus:SetPoint("CENTER", 0, 1)
    s.plus:SetJustifyH("CENTER")
    s.plus:SetText("+")
    -- The ring: its outer edge on the slot's (a slot of the game's bar), or
    -- 1 px out (yours)
    s.ring = s:CreateTexture(nil, "OVERLAY", nil, 0)
    s.ring:SetTexture(TEX .. "ck_ring" .. sq)
    s.ring:SetPoint("CENTER")
    s.ring:SetSize(size, size)
    -- Yours: a cyan diamond with a dark edge, bottom left
    s.markEdge = s:CreateTexture(nil, "OVERLAY", nil, 1)
    s.markEdge:SetTexture(TEX .. "ck_diamond")
    s.markEdge:SetVertexColor(C.boxBg[1], C.boxBg[2], C.boxBg[3])
    s.markEdge:SetSize(16, 16)
    s.markEdge:SetPoint("CENTER", s, "BOTTOMLEFT", 2.5, 5.5)
    s.mark = s:CreateTexture(nil, "OVERLAY", nil, 2)
    s.mark:SetTexture(TEX .. "ck_diamond")
    s.mark:SetVertexColor(C.yours[1], C.yours[2], C.yours[3])
    s.mark:SetSize(13, 13)
    s.mark:SetPoint("CENTER", s.markEdge, "CENTER")
    s.glow = s:CreateTexture(nil, "OVERLAY", nil, 3)
    s.glow:SetTexture(TEX .. "ck_slot_glow" .. sq)
    s.glow:SetBlendMode("ADD")
    s.glow:SetSize(math.floor(size * 1.46 + 0.5), math.floor(size * 1.46 + 0.5))
    s.glow:SetPoint("CENTER")
    s.dash = s:CreateTexture(nil, "OVERLAY", nil, 4)
    s.dash:SetTexture(TEX .. "ck_ring_dash")
    s.dash:SetVertexColor(C.focus[1], C.focus[2], C.focus[3])
    s.dash:SetSize(size + 10, size + 10)
    s.dash:SetPoint("CENTER")
    s.dash:Hide()
    s.size = size
    -- look = { icon, desaturate, discColor, plus, hatch, ring = color, ringOut, mark, glow, dash }
    function s:SetLook(look)
        local icon = look.icon
        CK.Paddles.SetIcon(self.icon, icon)
        self.icon:SetShown(icon ~= nil)
        self.icon:SetDesaturated(look.desaturate and true or false)
        local dc = look.discColor
        self.disc:SetShown(dc ~= nil)
        if dc then self.disc:SetVertexColor(dc[1], dc[2], dc[3]) end
        self.plus:SetShown(look.plus and true or false)
        self.hatch:SetShown(look.hatch and true or false)
        self.ring:SetShown(look.ring ~= nil)
        if look.ring then
            self.ring:SetVertexColor(look.ring[1], look.ring[2], look.ring[3])
            local r = look.ringOut and self.size + 2 or self.size
            self.ring:SetSize(r, r)
        end
        self.mark:SetShown(look.mark and true or false)
        self.markEdge:SetShown(look.mark and true or false)
        self.glow:SetShown(look.glow and true or false)
        self.dash:SetShown(look.dash and true or false)
    end
    return s
end

-- A layer and an input: glyph keys for a GlyphRow ("RT", "+", "A"), or a
-- text with the glyphs in it
function K.ComboKeys(inputId, layer)
    local keys = {}
    for _, trigger in ipairs({ "LT", "RT" }) do
        if layer:find(trigger, 1, true) then
            keys[#keys + 1] = trigger
            keys[#keys + 1] = "+"
        end
    end
    keys[#keys + 1] = inputId
    return keys
end

function K.ComboMarkup(inputId, layer, size)
    local parts = {}
    for _, key in ipairs(K.ComboKeys(inputId, layer)) do
        if key ~= "+" then
            local glyph = K.INPUT_GLYPH[key] or key
            parts[#parts + 1] = IMAGE[glyph] and CK:GlyphMarkup(glyph, size) or K.ChipText(key)
        end
    end
    return table.concat(parts, " + ")
end
