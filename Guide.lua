local _, CK = ...
local L = CK.L

-- The first launch guide (asked): 6 screens over the configuration panel,
-- shown once on a new install (not to those who already set the addon up),
-- again from Home > Guide or /ec welcome. Every choice is the panel's own
-- setting, saved at once; the guide has no "cancel all". It is a layer over
-- the panel's window (the panel keeps the pad and passes the presses here),
-- with its own header and help bar. Layout and pictures: design/onboarding
-- (README.md: places in pixels from the window's top left).
--
-- Modes: "normal"; "identify" (the back paddles, then the touchpad buttons
-- turned on, each pressed when asked); "bind" (a wheel's key: the button or
-- combination pressed next); "preview" (the gamepad bar's size, the window
-- made small at the top of the screen so the bar shows behind it).
local G = {}
CK.Guide = G

local K = CK.ConfigKit
local KC = K.C
local TEX = K.TEX
local W, H = 820, 580
local STEPS = 6
local VERSION = 1
-- The classes that heal: the healer's block (screen 5)
local HEALERS = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }
local IDENTIFY_WAIT = 5
local BIND_WAIT = 10

local function settings() return CK.db.settings end
local function C() return CK.Config end
local function M() return CK.Mapping end
local function P() return CK.Paddles end
local function Wheel() return CK.ConsumableWheel end

---------------------------------------------------------------------------
-- Drawing helpers: places from the top left, as the design gives them
---------------------------------------------------------------------------
local function at(region, parent, x, y, w, h)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if w then region:SetWidth(w) end
    if h then region:SetHeight(h) end
    return region
end

-- Friz (titles, labels)
local function text(parent, size, color, x, y)
    local fs = K.Text(parent, size, color)
    if x then at(fs, parent, x, y) end
    return fs
end

-- The chat's font (help texts), wrapped in its width
local function help(parent, size, color, x, y, w)
    local fs = K.ChatText(parent, size or 14, color or KC.help)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if x then at(fs, parent, x, y) end
    if w then
        fs:SetWidth(w)
        fs:SetWordWrap(true)
    end
    return fs
end

local function image(parent, name, x, y, w, h, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(TEX .. name)
    at(t, parent, x, y, w, h)
    return t
end

-- A glow over its picture (same place and size), lit by its alpha
local function glow(parent, name, x, y, w, h)
    local t = image(parent, name, x, y, w, h, "OVERLAY")
    t:SetBlendMode("ADD")
    t:SetAlpha(0)
    return t
end

local function rule(parent, x, y, w, h)
    local t = K.Solid(parent, KC.line3, 1, "ARTWORK")
    at(t, parent, x, y, w or 1, h or 1)
    return t
end

-- A rounded box on a frame (edge 1 px)
local function box(frame, fill, fillAlpha, edge, edgeAlpha)
    local b = K.Box(frame, 4, 1, "BACKGROUND")
    b:SetPoints(frame)
    b:SetColors(fill, fillAlpha or 1, edge, edgeAlpha or 1)
    return b
end

local function frameAt(parent, kind, x, y, w, h)
    local f = CK.NewFrame(kind or "Frame", nil, parent)
    at(f, parent, x, y, w, h)
    return f
end

-- The focus look (gold edge) or the plain one
local function focusLook(b, focused)
    if focused then
        b:SetColors(KC.nowBg, 1, KC.focus, 1)
    else
        b:SetColors(KC.controlBg, 1, KC.line1, 1)
    end
end

---------------------------------------------------------------------------
-- Controls. Each: frame (a click is an A on it), draw(c, focused), and as
-- needed press(c) for A, adjust(c, delta) with lr = true (left / right
-- change it), enabled(c), shown(c) (hidden ones take no focus), verbA(c)
---------------------------------------------------------------------------
local function add(screen, c)
    screen.controls[#screen.controls + 1] = c
    c.screen = screen
    if c.frame then
        c.frame:SetScript("OnClick", function() G:Click(c) end)
    end
    return c
end

local function enabled(c)
    return not c.enabled or c.enabled(c) and true or false
end

local function shown(c)
    return not c.shown or c.shown(c) and true or false
end

-- A button of the panel's look (primary: the gold text when not focused)
local function button(screen, parent, label, x, y, w, h, primary, onPress)
    local b = K.Button(parent, h and h < 40 and 15 or 16)
    at(b, parent, x, y, w, h or 40)
    b.label:SetText(label)
    local c = add(screen, { frame = b, press = onPress })
    function c.verbA() return L.V_CONFIRM end
    function c.draw(self, focused)
        local live = enabled(self)
        b:SetState({ focus = focused, disabled = not live })
        if primary and live and not focused then b.label:SetTextColor(unpack(KC.title)) end
    end
    return c
end

-- A check box: its box (20 x 20), its label, its help under it
local function check(screen, parent, x, y, w, label, helpText, get, set)
    local f = frameAt(parent, "Button", x, y, w, 34)
    f.bg = box(f, KC.nowBg, 0, KC.focus, 0)
    f.boxFrame = frameAt(f, "Frame", 8, 7, 20, 20)
    f.box = K.Box(f.boxFrame, 3, 2, "ARTWORK")
    f.box:SetPoints(f.boxFrame)
    -- (on the box's own frame, over its fill, as the panel's)
    f.tick = f.boxFrame:CreateTexture(nil, "OVERLAY")
    f.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    f.tick:SetSize(26, 26)
    f.tick:SetPoint("CENTER", f.boxFrame, "CENTER", 0, 0)
    f.tick:SetVertexColor(unpack(KC.focus))
    f.label = text(f, 16, KC.cream, 38, 8)
    f.label:SetText(label)
    if helpText then
        f.help = help(f, 14, KC.help, 38, 30, w - 50)
        f.help:SetText(helpText)
    end
    local c = add(screen, { frame = f, get = get, set = set })
    function c.press(self)
        self.set(not self.get())
        return true
    end
    function c.verbA(self) return self.get() and L.GUIDE_UNTICK or L.GUIDE_TICK end
    function c.draw(self, focused)
        local on, live = self.get() and true or false, enabled(self)
        f.bg:SetColors(KC.nowBg, focused and 1 or 0, KC.focus, focused and 1 or 0)
        f.box:SetColors(KC.controlBg, 1, focused and KC.focus or KC.boxEdge, 1)
        f.tick:SetShown(on)
        f.label:SetTextColor(unpack(not live and KC.disabled or (focused and KC.focusText or KC.cream)))
        f:SetAlpha(live and 1 or 0.5)
        f:SetHeight(f.help and math.max(34, 30 + (f.help:GetStringHeight() or 0) + 8) or 34)
    end
    return c
end

-- An on / off switch: a pill 40 x 20, its knob right when on
local function switch(parent, x, y)
    local s = frameAt(parent, "Frame", x, y, 40, 20)
    s.pill = K.Box(s, 4, 1, "ARTWORK")
    s.pill:SetPoints(s)
    s.knob = s:CreateTexture(nil, "OVERLAY")
    s.knob:SetTexture(TEX .. "ck_dot")
    s.knob:SetSize(13, 13)
    function s:Set(on, focused)
        self.pill:SetColors(on and { 0.18, 0.14, 0.06 } or KC.controlBg, 1,
            focused and KC.focus or (on and KC.dimGold or KC.line1), 1)
        self.knob:SetVertexColor(unpack(on and KC.focus or KC.disabled))
        self.knob:ClearAllPoints()
        self.knob:SetPoint(on and "RIGHT" or "LEFT", self, on and "RIGHT" or "LEFT", on and -4 or 4, 0)
    end
    return s
end

-- A line with a label (and its help) and a switch at its right
local function switchLine(screen, parent, x, y, w, h, label, helpText, get, set)
    local f = frameAt(parent, "Button", x, y, w, h)
    f.bg = box(f, KC.nowBg, 0, KC.focus, 0)
    f.label = text(f, 16, KC.cream, 12, helpText and 8 or (h - 16) / 2)
    if helpText then
        f.help = help(f, 14, KC.help, 12, 30, w - 80)
        f.help:SetText(helpText)
    end
    f.sw = switch(f, w - 52, (h - 20) / 2)
    local c = add(screen, { frame = f, get = get, set = set })
    function c.press(self)
        self.set(not self.get())
        return true
    end
    function c.verbA(self) return self.get() and L.GUIDE_TURN_OFF or L.GUIDE_TURN_ON end
    function c.draw(self, focused)
        local on = self.get() and true or false
        f.bg:SetColors(KC.nowBg, focused and 1 or 0, KC.focus, focused and 1 or 0)
        f.sw:Set(on, focused)
        f.label:SetText(type(label) == "function" and label(on) or label)
        f.label:SetTextColor(unpack(focused and KC.focusText or KC.cream))
    end
    return c
end

-- < value >: left / right (or A) change it
local function selector(screen, parent, x, y, w, getText, step)
    local f = frameAt(parent, "Button", x, y, w, 32)
    f.bg = box(f, KC.controlBg, 1, KC.line1, 1)
    f.left = text(f, 16, KC.dimGold)
    f.left:SetPoint("LEFT", 10, 0)
    f.left:SetText("<")
    f.right = text(f, 16, KC.dimGold)
    f.right:SetPoint("RIGHT", -10, 0)
    f.right:SetText(">")
    f.value = text(f, 15, KC.cream)
    f.value:SetPoint("LEFT", 26, 0)
    f.value:SetPoint("RIGHT", -26, 0)
    f.value:SetJustifyH("CENTER")
    local c = add(screen, { frame = f, lr = true })
    function c.adjust(_, d)
        step(d)
        return true
    end
    function c.press()
        step(1)
        return true
    end
    function c.verbA() return L.V_CHANGE end
    function c.draw(self, focused)
        local live = enabled(self)
        focusLook(f.bg, focused)
        f.value:SetText(getText())
        f.value:SetTextColor(unpack(not live and KC.disabled or (focused and KC.focus or KC.cream)))
        f.left:SetTextColor(unpack(focused and KC.focus or KC.dimGold))
        f.right:SetTextColor(unpack(focused and KC.focus or KC.dimGold))
        f:SetAlpha(live and 1 or 0.4)
    end
    return c
end

local function stepIn(list, current, d)
    local index = 1
    for i, e in ipairs(list) do
        if e.key == current then index = i end
    end
    return list[(index - 1 + d) % #list + 1]
end

local function nameIn(list, current)
    for _, e in ipairs(list) do
        if e.key == current then return e.name end
    end
    return list[1].name
end

---------------------------------------------------------------------------
-- The window: a layer over the panel's, its header and help bar
---------------------------------------------------------------------------
function G:Build()
    if self.frame then return end
    local panel = C().frame
    local o = CK.NewFrame("Frame", "ControllerKeyboardGuide", panel)
    o:SetAllPoints(panel)
    o:SetFrameLevel(panel:GetFrameLevel() + 60)
    o:EnableMouse(true)
    K.Panel(o)
    -- Header
    o.kicker = text(o, 11, KC.dimGold, 24, 14)
    o.title = text(o, 22, KC.title, 24, 29)
    o.close = K.Button(o, 14)
    o.close:SetSize(30, 28)
    o.close:SetPoint("TOPRIGHT", -20, -18)
    o.close.label:SetText("X")
    o.close:SetScript("OnClick", function() G:Later() end)
    o.count = help(o, 14, KC.help)
    o.count:SetPoint("RIGHT", o.close, "LEFT", -12, 0)
    o.dots = {}
    for i = 1, STEPS do o.dots[i] = o:CreateTexture(nil, "ARTWORK") end
    o.headRule = rule(o, 16, 62, W - 32)
    -- Help bar: the crumb on the left, the hints on the right
    o.bar = CK.NewFrame("Frame", nil, o)
    o.bar:SetSize(W - 4, 46)
    local bg = K.Solid(o.bar, KC.panel, 1, "BACKGROUND")
    bg:SetAllPoints()
    rule(o.bar, 0, 0, W - 4)
    o.crumb = K.ChatText(o.bar, 13, KC.grey)
    o.crumb:SetPoint("LEFT", 22, 0)
    o.crumb:SetWordWrap(false)
    o.hints = {}
    self.frame = o
    self.screens = {}
    for i = 1, STEPS do
        local s = { index = i, controls = {} }
        s.frame = CK.NewFrame("Frame", nil, o)
        s.frame:SetAllPoints(o)
        s.frame:Hide()
        self["BuildScreen" .. i](self, s, s.frame)
        self.screens[i] = s
    end
    self:BuildPreview(o)
    o:SetScript("OnUpdate", function() G:OnUpdate() end)
    o:Hide()
end

---------------------------------------------------------------------------
-- 1. Welcome, your controller
---------------------------------------------------------------------------
local GLYPH_STYLES = {
    { key = "xbox", name = "Xbox" },
    { key = "playstation", name = "PlayStation" },
    { key = "switch", name = "Switch" },
}

function G:BuildScreen1(s, f)
    image(f, "ck_onb_welcome", 24, 72, 384, 192)
    for i = 1, 3 do
        local y = 276 + (i - 1) * 40
        local d = f:CreateTexture(nil, "ARTWORK")
        d:SetTexture(TEX .. "ck_diamond")
        d:SetVertexColor(unpack(KC.dimGold))
        at(d, f, 24, y + 6, 8, 8)
        help(f, 16, KC.cream, 40, y, 368):SetText(L["GUIDE_WELCOME_" .. i])
    end
    -- The panel's shortcut
    local sc = frameAt(f, "Frame", 24, 404, 384, 58)
    box(sc, KC.controlBg, 1, KC.line3, 1)
    text(sc, 15, KC.cream2, 14, 10):SetText(L.GUIDE_SHORTCUT)
    s.shortcut = help(sc, 14, KC.help, 14, 33, 356)
    -- The buttons' icons
    text(f, 16, KC.title, 428, 72):SetText(L.GUIDE_GLYPHS)
    help(f, 14, KC.help, 428, 94, 368):SetText(L.GUIDE_GLYPHS_HELP)
    s.radios = {}
    for n, style in ipairs(GLYPH_STYLES) do
        local r = frameAt(f, "Button", 428, 122 + (n - 1) * 56, 368, 48)
        r.bg = box(r, KC.controlBg, 1, KC.line1, 1)
        r.ring = r:CreateTexture(nil, "ARTWORK")
        r.ring:SetTexture(TEX .. "ck_ring")
        r.ring:SetSize(16, 16)
        r.ring:SetPoint("LEFT", 14, 0)
        r.dot = r:CreateTexture(nil, "OVERLAY")
        r.dot:SetTexture(TEX .. "ck_dot")
        r.dot:SetSize(8, 8)
        r.dot:SetPoint("CENTER", r.ring, "CENTER")
        r.dot:SetVertexColor(unpack(KC.focus))
        r.label = text(r, 16, KC.cream)
        r.label:SetPoint("LEFT", 40, 0)
        r.label:SetText(style.name)
        -- A, B, X, Y (bottom, right, left, top) in that style
        r.glyphs = {}
        for i, key in ipairs({ "Y", "X", "B", "A" }) do
            local g = r:CreateTexture(nil, "ARTWORK")
            g:SetSize(24, 24)
            g:SetPoint("RIGHT", -14 - (i - 1) * 30, 0)
            r.glyphs[key] = g
        end
        local c = add(s, { frame = r, style = style.key })
        function c.press(self)
            settings().glyphStyle = self.style
            CK:UpdateGlyphs()
            return true
        end
        function c.verbA() return L.V_CHOOSE end
        function c.draw(self, focused)
            local on = settings().glyphStyle == self.style
            focusLook(r.bg, focused)
            r.ring:SetVertexColor(unpack(on and KC.focus or KC.boxEdge))
            r.dot:SetShown(on)
            r.label:SetTextColor(unpack(focused and KC.focus or KC.cream))
            for key, g in pairs(r.glyphs) do CK:SetGlyph(g, key, self.style) end
        end
        s.radios[n] = c
    end
    -- The tip
    local tip = frameAt(f, "Frame", 428, 304, 368, 150)
    box(tip, KC.yours, 0.06, KC.info, 0.45)
    text(tip, 15, KC.info, 14, 12):SetText(L.GUIDE_TIP)
    help(tip, 14, KC.cream2, 14, 36, 340):SetText(L.GUIDE_TIP_STEAM)
    button(s, f, L.GUIDE_LATER, 428, 468, 156, 40, false, function() G:Later() end)
    button(s, f, L.GUIDE_START, 596, 468, 200, 40, true, function() G:Go(2) end)
    function s.enter()
        local chord = settings().shortcut or CK.DEFAULT_SHORTCUT
        s.shortcut:SetText(format(L.GUIDE_SHORTCUT_KEYS, M():ChordLabel(chord)))
    end
    -- First focus: the style in use
    function s.first()
        for _, c in ipairs(s.radios) do
            if settings().glyphStyle == c.style then return c end
        end
        return s.radios[1]
    end
end

---------------------------------------------------------------------------
-- 2. Back paddles and touchpads
---------------------------------------------------------------------------
-- (the pictures' full names: the packaging checks every one is shipped)
local PADDLE_GLOW = { L4 = "ck_onb_paddles_l4_glow", R4 = "ck_onb_paddles_r4_glow",
    L5 = "ck_onb_paddles_l5_glow", R5 = "ck_onb_paddles_r5_glow" }
local ZONES = { "up", "right", "down", "left" }
local ZONE_GLOW = { "ck_onb_touchpad_up_glow", "ck_onb_touchpad_right_glow", "ck_onb_touchpad_down_glow",
    "ck_onb_touchpad_left_glow" }

-- A touchpad on: its 4 buttons turned on
local function touchSide(side)
    local on = settings().touchButtons
    if type(on) ~= "table" then return false end
    for n = 1, 4 do
        if on["T" .. side .. n] ~= true then return false end
    end
    return true
end

local function setTouchSide(side, v)
    local s = settings()
    s.touchButtons = s.touchButtons or {}
    for n = 1, 4 do s.touchButtons["T" .. side .. n] = v or nil end
    M():Apply()
    P():Apply()
end

local function mappingOn() return settings().modules.mapping and true or false end

function G:BuildScreen2(s, f)
    text(f, 16, KC.title, 24, 72):SetText(L.GUIDE_PADDLES)
    image(f, "ck_onb_paddles", 24, 100, 400, 200)
    s.paddlesGlow = glow(f, "ck_onb_paddles_glow", 24, 100, 400, 200)
    s.paddleGlow = {}
    for id, name in pairs(PADDLE_GLOW) do
        s.paddleGlow[id] = glow(f, name, 24, 100, 400, 200)
    end
    s.paddlesHelp = help(f, 14, KC.help, 24, 308, 400)
    s.paddlesHelp:SetText(L.GUIDE_PADDLES_HELP)
    s.identify = button(s, f, L.GUIDE_IDENTIFY, 24, 360, 260, 40, false, function() G:StartIdentify() end)
    -- While identifying (2b): what is asked
    local ask = frameAt(f, "Frame", 24, 308, 400, 90)
    box(ask, KC.nowBg, 1, KC.focus, 1)
    ask.title = text(ask, 22, KC.focus, 16, 12)
    ask.help = help(ask, 14, KC.cream2, 16, 44, 368)
    ask.dots = {}
    ask:Hide()
    s.ask = ask
    -- What was recognised
    s.found = help(f, 14, KC.done, 24, 404, 400)
    -- Touchpads
    s.right = CK.NewFrame("Frame", nil, f)
    s.right:SetAllPoints(f)
    text(s.right, 16, KC.title, 448, 72):SetText(L.GUIDE_TOUCH)
    image(s.right, "ck_onb_touchpad", 448, 100, 160, 160)
    s.zoneGlow = {}
    for n, name in ipairs(ZONE_GLOW) do
        s.zoneGlow[n] = glow(s.right, name, 448, 100, 160, 160)
    end
    for i, side in ipairs({ "L", "R" }) do
        local c = check(s, s.right, 624, 112 + (i - 1) * 46, 172, L["GUIDE_TOUCH_" .. side], nil,
            function() return touchSide(side) end,
            function(v)
                setTouchSide(side, v)
                if v then G.zonesAt = GetTime() end
            end)
        c.enabled = mappingOn
    end
    help(s.right, 14, KC.help, 448, 272, 348):SetText(L.GUIDE_TOUCH_HELP)
    s.rule = rule(f, 24, 424, 772)
    s.rt = check(s, f, 24, 438, 772, L.LBL_RT_MODIFIER, L.GUIDE_RT_HELP,
        function() return M():TriggerModifier("PADRTRIGGER") ~= nil end,
        function(v) M():SetTriggerModifier("PADRTRIGGER", v) end)
    s.rt.enabled = function() return M():CanBeModifier("PADRTRIGGER") and true or false end
    function s.first() return s.identify end
end

---------------------------------------------------------------------------
-- 2b. Each paddle (then each touchpad button turned on) pressed when asked;
-- 5 seconds with nothing: the next one. X skips, B stops.
---------------------------------------------------------------------------
local function askHelp(id)
    local side, n = id:match("^T([LR])(%d)$")
    if side then
        return format(L.GUIDE_ASK_TOUCH, L["GUIDE_TOUCH_" .. side], L["GUIDE_ZONE_" .. ZONES[tonumber(n)]:upper()])
    end
    return L["GUIDE_ASK_" .. id] or ""
end

function G:StartIdentify()
    if CK:BlockedByCombat() then return end
    self.mode = "identify"
    self.queue = P():Order()
    self.queueAt = 1
    self.found = {}
    self:AskNext()
end

function G:AskNext()
    local id = self.queue[self.queueAt]
    if not id then return self:EndIdentify(true) end
    local asked = { id = id }
    self.asked, self.askedAt = asked, GetTime()
    P():Capture(id, function(key)
        if G.asked ~= asked then return end
        if key then G.found[#G.found + 1] = id end
        G.queueAt = G.queueAt + 1
        G:AskNext()
    end)
    self:Render()
end

function G:EndIdentify(done)
    self.asked = nil
    if P():IsCapturing() then P():StopCapture(nil) end
    self.mode = "normal"
    if done then
        C():Toast(#self.found > 0 and format(L.GUIDE_IDENTIFIED, table.concat(self.found, ", "))
            or L.GUIDE_IDENTIFIED_NONE, #self.found == 0)
    end
    self:Render()
end

---------------------------------------------------------------------------
-- 3. The gamepad bar
---------------------------------------------------------------------------
-- The size's slider: 70 to 150 %, the value saved before the preview marked
local function slider(screen, parent, x, y, w)
    local MIN, MAX = P().BAR_SCALE_MIN, P().BAR_SCALE_MAX
    local f = frameAt(parent, "Button", x, y, w, 64)
    f.bg = box(f, KC.controlBg, 1, KC.line1, 1)
    f.min = help(f, 14, KC.help)
    f.min:SetPoint("LEFT", 18, 0)
    f.min:SetText(format("%d %%", MIN * 100 + 0.5))
    f.value = text(f, 20, KC.focus)
    f.value:SetPoint("RIGHT", -18, 0)
    f.value:SetWidth(72)
    f.value:SetJustifyH("RIGHT")
    f.max = help(f, 14, KC.help)
    f.max:SetPoint("RIGHT", f.value, "LEFT", -16, 0)
    f.max:SetText(format("%d %%", MAX * 100 + 0.5))
    f.rail = CK.NewFrame("Frame", nil, f)
    f.rail:SetHeight(8)
    f.railBox = K.Box(f.rail, 3, 2, "ARTWORK")
    f.railBox:SetPoints(f.rail)
    f.railBox:SetColors(KC.controlBg, 1, KC.line1, 1)
    f.fill = K.Solid(f.rail, KC.fill, 1, "ARTWORK", 3)
    f.fill:SetPoint("LEFT", f.rail, "LEFT", 1, 0)
    f.fill:SetHeight(6)
    f.mark = K.Solid(f.rail, KC.boxEdge, 1, "ARTWORK", 4)
    f.mark:SetSize(1, 6)
    f.handle = f.rail:CreateTexture(nil, "OVERLAY")
    f.handle:SetTexture(TEX .. "ck_dot")
    f.handle:SetSize(20, 20)
    local c = add(screen, { frame = f, lr = true })
    function c.adjust(_, d)
        G:Preview(d)
        return true
    end
    function c.press()
        G:Preview(0)
        return true
    end
    function c.verbA() return L.GUIDE_PREVIEW end
    function c.draw(_, focused)
        focusLook(f.bg, focused)
        local k = P():BarScale()
        f.value:SetText(format("%d %%", k * 100 + 0.5))
        -- The rail between "70 %" and "150 %", its width worked out here (a
        -- width from its anchors may not be known yet the first time)
        local left = 18 + (f.min:GetStringWidth() or 0) + 16
        local width = math.max(40, w - left - (18 + 72 + 16 + (f.max:GetStringWidth() or 0) + 16))
        f.rail:ClearAllPoints()
        f.rail:SetPoint("LEFT", f, "LEFT", left, 0)
        f.rail:SetWidth(width)
        local t = (k - MIN) / (MAX - MIN)
        f.fill:SetWidth(math.max(1, (width - 2) * t))
        f.handle:ClearAllPoints()
        f.handle:SetPoint("CENTER", f.rail, "LEFT", width * t, 0)
        f.handle:SetVertexColor(unpack(focused and KC.focus or KC.dimGold))
        local saved = G.previewFrom or k
        f.mark:ClearAllPoints()
        f.mark:SetPoint("TOP", f.rail, "BOTTOMLEFT", width * (saved - MIN) / (MAX - MIN), -3)
    end
    return c
end

function G:BuildScreen3(s, f)
    text(f, 16, KC.title, 24, 72):SetText(L.GUIDE_BAR_SIZE)
    s.slider = slider(s, f, 24, 100, 772)
    help(f, 14, KC.help, 24, 174, 772):SetText(L.GUIDE_BAR_SIZE_HELP)
    s.toggle = check(s, f, 24, 226, 496, L.LBL_TRIGGER_TOGGLE, L.GUIDE_TOGGLE_HELP,
        function() return settings().features.triggerToggle == true end,
        function(v)
            settings().features.triggerToggle = v
            M():Apply()
        end)
    s.toggle.enabled = mappingOn
    image(f, "ck_onb_toggle", 540, 214, 256, 128)
    s.toggleGlow = glow(f, "ck_onb_toggle_glow", 540, 214, 256, 128)
    -- Edit Mode's compact bar: the warning, the button turning it on (asked)
    local warn = frameAt(f, "Frame", 24, 364, 772, 150)
    box(warn, KC.warn, 0.06, KC.warn, 0.55)
    text(warn, 16, KC.warn, 16, 14):SetText(L.GUIDE_EDITMODE_TITLE)
    help(warn, 14, KC.cream2, 16, 40, 500):SetText(format(L.GUIDE_EDITMODE_TEXT, LAYOUT_STYLE_GAMEPAD or "Gamepad"))
    s.compact = button(s, warn, L.GUIDE_COMPACT_ON, 532, 44, 224, 38, false, function()
        G:SetCompact(not P().CompactBar())
    end)
    s.compact.shown = function() return G:CanSetCompact() end
    s.compactNote = help(warn, 12, KC.grey, 532, 90, 224)
    s.compactNote:SetText(L.GUIDE_COMPACT_RELOAD)
    function s.first() return s.slider end
    function s.render()
        local can = G:CanSetCompact()
        s.compact.frame:SetShown(can)
        s.compactNote:SetShown(can)
        s.compact.frame.label:SetText(P().CompactBar() and L.GUIDE_COMPACT_OFF or L.GUIDE_COMPACT_ON)
    end
end

---------------------------------------------------------------------------
-- 3c. The compact bar (asked): Edit Mode's setting of the gamepad bar
-- (system 30) in the layout in use. The game's Gamepad layout can't change:
-- a copy of it is made ("Easy Controller"), as Edit Mode does. Saved with
-- the game's own functions, then the interface reloaded: no Edit Mode frame
-- or method is used from here (its taint would spread to the bar), the
-- reload applies the layout as the game loads it. The game's bug (patch of
-- 9 October: that bar dropped at the next launch) is said on the screen.
---------------------------------------------------------------------------
local COMPACT_LAYOUT = "Easy Controller"

local function compactIds()
    local E = Enum
    return E and E.EditModeSystem and E.EditModeSystem.GamepadMainActionBar,
        E and E.EditModeGamepadMainActionBarSetting and E.EditModeGamepadMainActionBarSetting.Compact,
        E and E.InputDeviceInterfaceType and E.InputDeviceInterfaceType.Gamepad
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = deepCopy(v) end
    return c
end

function G:CanSetCompact()
    local system, setting, gamepad = compactIds()
    return system ~= nil and setting ~= nil and gamepad ~= nil and C_EditMode ~= nil
        and C_EditMode.GetLayouts ~= nil and C_EditMode.SaveLayouts ~= nil
        and EditModePresetLayoutManager ~= nil and P().EditModeBar()
end

-- The layouts (the game's ones first, then the saved ones, as Edit Mode
-- keeps them) with the compact bar on or off in the one in use: { layouts,
-- activeLayout }, the index of that layout, whether it is new. nil and why
-- when it can't ("notGamepad": the layout in use isn't a gamepad one)
function G.CompactLayouts(on)
    local SYSTEM, COMPACT, GAMEPAD = compactIds()
    local PRESET = Enum.EditModeLayoutType.Preset
    local saved = C_EditMode.GetLayouts()
    local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    local layouts = {}
    for _, l in ipairs(presets) do layouts[#layouts + 1] = l end
    for _, l in ipairs(saved.layouts or {}) do layouts[#layouts + 1] = l end
    local gamepadPreset
    for _, l in ipairs(presets) do
        if l.interfaceStyle == GAMEPAD then gamepadPreset = l end
    end
    local index, isNew = saved.activeLayout, false
    local target = layouts[index]
    if not (gamepadPreset and target and target.interfaceStyle == GAMEPAD) then return nil, "notGamepad" end
    if target.layoutType == PRESET then
        -- Ours from before, else a new copy of the Gamepad layout, put
        -- after the account's layouts (the character's if those are full)
        index = nil
        for i, l in ipairs(layouts) do
            if l.layoutType ~= PRESET and l.layoutName == COMPACT_LAYOUT and l.interfaceStyle == GAMEPAD then index = i end
        end
        if index then
            target = layouts[index]
        else
            local ACCOUNT, CHARACTER = Enum.EditModeLayoutType.Account, Enum.EditModeLayoutType.Character
            local max = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType or 5
            local count, last = { [ACCOUNT] = 0, [CHARACTER] = 0 }, {}
            for i, l in ipairs(layouts) do
                if count[l.layoutType] then
                    count[l.layoutType] = count[l.layoutType] + 1
                    last[l.layoutType] = i
                end
            end
            local kind = count[ACCOUNT] < max and ACCOUNT or (count[CHARACTER] < max and CHARACTER) or nil
            if not kind then return nil, "full" end
            index = (last[kind] or (kind == CHARACTER and last[ACCOUNT]) or #presets) + 1
            target = deepCopy(gamepadPreset)
            target.layoutType, target.layoutName = kind, COMPACT_LAYOUT
            table.insert(layouts, index, target)
            isNew = true
        end
    end
    -- The bar in it (put back from the Gamepad layout if the game dropped it)
    local bar
    for _, sys in ipairs(target.systems) do
        if sys.system == SYSTEM then bar = sys end
    end
    if not bar then
        for _, sys in ipairs(gamepadPreset.systems) do
            if sys.system == SYSTEM then bar = deepCopy(sys) end
        end
        if not bar then return nil, "notGamepad" end
        target.systems[#target.systems + 1] = bar
    end
    local found
    for _, st in ipairs(bar.settings) do
        if st.setting == COMPACT then
            st.value = on and 1 or 0
            found = true
        end
    end
    if not found then bar.settings[#bar.settings + 1] = { setting = COMPACT, value = on and 1 or 0 } end
    return { layouts = layouts, activeLayout = saved.activeLayout }, index, isNew
end

-- Saved, the layout made the one in use, the interface reloaded; the guide
-- back at this step after it
function G:SetCompact(on)
    if CK:BlockedByCombat() then return end
    local info, index, isNew
    if self:CanSetCompact() then
        local ok, a, b, c = pcall(G.CompactLayouts, on)
        if ok then info, index, isNew = a, b, c end
    end
    if not info then
        return C():Toast(index == "notGamepad" and format(L.GUIDE_COMPACT_NOT_GAMEPAD, LAYOUT_STYLE_GAMEPAD or "Gamepad")
            or L.GUIDE_COMPACT_UNAVAILABLE, true)
    end
    C_EditMode.SaveLayouts(info)
    if isNew then
        C_EditMode.OnLayoutAdded(index, true, false)
    elseif index ~= info.activeLayout then
        C_EditMode.SetActiveLayout(index)
    end
    CK.db.onboarding = CK.db.onboarding or {}
    CK.db.onboarding.resume = self.step
    local reload = C_UI and C_UI.Reload or ReloadUI
    reload()
end

-- 3b: the window small, the bar's size changed live
function G:BuildPreview(o)
    local p = CK.NewFrame("Frame", nil, o)
    p:SetAllPoints(o)
    p:Hide()
    text(p, 18, KC.title, 24, 14):SetText(L.GUIDE_BAR_SIZE)
    p.count = help(p, 14, KC.help)
    p.count:SetPoint("TOPRIGHT", -24, -16)
    local s = { controls = {} }
    p.slider = slider(s, p, 24, 46, 772)
    self.previewScreen = s
    self.previewFrame = p
end

-- Is the game's gamepad bar in the top half of the screen?
local function barHigh()
    local bar = GamepadMainActionBarFrame
    if not (bar and bar.GetCenter) then return false end
    local _, y = bar:GetCenter()
    local h = UIParent:GetHeight()
    if not (y and h and h > 0) then return false end
    y = y * (bar:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    return y > h / 2
end

-- A size step (or A on the size): the window made small first, at the top
-- of the screen (at the bottom when the bar is up there)
function G:Preview(d)
    if self.mode ~= "preview" then
        if CK:BlockedByCombat() then return end
        self.mode = "preview"
        self.previewFrom = P():BarScale()
        local f = C().frame
        self.savedPoint = { f:GetPoint(1) }
        -- (the panel's own body and help bar stay out of the small window)
        f.body:Hide()
        f.bar:Hide()
        f:SetHeight(176)
        f:ClearAllPoints()
        if barHigh() then
            f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 24)
        else
            f:SetPoint("TOP", UIParent, "TOP", 0, -24)
        end
    end
    if d ~= 0 then P():ScaleBar(d) end
    self:Render()
end

-- A keeps the size, B puts back the one before; the window as it was
function G:EndPreview(keep)
    if self.mode ~= "preview" then return end
    if not keep and self.previewFrom then
        settings().barScale = self.previewFrom
        P():ApplyBarOffset()
    end
    self.mode, self.previewFrom = "normal", nil
    local f = C().frame
    f:SetHeight(H)
    f:ClearAllPoints()
    local p = self.savedPoint
    if p and p[1] then
        f:SetPoint(p[1], p[2] or UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    end
    f.body:Show()
    f.bar:Show()
    self:Render()
end

---------------------------------------------------------------------------
-- 4. The chat keyboard
---------------------------------------------------------------------------
local LAYOUTS = {
    { key = "azerty", name = "AZERTY" }, { key = "qwerty", name = "QWERTY" },
    { key = "qwertz", name = "QWERTZ" }, { key = "qwerty_es", name = "QWERTY (español)" },
    { key = "qwerty_it", name = "QWERTY (italiano)" },
}

local function keyboardOn() return settings().modules.keyboard and true or false end

local function stepLanguage(d)
    local key = CK:GetLanguage().key
    local index = 1
    for i, lang in ipairs(CK.LANGUAGES) do
        if lang.key == key then index = i end
    end
    CK:SetLanguage(CK.LANGUAGES[(index - 1 + d) % #CK.LANGUAGES + 1].key)
end

function G:BuildScreen4(s, f)
    s.module = switchLine(s, f, 24, 72, 772, 52, L.LBL_CHAT_KEYBOARD, L.GUIDE_KEYBOARD_HELP,
        keyboardOn,
        function(v)
            settings().modules.keyboard = v
            if not v then CK:Close("keyboard module off") end
        end)
    local function card(method, x, title, desc, art)
        -- (smaller than the design's: the quick phrases under them, asked)
        local cf = frameAt(f, "Button", x, 132, 378, 296)
        cf.bg = K.Box(cf, 4, 2, "BACKGROUND")
        cf.bg:SetPoints(cf)
        cf.art = image(cf, art, 133, 10, 112, 112)
        cf.title = text(cf, 18, KC.title, 18, 128)
        cf.title:SetText(title)
        cf.ring = cf:CreateTexture(nil, "ARTWORK")
        cf.ring:SetTexture(TEX .. "ck_ring")
        cf.ring:SetSize(16, 16)
        cf.ring:SetPoint("TOPRIGHT", -18, -130)
        cf.dot = cf:CreateTexture(nil, "OVERLAY")
        cf.dot:SetTexture(TEX .. "ck_dot")
        cf.dot:SetSize(8, 8)
        cf.dot:SetPoint("CENTER", cf.ring, "CENTER")
        cf.dot:SetVertexColor(unpack(KC.focus))
        help(cf, 14, KC.cream2, 18, 156, 342):SetText(desc)
        cf.note = help(cf, 13, KC.disabled, 18, 256, 342)
        cf.note:SetText(L.GUIDE_CARD_PICK)
        local c = add(s, { frame = cf, method = method, enabled = keyboardOn })
        function c.press(self)
            CK:SetInputMethod(self.method)
            return true
        end
        function c.verbA() return L.V_CHOOSE end
        function c.draw(self, focused)
            local chosen, live = settings().inputMethod == self.method, keyboardOn()
            if focused then
                cf.bg:SetColors({ 0.16, 0.13, 0.05 }, 1, KC.focus, 1)
            else
                cf.bg:SetColors(chosen and { 0.11, 0.08, 0.04 } or KC.controlBg, 1, chosen and KC.dimGold or KC.line1, 1)
            end
            cf.ring:SetVertexColor(unpack(chosen and KC.focus or KC.boxEdge))
            cf.dot:SetShown(chosen)
            cf.note:SetShown(not chosen)
            cf:SetAlpha(live and 1 or 0.35)
            cf.art:SetAlpha(chosen and 1 or 0.7)
        end
        return cf
    end
    local wheelCard = card("wheel", 24, L.METHOD_WHEEL, L.GUIDE_DAISY_TEXT, "ck_onb_daisywheel")
    local stickCard = card("stick", 418, L.METHOD_STICK, L.GUIDE_SPLIT_TEXT, "ck_onb_splitkb")
    -- The chosen card's options, at its bottom
    local function option(cardFrame, method, y, label, getText, step)
        local lab = help(cardFrame, 14, KC.help, 18, y + 8)
        lab:SetText(label)
        local c = selector(s, cardFrame, 114, y, 246, getText, step)
        c.enabled = keyboardOn
        c.shown = function() return settings().inputMethod == method end
        c.label = lab
        return c
    end
    local function language() return CK:GetLanguage().name end
    s.options = {
        option(wheelCard, "wheel", 212, L.LBL_DW_LOOK,
            function() return settings().petalRings and L.DW_LOOK_RINGS or L.DW_LOOK_PLAIN end,
            function()
                settings().petalRings = not settings().petalRings
                CK:UpdateMethod()
            end),
        option(wheelCard, "wheel", 252, L.LBL_SUGGESTIONS, language, stepLanguage),
        option(stickCard, "stick", 212, L.LBL_LAYOUT,
            function() return nameIn(LAYOUTS, settings().kbLayout) end,
            function(d)
                settings().kbLayout = stepIn(LAYOUTS, settings().kbLayout, d).key
                CK:UpdateMethod()
            end),
        option(stickCard, "stick", 252, L.LBL_SUGGESTIONS, language, stepLanguage),
    }
    -- The quick phrases (asked: little used, their settings unclear): what
    -- they are, their key given here as a wheel's (they send without the
    -- keyboard too: never greyed with it)
    local qp = frameAt(f, "Frame", 24, 436, 772, 88)
    box(qp, KC.panel, 1, KC.line1, 1)
    local icon = qp:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(CK.Phrases and CK.Phrases.ICON or "Interface\\Icons\\UI_Chat")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    at(icon, qp, 16, 18, 48, 48)
    text(qp, 16, KC.title, 78, 10):SetText(L.PHRASES_NAME)
    help(qp, 13, KC.help, 78, 32, 456):SetText(L.GUIDE_PHRASES_TEXT)
    s.phrasesKey = button(s, qp, L.GUIDE_PICK_KEY, 552, 14, 204, 34, false, function() G:StartBind("wheel:phrases") end)
    s.phrasesLine = help(qp, 13, KC.help, 552, 54, 204)
    function s.first() return s.module end
    function s.render()
        for _, c in ipairs(s.options) do
            local on = shown(c)
            c.frame:SetShown(on)
            c.label:SetShown(on)
        end
        local keys = G.KeysOf("wheel:phrases")
        if #keys > 0 then
            s.phrasesLine:SetText(format(L.GUIDE_KEY_IS, table.concat(keys, ", ", 1, math.min(2, #keys))))
            s.phrasesLine:SetTextColor(unpack(KC.cream2))
        else
            s.phrasesLine:SetText(L.GUIDE_NO_KEY)
            s.phrasesLine:SetTextColor(unpack(KC.disabled))
        end
    end
end

---------------------------------------------------------------------------
-- 5. The wheels, the healer's
---------------------------------------------------------------------------
-- The keys a wheel is on now ("UP", "LT + Y"...), as glyphs
local function keysOf(action)
    local found = {}
    for _, input in ipairs(M().INPUTS) do
        if M():InputEnabled(input) and not input.layer then
            for _, layer in ipairs(M().LAYERS) do
                if M():Get(input.id, layer) == action or M():GetReplaced(input.id, layer) == action then
                    found[#found + 1] = K.ComboMarkup(input.id, layer, 16)
                end
            end
        end
    end
    return found
end
G.KeysOf = keysOf

local function isHealer()
    local _, class = UnitClass("player")
    return HEALERS[class or ""] == true
end

function G:BuildScreen5(s, f)
    s.cards = {}
    local function wheelCard(x, action, title, desc, art, get, set)
        local cf = frameAt(f, "Frame", x, 72, 378, 172)
        box(cf, KC.panel, 1, KC.line1, 1)
        cf.art = image(cf, art, 16, 16, 112, 112)
        text(cf, 16, KC.title, 144, 12):SetText(title)
        help(cf, 13, KC.help, 144, 34, 222):SetText(desc)
        switchLine(s, cf, 136, 88, 234, 30, function(on) return on and L.GUIDE_WHEEL_ON or L.GUIDE_WHEEL_OFF end,
            nil, get, set)
        local key = button(s, cf, L.GUIDE_PICK_KEY, 144, 126, 222, 34, false, function() G:StartBind(action) end)
        key.enabled = get
        cf.keyLine = help(cf, 13, KC.help, 16, 136, 120)
        cf.action, cf.get = action, get
        s.cards[#s.cards + 1] = cf
    end
    wheelCard(24, "wheel:consumables", L.WHEEL_NAME, L.GUIDE_WHEEL_C_TEXT, "ck_onb_wheel_consumables",
        function() return settings().wheel.enabled and true or false end,
        function(v)
            settings().wheel.enabled = v
            Wheel():Fill()
        end)
    wheelCard(418, "wheel:usable", L.USABLE_WHEEL_NAME, L.GUIDE_WHEEL_U_TEXT, "ck_onb_wheel_usable",
        function() return settings().wheel.usableEnabled ~= false end,
        function(v)
            settings().wheel.usableEnabled = v
            Wheel():Fill()
        end)
    -- How every wheel opens, said in full (asked: "Hold to show" wasn't
    -- clear); the stick that aims: Wheels > Opening
    check(s, f, 24, 252, 772, L.GUIDE_HOLD, L.GUIDE_HOLD_HELP,
        function() return settings().wheel.hold and true or false end,
        function(v)
            settings().wheel.hold = v
            Wheel():Fill()
        end)
    rule(f, 24, 328, 772)
    -- The healer's: a party wheel on a button (the healing classes), how to
    -- set it explained (asked: no button leaving the guide)
    local hb = frameAt(f, "Frame", 24, 336, 772, 180)
    box(hb, KC.panel, 1, KC.bronze, 1)
    image(hb, "ck_onb_wheel_party", 16, 16, 144, 144)
    text(hb, 18, KC.title, 180, 16):SetText(L.GUIDE_HEALER)
    local chip = help(hb, 12, KC.grey)
    chip:SetPoint("TOPRIGHT", -18, -20)
    chip:SetText(L.GUIDE_HEALER_CHIP)
    help(hb, 14, KC.cream2, 180, 46, 574):SetText(L.GUIDE_HEALER_TEXT)
    help(hb, 14, KC.info, 180, 128, 574):SetText(L.GUIDE_HEALER_HOW)
    s.healerBlock = hb
    -- The others: what the wheels do by themselves
    local auto = frameAt(f, "Frame", 24, 336, 772, 120)
    box(auto, KC.yours, 0.06, KC.info, 0.45)
    text(auto, 15, KC.info, 16, 14):SetText(L.GUIDE_AUTO_TITLE)
    help(auto, 14, KC.cream2, 16, 40, 740):SetText(L.GUIDE_AUTO_TEXT)
    s.autoBlock = auto
    function s.first() return s.controls[1] end
    function s.render()
        local healer = isHealer()
        hb:SetShown(healer)
        auto:SetShown(not healer)
        for _, card in ipairs(s.cards) do
            local keys = keysOf(card.action)
            if #keys > 0 then
                card.keyLine:SetText(format(L.GUIDE_KEY_IS, table.concat(keys, ", ", 1, math.min(2, #keys))))
                card.keyLine:SetTextColor(unpack(KC.cream2))
            else
                card.keyLine:SetText(L.GUIDE_NO_KEY)
                card.keyLine:SetTextColor(unpack(KC.disabled))
            end
            card.art:SetAlpha(card.get() and 1 or 0.6)
        end
    end
end

---------------------------------------------------------------------------
-- 5b. A wheel's key: the button pressed next (LT / RT held for their
-- layers) or a paddle; B cancels. Put like the Gamepad tab puts a wheel.
---------------------------------------------------------------------------
-- Never a wheel's key: the triggers, Start, Select, the system button
local NOT_A_KEY = { PADLTRIGGER = true, PADRTRIGGER = true, PADFORWARD = true, PADBACK = true, PADSYSTEM = true,
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true,
    UNKNOWN = true }

-- The input a key is: a gamepad button by its own key, a paddle or a
-- touchpad button turned on by the key it learned
local function inputOf(key)
    for _, input in ipairs(M().INPUTS) do
        if M():InputEnabled(input) and not input.layer and M():InputKey(input) == key then return input end
    end
end
G.InputOf = inputOf

-- The triggers, as the layer's letters
local TRIGGER_OF = { PADLTRIGGER = "LT", PADRTRIGGER = "RT" }
-- Alone, the game's own (jump, interact, inspect): never taken here, a
-- wrong layer read would replace them (B alone cancels)
local GAME_ALONE = { PAD1 = true, PAD3 = true, PAD4 = true }

-- A trigger down on the controller itself (its buttons as the game maps them)
local function padHeld(button)
    local G2 = C_GamePad
    local id = G2 and G2.GetActiveDeviceID and G2.GetActiveDeviceID()
    local state = id and G2.GetDeviceMappedState and G2.GetDeviceMappedState(id)
    local index = state and state.buttons and G2.ButtonBindingToIndex and G2.ButtonBindingToIndex(button)
    return index ~= nil and state.buttons[index + 1] and true or false
end

-- The layer of the press: the triggers this wait saw go down (it keeps
-- them from the game, and from the trigger toggle), or held on the pad
function G:BindLayer()
    local held = self.bindHeld or {}
    local lt = held.LT or padHeld("PADLTRIGGER")
    local rt = held.RT or padHeld("PADRTRIGGER")
    return (lt and "LT" or "") .. (rt and "RT" or "")
end

function G:StartBind(action)
    if CK:BlockedByCombat() then return end
    self.mode = "bind"
    self.binding = action
    self.bindAt = GetTime()
    self.bindHeld, self.bindWhy = {}, nil
    local f = self.capture
    if not f then
        f = CK.NewFrame("Frame", nil, UIParent)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetSize(1, 1)
        f:SetPoint("CENTER")
        if f.EnableGamePadButton then
            -- (false: the button stops here, not passed on to the game)
            f:SetScript("OnGamePadButtonDown", function(_, button)
                G:BindPressed(button)
                return false
            end)
            -- A trigger let go: its layer no more (its release ours too)
            f:SetScript("OnGamePadButtonUp", function(_, button)
                local t = TRIGGER_OF[button]
                if not t then return true end
                if G.bindHeld then G.bindHeld[t] = nil end
                return false
            end)
        end
        f:SetScript("OnKeyDown", function(_, key) G:BindPressed(key) end)
        f:Hide()
        self.capture = f
    end
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(false)
    if f.EnableGamePadButton then f:EnableGamePadButton(true) end
    f:Show()
    self:Render()
end

function G:EndBind()
    local f = self.capture
    if f and f:IsShown() then
        f:Hide()
        if not InCombatLockdown() then
            f:EnableKeyboard(false)
            if f.EnableGamePadButton then f:EnableGamePadButton(false) end
        end
    end
    self.mode, self.binding, self.bindHeld, self.bindWhy = "normal", nil, nil, nil
    self:Render()
end

-- Refused: why, kept in the help bar while it still waits (more time given)
function G:BindRefused(why)
    self.bindWhy = why
    self.bindAt = GetTime()
    self:Render()
end

function G:BindPressed(key)
    if self.mode ~= "bind" then return end
    local trigger = TRIGGER_OF[key]
    if trigger then
        self.bindHeld[trigger] = true
        return
    end
    if NOT_A_KEY[key] then return end
    -- (its release, should it reach the panel's keys, is no press: B goes back)
    C():Swallow({ [key] = true })
    local layer = self:BindLayer()
    -- B alone cancels (reported: LT + RT + B cancelled); with a trigger, a key
    if key == "ESCAPE" or (key == "PAD2" and layer == "") then return self:EndBind() end
    local input = inputOf(key)
    if not input then return self:BindRefused(L.GUIDE_KEY_UNKNOWN) end
    local combo = K.ComboMarkup(input.id, layer, 14)
    if layer == "" and GAME_ALONE[key] then return self:BindRefused(format(L.GUIDE_KEY_ALONE, combo)) end
    local page = CK.MapPage
    local cell = page:Cell(input, layer)
    if cell.lockedAlone or (cell.state == "off" and not cell.pick) then
        return self:BindRefused(cell.why or format(L.GUIDE_KEY_REFUSED, combo))
    end
    if page:Put(input, layer, self.binding) then
        C():Toast(format(L.TOAST_ON, M():ActionName(self.binding) or "", combo))
        self:EndBind()
    else
        self:BindRefused(not M():Enabled() and L.MAP_MODULE_OFF
            or (not M():CanOwnKeys() and L.MAP_REPLACE_NO_MOD) or format(L.GUIDE_KEY_REFUSED, combo))
    end
end

---------------------------------------------------------------------------
-- 6. Comfort, and off you go
---------------------------------------------------------------------------
local COMFORT = {
    { label = "LBL_RANGE_TINT", help = "GUIDE_C_RANGE", icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
        get = function() return settings().features.rangeTint == true end,
        set = function(v)
            settings().features.rangeTint = v
            CK.Range:Apply()
        end },
    { label = "SEC_QUESTITEMS", help = "GUIDE_C_QUEST", icon = "Interface\\Icons\\INV_Misc_Note_01",
        get = function() return settings().modules.questItems and true or false end,
        set = function(v)
            settings().modules.questItems = v
            if v then
                CK.QuestItems:ScanBags()
                CK.QuestItems:ScanQuests()
            end
            CK.QuestItems:RefreshBorders()
        end },
    { label = "LBL_UPGRADES", help = "GUIDE_C_UPGRADES", icon = "Interface\\Icons\\INV_Chest_Chain_05",
        get = function() return settings().modules.upgrades and true or false end,
        set = function(v)
            settings().modules.upgrades = v
            CK.Upgrades:Refresh()
        end },
    { label = "LBL_SUPPLY_BUTTONS", help = "GUIDE_C_SUPPLIES", icon = "Interface\\Icons\\INV_Misc_Bag_08",
        get = function() return settings().supplies.enabled and true or false end,
        set = function(v)
            settings().supplies.enabled = v
            CK.Supplies:Refresh()
        end },
    { label = "GUIDE_C_JUNK_LABEL", help = "GUIDE_C_JUNK", icon = "Interface\\Icons\\INV_Misc_Coin_02",
        get = function() return settings().modules.sellJunk and settings().modules.autoRepair and true or false end,
        set = function(v)
            settings().modules.sellJunk = v
            settings().modules.autoRepair = v
        end },
    { label = "SEC_VIBRATIONS", help = "GUIDE_C_VIBRATIONS", icon = "Interface\\Icons\\Spell_Nature_Earthquake",
        get = function() return settings().vibration.enabled and true or false end,
        set = function(v)
            local V = CK.Vibration
            V:Settings().enabled = v
            if v then V:Play("pulse") else V:Stop() end
        end },
    { label = "LBL_STAY_SEATED", help = "GUIDE_C_SEATED", icon = "Interface\\Icons\\INV_Misc_Food_15",
        get = function() return settings().wheel.staySeated and true or false end,
        set = function(v)
            settings().wheel.staySeated = v
            if not v and Wheel().seated then Wheel().seated:Hide() end
        end },
}

-- A comfort line: its game icon, label and help, its box at the right
local function comfortRow(screen, parent, e)
    local f = frameAt(parent, "Button", 24, 100, 452, 54)
    f.bg = box(f, KC.nowBg, 0, KC.focus, 0)
    local frame = frameAt(f, "Frame", 14, 11, 32, 32)
    box(frame, KC.controlBg, 1, KC.line1, 1)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(e.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER")
    f.label = text(f, 15, KC.cream, 58, 8)
    f.label:SetText(L[e.label])
    f.help = help(f, 13, KC.help, 58, 27, 452 - 58 - 46)
    f.help:SetText(L[e.help])
    f.boxFrame = frameAt(f, "Frame", 452 - 14 - 20, 17, 20, 20)
    f.box = K.Box(f.boxFrame, 3, 2, "ARTWORK")
    f.box:SetPoints(f.boxFrame)
    -- (on the box's own frame, over its fill, as the panel's)
    f.tick = f.boxFrame:CreateTexture(nil, "OVERLAY")
    f.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    f.tick:SetSize(26, 26)
    f.tick:SetPoint("CENTER", f.boxFrame, "CENTER", 0, 0)
    f.tick:SetVertexColor(unpack(KC.focus))
    f.rule = K.Solid(f, KC.line3, 1, "ARTWORK")
    f.rule:SetPoint("BOTTOMLEFT", 0, 0)
    f.rule:SetPoint("BOTTOMRIGHT", 0, 0)
    f.rule:SetHeight(1)
    local c = add(screen, { frame = f, get = e.get, set = e.set })
    function c.press(self)
        self.set(not self.get())
        return true
    end
    function c.verbA(self) return self.get() and L.GUIDE_UNTICK or L.GUIDE_TICK end
    function c.draw(self, focused)
        local on = self.get() and true or false
        f.bg:SetColors(KC.nowBg, focused and 1 or 0, KC.focus, focused and 1 or 0)
        f.box:SetColors(KC.controlBg, 1, focused and KC.focus or KC.boxEdge, 1)
        f.tick:SetShown(on)
        f.label:SetTextColor(unpack(focused and KC.focusText or KC.cream))
        f:SetHeight(math.max(54, 27 + (f.help:GetStringHeight() or 0) + 10))
    end
    return c
end

function G:BuildScreen6(s, f)
    text(f, 16, KC.title, 24, 72):SetText(L.GUIDE_COMFORT)
    s.rows = {}
    for i, e in ipairs(COMFORT) do s.rows[i] = comfortRow(s, f, e) end
    rule(f, 492, 72, 1, 444)
    image(f, "ck_onb_done", 584, 72, 128, 128)
    text(f, 15, KC.title, 508, 212):SetText(L.GUIDE_SUMMARY)
    s.summary = {}
    for i = 1, 6 do
        local y = 238 + (i - 1) * 22
        local key = help(f, 14, KC.grey, 508, y)
        local value = help(f, 14, KC.cream2, 612, y)
        value:SetWidth(184)
        value:SetWordWrap(false)
        s.summary[i] = { key, value }
    end
    button(s, f, L.GUIDE_PLACE_SPELLS, 508, 388, 288, 40, false, function() G:Finish("gamepad") end)
    button(s, f, L.GUIDE_FINISH, 508, 438, 288, 40, true, function() G:Finish() end)
    help(f, 13, KC.grey, 508, 492, 288):SetText(L.GUIDE_AGAIN)
    function s.first() return s.rows[1] end
    -- The rows one under the other, each as tall as its help
    function s.layout()
        local y = 100
        for _, c in ipairs(s.rows) do
            at(c.frame, f, 24, y)
            y = y + c.frame:GetHeight()
        end
    end
    function s.render()
        local st = settings()
        local paddles, pads = 0, {}
        for _, id in ipairs(P().ORDER) do
            if P():Identified(id) then paddles = paddles + 1 end
        end
        for _, side in ipairs({ "L", "R" }) do
            if touchSide(side) then pads[#pads + 1] = L["GUIDE_TOUCH_" .. side] end
        end
        local wheels = {}
        if st.wheel.enabled then wheels[#wheels + 1] = L.GUIDE_SUM_CONSUMABLES end
        if st.wheel.usableEnabled ~= false then wheels[#wheels + 1] = L.GUIDE_SUM_USABLE end
        local lines = {
            { L.GUIDE_SUM_ICONS, nameIn(GLYPH_STYLES, st.glyphStyle) },
            { L.GUIDE_SUM_PADDLES, paddles > 0 and format(L.GUIDE_SUM_IDENTIFIED, paddles) or L.GUIDE_SUM_NONE },
            { L.GUIDE_SUM_PADS, #pads > 0 and table.concat(pads, ", ") or L.GUIDE_SUM_NONE },
            { L.GUIDE_SUM_BAR, format("%d %%", P():BarScale() * 100 + 0.5) },
            { L.GUIDE_SUM_KEYBOARD, not st.modules.keyboard and L.GUIDE_SUM_OFF
                or (st.inputMethod == "stick" and L.METHOD_STICK or L.METHOD_WHEEL) },
            { L.GUIDE_SUM_WHEELS, #wheels > 0 and table.concat(wheels, ", ") or L.GUIDE_SUM_NONE },
        }
        for i, l in ipairs(lines) do
            s.summary[i][1]:SetText(l[1])
            s.summary[i][2]:SetText(l[2])
        end
    end
end

---------------------------------------------------------------------------
-- Moving through it
---------------------------------------------------------------------------
local function focusables(s)
    local list = {}
    for _, c in ipairs(s.controls) do
        if c.frame and shown(c) and enabled(c) then list[#list + 1] = c end
    end
    return list
end

function G:Current() return self.screens and self.screens[self.step] end

-- The control with the focus (the first one that can, if it can't)
function G:Focused()
    local s = self:Current()
    if not s then return nil end
    local list = focusables(s)
    for _, c in ipairs(list) do
        if c == s.focus then return c end
    end
    s.focus = list[1]
    return s.focus
end

function G:Move(d)
    local s = self:Current()
    local list = focusables(s)
    if #list == 0 then return end
    local current, index = self:Focused(), 1
    for i, c in ipairs(list) do
        if c == current then index = i end
    end
    s.focus = list[math.max(1, math.min(#list, index + d))]
    self:Render()
end

-- To a step (1-6), its first control focused
function G:Go(step)
    self.step = math.max(1, math.min(STEPS, step))
    local s = self:Current()
    if s.enter then s.enter() end
    s.focus = s.first and s.first() or s.controls[1]
    self:Render()
end

-- A control clicked with the mouse: focused, then as A
function G:Click(c)
    if self.mode ~= "normal" or c.screen ~= self:Current() or not (shown(c) and enabled(c)) then return end
    c.screen.focus = c
    if c.press then c:press() end
    self:Render()
end

function G:Press(name)
    if not self.active then return end
    if self.mode == "identify" then
        if name == "B" then return self:EndIdentify(false) end
        if name == "X" then P():StopCapture(nil) end
        return
    end
    if self.mode == "bind" then
        if name == "B" then self:EndBind() end
        return
    end
    if self.mode == "preview" then
        if name == "LEFT" or name == "RIGHT" then
            self:Preview(name == "LEFT" and -1 or 1)
        elseif name == "A" then
            self:EndPreview(true)
        elseif name == "B" then
            self:EndPreview(false)
        end
        return
    end
    local c = self:Focused()
    if name == "UP" or name == "DOWN" then return self:Move(name == "UP" and -1 or 1) end
    if name == "LEFT" or name == "RIGHT" then
        local d = name == "LEFT" and -1 or 1
        if c and c.lr then
            c:adjust(d)
            return self:Render()
        end
        return self:Move(d)
    end
    if name == "A" then
        if c and c.press then
            c:press()
            self:Render()
        end
    elseif name == "LB" then
        if self.step > 1 then self:Go(self.step - 1) end
    elseif name == "RB" then
        if self.step < STEPS then self:Go(self.step + 1) end
    elseif name == "B" then
        if self.step == 1 then return self:Later() end
        self:Go(self.step - 1)
    end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function G:Hints()
    local Hn = K.H
    if self.mode == "identify" then return { Hn({ "X" }, L.V_SKIP, "X"), Hn({ "B" }, L.V_CANCEL, "B") } end
    if self.mode == "bind" then return { Hn({ "B" }, L.V_CANCEL, "B") } end
    if self.mode == "preview" then
        return { Hn({ "DPAD_LR" }, L.GUIDE_ADJUST, "RIGHT"), Hn({ "A" }, L.GUIDE_KEEP, "A"), Hn({ "B" }, L.V_CANCEL, "B") }
    end
    local list = {}
    local c = self:Focused()
    if c and c.lr then
        list[#list + 1] = Hn({ "DPAD_LR" }, L.GUIDE_ADJUST, "RIGHT")
    else
        list[#list + 1] = Hn({ "DPAD" }, L.V_CHOOSE, "DOWN")
    end
    if c and c.press then list[#list + 1] = Hn({ "A" }, c.verbA and c:verbA() or L.V_CONFIRM, "A") end
    if self.step == 1 then
        list[#list + 1] = Hn({ "RB" }, L.GUIDE_NEXT, "RB")
        list[#list + 1] = Hn({ "B" }, L.GUIDE_LATER, "B")
    else
        list[#list + 1] = Hn(self.step < STEPS and { "LB", "RB" } or { "LB" }, L.GUIDE_STEP, "LB")
        list[#list + 1] = Hn({ "B" }, L.V_BACK, "B")
    end
    return list
end

function G:Crumb()
    if self.mode == "identify" then return L.GUIDE_CRUMB .. " › " .. L.GUIDE_C2 .. " › " .. L.GUIDE_IDENTIFYING end
    if self.mode == "bind" then return L.GUIDE_BIND_NOW end
    if self.mode == "preview" then return L.GUIDE_PREVIEW_LIVE end
    return L.GUIDE_CRUMB .. " › " .. L["GUIDE_C" .. self.step]
end

function G:RenderHelp()
    local o = self.frame
    local hints = self:Hints()
    local crumb, color = self:Crumb(), KC.grey
    if self.mode == "bind" and self.bindWhy then crumb, color = self.bindWhy, KC.warn end
    local toast = C().toast
    if toast then crumb, color = toast.text, toast.color end
    o.crumb:SetText(crumb)
    o.crumb:SetTextColor(unpack(color))
    local x = W - 4 - 20
    for i = #hints, 1, -1 do
        local h = o.hints[i]
        if not h then
            h = K.Hint(o.bar)
            o.hints[i] = h
        end
        h:Set(hints[i])
        h:ClearAllPoints()
        h:SetPoint("RIGHT", o.bar, "LEFT", x, 0)
        x = x - h:GetWidth() - 18
    end
    for i = #hints + 1, #o.hints do o.hints[i]:Hide() end
    o.crumb:SetWidth(math.max(10, x - 22))
end

-- The step's dots: done (gold), now (bright, bigger), to come (rings)
function G:RenderHeader()
    local o = self.frame
    o.kicker:SetText(K.Upper(L.GUIDE_KICKER))
    o.title:SetText(L["GUIDE_T" .. self.step])
    o.count:SetText(format("%d / %d", self.step, STEPS))
    local x = 0
    for i = STEPS, 1, -1 do
        local d, now, done = o.dots[i], i == self.step, i < self.step
        local size = now and 10 or 8
        d:SetTexture(TEX .. ((now or done) and "ck_dot" or "ck_ring"))
        d:SetVertexColor(unpack(now and KC.focus or (done and KC.dimGold or KC.line1)))
        d:SetSize(size, size)
        d:ClearAllPoints()
        d:SetPoint("RIGHT", o.count, "LEFT", -10 - x, 0)
        x = x + size + 7
    end
end

function G:Render()
    local o = self.frame
    if not (o and self.active) then return end
    local preview = self.mode == "preview"
    self:RenderHeader()
    for _, part in ipairs({ o.kicker, o.title, o.count, o.close, o.headRule }) do part:SetShown(not preview) end
    for _, d in ipairs(o.dots) do d:SetShown(not preview) end
    self.previewFrame:SetShown(preview)
    for i, s in ipairs(self.screens) do s.frame:SetShown(not preview and i == self.step) end
    o.bar:ClearAllPoints()
    if preview then
        -- 3b: the size alone, the help bar under it
        o.bar:SetPoint("TOPLEFT", o, "TOPLEFT", 2, -128)
        self.previewFrame.count:SetText(format("%s · %d / %d", L.GUIDE_CRUMB, self.step, STEPS))
        self.previewScreen.controls[1]:draw(true)
    else
        o.bar:SetPoint("TOPLEFT", o, "TOPLEFT", 2, -532)
        local s = self:Current()
        if s.render then s.render() end
        local focused = self.mode == "normal" and self:Focused()
        for _, c in ipairs(s.controls) do c:draw(c == focused) end
        if s.layout then s.layout() end
        self:RenderStep(s)
    end
    self:RenderHelp()
end

-- What a screen shows besides its controls
function G:RenderStep(s)
    if self.step == 2 then
        local identifying = self.mode == "identify"
        s.ask:SetShown(identifying)
        s.paddlesHelp:SetShown(not identifying)
        s.identify.frame:SetShown(not identifying)
        s.right:SetAlpha(identifying and 0.35 or 1)
        s.found:SetText(self.found and #self.found > 0 and format(L.GUIDE_FOUND, table.concat(self.found, ", ")) or "")
        local id = identifying and self.asked and self.asked.id
        for pid, t in pairs(s.paddleGlow) do t:SetAlpha(pid == id and 1 or 0) end
        s.paddlesGlow:SetAlpha(identifying and 0 or 0.35)
        if id then
            s.ask.title:SetText(format(L.GUIDE_PRESS, id))
            s.ask.help:SetText(askHelp(id) .. " " .. format(L.GUIDE_ASK_WAIT, IDENTIFY_WAIT))
            -- The progress: one dot each
            for i = 1, math.max(#self.queue, #s.ask.dots) do
                local d = s.ask.dots[i]
                if not d and i <= #self.queue then
                    d = s.ask:CreateTexture(nil, "OVERLAY")
                    s.ask.dots[i] = d
                end
                if d then
                    d:SetShown(i <= #self.queue)
                    local now = i == self.queueAt
                    d:SetTexture(TEX .. (now and "ck_dot" or "ck_ring"))
                    d:SetVertexColor(unpack(now and KC.focus or KC.boxEdge))
                    d:SetSize(now and 10 or 8, now and 10 or 8)
                    d:ClearAllPoints()
                    d:SetPoint("CENTER", s.ask, "TOPRIGHT", -16 - (#self.queue - i) * 14, -24)
                end
            end
        end
    elseif self.step == 3 then
        s.toggleGlow:SetAlpha(settings().features.triggerToggle and 1 or 0)
    end
end

-- Animations: the asked paddle's glow breathing, the touchpad's zones lit
-- in turn once ticked; the waits (5 s a paddle, 10 s a key)
function G:OnUpdate()
    if not self.active then return end
    local now = GetTime()
    if self.mode == "identify" and self.asked and self.askedAt and now - self.askedAt > IDENTIFY_WAIT then
        self.askedAt = nil
        P():StopCapture(nil)
        return
    end
    if self.mode == "bind" and self.bindAt and now - self.bindAt > BIND_WAIT then return self:EndBind() end
    local s = self:Current()
    if self.step ~= 2 or not s then return end
    local pulse = 0.55 + 0.45 * math.sin(now * 4)
    if self.mode == "identify" and self.asked then
        local t = s.paddleGlow[self.asked.id]
        if t then t:SetAlpha(pulse) end
        local n = tonumber(self.asked.id:match("^T[LR](%d)$") or "")
        for i, z in ipairs(s.zoneGlow) do z:SetAlpha(n == i and pulse or 0) end
    else
        local t0 = self.zonesAt
        for i, z in ipairs(s.zoneGlow) do
            local lit = t0 and now - t0 < 1.2 and math.floor((now - t0) / 0.3) + 1 == i
            z:SetAlpha(lit and 1 or 0)
        end
    end
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------
function G:Seen()
    local o = CK.db and CK.db.onboarding
    return type(o) == "table" and o.seen == true
end

function G:SetSeen()
    if not CK.db then return end
    CK.db.onboarding = { seen = true, version = VERSION }
end

function G:IsOpen() return self.active and true or false end

-- At step `step` (1 by default), over the panel (opened for it, or already
-- open: Home > Guide)
function G:Open(step)
    if CK:BlockedByCombat() then return end
    local Cfg = C()
    self.fromPanel = Cfg.frame ~= nil and Cfg.frame:IsShown() and not Cfg.placing
    if not self.fromPanel then Cfg:Open() end
    if not (Cfg.frame and Cfg.frame:IsShown()) then return end
    Cfg:StopChordCapture(nil)
    Cfg:Disarm()
    self:Build()
    self.active, self.mode = true, "normal"
    self.frame:Show()
    Cfg.guide = self
    self:Go(step or 1)
end

-- Its layer away: what it was doing ended, the panel's own pages back
function G:Leave()
    if not self.active then return end
    if self.mode == "identify" then self:EndIdentify(false) end
    if self.mode == "bind" then self:EndBind() end
    if self.mode == "preview" then self:EndPreview(true) end
    self.active, self.mode = false, "normal"
    if self.frame then self.frame:Hide() end
    if C().guide == self then C().guide = nil end
end

-- Done (Finish, Later, the window's X, B on the first step): seen. Opened
-- from the panel, back to it; else the panel closed (or on a tab of it:
-- "gamepad", to put spells)
function G:Finish(tab)
    self:SetSeen()
    local fromPanel = self.fromPanel
    self:Leave()
    if tab then
        C():SetTab(tab)
    elseif fromPanel then
        C():Render()
    else
        C():Close()
    end
end

function G:Later() self:Finish() end

-- The panel closed under it: by a fight, back at this step once it's over
-- (not seen yet); by the player, as Later
function G:Closed(reason)
    if not self.active then return end
    if reason == "combat" then
        self.interrupted = not self:Seen() and self.step or nil
    else
        self:SetSeen()
    end
    self:Leave()
end

-- Once the game is free (no game window with the pad, no fight), within
-- two minutes. overChat: typed in the chat (/ec welcome), the chat still
-- open doesn't stop it. firstTime: by itself (a new install, after a
-- fight), dropped once seen
function G:OpenWhenFree(step, overChat, firstTime)
    local Cfg = C()
    local function ready()
        if InCombatLockdown() or Cfg.placing then return false end
        return (Cfg.frame ~= nil and Cfg.frame:IsShown()) or Cfg:GameIsFree(overChat)
    end
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if not firstTime and ready() then
        -- (typed in the chat: once the game is done with the send)
        if overChat then
            C_Timer.After(0.15, function()
                if ready() and not G:IsOpen() then G:Open(step) end
            end)
        else
            self:Open(step)
        end
        return
    end
    local tries = 0
    self.ticker = C_Timer.NewTicker(0.5, function(ticker)
        tries = tries + 1
        if G:IsOpen() or (firstTime and G:Seen()) or tries > 240 then
            ticker:Cancel()
            G.ticker = nil
        elseif ready() then
            ticker:Cancel()
            G.ticker = nil
            G:Open(step)
        end
    end)
end

function G:Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(frame, event)
        if not CK.db then return end
        if event == "PLAYER_ENTERING_WORLD" then
            frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
            local resume = CK.db.onboarding and CK.db.onboarding.resume
            if resume then
                -- Reloaded by the guide (the compact bar): back at its step
                CK.db.onboarding.resume = nil
                C_Timer.After(2, function() G:OpenWhenFree(resume) end)
            elseif not G:Seen() then
                -- The first login of a new install: a few seconds in
                C_Timer.After(3, function() G:OpenWhenFree(1, false, true) end)
            end
        elseif G.interrupted then
            local step = G.interrupted
            G.interrupted = nil
            if not G:Seen() then C_Timer.After(1, function() G:OpenWhenFree(step, false, true) end) end
        end
    end)
end
G:Init()
