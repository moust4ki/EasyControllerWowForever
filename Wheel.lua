local _, CK = ...
local L = CK.L

-- Input method "daisywheel": the left stick picks one of 8 petals, the right
-- stick flicks toward one of its 4 characters (left, top, right, bottom).
CK.Methods = CK.Methods or {}
local M = { key = "wheel", width = 340, areaWidth = 304, height = 304 }
CK.Methods.wheel = M

local LAYOUTS = {
    letters = {
        { "a", "b", "c", "d" },
        { "e", "f", "g", "h" },
        { "i", "j", "k", "l" },
        { "m", "n", "o", "p" },
        { "q", "r", "s", "t" },
        { "u", "v", "w", "x" },
        { "y", "z", "'", "-" },
        { ".", ",", "?", "!" },
    },
    symbols = {
        { "1", "2", "3", "4" },
        { "5", "6", "7", "8" },
        { "9", "0", "+", "=" },
        { "é", "è", "ê", "à" },
        { "ç", "ù", "â", "ô" },
        { "î", "û", "ë", "ï" },
        { ":", ";", "(", ")" },
        { "/", "@", "\"", "%" },
    },
}
CK.LAYOUTS = LAYOUTS

-- Petals 4 to 6 of the 123 layer hold the accents of the language
local accentLayouts = {}
local function layoutFor(layer)
    if layer ~= "symbols" then return LAYOUTS.letters end
    local accents = CK:Accents()
    local layout = accentLayouts[accents]
    if not layout then
        layout = {}
        for i, petal in ipairs(LAYOUTS.symbols) do layout[i] = petal end
        for p = 0, 2 do
            layout[4 + p] = { accents[p * 4 + 1], accents[p * 4 + 2], accents[p * 4 + 3], accents[p * 4 + 4] }
        end
        accentLayouts[accents] = layout
    end
    return layout
end

-- Pad buttons of this method (D-pad, A, B and right stick click are common)
M.buttons = {
    PADLSHOULDER = "Backspace",
    PADRSHOULDER = "Space",
    PADLTRIGGER = "ToggleShift",
    PADRTRIGGER = "ToggleSymbols",
    PADLSTICK = "ToggleSymbols",
}

function M:Help()
    return {
        { "LS", L.HELP_PETAL }, { "RS", L.HELP_LETTER }, { "LB", L.BACKSPACE }, { "RB", L.SPACE },
        { "LT", L.SHIFT }, { "RT", L.SYMBOLS },
    }
end

-- Native Forever stone and circular chrome surround the original eight
-- petals. Character positions and hitboxes retain the 304px input layout;
-- only the padded artwork extends beyond it (its visible rim stays inside).
local SIZE = 304
local S = SIZE / 512
local PETAL_R, CHAR_D = 160 * S, 28 * S
local HUB_SIZE, KEY_SIZE, RING_SIZE = 120 * S, 54 * S, 108 * S
local RIM_SIZE, FACE_SIZE, HUB_RIM_SIZE, HUB_FACE_SIZE = 352, 276, 132, 103
local PRESSED_TIME = 0.12
local SECTION = { 256 * RIM_SIZE / 512, 143 * RIM_SIZE / 512 }    -- the section overlays: their size, their centre's distance
local CHAR_FONT, HUB_FONT, LAYER_FONT = 16, 38, 10
-- Character offsets in a petal (WoW axes, y up): left, up, right, down
local CHAR_OFF = { { -CHAR_D, 0 }, { 0, CHAR_D }, { CHAR_D, 0 }, { 0, -CHAR_D } }
local COLORS = {
    normal = { 1, 0.82, 0 }, chosen = { 1, 0.91, 0.66 }, target = { 1, 0.96, 0.85 }, hover = { 1, 0.96, 0.85 },
    layer = { 0.79, 0.64, 0.29 },
}
local DIM_ALPHA = 0.65
local LEFT_IN, LEFT_OUT = 0.5, 0.35      -- petal selection deadzone (with hysteresis)

local function sector(x, y, count)
    local fromNorth = (90 - math.deg(math.atan2(y, x))) % 360
    local size = 360 / count
    return math.floor((fromNorth + size / 2) / size) % count
end

-- Petal i's angle (radians, clockwise from 12 o'clock) and centre (y up)
local function petalAngle(i) return (i - 1) * math.pi / 4 end
local function petalCenter(i)
    local a = petalAngle(i)
    return PETAL_R * math.sin(a), PETAL_R * math.cos(a)
end

-- A section overlay (ck_wheel_sel_8, ck_dw_dim: cut to section 1) on petal i
local function placeSection(tex, area, i)
    local a = petalAngle(i)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", area, "CENTER", SECTION[2] * math.sin(a), SECTION[2] * math.cos(a))
    tex:SetRotation(-a)
end

function M:Build(area)
    local K = CK.UIKit
    local function tex(parent, name, layer, sub, size)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(K.TEX .. name)
        if size then t:SetSize(size, size) end
        return t
    end
    local function native(parent, name, fallback, layer, sub, size, fallbackSize)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
            t:SetAtlas(name, false)
        elseif fallback then
            t:SetTexture(K.TEX .. fallback)
            size = fallbackSize or size
        end
        t:SetSize(size, size)
        t:SetPoint("CENTER")
        return t
    end
    local function mask(parent, anchor)
        local m = parent:CreateMaskTexture()
        m:SetAllPoints(anchor)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("ui-hud-minimap-frame-generic-mask") then
            m:SetAtlas("ui-hud-minimap-frame-generic-mask", false)
        else
            m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        return m
    end
    self.face = area:CreateTexture(nil, "BACKGROUND", nil, -3)
    self.face:SetPoint("CENTER"); self.face:SetSize(FACE_SIZE, FACE_SIZE)
    self.face:SetColorTexture(0.055, 0.04, 0.025, 1)
    self.material = tex(area, "ck_panel_bg", "BACKGROUND", -2)
    self.material:SetAllPoints(self.face)
    self.material:SetHorizTile(true); self.material:SetVertTile(true)
    self.material:SetVertexColor(0.72, 0.62, 0.48, 1)
    self.faceMask = mask(area, self.face)
    self.face:AddMaskTexture(self.faceMask); self.material:AddMaskTexture(self.faceMask)
    local bg = tex(area, "ck_wheel_bg_8", "BACKGROUND", 0)
    bg:SetPoint("CENTER"); bg:SetSize(RIM_SIZE, RIM_SIZE)
    bg:SetAlpha(0.60); bg:AddMaskTexture(self.faceMask)
    self.bg = bg
    self.rim = native(area, "UI-HUD-Minimap-Frame-Circle", nil, "ARTWORK", 3, RIM_SIZE)

    -- The other sections veiled, the chosen one lit
    self.dims = {}
    for i = 1, 8 do
        local d = tex(area, "ck_dw_dim", "ARTWORK", 1, SECTION[1])
        placeSection(d, area, i)
        d:AddMaskTexture(self.faceMask)
        d:Hide()
        self.dims[i] = d
    end
    self.section = tex(area, "ck_wheel_sel_8", "ARTWORK", 2, SECTION[1])
    self.section:AddMaskTexture(self.faceMask)
    self.section:Hide()

    self.petals = {}
    for i = 1, 8 do
        local px, py = petalCenter(i)
        local p = CK.NewFrame("Frame", nil, area)
        p:SetPoint("CENTER", area, "CENTER", px, py)
        p:SetSize(RING_SIZE, RING_SIZE)
        -- Variant "rings": the group's ring
        p.ring = native(p, "gamepad-actionbar-circleslot-border-normal", "ck_dw_ring", "BORDER", 0, RING_SIZE)
        -- The selected atlas includes 8px of glow on each side of its 64px ring.
        p.selectedRing = native(p, "gamepad-actionbar-circleslot-border-selected", "ck_dw_ring_sel", "BORDER", 1, RING_SIZE * 80 / 64, RING_SIZE)
        p.selectedRing:Hide()
        p.keys = {}
        for j = 1, 4 do
            local k = CK.NewFrame("Button", nil, p)
            k:SetSize(KEY_SIZE * 0.8, KEY_SIZE * 0.8)
            k:SetPoint("CENTER", p, "CENTER", CHAR_OFF[j][1], CHAR_OFF[j][2])
            k.hover = native(k, "gamepad-actionbar-circleslot-border-hover", "ck_reforged_slot_hover", "ARTWORK", 5, KEY_SIZE)
            k.hover:Hide()
            k.target = native(k, "gamepad-actionbar-circleslot-border-selected", "ck_reforged_slot_hover", "ARTWORK", 6, KEY_SIZE * 80 / 64, KEY_SIZE)
            k.target:Hide()
            k.press = native(k, "gamepad-actionbar-circleslot-border-pressed", "ck_reforged_slot_pressed", "ARTWORK", 7, KEY_SIZE)
            k.press:Hide()
            k.label = k:CreateFontString(nil, "OVERLAY")
            k.label:SetFont(CK:GetFontPath(), CHAR_FONT, "")
            k.label:SetPoint("CENTER", 0, 1)
            k.label:SetShadowOffset(1, -1)
            k:SetScript("OnClick", function() CK:TypeSlot(i, j) end)
            k:SetScript("OnEnter", function()
                M.hoverPetal, M.hoverChar = i, j
                M:Update()
            end)
            k:SetScript("OnLeave", function()
                if M.hoverPetal == i and M.hoverChar == j then
                    M.hoverPetal, M.hoverChar = nil, nil
                end
                M:Update()
            end)
            p.keys[j] = k
        end
        self.petals[i] = p
    end

    -- Hub: the aimed character in large, "123" under it on that layer
    local hub = CK.NewFrame("Frame", nil, area)
    hub:SetSize(HUB_SIZE, HUB_SIZE)
    hub:SetPoint("CENTER", area, "CENTER", 0, 0)
    hub:SetFrameLevel(area:GetFrameLevel() + 20)
    self.hubFace = hub:CreateTexture(nil, "BACKGROUND")
    self.hubFace:SetPoint("CENTER"); self.hubFace:SetSize(HUB_FACE_SIZE, HUB_FACE_SIZE)
    self.hubFace:SetColorTexture(0.035, 0.025, 0.016, 1)
    self.hubMask = mask(hub, self.hubFace)
    self.hubFace:AddMaskTexture(self.hubMask)
    self.hubTex = native(hub, "UI-HUD-Minimap-Frame-Circle", "ck_dw_hub", "ARTWORK", 3, HUB_RIM_SIZE)
    self.aimed = hub:CreateFontString(nil, "OVERLAY")
    self.aimed:SetFont(CK:GetFontPath(), HUB_FONT, "")
    self.aimed:SetPoint("CENTER", 0, 2)
    self.aimed:SetTextColor(unpack(COLORS.normal))
    self.aimed:SetShadowOffset(1, -1)
    self.aimed:SetShadowColor(0, 0, 0, 1)
    self.layerLabel = hub:CreateFontString(nil, "OVERLAY")
    self.layerLabel:SetFont(CK:GetFontPath(), LAYER_FONT, "")
    self.layerLabel:SetPoint("CENTER", 0, -24)
    self.layerLabel:SetTextColor(unpack(COLORS.layer))
    self.layerLabel:SetText("123")
    -- Switching input methods hides the old area without resetting it.
    area:HookScript("OnHide", function() M:Reset() end)
end

function M:Reset()
    self.petal, self.hoverPetal, self.hoverChar = nil, nil, nil
    for _, p in ipairs(self.petals or {}) do
        for _, k in ipairs(p.keys) do
            k.pressSerial = (k.pressSerial or 0) + 1
            k.activated = nil
            k.press:Hide()
        end
    end
end

function M:Flash(key)
    if not key then return end
    key.pressSerial = (key.pressSerial or 0) + 1
    local serial = key.pressSerial
    key.activated = true
    self:Update()
    C_Timer.After(PRESSED_TIME, function()
        if key.pressSerial ~= serial then return end
        key.activated = nil
        M:Update()
    end)
end

function CK:TypeSlot(petal, slot)
    local ch = layoutFor(self.state.layer)[petal][slot]
    if not ch then return end
    self:TypeChar(ch)
    M:Flash(M.petals and M.petals[petal].keys[slot])
end

function M:OnLeftStick(x, y)
    local len = math.sqrt(x * x + y * y)
    local petal
    if len >= LEFT_IN or (self.petal and len >= LEFT_OUT) then
        petal = sector(x, y, 8) + 1
    end
    if petal ~= self.petal then
        self.petal = petal
        self:Update()
    end
end

-- Right stick flick: the aimed character when a petal is picked, otherwise
-- the common navigation (see CK:SetRightStick)
function M:OnFlick(aim)
    if not self.petal then return false end
    CK:TypeSlot(self.petal, aim)
    return true
end

function M:Update()
    if not self.petals then return end
    local state = CK.state
    local layout = layoutFor(state.layer)
    local rings = CK.db.settings.petalRings ~= false
    local chosen = self.petal
    local font = CK:GetFontPath()

    -- The chosen section lit, the others veiled
    for i, d in ipairs(self.dims) do d:SetShown(chosen ~= nil and i ~= chosen) end
    self.section:SetShown(chosen ~= nil)
    if chosen then placeSection(self.section, self.area, chosen) end

    for i, p in ipairs(self.petals) do
        local selected = chosen == i
        local dimmed = chosen ~= nil and not selected
        p.ring:SetShown(rings)
        p.selectedRing:SetShown(rings and selected)
        if rings then p.ring:SetAlpha(dimmed and 0.55 or 1) end
        for j, k in ipairs(p.keys) do
            local aimed = selected and state.aim == j
            local mouse = self.hoverPetal == i and self.hoverChar == j
            local pressed = k.activated == true
            k.press:SetShown(pressed)
            k.target:SetShown(aimed and not pressed)
            k.hover:SetShown(mouse and not aimed and not pressed)
            k.label:SetFont(font, CHAR_FONT, "")
            k.label:SetText(CK:DisplayChar(layout[i][j]))
            k.label:SetPoint("CENTER", 0, pressed and 0 or 1)
            local color = (pressed or aimed) and COLORS.target or (mouse and COLORS.hover) or (selected and COLORS.chosen) or COLORS.normal
            k.label:SetTextColor(unpack(color))
            k.label:SetShadowColor(0, 0, 0, 1)
            k:SetAlpha((dimmed and not mouse and not pressed) and DIM_ALPHA or 1)
        end
    end

    -- The hub: the aimed character, lit; the one under the mouse, faint
    local aimedChar = chosen and state.aim and layout[chosen][state.aim]
    local hoverChar = not aimedChar and self.hoverPetal and layout[self.hoverPetal][self.hoverChar]
    local shown = aimedChar or hoverChar
    self.aimed:SetFont(font, HUB_FONT, "")
    self.aimed:SetShown(shown ~= nil)
    if shown then
        self.aimed:SetText(CK:DisplayChar(shown))
        self.aimed:SetAlpha(aimedChar and 1 or 0.55)
    end
    self.layerLabel:SetShown(state.layer == "symbols" and not shown)
end
