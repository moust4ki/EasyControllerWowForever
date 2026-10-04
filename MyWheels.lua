local _, CK = ...
local L = CK.L

-- Module "my wheels": wheels of the player's own, drawn and handled like the
-- consumables wheel (ConsumableWheel.lua shows them all): 8 slots each, the
-- spells, items and macros the player picks, up to 8 wheels. Each has a key
-- of its own: the Gamepad tab's Items list (any button), or the game's Key
-- Bindings ("CLICK ControllerKeyboardMyWheelN"). Made, named and filled in
-- the Wheels tab: the list of wheels, and each wheel's editor (its slots
-- around it, what a slot can take beside them); names typed with the
-- addon's keyboard or a physical one.
local MW = {}
CK.MyWheels = MW

local SLOTS = 8
-- The lists a slot takes from (the Gamepad tab's)
local TABS = { "spells", "items", "macros" }

local function settings() return CK.db.settings.myWheels end
local function bindings(kind)
    if CK.Profiles and CK.Profiles.ready then return CK.Profiles:BindingPairs(kind) end
    return pairs(CK.db.settings[kind])
end

---------------------------------------------------------------------------
-- The wheels: settings.myWheels.list = { { id = 1-8, name, slots = { [1-8] = "spell:133" } } }
---------------------------------------------------------------------------
function MW:List()
    return settings().list
end

function MW:Get(id)
    for _, w in ipairs(self:List()) do
        if w.id == id then return w end
    end
end

function MW:Name(id)
    local w = self:Get(id)
    return w and w.name
end

function MW:Count(w)
    local n = 0
    for i = 1, SLOTS do
        if w.slots[i] then n = n + 1 end
    end
    return n
end

-- Its picture: its first slot's
function MW:Icon(id)
    local w = self:Get(id)
    for i = 1, SLOTS do
        local action = w and w.slots[i]
        local icon = action and CK.Mapping:ActionIcon(action)
        if icon then return icon end
    end
    return CK.Mapping.WHEEL_ICON
end

-- What ConsumableWheel.lua puts in it: { [slot] = entry }
function MW:Entries(id)
    local w = self:Get(id)
    local entries = {}
    for i = 1, SLOTS do
        local kind, value = ((w and w.slots[i]) or ""):match("^(%a+):(.+)$")
        if kind == "spell" or kind == "item" then
            entries[i] = { kind = kind, id = tonumber(value) }
        elseif kind == "macro" and GetMacroInfo(value) then
            entries[i] = { kind = "macro", name = value }
        end
    end
    return entries
end

local function changed()
    MW:UpdateBindingNames()
    CK.ConsumableWheel:Fill()
end

function MW:Create()
    local used = {}
    for _, w in ipairs(self:List()) do used[w.id] = true end
    for id = 1, CK.ConsumableWheel.MY_MAX do
        if not used[id] then
            table.insert(self:List(), { id = id, name = format(L.MYWHEEL_DEFAULT, id), slots = {} })
            changed()
            return id
        end
    end
end

-- Gone, and gone from every button it was on
function MW:Delete(id)
    local list = self:List()
    for i, w in ipairs(list) do
        if w.id == id then table.remove(list, i) break end
    end
    local action = "wheel:" .. id
    for _, kind in ipairs({ "mapping", "replaced" }) do
        for key, value in bindings(kind) do
            if value == action then
                if CK.Profiles and CK.Profiles.ready then CK.Profiles:SetBinding(kind, key, nil)
                else CK.db.settings[kind][key] = nil end
            end
        end
    end
    changed()
    CK.Mapping:Apply()
    CK.Paddles:Apply()
end

function MW:SetSlot(id, slot, action)
    local w = self:Get(id)
    if not w then return end
    w.slots[slot] = action
    changed()
end

function MW:Rename(id, name)
    local w = self:Get(id)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if not w or name == "" then return end
    w.name = CK.Utf8Sub(name, 40)
    changed()
end

-- The game's Key Bindings menu shows each wheel's name
function MW:UpdateBindingNames()
    for id = 1, CK.ConsumableWheel.MY_MAX do
        _G["BINDING_NAME_CLICK ControllerKeyboardMyWheel" .. id .. ":LeftButton"] =
            self:Name(id) or format(L.MYWHEEL_DEFAULT, id)
    end
end

-- The button a wheel is on (the first found): its input and layer
function MW:Bound(id)
    local action = "wheel:" .. id
    for _, kind in ipairs({ "mapping", "replaced" }) do
        for key, value in bindings(kind) do
            if value == action then
                local input, layer = key:match("^(%w+):(%w*)$")
                if input then return input, layer end
            end
        end
    end
end

-- "RT + X" with the glyphs, or nil
function MW:BoundText(id, size)
    local input, layer = self:Bound(id)
    return input and CK.ConfigKit.ComboMarkup(input, layer, size or 14)
end

local K = CK.ConfigKit
local KC = K.C
local C = CK.Config

local KIND_COLOR = { spell = "spell", item = "item", macro = "macro" }

local function positions() return { strsplit(",", L.MYWHEEL_POS) } end

---------------------------------------------------------------------------
-- The Wheels tab, My wheels: a grid of cards, "New wheel" first. Each card
-- shows its 8 slots (a dot each), its name and the button it is on.
---------------------------------------------------------------------------
local G = {}
MW.Grid = G
G.cell = 1

local CARD_W, CARD_H, COLS, COL_GAP, ROW_GAP = 116, 124, 3, 10, 4
local PREVIEW, DOT, DOT_R = 80, 14, 27

local function newCard(parent, i)
    local c = CK.NewFrame("Button", nil, parent)
    c:SetSize(CARD_W, CARD_H)
    c.preview = CK.NewFrame("Frame", nil, c)
    c.preview:SetSize(PREVIEW, PREVIEW)
    c.preview:SetPoint("TOP", 0, 0)
    -- "New wheel": a slot and a "+"
    c.slot = c.preview:CreateTexture(nil, "ARTWORK")
    c.slot:SetTexture(K.TEX .. "ck_slot")
    c.slot:SetSize(64, 64)
    c.slot:SetPoint("CENTER")
    c.plus = K.Text(c.preview, 28, KC.title, "OVERLAY")
    c.plus:SetPoint("CENTER", 0, 1)
    c.plus:SetText("+")
    -- A wheel: its disc, a dot per slot, how many are filled
    c.disc = c.preview:CreateTexture(nil, "ARTWORK")
    c.disc:SetTexture(K.TEX .. "ck_disc")
    c.disc:SetAllPoints()
    c.dots = {}
    for n = 1, 8 do
        local a = (n - 1) * math.pi / 4
        local edge = c.preview:CreateTexture(nil, "OVERLAY", nil, 0)
        edge:SetTexture(K.TEX .. "ck_dot")
        edge:SetSize(DOT, DOT)
        edge:SetPoint("CENTER", c.preview, "CENTER", DOT_R * math.sin(a), DOT_R * math.cos(a))
        local fill = c.preview:CreateTexture(nil, "OVERLAY", nil, 1)
        fill:SetTexture(K.TEX .. "ck_dot")
        fill:SetSize(DOT - 2, DOT - 2)
        fill:SetPoint("CENTER", edge, "CENTER")
        c.dots[n] = { edge = edge, fill = fill }
    end
    c.count = K.Text(c.preview, 13, KC.cream, "OVERLAY")
    c.count:SetPoint("CENTER", 0, 0)
    c.glow = c.preview:CreateTexture(nil, "OVERLAY", nil, 3)
    c.glow:SetTexture(K.TEX .. "ck_slot_glow")
    c.glow:SetBlendMode("ADD")
    c.glow:SetAllPoints()
    c.name = K.Text(c, 14, KC.cream)
    c.name:SetPoint("TOP", c.preview, "BOTTOM", 0, -2)
    c.name:SetWidth(112)
    c.name:SetJustifyH("CENTER")
    if c.name.SetMaxLines then c.name:SetMaxLines(1) end
    c.sub = K.ChatText(c, 12, KC.grey)
    c.sub:SetPoint("TOP", c.name, "BOTTOM", 0, -2)
    c.sub:SetWidth(112)
    c.sub:SetJustifyH("CENTER")
    c:SetScript("OnClick", function()
        local page = C:Page()
        if page.SetZone then page:SetZone("list") end
        G.cell = i
        G:Activate()
    end)
    return c
end

function G:Build(list)
    local f = CK.NewFrame("Frame", nil, list)
    f:SetAllPoints()
    f:Hide()
    self.frame = f
    f.head = K.Text(f, 15, KC.title)
    f.head:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, -25)
    f.total = K.ChatText(f, 13, KC.grey)
    f.total:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -2, -25)
    local line = K.Solid(f, KC.line2, 1, "BORDER")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -30)
    line:SetPoint("TOPRIGHT", 0, -30)
    f.cards = {}
    for i = 1, CK.ConsumableWheel.MY_MAX + 1 do
        local c = newCard(f, i)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        c:SetPoint("TOPLEFT", col * (CARD_W + COL_GAP), -38 - row * (CARD_H + ROW_GAP))
        f.cards[i] = c
    end
end

-- The cards: "New wheel", then each wheel
function G:Cells()
    local cells = { { new = true } }
    for _, w in ipairs(MW:List()) do cells[#cells + 1] = { wheel = w } end
    return cells
end

function G:Render(page, focused)
    local f, cells = self.frame, self:Cells()
    self.cell = math.max(1, math.min(self.cell or 1, #cells))
    local list = MW:List()
    local max = CK.ConsumableWheel.MY_MAX
    f.head:SetText(L.MYWHEEL_H)
    f.total:SetText(format("%d / %d", #list, max))
    for i, c in ipairs(f.cards) do
        local cell = cells[i]
        c:SetShown(cell ~= nil)
        if cell then
            local focus = focused and i == self.cell
            c.glow:SetShown(focus)
            c.slot:SetShown(cell.new or false)
            c.plus:SetShown(cell.new or false)
            c.disc:SetShown(not cell.new)
            c.count:SetShown(not cell.new)
            local nameColor = focus and KC.focus or KC.cream
            c.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
            if cell.new then
                c.name:SetText(L.MYWHEEL_NEW)
                c.sub:SetText(format(L.LBL_N_LEFT, max - #list))
                c.sub:SetTextColor(KC.grey[1], KC.grey[2], KC.grey[3])
                for _, d in ipairs(c.dots) do
                    d.edge:Hide()
                    d.fill:Hide()
                end
                c:SetAlpha(#list >= max and 0.4 or 1)
            else
                local w = cell.wheel
                c:SetAlpha(1)
                c.name:SetText(w.name)
                c.count:SetText(format("%d/%d", MW:Count(w), 8))
                for n, d in ipairs(c.dots) do
                    local kind = (w.slots[n] or ""):match("^(%a+):")
                    local filled = KIND_COLOR[kind] and KC[KIND_COLOR[kind]]
                    local edge = filled and KC.slot or KC.emptyDot
                    local fill = filled or KC.controlBg
                    d.edge:SetVertexColor(edge[1], edge[2], edge[3])
                    d.fill:SetVertexColor(fill[1], fill[2], fill[3])
                    d.edge:Show()
                    d.fill:Show()
                end
                local bound = MW:BoundText(w.id, 12)
                c.sub:SetText(bound or L.LBL_NO_BUTTON)
                local sc = bound and KC.info or KC.eventOff
                c.sub:SetTextColor(sc[1], sc[2], sc[3])
            end
        end
    end
end

function G:Activate()
    local cell = self:Cells()[self.cell]
    if not cell then return end
    if cell.new then
        local id = MW:Create()
        if id then MW:OpenEditor(id, true) end
    else
        MW:OpenEditor(cell.wheel.id)
    end
end

function G:Press(page, name)
    local n = #self:Cells()
    local i = self.cell
    if name == "LEFT" then
        if (i - 1) % COLS == 0 then return false end
        self.cell = i - 1
    elseif name == "RIGHT" then
        if (i - 1) % COLS < COLS - 1 and i < n then self.cell = i + 1 end
    elseif name == "UP" then
        if i > COLS then self.cell = i - COLS end
    elseif name == "DOWN" then
        if i + COLS <= n then self.cell = i + COLS end
    elseif name == "A" then
        self:Activate()
        return true
    else
        return false
    end
    C:Render()
    return true
end

function G:Detail()
    local cell = self:Cells()[self.cell]
    if not cell then return {} end
    if cell.new then
        local full = #MW:List() >= CK.ConsumableWheel.MY_MAX
        return { title = L.MYWHEEL_NEW, body = full and L.MYWHEEL_FULL or L.MYWHEEL_NEW_TIP }
    end
    local w = cell.wheel
    return { title = w.name, tag = L.TAG_MY_WHEEL, tagColor = KC.yours, body = format(L.MYWHEEL_FILLED, MW:Count(w)),
        extra = MW:BoundText(w.id, 14) }
end

function G:Help()
    local H = K.H
    local cell = self:Cells()[self.cell]
    local full = cell and cell.new and #MW:List() >= CK.ConsumableWheel.MY_MAX
    local list = { H({ "DPAD" }, L.V_MOVE) }
    if not full then list[#list + 1] = H({ "A" }, cell and cell.new and L.V_CREATE or L.V_EDIT, "A") end
    list[#list + 1] = H({ "LB", "RB" }, L.V_TAB, "RB")
    list[#list + 1] = H({ "B" }, L.V_BACK, "B")
    return list
end

-- The card of a wheel
function G:Focus(id)
    for i, cell in ipairs(self:Cells()) do
        if cell.wheel and cell.wheel.id == id then self.cell = i end
    end
end

---------------------------------------------------------------------------
-- The tab's page: the rail of sections, or a wheel's editor in its place
---------------------------------------------------------------------------
function MW:TabPage(rail)
    self.rail = rail
    local E = self.Editor
    local page = {}
    local function current() return MW.open and E or rail end
    function page:Build(parent)
        rail:Build(parent)
        E:Build(parent)
    end
    function page:Show(resume)
        if MW.open then
            rail:Hide()
            E:Show()
        else
            E:Hide()
            rail:Show(resume)
        end
    end
    -- Leaving the tab closes the editor
    function page:Hide()
        if MW.open then
            MW:FinishRename(nil)
            MW.open = false
            G:Focus(E.id)
        end
        rail:Hide()
        E:Hide()
    end
    function page:Render() current():Render() end
    function page:Press(name) return current():Press(name) end
    function page:Help() return current():Help() end
    function page:Crumb() return current():Crumb() end
    function page:SetZone(zone) rail.zone = zone end
    page.rail = rail
    function page:SetSection(i, zone)
        if MW.open then MW:CloseEditor() end
        rail:SetSection(i, zone)
    end
    return page
end

function MW:OpenEditor(id, toPicker)
    if not self:Get(id) then return end
    self.open = true
    self.rail:Hide()
    self.Editor:Open(id, toPicker)
    C:Render()
end

function MW:CloseEditor()
    if not self.open then return end
    local id = self.Editor.id
    self:FinishRename(nil)
    self.open = false
    self.Editor:Hide()
    G:Focus(id)
    self.rail:Show()
    C:Render()
end

---------------------------------------------------------------------------
-- A wheel's editor: the wheel (disc, hub with its name and count, its 8
-- slots around it and their names), the button it is on, Rename / Assign a
-- button / Delete; on the right, always, the lists picker: a choice fills
-- the slot aimed at (dashed ring) and goes on to the next one.
---------------------------------------------------------------------------
local E = {}
MW.Editor = E

local ZONE_W, PANEL_W, BODY_H, WHEEL_H = 480, 292, 424, 384
local CX, CY, RADIUS = 240, 186, 108
local SLOT_SIZE, ICON_SIZE = 52, 38
local TABS = { "spells", "items", "macros" }

local function slotPoint(i)
    local a = (i - 1) * math.pi / 4
    return CX + RADIUS * math.sin(a), CY - RADIUS * math.cos(a)
end

function E:Build(parent)
    local f = CK.NewFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()
    self.frame = f

    local zone = CK.NewFrame("Frame", nil, f)
    zone:SetPoint("TOPLEFT")
    zone:SetSize(ZONE_W, WHEEL_H)
    f.zone = zone
    -- Match the live wheel's opaque native brown rock and weathered bevel,
    -- while keeping all editor slots and labels at their existing positions.
    local function setAtlas(texture, name, fallback)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
            texture:SetAtlas(name, false)
        elseif fallback then
            texture:SetTexture(fallback)
        end
    end
    local disc = zone:CreateTexture(nil, "BACKGROUND", nil, -3)
    disc:SetColorTexture(0.055, 0.04, 0.025, 1)
    -- Match the native minimap mask to the rim's inner face; the old soft
    -- portrait mask exposed its square boundary when enlarged here.
    disc:SetSize(272, 272)
    disc:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    f.face = disc
    local material = zone:CreateTexture(nil, "BACKGROUND", nil, -2)
    material:SetAllPoints(disc)
    material:SetTexture(K.TEX .. "ck_panel_bg", "REPEAT", "REPEAT")
    material:SetHorizTile(true); material:SetVertTile(true)
    material:SetVertexColor(0.72, 0.62, 0.48, 1)
    f.faceArt = material
    local mask = zone:CreateMaskTexture()
    mask:SetAllPoints(disc)
    setAtlas(mask, "ui-hud-minimap-frame-generic-mask", "Interface\\CharacterFrame\\TempPortraitAlphaMask")
    disc:AddMaskTexture(mask); material:AddMaskTexture(mask)
    f.faceMask = mask
    local rim = zone:CreateTexture(nil, "BORDER")
    rim:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    setAtlas(rim, "UI-HUD-Minimap-Frame-Circle")
    -- Native padding makes the full 347px atlas's visible rim about 290px.
    rim:SetSize(347, 347)
    f.rim = rim
    local hub = zone:CreateTexture(nil, "BORDER")
    setAtlas(hub, "ui-hud-minimap-frame-generic-mask", "Interface\\CharacterFrame\\TempPortraitAlphaMask")
    hub:SetVertexColor(0.035, 0.025, 0.016, 1)
    hub:SetSize(100, 100)
    hub:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    f.hub = hub
    local hubRim = zone:CreateTexture(nil, "BORDER", nil, 1)
    hubRim:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    setAtlas(hubRim, "UI-HUD-Minimap-Frame-Circle")
    hubRim:SetSize(128, 128)
    f.hubRim = hubRim
    f.name = K.Text(zone, 14, KC.title)
    f.name:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY - 11))
    f.name:SetSize(86, 18)
    f.name:SetWordWrap(true)
    if f.name.SetNonSpaceWrap then f.name:SetNonSpaceWrap(true) end
    f.name:SetJustifyH("CENTER")
    if f.name.SetMaxLines then f.name:SetMaxLines(1) end
    f.count = K.Text(zone, 20, KC.cream)
    f.count:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY + 12))
    f.count:SetJustifyH("CENTER")

    f.slots, f.labels = {}, {}
    for i = 1, 8 do
        local x, y = slotPoint(i)
        local s = K.Slot(zone, SLOT_SIZE, ICON_SIZE)
        s:SetPoint("CENTER", zone, "TOPLEFT", x, -y)
        s:SetScript("OnClick", function(_, button)
            if MW.renaming then return end
            C:Disarm()
            E.slot = i
            if button == "RightButton" then
                E:Empty()
            else
                E:Aim()
            end
        end)
        f.slots[i] = s
        -- Its name outside the ring: beside it on the sides (aligned
        -- outwards), above the top one, under the bottom one
        local a = (i - 1) * math.pi / 4
        local sn, cs = math.sin(a), math.cos(a)
        local label = K.Text(zone, 13, KC.grey)
        label:SetSize(100, 32)
        label:SetWordWrap(true)
        if label.SetMaxLines then label:SetMaxLines(2) end
        local lx, ly
        if sn > 0.3 then
            lx = CX + 150 * sn
            label:SetJustifyH("LEFT")
        elseif sn < -0.3 then
            lx = CX + 150 * sn - 100
            label:SetJustifyH("RIGHT")
        else
            lx = CX - 50
            label:SetJustifyH("CENTER")
        end
        if math.abs(sn) > 0.3 then
            ly = CY - 150 * cs - 16
        else
            ly = (cs > 0 and CY - 168 or CY + 147) - 16
        end
        label:SetPoint("TOPLEFT", zone, "TOPLEFT", lx, -ly)
        f.labels[i] = label
    end

    -- The button it is on, under the wheel
    local bind = CK.NewFrame("Frame", nil, zone)
    bind:SetSize(10, 20)
    bind:SetPoint("BOTTOM", zone, "BOTTOM", 0, -4)
    bind.label = K.ChatText(bind, 13, KC.grey)
    bind.label:SetPoint("LEFT")
    bind.label:SetText(L.LBL_BUTTON)
    bind.chip = CK.NewFrame("Frame", nil, bind)
    bind.chip:SetHeight(20)
    bind.chip:SetPoint("LEFT", bind.label, "RIGHT", 8, 0)
    bind.chip.box = K.Box(bind.chip, 3, 2, "ARTWORK")
    bind.chip.box:SetPoints(bind.chip)
    bind.chip.box:SetColors(KC.controlBg, 1, KC.control, 1)
    bind.chip.text = K.Text(bind.chip, 14, KC.info)
    bind.chip.text:SetPoint("CENTER", 0, 0)
    f.bind = bind

    -- Rename, Assign a button, Delete
    local row = CK.NewFrame("Frame", nil, f)
    row:SetPoint("TOPLEFT", 0, -(WHEEL_H + 8))
    row:SetSize(ZONE_W, 32)
    f.buttonRow = row
    f.buttons = {}
    for i = 1, 3 do
        local b = K.Button(row, 15)
        b:SetScript("OnClick", function()
            if MW.renaming then return end
            if i ~= 3 then C:Disarm() end
            E.zone, E.btn = "buttons", i
            E:Button(i)
        end)
        f.buttons[i] = b
    end

    -- The name typed in a box over the wheel (a physical keyboard, or the
    -- addon's keyboard with the pad)
    local veil = CK.NewFrame("Frame", nil, zone)
    veil:SetAllPoints()
    veil:SetFrameLevel(zone:GetFrameLevel() + 20)
    veil:EnableMouse(true)
    K.Solid(veil, { 0.04, 0.03, 0.02 }, 0.72, "BACKGROUND"):SetAllPoints()
    veil:Hide()
    f.veil = veil
    local box = CK.NewFrame("Frame", nil, veil)
    box:SetSize(340, 136)
    box:SetPoint("TOPLEFT", zone, "TOPLEFT", 70, -150)
    box.bg = K.Box(box, 4, 2, "BACKGROUND")
    box.bg:SetPoints(box)
    box.bg:SetColors(KC.panel, 1, KC.focus, 1)
    box.kicker = K.ChatText(box, 12, KC.grey)
    box.kicker:SetPoint("TOPLEFT", 14, -14)
    box.kicker:SetText(K.Upper(L.MYWHEEL_NAME_PROMPT))
    local field = CK.NewFrame("Frame", nil, box)
    field:SetPoint("TOPLEFT", box.kicker, "BOTTOMLEFT", 0, -8)
    field:SetSize(340 - 28, 36)
    field.box = K.Box(field, 3, 2, "ARTWORK")
    field.box:SetPoints(field)
    field.box:SetColors(KC.boxBg, 1, KC.control, 1)
    local edit = CK.NewFrame("EditBox", nil, field)
    edit:SetAllPoints()
    edit:SetFont(CK:GetFontPath(), 18, "")
    edit:SetTextColor(KC.focusText[1], KC.focusText[2], KC.focusText[3])
    edit:SetTextInsets(10, 10, 0, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(40)
    edit:SetScript("OnEnterPressed", function(self) MW:FinishRename(self:GetText()) end)
    edit:SetScript("OnEscapePressed", function() MW:FinishRename(nil) end)
    -- Typed on a physical keyboard: the addon's keyboard follows
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and CK.prompt and CK.prompt.box == self then
            CK.buffer = self:GetText()
            CK:Refresh()
        end
    end)
    box.edit = edit
    box.help = K.ChatText(box, 13, KC.help)
    box.help:SetPoint("TOPLEFT", field, "BOTTOMLEFT", 0, -8)
    box.help:SetWidth(340 - 28)
    box.help:SetWordWrap(true)
    box.help:SetSpacing(5)
    box.help:SetText(L.MYWHEEL_NAME_HELP)
    self.box = box

    -- Right: the lists picker, always there
    self.picker = K.Picker(f, PANEL_W)
    self.picker:SetPoint("TOPRIGHT")
    self.picker:SetHeight(BODY_H)
end

function E:Show() self.frame:Show() end

function E:Hide()
    self.picker:Close()
    self.frame:Hide()
end

function E:Wheel() return MW:Get(self.id) end

-- What a slot takes: the Gamepad tab's spells, items and macros
function E:Open(id, toPicker)
    self.id, self.slot, self.btn = id, 1, 1
    self.zone = toPicker and "picker" or "slots"
    local lists = {}
    for _, tab in ipairs(TABS) do
        lists[#lists + 1] = { key = tab, label = L["MAP_TAB_" .. tab:upper()], entries = function() return CK.Mapping:Catalog(tab, true) end }
    end
    local w = self:Wheel()
    self.picker:Open({
        kicker = function() return format(L.KICK_SLOT, E.slot, positions()[E.slot] or "") end,
        title = function() return E:Wheel() and E:Wheel().name or "" end,
        lists = lists, rows = 10, current = w and w.slots[1], chooseVerb = L.V_CHOOSE_NEXT,
        -- Already in this wheel: a cyan diamond
        marked = function(e)
            local wheel = E:Wheel()
            for i = 1, 8 do
                if wheel and wheel.slots[i] == e.action then return true end
            end
            return false
        end,
        onChoose = function(e)
            if MW.renaming then return end
            E:Fill(e)
        end,
        onBack = function()
            E.zone = "slots"
            C:Render()
        end,
    })
    self:Show()
end

-- The picker takes the focus, aimed at this slot (on what it holds)
function E:Aim()
    local w = self:Wheel()
    if not w then return end
    self.zone = "picker"
    local current = w.slots[self.slot]
    local def = self.picker.def
    if def then
        def.current = current
        local kind = current and current:match("^(%a+):")
        local list = kind and ({ spell = 1, item = 2, macro = 3 })[kind]
        if current then self.picker:SetList(list or self.picker.list) end
    end
    C:Render()
end

-- A choice fills the slot, and the next one is aimed at
function E:Fill(e)
    local w = self:Wheel()
    if not (w and e and e.action) then return end
    MW:SetSlot(self.id, self.slot, e.action)
    C:Toast(format(L.TOAST_PAIR, positions()[self.slot] or "", e.name or ""))
    self.slot = self.slot % 8 + 1
end

function E:Empty()
    local w = self:Wheel()
    if w and w.slots[self.slot] then
        MW:SetSlot(self.id, self.slot, nil)
        C:Toast(L.TOAST_SLOT_EMPTIED)
    end
    C:Render()
end

function E:Button(i)
    local b = self.frame and self.frame.buttons[i]
    if b then b:Pulse() end
    if i == 1 then
        MW:StartRename(self.id)
    elseif i == 2 then
        local id = self.id
        MW:CloseEditor()
        CK.MapPage:StartAssign(id)
    elseif i == 3 then
        if C:IsArmed("delwheel") then
            C:Disarm()
            local id = self.id
            MW:CloseEditor()
            MW:Delete(id)
            C:Toast(L.MYWHEEL_GONE)
        else
            C:Arm("delwheel")
            C:Render()
            if UIFrameFadeIn then UIFrameFadeIn(self.frame.buttons[3], 0.15, 0.3, 1) end
        end
    end
end

-- Around the wheel: the nearest slot that way (none down: the buttons)
function E:Nearest(dir)
    local fx, fy = slotPoint(self.slot)
    local best, bestScore
    for i = 1, 8 do
        if i ~= self.slot then
            local x, y = slotPoint(i)
            local dx, dy = x - fx, y - fy
            local main, cross
            if dir == "UP" then
                main, cross = -dy, dx
            elseif dir == "DOWN" then
                main, cross = dy, dx
            elseif dir == "LEFT" then
                main, cross = -dx, dy
            else
                main, cross = dx, dy
            end
            if main > 6 and math.abs(cross) <= main * 2.2 then
                local score = main + math.abs(cross) * 2
                if not bestScore or score < bestScore then best, bestScore = i, score end
            end
        end
    end
    return best
end

local DIRS = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

function E:Press(name)
    if self.zone == "rename" then
        if name == "A" then
            MW:FinishRename(self.box.edit:GetText())
        elseif name == "B" then
            MW:FinishRename(nil)
        end
        return true
    end
    if self.zone == "picker" then
        self.picker:Press(name)
        C:Render()
        return true
    end
    if self.zone == "buttons" then
        if name == "LEFT" or name == "RIGHT" then
            self.btn = math.max(1, math.min(3, self.btn + (name == "LEFT" and -1 or 1)))
        elseif name == "UP" then
            self.zone, self.slot = "slots", 5
        elseif name == "A" then
            self:Button(self.btn)
            return true
        elseif name == "B" then
            MW:CloseEditor()
            return true
        end
        C:Render()
        return true
    end
    if name == "LB" or name == "RB" then
        self.slot = (self.slot - 1 + (name == "LB" and -1 or 1)) % 8 + 1
    elseif DIRS[name] then
        local to = self:Nearest(name)
        if to then
            self.slot = to
        elseif name == "DOWN" then
            self.zone = "buttons"
        end
    elseif name == "A" then
        self:Aim()
        return true
    elseif name == "X" then
        self:Empty()
        return true
    elseif name == "Y" then
        MW:StartRename(self.id)
        return true
    elseif name == "B" then
        MW:CloseEditor()
        return true
    end
    C:Render()
    return true
end

function E:Help()
    local H = K.H
    if self.zone == "rename" then return { H({ "A" }, L.V_CONFIRM, "A"), H({ "B" }, L.V_CANCEL, "B") } end
    if self.zone == "picker" then return self.picker:Hints() end
    if self.zone == "buttons" then
        return { H({ "DPAD_LR" }, L.V_MOVE, "RIGHT"), H({ "A" }, L.V_SELECT, "A"), H({ "B" }, L.V_BACK, "B") }
    end
    return { H({ "DPAD", "LB", "RB" }, L.V_SLOT, "RB"), H({ "A" }, L.V_CHOOSE, "A"), H({ "X" }, L.V_EMPTY, "X"),
        H({ "Y" }, L.V_RENAME, "Y"), H({ "B" }, L.V_BACK, "B") }
end

function E:Crumb()
    local w = self:Wheel()
    return L.TAB_WHEELS .. " › " .. L.MYWHEEL_H .. " › " .. (w and w.name or "")
end

function E:Render()
    local f, w = self.frame, self:Wheel()
    if not (f and w) then return end
    f:Show()
    f.name:SetText(w.name)
    f.count:SetText(format("%d / %d", MW:Count(w), 8))
    local pos = positions()
    for i, s in ipairs(f.slots) do
        local action = w.slots[i]
        local focus = self.zone == "slots" and i == self.slot
        local target = self.zone == "picker" and i == self.slot
        s:SetLook({ icon = action and CK.Mapping:ActionIcon(action), discColor = action and KC.iconBg or nil,
            plus = not action, glow = focus, dash = target })
        local label = f.labels[i]
        label:SetText(action and (CK.Mapping:ActionName(action) or action) or pos[i] or "")
        local c = (focus or target) and KC.focus or (action and KC.cream or KC.grey)
        label:SetTextColor(c[1], c[2], c[3])
    end
    -- The button it is on
    local bound = MW:BoundText(w.id, 14)
    local chip = f.bind.chip
    chip.text:SetText(bound or L.LBL_NO_BUTTON)
    local bc = bound and KC.info or KC.eventOff
    chip.text:SetTextColor(bc[1], bc[2], bc[3])
    chip:SetWidth(chip.text:GetStringWidth() + 16)
    f.bind:SetWidth(f.bind.label:GetStringWidth() + 8 + chip:GetWidth())
    -- Rename, Assign a button, Delete (armed: wider, asking again)
    local armed = C:IsArmed("delwheel")
    local labels = { L.V_RENAME, L.LBL_ASSIGN_BUTTON, armed and L.LBL_PRESS_DELETE or L.LBL_DELETE }
    for i, b in ipairs(f.buttons) do
        b.label:SetText(labels[i])
        b:SetState({ focus = self.zone == "buttons" and self.btn == i, armed = i == 3 and armed })
    end
    K.LayoutRow(f.buttonRow, f.buttons, { 1, 1.3, armed and 1.5 or 0.9 }, 8)
    -- The picker: always there, faded while the wheel has the focus
    local picker = self.picker
    picker:Show()
    picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
    picker:Render()
    f.veil:SetShown(self.zone == "rename")
end

---------------------------------------------------------------------------
-- Naming: the box over the wheel, with a field for a physical keyboard, and
-- the addon's keyboard (A confirms, B cancels) when its module is on
---------------------------------------------------------------------------
function MW:StartRename(id)
    local w = self:Get(id)
    if not w or CK:BlockedByCombat() then return end
    -- The chat being typed in: our field would take its focus, closing it
    -- from addon code (never done)
    local chat = CK.ActiveChatWindow and CK.ActiveChatWindow()
    if chat and chat:HasFocus() then
        C:Toast(L.TOAST_CLOSE_CHAT, true)
        return
    end
    self.renaming = id
    E.zone = "rename"
    local edit = E.box.edit
    edit:SetText(w.name)
    E.frame.veil:Show()
    edit:SetFocus()
    edit:HighlightText()
    -- The addon's keyboard takes the pad (the panel lets it go meanwhile)
    if CK.db.settings.modules.keyboard then
        C:UnbindPad()
        CK:OpenPrompt(L.MYWHEEL_NAME_PROMPT, w.name, function(text) MW:FinishRename(text) end, edit)
    end
    C:Render()
end

function MW:FinishRename(text)
    local id = self.renaming
    if not id then return end
    self.renaming = nil
    if E.box then
        E.box.edit:ClearFocus()
        E.frame.veil:Hide()
    end
    if E.zone == "rename" then E.zone = "slots" end
    -- Confirmed with the field (Enter, A on the panel): the keyboard closes
    if CK.prompt then CK:FinishPrompt(false) end
    if text then self:Rename(id, text) end
    if C:IsOpen() then
        C:BindPad()
        C:Render()
    end
end

function MW:Init()
    self:UpdateBindingNames()
    -- The panel closed (B, combat) while a name was being typed: cancelled;
    -- it opens on the list of wheels next time
    hooksecurefunc(C, "Close", function()
        MW:FinishRename(nil)
        if MW.open then
            MW.open = false
            MW.Editor:Hide()
            G:Focus(MW.Editor.id)
        end
    end)
end
