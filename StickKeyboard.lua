local _, CK = ...
local L = CK.L

-- Input method "split keyboard" (settings key "stick"): a full AZERTY / QWERTY
-- keyboard cut in two halves. The left stick moves a cursor on the left half
-- (columns 1-5), the right stick on the right half (columns 6-10); each
-- stick's tilt is its cursor's ABSOLUTE position around the center of its
-- half (released = center). LT types the left cursor's key, RT the right one.
CK.Methods = CK.Methods or {}
local M = { key = "stick", width = 600, areaWidth = 584 }
CK.Methods.stick = M

M.buttons = {
    PADLTRIGGER = "TypeLeft",
    PADRTRIGGER = "TypeRight",
    PADLSHOULDER = "Backspace",
    PADRSHOULDER = "Space",
    PADLSTICK = "ToggleSymbols",
}

function M:Help()
    return {
        { "LS", L.HELP_CURSOR_L }, { "RS", L.HELP_CURSOR_R }, { "LT", L.HELP_TYPE_L }, { "RT", L.HELP_TYPE_R },
        { "LB", L.BACKSPACE }, { "RB", L.SPACE },
    }
end

-- Keys: a character, or { k = special key } (their places: ROW_X below)
local function special(k, w) return { k = k, w = w } end
local SHIFT, BACK, LAYER, SPACE = special("SHIFT", 1.5), special("BACK", 1.5), special("LAYER", 1), special("SPACE", 4)
-- A key of the 123 layer showing the language's n-th accent (CK:Accents())
local function accent(n) return { acc = n } end

local LAYOUTS = {
    azerty = {
        { "a", "z", "e", "r", "t", "y", "u", "i", "o", "p" },
        { "q", "s", "d", "f", "g", "h", "j", "k", "l", "m" },
        { SHIFT, "w", "x", "c", "v", "b", "n", "'", BACK },
        { LAYER, ",", "-", SPACE, ".", "?", "!" },
    },
    qwerty = {
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
        { "a", "s", "d", "f", "g", "h", "j", "k", "l", "'" },
        { SHIFT, "z", "x", "c", "v", "b", "n", "m", BACK },
        { LAYER, ",", "-", SPACE, ".", "?", "!" },
    },
    qwertz = {
        { "q", "w", "e", "r", "t", "z", "u", "i", "o", "p" },
        { "a", "s", "d", "f", "g", "h", "j", "k", "l", "ö" },
        { SHIFT, "y", "x", "c", "v", "b", "n", "m", BACK },
        { LAYER, "ä", "ü", SPACE, "ß", ".", "," },
    },
    qwerty_es = {
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
        { "a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ" },
        { SHIFT, "z", "x", "c", "v", "b", "n", "m", BACK },
        { LAYER, ",", "-", SPACE, ".", "?", "!" },
    },
    qwerty_it = {
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
        { "a", "s", "d", "f", "g", "h", "j", "k", "l", "'" },
        { SHIFT, "z", "x", "c", "v", "b", "n", "m", BACK },
        { LAYER, ",", "è", SPACE, ".", "?", "!" },
    },
    symbols = {
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
        { accent(1), accent(2), accent(3), accent(4), accent(5), accent(6), accent(7), accent(8), accent(9), accent(10) },
        { SHIFT, accent(11), accent(12), "œ", "@", "/", ":", ";", BACK },
        { LAYER, "(", ")", SPACE, "\"", "%", "+" },
    },
}

-- The look (Claude Design, design/splitkb/): the key area 584 x 220, its two
-- halves (0-286, 298-584) with a gutter between, 4 rows of 50 at y 4, 58,
-- 112, 166, keys 54 wide on a 58 pitch, columns aligned in every row. Shift
-- and 123 are one key wide, Backspace two, Space 236 across the gutter.
local KEY_H = 50
local ROW_Y = { 4, 58, 112, 166 }
local ROW_X = {
    { { 0, 54 }, { 58, 54 }, { 116, 54 }, { 174, 54 }, { 232, 54 }, { 298, 54 }, { 356, 54 }, { 414, 54 }, { 472, 54 }, { 530, 54 } },
    { { 0, 54 }, { 58, 54 }, { 116, 54 }, { 174, 54 }, { 232, 54 }, { 298, 54 }, { 356, 54 }, { 414, 54 }, { 472, 54 }, { 530, 54 } },
    { { 0, 54 }, { 58, 54 }, { 116, 54 }, { 174, 54 }, { 232, 54 }, { 298, 54 }, { 356, 54 }, { 414, 54 }, { 472, 112 } },
    { { 0, 54 }, { 58, 54 }, { 116, 54 }, { 174, 236 }, { 414, 54 }, { 472, 54 }, { 530, 54 } },
}
M.height = 220
local HALF_L, HALF_R = 286, 298       -- the left half ends, the right one starts
local CENTER_Y = 110
-- Each half's center, and the cursor's reach around it. Full tilt puts the
-- cursor EDGE_IN px inside the half's edge keys, so an imperfect push still
-- reaches them.
local EDGE_IN = 6
local HALVES = {
    left = { cx = 143 },
    right = { cx = 441 },
}
local REACH_X, REACH_Y = 143 - EDGE_IN, 106 - EDGE_IN
-- Text colours by state
local COLOR = {
    char = { 1, 0.82, 0 }, special = { 0.85, 0.79, 0.63 }, lit = { 1, 0.94, 0.78 },
    hover = { 1, 0.96, 0.85 }, pressed = { 1, 0.94, 0.78 },
}
local PRESSED_TIME = 0.12
-- Per axis, from this tilt on the stick counts as pushed all the way: sticks
-- rarely report a full 1.0, and a round stick pushed diagonally only reaches
-- about 0.71 on each axis, which must still land on the corner keys
local AXIS_SATURATION = 0.72
-- Response curve exponent: 1 = linear, > 1 = gentle (precise near the center),
-- < 1 = fast (reaches the edges sooner)
local CURVES = { linear = 1, gentle = 1.6, fast = 0.7 }

local MAGNET_PX = { none = 0, weak = 4, medium = 8, strong = 14 }

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local function buildKey(parent, def, x, y, w)
    local K = CK.UIKit
    local b = CK.NewFrame("Button", nil, parent)
    K.place(b, parent, x, y, w, KEY_H)
    b.base = K.nineSlice(b, "ck_sk_key_normal", 128, 64, 12, 12, "BORDER")
    b.file = "ck_sk_key_normal"
    local isChar = type(def) == "string"
    b.accent = type(def) == "table" and def.acc or nil
    b.label = K.text(b, (isChar or b.accent) and 20 or 13)
    b.label:SetPoint("CENTER", 0, 1)
    b.label:SetShadowOffset(1, -1)
    b.char = isChar and def or nil
    b.special = type(def) == "table" and def.k or nil
    -- Center and size in area coordinates (y down), for the nearest-key search
    b.cx, b.cy, b.w, b.h = x + w / 2, y + KEY_H / 2, w, KEY_H
    -- Halves the key belongs to: a key straddling the middle (Space) is in both
    b.inHalf = { left = x < HALF_L, right = x + w > HALF_R }
    b:SetScript("OnClick", function() M:Press(b) end)
    b:SetScript("OnEnter", function() M.hover = b; M:Update() end)
    b:SetScript("OnLeave", function() M.hover = nil; M:Update() end)
    return b
end

function M:Build(area)
    local K = CK.UIKit
    self.sets = {}
    for name, rows in pairs(LAYOUTS) do
        local set = CK.NewFrame("Frame", nil, area)
        set:SetAllPoints()
        set.keys = {}
        for r, row in ipairs(rows) do
            for n, def in ipairs(row) do
                local place = ROW_X[r][n]
                set.keys[#set.keys + 1] = buildKey(set, def, place[1], ROW_Y[r], place[2])
            end
        end
        set:Hide()
        self.sets[name] = set
    end

    local divider = area:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(K.TEX .. "ck_sk_divider")
    K.place(divider, area, 284, 4, 16, 158)

    -- One cursor per half, with a line from the half's center, above the keys
    local over = CK.NewFrame("Frame", nil, area)
    over:SetAllPoints()
    over:SetFrameLevel(area:GetFrameLevel() + 30)
    self.over = over
    self.cursors = {}
    for side, half in pairs(HALVES) do
        local c = { side = side, homeX = half.cx }
        -- The line is optional: the keyboard works without it on a client lacking lines
        local line = over.CreateLine and over:CreateLine(nil, "OVERLAY", nil, -1)
        if line then
            line:SetThickness(2)
            line:SetColorTexture(0.902, 0.733, 0.467, 0.6)
            c.line = line
        end
        -- The half's centre (it never moves) and the cursor's dot
        c.hub = K.texture(over, "ck_sk_center", "OVERLAY")
        c.hub:SetSize(32, 32)
        c.hub:SetPoint("CENTER", over, "TOPLEFT", half.cx, -CENTER_Y)
        c.dot = K.texture(over, "ck_sk_cursor", "OVERLAY", 1)
        c.dot:SetSize(32, 32)
        self.cursors[side] = c
    end
    self:Reset()
end

---------------------------------------------------------------------------
-- Cursors
---------------------------------------------------------------------------
-- One axis: saturate, then apply the response curve (linear by default, so
-- the cursor moves the same distance for each notch of tilt: no acceleration)
local function axis(value, exponent)
    local a = math.min(math.abs(value) / AXIS_SATURATION, 1) ^ exponent
    return value < 0 and -a or a
end

function M:MoveCursor(side, x, y)
    local c = self.cursors and self.cursors[side]
    if not c then return end
    local dead = CK.db.settings.deadzone
    local len = math.sqrt(x * x + y * y)
    if CK.db.settings.debug and len > (c.maxLen or 0) then
        c.maxLen = len
        CK:Print("%s stick x=%.2f y=%.2f len=%.2f (max so far)", side, x, y, len)
    end
    -- Radial dead zone, then each axis on its own (a square response suits the
    -- rectangular keyboard and has none of the disc-to-square acceleration)
    local u, v = 0, 0
    if len > dead then
        local scale = (math.min(len, 1) - dead) / (1 - dead) / len
        u, v = x * scale, y * scale
    end
    local exponent = CURVES[CK.db.settings.stickCurve] or 1
    local sx, sy = axis(u, exponent), axis(v, exponent)
    c.cx, c.cy = c.homeX + sx * REACH_X, CENTER_Y - sy * REACH_Y
    self:Update()
end

function M:OnLeftStick(x, y) self:MoveCursor("left", x, y) end
function M:OnRightStick(x, y) self:MoveCursor("right", x, y) end

local function rectDistance(key, x, y)
    local dx = math.max(math.abs(x - key.cx) - key.w / 2, 0)
    local dy = math.max(math.abs(y - key.cy) - key.h / 2, 0)
    return math.sqrt(dx * dx + dy * dy), math.abs(x - key.cx) + math.abs(y - key.cy)
end

-- Nearest key of the cursor's half, with a magnet: the highlighted key only
-- changes when another one is clearly closer, so it does not flicker
function M:PickKey(set, c)
    local best, bestD, bestTie
    for _, key in ipairs(set.keys) do
        if key.inHalf[c.side] then
            local d, tie = rectDistance(key, c.cx, c.cy)
            if not best or d < bestD or (d == bestD and tie < bestTie) then
                best, bestD, bestTie = key, d, tie
            end
        end
    end
    local current = c.selected
    if current and current:GetParent() == set and current.inHalf[c.side] and best ~= current then
        local magnet = MAGNET_PX[CK.db.settings.magnet] or 8
        if rectDistance(current, c.cx, c.cy) <= bestD + magnet then return current end
    end
    return best
end

function M:ActiveSet()
    if CK.state.layer == "symbols" then return self.sets.symbols end
    return self.sets[CK.db.settings.kbLayout] or self.sets.azerty
end

function M:Reset()
    if not self.cursors then return end
    for _, c in pairs(self.cursors) do
        c.cx, c.cy, c.selected = c.homeX, CENTER_Y, nil
    end
end

---------------------------------------------------------------------------
-- Typing
---------------------------------------------------------------------------
function M:Press(key)
    if not key then return end
    if key.char then
        CK:TypeChar(key.char)
    elseif key.special == "SHIFT" then
        CK:ToggleShift()
    elseif key.special == "BACK" then
        CK:Backspace()
    elseif key.special == "LAYER" then
        CK:ToggleSymbols()
    elseif key.special == "SPACE" then
        CK:Space()
    end
end

-- LT / RT: the binding gives one press per pull of the trigger, so one letter
function M:Flash(key)
    if not key then return end
    local untilTime = GetTime() + PRESSED_TIME
    key.pressedUntil = untilTime
    self:Update()
    C_Timer.After(PRESSED_TIME, function()
        if key.pressedUntil == untilTime then key.pressedUntil = nil end
        if M.sets then M:Update() end
    end)
end

function CK:TypeLeft()
    if self:GetMethod() == M and M.cursors then
        local key = M.cursors.left.selected
        M:Flash(key)
        M:Press(key)
    end
end

function CK:TypeRight()
    if self:GetMethod() == M and M.cursors then
        local key = M.cursors.right.selected
        M:Flash(key)
        M:Press(key)
    end
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
local SPECIAL_LABEL = { SHIFT = "SHIFT", BACK = "BACKSPACE", SPACE = "SPACE" }

function M:Update()
    if not self.sets then return end
    local K = CK.UIKit
    local state = CK.state
    local set = self:ActiveSet()
    for _, s in pairs(self.sets) do s:SetShown(s == set) end

    local left, right = self.cursors.left, self.cursors.right
    left.selected = self:PickKey(set, left)
    right.selected = self:PickKey(set, right)
    local shiftOn = state.shift or state.caps
    local accents = CK:Accents()

    local now = GetTime()
    for _, key in ipairs(set.keys) do
        local selected = key == left.selected or key == right.selected
        local active = (key.special == "SHIFT" and shiftOn) or (key.special == "LAYER" and state.layer == "symbols")
        local pressed = key.pressedUntil and now < key.pressedUntil
        local file = pressed and "ck_sk_key_pressed"
            or (key == left.selected and "ck_sk_key_target_l")
            or (key == right.selected and "ck_sk_key_target_r")
            or (active and "ck_sk_key_active")
            or (key == self.hover and "ck_sk_key_hover")
            or "ck_sk_key_normal"
        if file ~= key.file then
            key.base:SetFile(file)
            key.file = file
        end

        if key.accent then key.char = accents[key.accent] end
        if key.char then
            key.label:SetText(CK:DisplayChar(key.char))
        elseif key.special == "LAYER" then
            key.label:SetText(state.layer == "symbols" and L.LETTERS or L.SYMBOLS)
        else
            key.label:SetText(L[SPECIAL_LABEL[key.special]])
        end
        local color = pressed and COLOR.pressed or ((selected or active) and COLOR.lit)
            or (key == self.hover and COLOR.hover) or ((key.char or key.accent) and COLOR.char) or COLOR.special
        key.label:SetTextColor(unpack(color))
        key.label:SetShadowColor(0, 0, 0, pressed and 0 or 1)
    end

    local showLine = CK.db.settings.showLine
    for _, c in pairs(self.cursors) do
        c.dot:ClearAllPoints()
        c.dot:SetPoint("CENTER", self.over, "TOPLEFT", c.cx, -c.cy)
        if c.line then
            -- Not when the cursor rests on the centre
            local moved = math.abs(c.cx - c.homeX) > 1 or math.abs(c.cy - CENTER_Y) > 1
            c.line:SetShown(showLine and moved)
            c.line:SetStartPoint("TOPLEFT", self.over, c.homeX, -CENTER_Y)
            c.line:SetEndPoint("TOPLEFT", self.over, c.cx, -c.cy)
        end
    end
end
