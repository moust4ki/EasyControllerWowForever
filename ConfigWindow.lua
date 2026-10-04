local _, CK = ...
local L = CK.L

-- The addon's own configuration panel (RB + D-pad down, /ec config), 2.0
-- (Claude Design handoff "design_handoff_config_panel"): 820 x 580, five
-- tabs (Home, Gamepad, Wheels, Keyboard, Alerts). A tab is a rail of
-- sections, the section's list and a detail panel (the Gamepad tab and the
-- wheel editor draw their own); the help bar under them shows where the
-- focus is and what the pad does there. One focus at a time, driven with
-- the pad or the mouse. Like the keyboard it is our own frame, never a game
-- panel: while it is open the pad is bound to hidden buttons of ours, out of
-- combat only, and released when it closes.
local C = {}
CK.Config = C

local K = CK.ConfigKit
local KC = K.C
local W, H = 820, 580

C.TABS = { "home", "gamepad", "wheels", "keyboard", "alerts" }
-- Earlier tab names (slash commands, other modules): a tab and a section
C.ALIASES = {
    general = { "home" }, map = { "gamepad" }, wheel = { "wheels" },
    vibration = { "alerts", 1 }, supplies = { "alerts", 2 },
}
C.pages = {}

function C:IsOpen()
    return (self.frame and self.frame:IsShown()) or self.placing or false
end

function C:Page()
    return self.pages[self.tab]
end

local function settings() return CK.db.settings end

---------------------------------------------------------------------------
-- Transient states, shared by every page: a destructive button armed (a
-- second A does it; B, a move or 4 s let it go), a short message in the
-- help bar's crumb (cyan, 1.8 s)
---------------------------------------------------------------------------
function C:Arm(id)
    self.armed = id
    self.armToken = (self.armToken or 0) + 1
    local token = self.armToken
    C_Timer.After(4, function()
        if self.armToken == token and self.armed == id then
            self.armed = nil
            if self:IsOpen() then self:Render() end
        end
    end)
end

function C:IsArmed(id)
    return self.armed ~= nil and self.armed == id
end

function C:Disarm()
    self.armed = nil
end

function C:Toast(text, warn)
    self.toast = { text = text, color = warn and KC.warn or KC.info }
    self.toastToken = (self.toastToken or 0) + 1
    local token = self.toastToken
    C_Timer.After(1.8, function()
        if self.toastToken == token then
            self.toast = nil
            if self:IsOpen() then self:Render() end
        end
    end)
    if self:IsOpen() then self:Render() end
end

---------------------------------------------------------------------------
-- The pages made of sections (Home, Keyboard, Alerts...): a rail of
-- sections (140), the section's list (388), a detail panel (232) or the
-- lists picker in its place. def = { key, sections = { { key, label, tip,
-- rows = function(b) end } }, crumb = "Gamepad" (a sub-screen's parent) }
---------------------------------------------------------------------------
local RailPage = {}
RailPage.__index = RailPage
RailPage.isRail = true

local RAIL_W, LIST_W, DETAIL_W, GAP, BODY_H = 140, 388, 232, 12, 420
local BUDGET = 420
local HEIGHT = { header = 32, check = 36, choice = 36, slider = 36, event = 36, value = 36, stat = 36, button = 42 }
local FOCUSABLE = { check = true, choice = true, slider = true, event = true, value = true, button = true }

function C.NewRailPage(def)
    return setmetatable({ def = def, zone = "list", section = 1, focusId = {}, focusIndex = {}, focusNext = {},
        focusPrev = {}, start = {} }, RailPage)
end

-- The rows of a section: b.header(text), b.info(text), b.check{...},
-- b.choice{...}, b.slider{...}, b.event{...}, b.button{...}, b.value{...},
-- b.stat{...}
local function builder()
    local rows, b = {}, {}
    local function add(row)
        rows[#rows + 1] = row
        return row
    end
    function b.header(label) return add({ kind = "header", label = label }) end
    function b.info(text) return add({ kind = "info", label = text }) end
    for _, kind in ipairs({ "check", "choice", "slider", "event", "button", "value", "stat" }) do
        b[kind] = function(o)
            o.kind = kind
            return add(o)
        end
    end
    return rows, b
end

local function resolve(v)
    if type(v) == "function" then return v() end
    return v
end

local function focusable(row)
    return row and FOCUSABLE[row.kind] and not resolve(row.disabled) or false
end

function RailPage:Section()
    return self.def.sections[self.section] or self.def.sections[1]
end

function RailPage:Rebuild()
    local rows, b = builder()
    local sec = self:Section()
    if sec and sec.rows then sec.rows(b, self) end
    self.rows = rows
end

-- The row with the focus: the one last focused in this section (by its id),
-- else, gone (an item removed...), the row after it or the one before it,
-- else near its place, else the first
function RailPage:FocusIndex()
    local rows, key = self.rows, self:Section().key
    -- A row without an id: found again by its place
    local at = self.focusIndex[key]
    if self.focusId[key] == nil and at and rows[at] and rows[at].id == nil and focusable(rows[at]) then return at end
    local ids = { self.focusId[key], self.focusNext[key], self.focusPrev[key] }
    for n = 1, 3 do
        local id = ids[n]
        if id then
            for i, row in ipairs(rows) do
                if row.id == id and focusable(row) then return i end
            end
        end
    end
    local near = self.focusIndex[key]
    if near then
        for i = math.min(near, #rows), 1, -1 do
            if focusable(rows[i]) then return i end
        end
    end
    for i, row in ipairs(rows) do
        if focusable(row) then return i end
    end
end

function RailPage:SetFocus(i)
    local rows = self.rows
    local row = rows[i]
    if not row then return end
    local key = self:Section().key
    self.focusId[key], self.focusIndex[key] = row.id, i
    local function neighbour(step)
        local j = i + step
        while rows[j] and not focusable(rows[j]) do j = j + step end
        return rows[j] and rows[j].id
    end
    self.focusNext[key], self.focusPrev[key] = neighbour(1), neighbour(-1)
end

function RailPage:RowHeight(row)
    if row.height then return row.height end
    if row.kind == "info" then return 44 end
    return HEIGHT[row.kind] or 36
end

---------------------------------------------------------------------------
-- Building the page
---------------------------------------------------------------------------
local function arrow(parent, text, page, row, delta)
    local a = CK.NewFrame("Button", nil, parent)
    a:SetSize(22, 22)
    a.box = K.Box(a, 4, 1, "ARTWORK")
    a.box:SetPoints(a)
    a.text = K.Text(a, 13, KC.dimGold)
    a.text:SetPoint("CENTER", 0, 0)
    a.text:SetJustifyH("CENTER")
    a.text:SetText(text)
    a:SetScript("OnClick", function() page:ClickRow(row, delta) end)
    return a
end

local function newRow(page, n)
    local r = CK.NewFrame("Button", nil, page.list)
    r:SetWidth(LIST_W)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.sel = CK.UIKit.nineSlice(r, "ck_select", 128, 32, 10, 10, "ARTWORK")
    -- A section's title
    r.head = K.Text(r, 15, KC.title)
    r.head:SetPoint("BOTTOMLEFT", 2, 7)
    r.headLine = K.Solid(r, KC.line2, 1, "BORDER")
    r.headLine:SetHeight(1)
    r.headLine:SetPoint("BOTTOMLEFT", 0, 2)
    r.headLine:SetPoint("BOTTOMRIGHT", 0, 2)
    -- An explanation
    r.info = K.ChatText(r, 14, KC.help)
    r.info:SetPoint("TOPLEFT", 10, -8)
    r.info:SetWidth(LIST_W - 20)
    r.info:SetWordWrap(true)
    r.info:SetSpacing(6)
    -- A setting: its label, its control on the right
    r.indentLine = K.Solid(r, KC.line1, 1, "BORDER")
    r.indentLine:SetWidth(1)
    r.indentLine:SetPoint("TOPLEFT", 18, 0)
    r.indentLine:SetPoint("BOTTOMLEFT", 18, 0)
    r.label = K.Text(r, 16, KC.cream)
    r.label:SetWordWrap(true)
    r.status = K.ChatText(r, 13, KC.grey)
    r.status:SetJustifyH("RIGHT")
    r.stat = K.Text(r, 16, KC.focus)
    r.stat:SetJustifyH("RIGHT")
    -- A value in a chip (the shortcut's combination)
    r.chip = CK.NewFrame("Frame", nil, r)
    r.chip:SetHeight(24)
    r.chip.box = K.Box(r.chip, 4, 1, "ARTWORK")
    r.chip.box:SetPoints(r.chip)
    r.chip.box:SetColors(KC.controlBg, 1, KC.control, 1)
    r.chip.text = K.Text(r.chip, 15, KC.cream)
    r.chip.text:SetPoint("CENTER", 0, 0)
    -- < value >
    r.choice = CK.NewFrame("Frame", nil, r)
    r.choice:SetHeight(22)
    r.left = arrow(r.choice, "<", page, r, -1)
    r.left:SetPoint("LEFT")
    r.right = arrow(r.choice, ">", page, r, 1)
    r.right:SetPoint("RIGHT")
    r.value = K.Text(r.choice, 15, KC.cream)
    r.value:SetPoint("LEFT", r.left, "RIGHT", 4, 0)
    r.value:SetPoint("RIGHT", r.right, "LEFT", -4, 0)
    r.value:SetJustifyH("CENTER")
    -- The box, always on the right
    r.box = CK.NewFrame("Button", nil, r)
    r.box:SetSize(24, 24)
    r.box.frame = K.Box(r.box, 3, 2, "ARTWORK")
    r.box.frame:SetPoints(r.box)
    r.box.tick = r.box:CreateTexture(nil, "OVERLAY")
    r.box.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    r.box.tick:SetPoint("CENTER", 0, 0)
    r.box.tick:SetSize(26, 26)
    r.box.tick:SetVertexColor(KC.focus[1], KC.focus[2], KC.focus[3])
    r.box:SetScript("OnClick", function() page:ClickRow(r) end)
    -- A slider: its track, the filled part, the handle, the value
    r.slider = CK.NewFrame("Button", nil, r)
    r.slider:SetHeight(16)
    r.slider.value = K.Text(r.slider, 15, KC.cream)
    r.slider.value:SetPoint("RIGHT")
    r.slider.value:SetWidth(40)
    r.slider.value:SetJustifyH("RIGHT")
    r.slider.track = CK.NewFrame("Frame", nil, r.slider)
    r.slider.track:SetPoint("LEFT")
    r.slider.track:SetPoint("RIGHT", -48, 0)
    r.slider.track:SetHeight(8)
    r.slider.trackBox = K.Box(r.slider.track, 4, 1, "ARTWORK")
    r.slider.trackBox:SetPoints(r.slider.track)
    r.slider.fill = K.Solid(r.slider.track, KC.fill, 1, "ARTWORK", 3)
    r.slider.fill:SetPoint("TOPLEFT", 1, -1)
    r.slider.fill:SetPoint("BOTTOMLEFT", 1, 1)
    r.slider.handle = K.Solid(r.slider.track, KC.dimGold, 1, "OVERLAY")
    r.slider.handle:SetSize(14, 16)
    r.slider:SetScript("OnMouseDown", function(self)
        local x = GetCursorPosition() / self:GetEffectiveScale()
        local left, width = self.track:GetLeft(), self.track:GetWidth()
        if left and width and width > 0 then page:SlideRow(r, (x - left) / width) end
    end)
    -- A button row's button
    r.btn = K.Button(r, 15)
    r.btn:SetScript("OnClick", function() page:ClickRow(r) end)
    r:SetScript("OnClick", function(self, button)
        page:ClickRow(self, button == "RightButton" and -1 or nil)
    end)
    page.rowsUI[n] = r
    return r
end

function RailPage:Build(parent)
    local f = CK.NewFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()
    self.frame = f
    local page = self

    -- The rail of sections
    local rail = CK.NewFrame("Frame", nil, f)
    rail:SetPoint("TOPLEFT")
    rail:SetSize(RAIL_W, BODY_H)
    local shade = K.Solid(rail, KC.black, 0.22, "BACKGROUND")
    shade:SetAllPoints()
    local divider = K.Solid(rail, KC.line2, 1, "BORDER")
    divider:SetWidth(1); divider:SetPoint("TOPRIGHT"); divider:SetPoint("BOTTOMRIGHT")
    self.railEntries = {}
    for i in ipairs(self.def.sections) do
        local e = K.Button(rail, 13, "nav")
        e:SetSize(RAIL_W - 16, 44)
        e:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 48)
        e.diamond = e:CreateTexture(nil, "OVERLAY")
        e.diamond:SetTexture(K.TEX .. "ck_tri")
        e.diamond:SetRotation(-math.pi / 2)
        e.diamond:SetSize(7, 7)
        e.diamond:SetPoint("LEFT", 10, 0)
        e.diamond:SetVertexColor(KC.title[1], KC.title[2], KC.title[3])
        e.label:ClearAllPoints()
        e.label:SetPoint("LEFT", 23, 0)
        e.label:SetWidth(RAIL_W - 16 - 28)
        e.label:SetWordWrap(true)
        e.label:SetHeight(34)
        e.label:SetJustifyH("LEFT")
        e:SetScript("OnClick", function() e:Pulse(); page:SetSection(i, "rail") end)
        self.railEntries[i] = e
    end

    -- The section's list
    local list = CK.NewFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", RAIL_W + GAP, 0)
    list:SetSize(LIST_W, BODY_H)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        if page:Section().view then return end
        page.zone = "list"
        page:MoveFocus(delta > 0 and -1 or 1, 3)
    end)
    self.list = list
    self.rowsUI = {}
    self.moreUp = list:CreateTexture(nil, "OVERLAY")
    self.moreUp:SetTexture(K.TEX .. "ck_tri")
    self.moreUp:SetTexCoord(0, 1, 1, 0)
    self.moreUp:SetSize(11, 11)
    self.moreUp:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, 10)
    self.moreDown = list:CreateTexture(nil, "OVERLAY")
    self.moreDown:SetTexture(K.TEX .. "ck_tri")
    self.moreDown:SetSize(11, 11)
    self.moreDown:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -4, -8)
    for _, t in ipairs({ self.moreUp, self.moreDown }) do t:SetVertexColor(KC.dimGold[1], KC.dimGold[2], KC.dimGold[3]) end
    -- Sections drawn their own way (the wheels' cards) in the list's place
    for _, sec in ipairs(self.def.sections) do
        if sec.view then sec.view:Build(list, self) end
    end

    -- The detail panel, the picker in its place
    self.detail = K.Detail(f, DETAIL_W)
    self.detail:SetPoint("TOPRIGHT")
    self.detail:SetHeight(BODY_H)
    self.picker = K.Picker(f, DETAIL_W)
    self.picker:SetPoint("TOPRIGHT")
    self.picker:SetHeight(BODY_H)
end

-- Back on the section last used, in its list
function RailPage:Show()
    local saved = settings().configSection
    local i = saved and saved[self.def.key]
    if i and self.def.sections[i] then self.section = i end
    self.zone = "list"
    self.frame:Show()
end

function RailPage:Hide()
    self.picker:Close()
    self.frame:Hide()
end

function RailPage:SetSection(i, zone)
    if not self.def.sections[i] then return end
    C:StopChordCapture(nil)
    if i ~= self.section then C:Disarm() end
    self.section = i
    if zone then self.zone = zone end
    settings().configSection = settings().configSection or {}
    settings().configSection[self.def.key] = i
    self.picker:Close()
    C:Render()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function setShown(r, parts)
    r.head:SetShown(parts.head or false)
    r.headLine:SetShown(parts.head or false)
    r.info:SetShown(parts.info or false)
    r.indentLine:SetShown(parts.indent or false)
    r.label:SetShown(parts.label or false)
    r.status:SetShown(parts.status or false)
    r.stat:SetShown(parts.stat or false)
    r.chip:SetShown(parts.chip or false)
    r.choice:SetShown(parts.choice or false)
    r.box:SetShown(parts.box or false)
    r.slider:SetShown(parts.slider or false)
    r.btn:SetShown(parts.btn or false)
end

function RailPage:LayoutRow(r, row, focused)
    r.row = row
    r.sel:SetShown(false)
    local kind = row.kind
    if kind == "header" then
        setShown(r, { head = true })
        r.head:SetText(row.label)
        return
    end
    if kind == "info" then
        setShown(r, { info = true })
        r.info:SetText(resolve(row.label))
        return
    end
    local disabled = resolve(row.disabled)
    local indent = row.indent and true or false
    if kind == "button" then
        setShown(r, { btn = true })
        local pad = indent and 24 or 0
        r.btn:ClearAllPoints()
        r.btn:SetPoint("TOPLEFT", pad, -5)
        r.btn:SetPoint("BOTTOMRIGHT", 0, 5)
        local armed = C:IsArmed(row.id)
        r.btn.label:SetText(armed and row.armedLabel or resolve(row.label))
        r.btn.label:SetWordWrap(true)
        r.btn:SetState({ focus = focused, armed = armed, disabled = disabled })
        if armed and r.btn.armedId ~= row.id and UIFrameFadeIn then UIFrameFadeIn(r.btn, 0.15, 0.3, 1) end
        r.btn.armedId = armed and row.id or nil
        return
    end

    -- A setting's row
    r.sel:SetShown(focused)
    local right = LIST_W - 8
    local controlLeft = right
    local parts = { label = true, indent = indent }
    if kind == "check" or kind == "event" then
        parts.box = true
        r.box:ClearAllPoints()
        r.box:SetPoint("RIGHT", r, "LEFT", right, 0)
        local on = kind == "check" and resolve(row.get) or (kind == "event" and resolve(row.on))
        r.box.frame:SetColors(KC.boxBg, 1, disabled and KC.boxOff or (on and KC.slot or KC.boxEdge), 1)
        r.box.tick:SetShown(on and true or false)
        controlLeft = right - 24
    end
    if kind == "choice" or kind == "event" then
        parts.choice = true
        local w = kind == "event" and 140 or 176
        r.choice:SetWidth(w)
        r.choice:ClearAllPoints()
        r.choice:SetPoint("RIGHT", r, "LEFT", kind == "event" and controlLeft - 10 or right, 0)
        local arrowColor = disabled and KC.arrowOff or (focused and KC.focus or KC.dimGold)
        for _, a in ipairs({ r.left, r.right }) do
            a.text:SetTextColor(unpack(arrowColor))
            a.box:SetColors(a.pressed and KC.pressed or KC.controlBg, 1, KC.control, 1)
        end
        r.value:SetText(resolve(kind == "event" and row.pattern or row.text) or "")
        local off = kind == "event" and not resolve(row.on)
        r.value:SetTextColor(unpack(disabled and KC.disabled or (off and KC.eventOff or KC.cream)))
        controlLeft = (kind == "event" and controlLeft - 10 or right) - w
    end
    if kind == "slider" then
        parts.slider = true
        r.slider:SetWidth(176)
        r.slider:ClearAllPoints()
        r.slider:SetPoint("RIGHT", r, "LEFT", right, 0)
        local v, lo, hi = resolve(row.get), row.min, row.max
        local frac = hi > lo and math.max(0, math.min(1, (v - lo) / (hi - lo))) or 0
        local trackW = 176 - 48
        r.slider.fill:SetWidth(math.max(0.01, (trackW - 2) * frac))
        r.slider.handle:ClearAllPoints()
        r.slider.handle:SetPoint("CENTER", r.slider.track, "LEFT", (trackW - 14) * frac + 7, 0)
        r.slider.trackBox:SetColors(KC.controlBg, 1, focused and KC.slot or KC.control, 1)
        local hc = focused and KC.focus or KC.dimGold
        r.slider.handle:SetColorTexture(hc[1], hc[2], hc[3], 1)
        r.slider.value:SetText(row.fmt and row.fmt(v) or tostring(v))
        r.slider:SetAlpha(disabled and 0.4 or 1)
        controlLeft = right - 176
    end
    if kind == "value" then
        parts.chip = true
        r.chip.text:SetText(resolve(row.text) or "")
        local w = math.min(176, r.chip.text:GetStringWidth() + 20)
        r.chip:SetWidth(w)
        r.chip.text:SetWidth(w - 20)
        r.chip:ClearAllPoints()
        r.chip:SetPoint("RIGHT", r, "LEFT", right, 0)
        controlLeft = right - w
    end
    if kind == "stat" then
        parts.stat = true
        r.stat:ClearAllPoints()
        r.stat:SetPoint("RIGHT", r, "LEFT", right, 0)
        r.stat:SetText(resolve(row.text) or "")
        r.stat:SetWidth(176)
        r.stat:SetWordWrap(true)
        controlLeft = right - 176
    end
    local status = resolve(row.status)
    if status and kind == "check" then
        parts.status = true
        r.status:ClearAllPoints()
        r.status:SetPoint("RIGHT", r, "LEFT", controlLeft - 10, 0)
        r.status:SetText(status)
        local statusWidth = math.min(128, r.status:GetStringWidth())
        r.status:SetWidth(statusWidth)
        r.status:SetWordWrap(true)
        controlLeft = controlLeft - 10 - statusWidth
    end
    setShown(r, parts)
    local x = indent and 47 or 14
    r.label:ClearAllPoints()
    r.label:SetPoint("LEFT", r, "LEFT", x, 0)
    r.label:SetWidth(math.max(20, controlLeft - 10 - x))
    r.label:SetFont(CK:GetFontPath(), indent and 15 or 16, "")
    r.label:SetText(resolve(row.label))
    r.label:SetTextColor(unpack(disabled and KC.disabled or (focused and KC.focusText or (indent and KC.cream2 or KC.cream))))
end

function RailPage:Render()
    local sec = self:Section()
    self.detail:SetHeight(BODY_H)
    -- The rail
    for i, e in ipairs(self.railEntries) do
        local active = i == self.section
        e.label:SetText(self.def.sections[i].label)
        e:SetState({ active = active, focus = active and self.zone == "rail" })
        e.diamond:SetShown(active)
    end
    -- A section drawn its own way
    for _, other in ipairs(self.def.sections) do
        if other.view then other.view.frame:SetShown(other == sec) end
    end
    if sec.view then
        self.rows = {}
        for _, r in ipairs(self.rowsUI) do r:Hide() end
        self.moreUp:Hide()
        self.moreDown:Hide()
        sec.view:Render(self, self.zone == "list")
        self:RenderSide()
        return
    end
    -- The list, windowed on the focus (the section title above it kept)
    self:Rebuild()
    local rows = self.rows
    local probe = self.rowsUI[1] or newRow(self, 1)
    for _, row in ipairs(rows) do
        if row.kind == "info" then
            probe.info:SetText(resolve(row.label))
            row.height = math.floor(probe.info:GetStringHeight() + 16 + 0.5)
        elseif FOCUSABLE[row.kind] or row.kind == "stat" then
            -- Measure the actual constrained font strings before pagination.
            -- Localized labels and character names can occupy multiple lines.
            self:LayoutRow(probe, row, false)
            local height = row.kind == "button" and probe.btn.label:GetStringHeight() or probe.label:GetStringHeight()
            for _, part in ipairs({ probe.status, probe.stat }) do
                if part:IsShown() then height = math.max(height, part:GetStringHeight()) end
            end
            row.height = math.max(HEIGHT[row.kind] or 36, math.ceil(height + 16))
        end
    end
    local fi = self:FocusIndex()
    if fi then self:SetFocus(fi) end
    local start = math.max(1, math.min(self.start[sec.key] or 1, #rows))
    local function sum(a, b)
        local t = 0
        for j = a, b do t = t + self:RowHeight(rows[j]) end
        return t
    end
    -- Everything fits (a section that shrank): from its top
    if sum(1, #rows) <= BUDGET then start = 1 end
    if fi then
        if fi < start then start = (fi > 1 and rows[fi - 1].kind == "header") and fi - 1 or fi end
        while start < fi and sum(start, fi) > BUDGET do start = start + 1 end
        local last = true
        for j = fi + 1, #rows do
            if focusable(rows[j]) then last = false break end
        end
        if last then
            while start < fi and sum(start, #rows) > BUDGET do start = start + 1 end
            -- Asked to go further down (only greyed rows left): those shown
            -- too, the focus staying where it is
            local peek = self.peek and self.peek[sec.key] or 0
            local moved = 0
            while moved < peek and start < #rows and sum(start, #rows) > BUDGET do
                start = start + 1
                moved = moved + 1
            end
            if self.peek then self.peek[sec.key] = moved end
        end
    end
    while start > 1 and sum(start - 1, #rows) <= BUDGET do start = start - 1 end
    self.start[sec.key] = start
    local used, n, moreBelow = 0, 0, false
    for j = start, #rows do
        local h = self:RowHeight(rows[j])
        if used + h > BUDGET + 2 then
            moreBelow = true
            break
        end
        n = n + 1
        local r = self.rowsUI[n] or newRow(self, n)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -used)
        r:SetHeight(h)
        r.index = j
        self:LayoutRow(r, rows[j], self.zone == "list" and j == fi)
        r:Show()
        used = used + h
    end
    for j = n + 1, #self.rowsUI do self.rowsUI[j]:Hide() end
    self.moreUp:SetShown(start > 1)
    self.moreDown:SetShown(moreBelow)
    self:RenderSide()
end

-- The detail panel, or the picker
function RailPage:RenderSide()
    if self.picker:IsOpen() then
        self.detail:Hide()
        self.picker:Render()
    else
        self.detail:Show()
        self.detail:Set(self:Detail())
    end
end

function RailPage:Detail()
    local sec = self:Section()
    if self.zone == "rail" then return { title = sec.label, body = resolve(sec.tip) } end
    if sec.view then return sec.view:Detail(self) end
    local row = self.rows[self:FocusIndex() or 0]
    if not row then return { title = sec.label, body = resolve(sec.tip) } end
    local extra = resolve(row.extra)
    local value = resolve(row.text) or (row.kind == "event" and resolve(row.pattern)) or resolve(row.status)
    if value ~= nil and value ~= "" then
        extra = extra and (extra .. "\n\n" .. tostring(value)) or tostring(value)
    end
    return { title = resolve(row.title) or resolve(row.label), body = resolve(row.tip), tag = resolve(row.tag),
        tagColor = row.tagColor, extra = extra }
end

function RailPage:Crumb()
    local parent = self.def.crumb or L["TAB_" .. self.def.key:upper()] or ""
    return parent .. " › " .. (self:Section().label or "")
end

---------------------------------------------------------------------------
-- The pad, the mouse
---------------------------------------------------------------------------
function RailPage:MoveFocus(delta, count)
    local rows, i = self.rows, self:FocusIndex()
    if not i then return C:Render() end
    local from = i
    for _ = 1, count or 1 do
        local j = i + delta
        while rows[j] and not focusable(rows[j]) do j = j + delta end
        if rows[j] then i = j end
    end
    -- Nothing to focus further down: the list still shows the rows below
    -- (greyed ones, a module off); going up brings the focus back in view
    local key = self:Section().key
    self.peek = self.peek or {}
    if i == from and delta > 0 then
        self.peek[key] = (self.peek[key] or 0) + (count or 1)
    else
        self.peek[key] = nil
    end
    -- The focus moved: an armed button lets go
    if i ~= from then C:Disarm() end
    self:SetFocus(i)
    C:Render()
end

-- A row's action: A (or a click), or its value moved (delta)
function RailPage:Act(row, delta)
    if not row or resolve(row.disabled) then return end
    local kind = row.kind
    if delta then
        if kind == "choice" or kind == "event" then
            if row.step then row.step(delta) end
        elseif kind == "slider" then
            local v = resolve(row.get) + delta * (row.stepSize or 1)
            row.set(math.max(row.min, math.min(row.max, v)))
        end
        return C:Render()
    end
    if kind == "check" then
        row.set(not resolve(row.get))
    elseif kind == "event" then
        if row.toggle then row.toggle() end
    elseif kind == "choice" then
        if row.step then row.step(1) end
    elseif kind == "button" then
        for _, r in ipairs(self.rowsUI or {}) do
            if r.row == row then r.btn:Pulse(); break end
        end
        if row.danger then
            if C:IsArmed(row.id) then
                C:Disarm()
                row.func()
            else
                C:Arm(row.id)
            end
        else
            row.func()
        end
    elseif kind == "value" then
        if row.onA then row.onA() end
    end
    C:Render()
end

function RailPage:ClickRow(r, delta)
    if not (r and r.index) then return end
    local row = self.rows[r.index]
    if not focusable(row) then return end
    if C:IsCapturingChord() and row.id ~= "sc_combo" then C:StopChordCapture(nil) end
    -- Another row clicked: an armed button lets go
    if C.armed and C.armed ~= row.id then C:Disarm() end
    self.zone = "list"
    self:SetFocus(r.index)
    if delta and not (row.kind == "choice" or row.kind == "event" or row.kind == "slider") then delta = nil end
    if delta and (row.kind == "choice" or row.kind == "event") and r.left then
        local a = delta < 0 and r.left or r.right
        a.pressed = true
        C_Timer.After(0.1, function()
            a.pressed = nil
            if C:IsOpen() then C:Render() end
        end)
    end
    self:Act(row, delta)
end

function RailPage:SlideRow(r, frac)
    local row = r.index and self.rows[r.index]
    if not (row and row.kind == "slider") or resolve(row.disabled) then return end
    self.zone = "list"
    self:SetFocus(r.index)
    local step = row.stepSize or 1
    local v = row.min + math.floor((row.max - row.min) * math.max(0, math.min(1, frac)) / step + 0.5) * step
    row.set(v)
    C:Render()
end

function RailPage:OpenPicker(def)
    def.onBack = def.onBack or function()
        self.picker:Close()
        C:Render()
    end
    self.picker:Open(def)
    C:Render()
    -- The handoff's only fades (0.15 s): the picker opening, a button armed
    if UIFrameFadeIn then UIFrameFadeIn(self.picker, 0.15, 0, 1) end
end

function RailPage:Press(name)
    if self.picker:IsOpen() then
        self.picker:Press(name)
        C:Render()
        return true
    end
    local sections = self.def.sections
    if self.zone == "rail" then
        if name == "UP" or name == "DOWN" then
            local i = math.max(1, math.min(#sections, self.section + (name == "UP" and -1 or 1)))
            self:SetSection(i)
        elseif name == "A" or name == "RIGHT" then
            self.zone = "list"
            C.repeatName = nil
            C:Render()
        elseif name == "B" then
            -- A sub-screen goes back to its parent; a tab closes the panel
            if self.def.onBack then
                self.def.onBack()
                return true
            end
            return false
        else
            return name ~= "LB" and name ~= "RB"
        end
        return true
    end
    -- A section drawn its own way: its presses; B or an edge back to the rail
    local view = self:Section().view
    if view then
        if view:Press(self, name) then return true end
        if name == "B" or name == "LEFT" then
            self.zone = "rail"
            C:Render()
            return true
        end
        return name ~= "LB" and name ~= "RB"
    end
    local rows = self.rows or {}
    local row = rows[self:FocusIndex() or 0]
    if name == "UP" or name == "DOWN" then
        self:MoveFocus(name == "UP" and -1 or 1)
    elseif name == "LEFT" then
        if row and (row.kind == "choice" or row.kind == "event" or row.kind == "slider") then
            self:Act(row, -1)
        else
            self.zone = "rail"
            C:Render()
        end
    elseif name == "RIGHT" then
        if row and (row.kind == "choice" or row.kind == "event" or row.kind == "slider") then self:Act(row, 1) end
    elseif name == "A" then
        if row then self:Act(row) end
    elseif name == "X" then
        if row and row.onX then
            row.onX()
            C:Render()
        end
    elseif name == "Y" then
        if row and row.onY then
            row.onY()
            C:Render()
        end
    elseif name == "B" then
        self.zone = "rail"
        C:Render()
    else
        return false
    end
    return true
end

function RailPage:Help()
    local H = K.H
    local tab = H({ "LB", "RB" }, L.V_TAB, "RB")
    if self.picker:IsOpen() then return self.picker:Hints() end
    if self.zone == "rail" then
        return { H({ "DPAD" }, L.V_MOVE), H({ "A" }, L.V_OPEN, "A"), tab,
            H({ "B" }, self.def.onBack and L.V_BACK or L.V_CLOSE, "B") }
    end
    local view = self:Section().view
    if view then return view:Help(self) end
    local row = self.rows and self.rows[self:FocusIndex() or 0]
    if not row then return { tab, H({ "B" }, L.V_BACK, "B") } end
    local hints = {}
    local kind = row.kind
    if kind == "check" then
        hints[#hints + 1] = H({ "A" }, resolve(row.get) and L.V_UNCHECK or L.V_CHECK, "A")
    elseif kind == "choice" or kind == "slider" then
        hints[#hints + 1] = H({ "DPAD_LR" }, L.V_CHANGE, "RIGHT")
    elseif kind == "event" then
        -- The design's order: the D-pad first, then A
        hints[#hints + 1] = H({ "DPAD_LR" }, L.V_PATTERN, "RIGHT")
        hints[#hints + 1] = H({ "A" }, resolve(row.on) and L.V_OFF or L.V_ON, "A")
    elseif kind == "button" then
        hints[#hints + 1] = H({ "A" }, row.verb or (row.danger and L.V_DELETE or L.V_SELECT), "A")
    elseif kind == "value" then
        hints[#hints + 1] = H({ "A" }, row.verb or L.V_SELECT, "A")
    end
    if row.onX then hints[#hints + 1] = H({ "X" }, row.xVerb, "X") end
    if row.onY then hints[#hints + 1] = H({ "Y" }, row.yVerb, "Y") end
    hints[#hints + 1] = tab
    hints[#hints + 1] = H({ "B" }, L.V_BACK, "B")
    return hints
end

---------------------------------------------------------------------------
-- Window: header (40), tabs (44), body (448), help bar (44)
---------------------------------------------------------------------------
C.panel = function(f) K.Panel(f) end

function C:Build()
    if self.frame then return end
    local f = CK.NewFrame("Frame", "ControllerKeyboardConfigFrame", UIParent)
    f:SetSize(W, H)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    -- Always movable with the mouse (its free parts: title, tabs row, edges)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        settings().configPos = { point = point, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
    end)
    local pos = settings().configPos
    if type(pos) == "table" and pos.point then
        f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        f:SetPoint("CENTER", 0, 30)
    end
    f:Hide()
    -- Let Forever resolve its own Metal atlases, native canvas sizes and
    -- Camelot offsets. The input-owning addon frame remains unchanged.
    if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(K.TEX .. "ck_panel_bg", "REPEAT", "REPEAT")
        bg:SetHorizTile(true); bg:SetVertTile(true)
        bg:SetPoint("TOPLEFT", 4, -21); bg:SetPoint("BOTTOMRIGHT", -4, 4)
        NineSliceUtil.ApplyLayoutByName(f, "ButtonFrameTemplateNoPortrait")
    else
        K.Panel(f)
    end
    self.frame = f

    local title = K.Text(f, 18, KC.title)
    title:SetPoint("TOP", 0, -5); title:SetJustifyH("CENTER")
    title:SetSize(680, 22)
    title:SetText("Easy Controller")
    f.title = title
    f.profile = K.ChatText(f, 12, KC.cream2)
    f.profile:SetPoint("TOP", 0, -37); f.profile:SetJustifyH("CENTER")
    f.profile:SetSize(700, 18); f.profile:SetWordWrap(false)
    local profileTip = CK.NewFrame("Frame", nil, f)
    profileTip:SetAllPoints(f.profile); profileTip:EnableMouse(true)
    profileTip:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(f.profile:GetText() or "")
            GameTooltip:Show()
        end
    end)
    profileTip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local close = CK.NewFrame("Button", nil, f, "UIPanelCloseButtonNoScripts")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, 1)
    close:SetScript("OnClick", function() C:Close() end)

    -- Tabs, centered: LB, the five tabs, RB
    local tabsW = 24 + 10 + #C.TABS * 126 + (#C.TABS - 1) * 6 + 10 + 24
    local x = math.floor((W - tabsW) / 2)
    f.lbGlyph = K.Glyph(f, 24)
    f.lbGlyph:SetPoint("TOPLEFT", x, -65)
    f.tabs = {}
    for i, key in ipairs(C.TABS) do
        local t = K.Button(f, 14, "nav")
        t:SetSize(126, 30)
        t:SetPoint("TOPLEFT", x + 34 + (i - 1) * 132, -62)
        t.key = key
        t:SetScript("OnClick", function() t:Pulse(); C:SetTab(key) end)
        f.tabs[i] = t
    end
    f.rbGlyph = K.Glyph(f, 24)
    f.rbGlyph:SetPoint("TOPLEFT", x + 38 + #C.TABS * 132, -65)

    -- Body: 784 x 420 inside its margins
    f.body = CK.NewFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", 18, -104)
    f.body:SetSize(784, 420)
    for _, key in ipairs(C.TABS) do
        local page = self.pages[key]
        if page then page:Build(f.body) end
    end

    -- Help bar: the crumb on the left, the hints on the right
    local bar = CK.NewFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", 18, -536)
    bar:SetSize(W - 36, 32)
    local line = K.Solid(bar, KC.line3, 1, "BORDER")
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    line:SetHeight(1)
    f.bar = bar
    f.crumb = K.ChatText(bar, 11, KC.grey)
    f.crumb:SetPoint("LEFT", 0, 0)
    f.crumb:SetWordWrap(false)
    f.hints = {}

    f:SetScript("OnUpdate", function(_, elapsed) C:OnUpdate(elapsed) end)
    self:CreateInput()
end

function C:SetTab(key, section)
    self.readingDetail = nil
    local alias = C.ALIASES[key]
    if alias then key, section = alias[1], section or alias[2] end
    if not self.pages[key] then return end
    -- A click elsewhere ends the shortcut's capture
    self:StopChordCapture(nil)
    if key == self.tab and not section and self.frame and self.frame:IsShown() then
        local page = self:Page()
        if page.def and page.zone == "rail" then
            page.zone = "list"
        elseif not page.def and page.SetZone and page.rail and page.rail.zone == "rail" then
            page:SetZone("list")
        end
        return self:Render()
    end
    self:Disarm()
    local old = self:Page()
    if old and self.tab ~= key then old:Hide() end
    self.tab = key
    settings().configTab = key
    local page = self:Page()
    page:Show()
    if section and page.SetSection then page:SetSection(section, "list") end
    self:Render()
end

function C:StepTab(delta)
    local index = 1
    for i, key in ipairs(C.TABS) do
        if key == self.tab then index = i end
    end
    local key = C.TABS[(index - 1 + delta) % #C.TABS + 1]
    self:SetTab(key)
    for _, t in ipairs(self.frame and self.frame.tabs or {}) do
        if t.key == key then t:Pulse(); break end
    end
end

function C:Render()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    if f.title then
        local P = CK.Profiles
        local name = P and P.ready and P:ActiveName()
        f.title:SetText("Easy Controller")
        if f.profile then f.profile:SetText(name and ("Profile: " .. name) or "") end
    end
    f.lbGlyph:Set("LB")
    f.rbGlyph:Set("RB")
    for _, t in ipairs(f.tabs) do
        t.label:SetText(L["TAB_" .. t.key:upper()])
        t:SetState({ active = t.key == self.tab })
    end
    local page = self:Page()
    page:Render()
    if self.readingDetail and (not page.detail or not page.detail:IsShown()
        or page.detail.contentKey ~= self.readingDetailKey) then self.readingDetail = nil end
    self:RenderHelp(page)
end

function C:RenderHelp(page)
    local f = self.frame
    local hints = page:Help() or {}
    local detail = page.detail
    if self.readingDetail then
        hints = { K.H({ "DPAD" }, "Scroll", "DOWN"), K.H({ "B" }, L.V_BACK, "B") }
    elseif detail and detail:IsShown() and detail.CanScroll and detail:CanScroll() then
        hints[#hints + 1] = K.H({ "R3" }, "Read", "R3")
    end
    local capturing = self:IsCapturingChord()
    if capturing then hints = { K.H({ "B" }, L.V_CANCEL, "B") } end
    if self.armed then hints = { K.H({ "A" }, L.V_CONFIRM, "A"), K.H({ "B" }, L.V_CANCEL, "B") } end
    local crumb, color = page.Crumb and page:Crumb() or L["TAB_" .. self.tab:upper()], KC.grey
    if capturing then crumb = L.CFG_SHORTCUT_PRESS end
    if self.toast then crumb, color = self.toast.text, self.toast.color end
    f.crumb:SetText(crumb)
    f.crumb:SetTextColor(unpack(color))
    local total, minimum = 0, 0
    for i = 1, #hints do
        local h = f.hints[i]
        if not h then
            h = K.Hint(f.bar)
            f.hints[i] = h
        end
        h:Set(hints[i])
        total = total + h:GetWidth()
        minimum = minimum + h.minWidth
    end
    local room = W - 36 - math.max(0, #hints - 1) * 12
    local x = W - 36
    for i = #hints, 1, -1 do
        local h = f.hints[i]
        if total > room and total > minimum then
            local share = (h:GetWidth() - h.minWidth) / (total - minimum)
            h:Set(hints[i], h.minWidth + math.max(0, room - minimum) * share)
        end
        h:ClearAllPoints()
        h:SetPoint("RIGHT", f.bar, "LEFT", x, 0)
        x = x - h:GetWidth() - 12
    end
    for i = #hints + 1, #f.hints do f.hints[i]:Hide() end
    f.crumb:SetWidth(math.max(1, math.min(200, x)))
    f.crumb:SetShown(x > 24)
end

---------------------------------------------------------------------------
-- Pad input while open: hidden buttons bound with priority, like the keyboard
---------------------------------------------------------------------------
local NAV = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", ESCAPE = "B",
    PADRSTICK = "R3",
}
-- Held triggers may add modifiers to the keys
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local REPEAT = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

-- A hint of the help bar clicked: its button pressed (while the shortcut is
-- being learned, only "B Cancel" is there)
function C:ClickHint(name)
    if self:IsCapturingChord() then
        if name == "B" then self:StopChordCapture(nil) end
        return
    end
    self:Press(name)
end

function C:Press(name)
    -- Learning the shortcut: the presses are for it
    if self:IsCapturingChord() then return end
    -- Placing something on the HUD (extra buttons, supplies)
    if self.placing then
        self.placer:PlacementPress(name)
        return
    end
    -- A destructive button armed: A does it, B cancels, a move lets it go
    if self.armed then
        if name == "B" then
            self:Disarm()
            return self:Render()
        end
        if name == "LB" or name == "RB" then return end
        if name ~= "A" then self:Disarm() end
    end
    local page = self:Page()
    local detail = page.detail
    if self.readingDetail then
        if name == "UP" or name == "DOWN" then
            detail:Scroll(name == "UP" and -1 or 1)
            return
        end
        self.readingDetail = nil
        if name == "B" or name == "R3" then self:RenderHelp(page); return end
    elseif name == "R3" and detail and detail:IsShown() and detail.CanScroll and detail:CanScroll() then
        self.readingDetail = true
        self.readingDetailKey = detail.contentKey
        self:RenderHelp(page)
        return
    end
    if page:Press(name) then return end
    if name == "LB" or name == "RB" then
        self:StepTab(name == "LB" and -1 or 1)
    elseif name == "B" then
        self:Close()
    end
end

function C:CreateInput()
    for key, name in pairs(NAV) do
        local b = CK.NewFrame("Button", "ControllerKeyboardConfigPad" .. key)
        b:SetSize(1, 1)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetScript("OnClick", function(_, _, down)
            -- A button of the shortcut just learned, still held
            if C.swallow and C.swallow[key] then
                if down == false then C.swallow[key] = nil end
                return
            end
            -- B acts on release: closing the panel on the press would leave
            -- the release to the game alone
            if name == "B" then
                if down == false then C:Press(name) end
                return
            end
            if down == false then
                if C.repeatName == name then C.repeatName = nil end
                return
            end
            if REPEAT[name] then
                C.repeatName, C.repeatKey, C.repeatAt = name, key, GetTime() + 0.35
            end
            C:Press(name)
        end)
    end
end

local function bindKey(f, key)
    local name = "ControllerKeyboardConfigPad" .. key
    if key == "ESCAPE" then
        SetOverrideBindingClick(f, true, key, name)
    else
        for _, prefix in ipairs(PREFIXES) do SetOverrideBindingClick(f, true, prefix .. key, name) end
    end
end

-- A button still held (RB of the RB + D-pad down shortcut...) is taken only
-- once released: its release belongs to the game, which saw it pressed (RB
-- held is the game's hostile targeting, until it is released)
function C:BindPad()
    -- The addon's keyboard typing a name for the panel: the pad is its own
    if InCombatLockdown() or not self.frame or CK.prompt then return end
    local f = self.frame
    ClearOverrideBindings(f)
    self.heldKeys = {}
    for key in pairs(NAV) do
        if key ~= "ESCAPE" and IsKeyDown and IsKeyDown(key) then
            self.heldKeys[key] = true
        else
            bindKey(f, key)
        end
    end
end

function C:BindReleasedKeys()
    if not self.heldKeys or not next(self.heldKeys) or InCombatLockdown() then return end
    for key in pairs(self.heldKeys) do
        if not IsKeyDown(key) then
            self.heldKeys[key] = nil
            bindKey(self.frame, key)
        end
    end
end

function C:UnbindPad()
    self.heldKeys = nil
    if self.frame and not InCombatLockdown() then ClearOverrideBindings(self.frame) end
end

function C:OnUpdate(elapsed)
    self:BindReleasedKeys()
    if self.swallow and IsKeyDown then
        for key in pairs(self.swallow) do
            if not IsKeyDown(key) then self.swallow[key] = nil end
        end
    end
    local page = self:Page()
    if page and page.OnUpdate then page:OnUpdate(elapsed) end
    -- Its release went elsewhere (the game rebound the pad): over
    if self.repeatName and IsKeyDown and self.repeatKey and not IsKeyDown(self.repeatKey) then
        self.repeatName = nil
    end
    if self.repeatName and GetTime() >= self.repeatAt then
        self.repeatAt = GetTime() + 0.08
        self:Press(self.repeatName)
    end
end

---------------------------------------------------------------------------
-- Open / close: back on the last tab and section
---------------------------------------------------------------------------
function C:Open(tab, section)
    if CK:BlockedByCombat() then return end
    self:Build()
    self:DropPlacement()
    local alias = tab and C.ALIASES[tab]
    if alias then tab, section = alias[1], section or alias[2] end
    if self.frame:IsShown() then
        if tab and self.pages[tab] then self:SetTab(tab, section) end
        return
    end
    self.readingDetail = nil
    -- Else the tab last used (a 1.x name maps to its 2.0 tab)
    local key = tab
    if not (key and self.pages[key]) then
        key = settings().configTab
        local old = key and C.ALIASES[key]
        -- with its section ("supplies": Alerts, Supplies)
        if old then key, section = old[1], section or old[2] end
    end
    if not self.pages[key or ""] then key = "home" end
    self.tab = key
    settings().configTab = key
    self:Disarm()
    -- What the game binds, before our own pad bindings hide it
    CK.Mapping:TakeSnapshot()
    self.frame:Show()
    local page = self:Page()
    page:Show()
    if section and page.SetSection then page:SetSection(section, "list") end
    self:BindPad()
    self:Render()
end

-- A placement on the HUD ended without going back to the panel (closed,
-- combat, the panel's key)
function C:DropPlacement()
    if not self.placing then return end
    if self.placer then self.placer:StopPlacement() end
    self.placing, self.placer = false, nil
end

function C:Close()
    self.readingDetail = nil
    if not self:IsOpen() then return end
    self:DropPlacement()
    CK.Paddles:StopCapture(nil)
    self:StopChordCapture(nil)
    self:Disarm()
    local page = self:Page()
    if page then page:Hide() end
    self:UnbindPad()
    self.frame:Hide()
    self.repeatName = nil
    CK.Mapping:DropSnapshot()
    CK.Mapping:Apply()
end

function C:Toggle(tab)
    if self:IsOpen() then self:Close() else self:Open(tab) end
end

-- Placing things on the HUD (the extra buttons, the supplies): the panel
-- steps aside and keeps the pad, the placer gets the presses
function C:BeginPlacement(placer)
    self.placer = placer or CK.Paddles
    self.placing = true
    self.frame:Hide()
    self.repeatName = nil
end

function C:EndPlacement()
    self.placing = false
    self.frame:Show()
    self:Page():Show(true)
    self:Render()
end

-- Nothing of the game's has the pad: no settings, game menu, chat or other
-- gamepad window
function C:GameIsFree()
    if SettingsPanel and SettingsPanel:IsShown() then return false end
    if GameMenuFrame and GameMenuFrame:IsShown() then return false end
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if manager and manager.GetActiveFrame and manager:GetActiveFrame() then return false end
    local chat = CK.ActiveChatWindow and CK.ActiveChatWindow()
    return not (chat and chat:HasFocus())
end

-- From the game's options or the chat: those have the pad, and closing the
-- options brings back the game menu, whose B would close the panel too.
-- Open once the player is back in the game.
function C:OpenWhenFree(tab)
    if self:GameIsFree() then
        self:Open(tab)
        return
    end
    self.openLater = tab or true
    if SettingsPanel and SettingsPanel:IsShown() then CK:Print(L.CFG_OPEN_LATER) end
    if self.laterTicker then return end
    local tries = 0
    self.laterTicker = C_Timer.NewTicker(0.25, function(ticker)
        tries = tries + 1
        local later = C.openLater
        if later and C:GameIsFree() and not InCombatLockdown() then
            C.openLater = nil
            C:Open(later ~= true and later or nil)
        end
        -- Given up after two minutes
        if not C.openLater or tries > 480 then
            ticker:Cancel()
            C.laterTicker, C.openLater = nil, nil
        end
    end)
end

function C:Init()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    local redraw
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then return C:Close() end
        if redraw or not (C.frame and C.frame:IsShown()) then return end
        redraw = true
        C_Timer.After(0.2, function()
            redraw = nil
            -- Closed meanwhile, or placing on the HUD: nothing to draw
            if C.frame and C.frame:IsShown() and not C.placing then C:Render() end
        end)
    end)
    -- A game window opened meanwhile (Start menu...) rebinds the pad when it
    -- closes: take the panel's keys back
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("Gamepad.RefreshFrameFocus", function()
            C_Timer.After(0, function()
                local manager = GamepadMode and GamepadMode.FrameControlsManager
                local focused = manager and manager.GetActiveFrame and manager:GetActiveFrame()
                if C:IsOpen() and not focused and not InCombatLockdown() then C:BindPad() end
            end)
        end, C)
    end
    -- The panel's shortcut: a button held, another pressed (RB + D-pad down
    -- by default: with RB held, the game's hostile targeting bar turns its
    -- D-pad off). Only watched, never bound: the game keeps whatever it does
    -- with them, and the game's own windows keep their buttons.
    local watch = CK.NewFrame("Frame", nil, UIParent)
    C.watch = watch
    local wasDown = false
    watch:SetScript("OnUpdate", function()
        local s = CK.db.settings
        local chord = s.shortcut
        if not (s.features.configShortcut and chord and IsKeyDown) then
            wasDown = false
            CK.Mapping:Resume()
            return
        end
        -- Its first button held: our action on the second one waits (the
        -- press opens the panel only), back once it is released
        local M = CK.Mapping
        if IsKeyDown(chord.hold) then
            if not M.suspended and M:IsOurs(chord.press) and not InCombatLockdown() then M:Suspend(chord.press) end
        elseif M.suspended then
            M:Resume()
        end
        -- While the panel is open, and after it closes until the buttons
        -- are released, the combination does nothing
        if C:IsOpen() then
            wasDown = true
            return
        end
        local down = IsKeyDown(chord.hold) and IsKeyDown(chord.press) and true or false
        if down and not wasDown and not InCombatLockdown() and C:GameIsFree() then C:Open() end
        wasDown = down
    end)
end

---------------------------------------------------------------------------
-- Learning the panel's shortcut: hold a button, press a second one
---------------------------------------------------------------------------
function C:StopChordCapture(chord)
    local f = self.chordFrame
    if not (f and f:IsShown()) then return end
    f:Hide()
    if f.timer then f.timer:Cancel() end
    if not InCombatLockdown() then
        f:EnableKeyboard(false)
        if f.EnableGamePadButton then f:EnableGamePadButton(false) end
    end
    local onDone = f.onDone
    f.onDone, f.held = nil, nil
    -- The chord's buttons are still held: their release is not a press for
    -- the panel (a chord with B would go back)
    if chord then self:Swallow({ [chord.hold] = true, [chord.press] = true }) end
    if onDone then onDone(chord) end
end

-- Buttons pressed for something else (a capture): their release, should it
-- reach the panel's keys, is no press
function C:Swallow(keys)
    self.swallow = keys
    local function check()
        if C.swallow ~= keys then return end
        for key in pairs(keys) do
            if IsKeyDown and IsKeyDown(key) then return C_Timer.After(0.5, check) end
        end
        C.swallow = nil
    end
    C_Timer.After(2, check)
end

-- A panel button pressed while a capture frame had the pad (a paddle's key
-- being learned: B cancels, X skips one): pressed here, as the game may keep
-- it from the panel's keys
function C:PressFromCapture(key)
    local name = NAV[key]
    if not name then return end
    self:Swallow({ [key] = true })
    self:Press(name)
end

function C:CaptureChord(onDone)
    if CK:BlockedByCombat() then return end
    local f = self.chordFrame
    if not f then
        f = CK.NewFrame("Frame", nil, UIParent)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetSize(1, 1)
        f:SetPoint("CENTER")
        f:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then
                C:StopChordCapture(nil)
                C:Swallow({ ESCAPE = true })
            end
        end)
        if f.EnableGamePadButton then
            -- The buttons stop here (false: not passed on to the game)
            f:SetScript("OnGamePadButtonDown", function(self, button)
                local held = self.held
                if held and held ~= button and IsKeyDown(held) then
                    C:StopChordCapture({ hold = held, press = button })
                else
                    self.held = button
                end
                return false
            end)
            -- B pressed and released alone cancels
            f:SetScript("OnGamePadButtonUp", function(self, button)
                if button == self.held then
                    if button == "PAD2" then
                        C:StopChordCapture(nil)
                    else
                        self.held = nil
                    end
                end
                return false
            end)
        end
        f:Hide()
        self.chordFrame = f
    end
    f.onDone, f.held = onDone, nil
    if f.timer then f.timer:Cancel() end
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(false)
    if f.EnableGamePadButton then f:EnableGamePadButton(true) end
    f:Show()
    f.timer = C_Timer.NewTimer(10, function() C:StopChordCapture(nil) end)
end

function C:IsCapturingChord()
    return self.chordFrame and self.chordFrame:IsShown() or false
end

-- Key bindings
function ControllerKeyboard_OpenConfig()
    C:Toggle()
end

function ControllerKeyboard_OpenMap()
    if C:IsOpen() and C.tab ~= "gamepad" and not C.placing then
        C:SetTab("gamepad")
    else
        C:Toggle("gamepad")
    end
end
