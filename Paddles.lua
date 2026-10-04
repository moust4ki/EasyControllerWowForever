local _, CK = ...
local L = CK.L

-- Extra buttons (back paddles L4 / R4 / L5 / R5, L3 / R3) and helpers for the
-- game's gamepad bar.
--
-- Steam Input sends the paddles as keyboard keys (F13-F16, F9-F12...), some
-- controllers as gamepad buttons (PADPADDLE1-4): each paddle learns its key by
-- being pressed once (configuration, Gamepad tab). What they do is set there
-- like any free input (Mapping.lua).
--
-- The extra buttons that do something are drawn around the game's gamepad
-- action bar, each where the player placed it, in the bar's round slot style:
-- icon, count, cooldown, pressed look. The game's frames are only read; ours
-- are plain, not secure: they show, hide and update in combat.
local P = {}
CK.Paddles = P

-- The back paddles, in the order they are identified
P.ORDER = { "L4", "R4", "L5", "R5" }
-- Every input learning a key (the paddles, the touchpad buttons)
P.ALL = { "L4", "R4", "L5", "R5", "TL1", "TL2", "TL3", "TL4", "TR1", "TR2", "TR3", "TR4" }

-- The ones to identify: the paddles, then the touchpad buttons turned on
function P:Order()
    local M, list = CK.Mapping, {}
    for _, id in ipairs(P.ALL) do
        if M:InputEnabled(M.BY_ID[id]) then list[#list + 1] = id end
    end
    return list
end

-- The game's gamepad bars (no trigger, LT, RT, LT+RT) and their buttons:
-- the D-pad group ("Left") and the face group ("Right"). The face buttons
-- of the top bar are fixed (jump, interact, back, inspect).
P.BARS = {
    { key = "top", glyphs = {} },
    { key = "left", glyphs = { "LT" } },
    { key = "right", glyphs = { "RT" } },
    { key = "bottom", glyphs = { "LT", "RT" } },
}
P.BUTTONS = {
    { key = "left", group = "Left", index = 1, glyph = "DPAD_LEFT" },
    { key = "up", group = "Left", index = 2, glyph = "DPAD_UP" },
    { key = "right", group = "Left", index = 3, glyph = "DPAD_RIGHT" },
    { key = "down", group = "Left", index = 4, glyph = "DPAD_DOWN" },
    { key = "x", group = "Right", index = 1, glyph = "X" },
    { key = "y", group = "Right", index = 2, glyph = "Y" },
    { key = "b", group = "Right", index = 3, glyph = "B" },
    { key = "a", group = "Right", index = 4, glyph = "A" },
}

local function settings() return CK.db.settings end

local function enabled()
    return CK.db and settings().modules.mapping
end

function P:Config(id)
    local paddles = settings().paddles
    paddles[id] = paddles[id] or {}
    return paddles[id]
end

local function findBy(list, key)
    for _, item in ipairs(list) do
        if item.key == key then return item end
    end
end

---------------------------------------------------------------------------
-- The game's gamepad bar: "bar:<bar>:<button>"
---------------------------------------------------------------------------
-- The game's button for "bar:bottom:a" (nil while the gamepad bars are not loaded)
function P:NativeButton(action)
    local barKey, buttonKey = (action or ""):match("^bar:(%a+):(%a+)$")
    local button = findBy(P.BUTTONS, buttonKey)
    if not (barKey and button) then return end
    local main = GamepadMainActionBarFrame
    local bars = main and main.PageUnit and main.PageUnit.actionBars
    local bar = bars and bars[barKey .. "Bar"]
    local group = bar and bar[button.group]
    return group and group["ActionButton" .. button.index]
end

-- Action slot the game's button holds on the current page
function P:NativeSlot(action)
    local native = self:NativeButton(action)
    local slot = native and native.action
    if type(slot) == "number" and slot > 0 then return slot end
end

local function hasAction(slot)
    if C_ActionBar and C_ActionBar.HasAction then return C_ActionBar.HasAction(slot) end
    return HasAction and HasAction(slot)
end

function P.SlotTexture(slot)
    if not (slot and hasAction(slot)) then return nil end
    if C_ActionBar and C_ActionBar.GetActionTexture then return C_ActionBar.GetActionTexture(slot) end
    return GetActionTexture and GetActionTexture(slot)
end

-- Name of what an action slot holds (spell, item, macro, mount...)
function P.SlotName(slot)
    if not (slot and hasAction(slot)) then return nil end
    local kind, id = GetActionInfo(slot)
    if kind == "spell" then
        if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
        return GetSpellInfo and (GetSpellInfo(id))
    elseif kind == "item" then
        if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
        return GetItemInfo and (GetItemInfo(id))
    elseif kind == "macro" then
        return GetActionText and GetActionText(slot) or (GetMacroInfo and (GetMacroInfo(id)))
    elseif kind == "summonmount" and C_MountJournal and C_MountJournal.GetMountInfoByID then
        return (C_MountJournal.GetMountInfoByID(id))
    elseif kind == "flyout" then
        -- The game's pop-out menus (hunter aspects, tracking, pets...)
        local name
        if C_Flyout and C_Flyout.GetFlyoutInfo then
            local ok, info = pcall(C_Flyout.GetFlyoutInfo, id)
            name = ok and type(info) == "table" and info.name
        end
        if not name and GetFlyoutInfo then name = GetFlyoutInfo(id) end
        if name and name ~= "" then return name end
    elseif kind == "summonpet" and C_PetJournal and C_PetJournal.GetPetInfoByPetID then
        local _, customName, _, _, _, _, _, petName = C_PetJournal.GetPetInfoByPetID(id)
        return customName or petName
    end
    local text = GetActionText and GetActionText(slot)
    if text and text ~= "" then return text end
    -- Anything else: the first line of its tooltip
    if C_TooltipInfo and C_TooltipInfo.GetAction then
        local ok, data = pcall(C_TooltipInfo.GetAction, slot)
        local line = ok and type(data) == "table" and data.lines and data.lines[1]
        local left = line and line.leftText
        if type(left) == "string" and not (issecretvalue and issecretvalue(left)) and left ~= "" then return left end
    end
end

function P:CommandName(command)
    local name = GetBindingName and GetBindingName(command)
    if not name or name == command then name = _G["BINDING_NAME_" .. command] end
    return name or command
end

-- "LT RT" glyphs of a layer ("" = no trigger)
function P:LayerLabel(layer, size)
    if layer == "" then return L.MAP_ALONE end
    local parts = {}
    if layer:find("LT", 1, true) then parts[#parts + 1] = CK:GlyphMarkup("LT", size or 18) end
    if layer:find("RT", 1, true) then parts[#parts + 1] = CK:GlyphMarkup("RT", size or 18) end
    return table.concat(parts, " ")
end

-- Glyphs of a bar button: "LT RT + A"
function P:BarLabel(action)
    local barKey, buttonKey = (action or ""):match("^bar:(%a+):(%a+)$")
    local bar, button = findBy(P.BARS, barKey), findBy(P.BUTTONS, buttonKey)
    if not (bar and button) then return "?" end
    local parts = {}
    for _, glyph in ipairs(bar.glyphs) do parts[#parts + 1] = CK:GlyphMarkup(glyph, 18) end
    local label = table.concat(parts, "")
    if label ~= "" then label = label .. " + " end
    return label .. CK:GlyphMarkup(button.glyph, 18)
end

-- Glyphs and what the game's button holds
function P:ActionLabel(action)
    local name = P.SlotName(self:NativeSlot(action))
    return format("%s  |cffffffff%s|r", self:BarLabel(action), name or L.MAP_EMPTY_SLOT)
end

function P:ActionIcon(action)
    return P.SlotTexture(self:NativeSlot(action))
end

---------------------------------------------------------------------------
-- Learning a paddle's key: press it once
---------------------------------------------------------------------------
local IGNORED_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true, UNKNOWN = true,
}

-- Gamepad buttons the game already uses: never taken as a paddle
local function isStandardPadButton(button)
    return button:find("^PAD%d$") or button:find("^PADD") or button:find("^PAD[LR]STICK")
        or button:find("^PAD[LR]SHOULDER") or button:find("^PAD[LR]TRIGGER")
        or button == "PADBACK" or button == "PADFORWARD" or button == "PADSYSTEM"
end

function P:StopCapture(key)
    local f = self.captureFrame
    if not (f and f:IsShown()) then return end
    f:Hide()
    if f.timer then f.timer:Cancel() end
    if not InCombatLockdown() then
        f:EnableKeyboard(false)
        if f.EnableGamePadButton then f:EnableGamePadButton(false) end
    end
    local id, onDone = f.id, f.onDone
    f.id, f.onDone = nil, nil
    if key then
        -- One key per paddle (learned or by default): the paddle on it takes
        -- this one's key in exchange
        local M = CK.Mapping
        local was = M:InputKey(M.BY_ID[id])
        for _, other in ipairs(P.ALL) do
            if other ~= id and M:InputKey(M.BY_ID[other]) == key then self:Config(other).key = was end
        end
        local previous = GetBindingAction and GetBindingAction(key)
        if previous and previous ~= "" then
            CK:Print(L.PADDLE_KEY_REPLACES, GetBindingText and GetBindingText(key) or key, self:CommandName(previous))
        end
        self:Config(id).key = key
        CK.Mapping:Apply()
        self:Apply()
    end
    if onDone then onDone(key) end
end

function P:Capture(id, onDone)
    if CK:BlockedByCombat() then return end
    local f = self.captureFrame
    if not f then
        f = CK.NewFrame("Frame", nil, UIParent)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetSize(1, 1)
        f:SetPoint("CENTER")
        f:SetScript("OnKeyDown", function(_, key)
            if IGNORED_KEYS[key] then return end
            if key == "ESCAPE" then return CK.Config:PressFromCapture("ESCAPE") end
            P:StopCapture(key)
        end)
        if f.EnableGamePadButton then
            f:SetScript("OnGamePadButtonDown", function(_, button)
                if not isStandardPadButton(button) then
                    P:StopCapture(button)
                elseif button == "PAD2" or button == "PAD3" then
                    CK.Config:PressFromCapture(button)
                end
                return false
            end)
        end
        f:Hide()
        self.captureFrame = f
    end
    self:StopCapture(nil)
    f.id, f.onDone = id, onDone
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(false)
    if f.EnableGamePadButton then f:EnableGamePadButton(true) end
    f:Show()
    f.timer = C_Timer.NewTimer(10, function() P:StopCapture(nil) end)
end

function P:IsCapturing(id)
    local f = self.captureFrame
    return f and f:IsShown() and (id == nil or f.id == id) or false
end

---------------------------------------------------------------------------
-- The extra buttons on screen (back paddles, L3 / R3), next to the game's
-- gamepad action bar
---------------------------------------------------------------------------
local SIZE = 38
local PRESSED = 4       -- the game's buttons shrink by 4 px when pressed
local SLOT_TEXTURE = "Interface\\AddOns\\EasyController\\textures\\ck_reforged_slot_"

-- Each one has its own place, relative to the game's left / right bar (both
-- on the bottom bar in the compact layout); the right side mirrors the left
P.EXTRA = { "L4", "L5", "L3", "R4", "R5", "R3", "TL1", "TL2", "TL3", "TL4", "TR1", "TR2", "TR3", "TR4" }
local SIDE = { L4 = -1, L5 = -1, L3 = -1, R4 = 1, R5 = 1, R3 = 1,
    TL1 = -1, TL2 = -1, TL3 = -1, TL4 = -1, TR1 = 1, TR2 = 1, TR3 = 1, TR4 = 1 }
local PARTNER = { L4 = "R4", R4 = "L4", L5 = "R5", R5 = "L5", L3 = "R3", R3 = "L3",
    TL1 = "TR1", TR1 = "TL1", TL2 = "TR2", TR2 = "TL2", TL3 = "TR3", TR3 = "TL3", TL4 = "TR4", TR4 = "TL4" }
P.DEFAULT_POS = {
    L4 = { x = -182, y = 26 }, L5 = { x = -182, y = -26 }, L3 = { x = -65, y = -78 },
    R4 = { x = 182, y = 26 }, R5 = { x = 182, y = -26 }, R3 = { x = 65, y = -78 },
    -- The touchpad buttons: the outer column
    TL1 = { x = -234, y = 52 }, TL2 = { x = -234, y = 26 }, TL3 = { x = -234, y = 0 }, TL4 = { x = -234, y = -26 },
    TR1 = { x = 234, y = 52 }, TR2 = { x = 234, y = 26 }, TR3 = { x = 234, y = 0 }, TR4 = { x = 234, y = -26 },
}

local function atlasOr(tex, atlas, fallback)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
    elseif fallback then
        tex:SetTexture(fallback)
    else
        tex:Hide()
    end
end
P.atlasOr = atlasOr

-- An icon: a texture or file ID (zoomed in a little, like the game's buttons,
-- so square edges never show in the round slot), { atlas = "..." } or
-- { glyph = "A" } (the gamepad button's own picture)
function P.SetIcon(tex, icon)
    if type(icon) == "table" then
        if icon.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(icon.atlas) then
            tex:SetAtlas(icon.atlas)
        elseif icon.glyph then
            CK:SetGlyph(tex, icon.glyph)
        elseif icon.texture then
            tex:SetTexture(icon.texture)
            tex:SetTexCoord(0, 1, 0, 1)
        else
            tex:Hide()
            return
        end
        tex:Show()
    elseif icon then
        tex:SetTexture(icon)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tex:Show()
    else
        tex:Hide()
    end
end

-- A round slot in the style of the game's gamepad bar: icon, cooldown,
-- count, border, pressed look. Shared with the mapping page. The visuals sit
-- in `b.visual`, which shrinks when pressed while `b` keeps its place.
function P:CreateSlot(parent, size)
    local b = CK.NewFrame("Frame", nil, parent)
    b:SetSize(size, size)
    b.size = size
    local v = CK.NewFrame("Frame", nil, b)
    v:SetPoint("CENTER")
    v:SetSize(size, size)
    b.visual = v

    local shadow = v:CreateTexture(nil, "BACKGROUND", nil, -2)
    shadow:SetPoint("TOPLEFT", -4, 4)
    shadow:SetPoint("BOTTOMRIGHT", 4, -4)
    atlasOr(shadow, "gamepad-actionbar-circleslot-dropshadow")
    -- Dark round background: an empty slot, like the game's
    local empty = v:CreateTexture(nil, "BACKGROUND", nil, -1)
    empty:SetPoint("TOPLEFT", 3, -3)
    empty:SetPoint("BOTTOMRIGHT", -3, 3)
    empty:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    empty:SetVertexColor(0, 0, 0, 0.6)

    b.icon = v:CreateTexture(nil, "BACKGROUND")
    b.icon:SetPoint("TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b.mask = v:CreateMaskTexture()
    b.mask:SetAllPoints(b.icon)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("CircleMask") then
        b.mask:SetAtlas("CircleMask")
    else
        b.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    b.icon:AddMaskTexture(b.mask)

    b.cooldown = CK.NewFrame("Cooldown", nil, v, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    b.cooldown:SetSwipeTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    b.cooldown:SetSwipeColor(0, 0, 0, 0.7)
    b.cooldown:SetDrawEdge(false)
    b.cooldown:SetDrawBling(false)
    if b.cooldown.SetUseCircularEdge then b.cooldown:SetUseCircularEdge(true) end

    -- Above the cooldown swipe
    local over = CK.NewFrame("Frame", nil, v)
    over:SetAllPoints()
    over:SetFrameLevel(b.cooldown:GetFrameLevel() + 2)
    b.over = over
    b.border = over:CreateTexture(nil, "ARTWORK")
    b.border:SetAllPoints()
    b.border:SetTexture(SLOT_TEXTURE .. "normal")
    b.pressed = over:CreateTexture(nil, "ARTWORK", nil, 1)
    b.pressed:SetAllPoints()
    b.pressed:SetTexture(SLOT_TEXTURE .. "pressed")
    b.pressed:Hide()
    b.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    return b
end

-- Hover is deliberately a thin rim, not a large glow or a new HUD panel.
function P.SetHover(b, hovered)
    hovered = hovered and true or false
    if b.isHovered == hovered then return end
    b.isHovered = hovered
    b.border:SetTexture(SLOT_TEXTURE .. (hovered and "hover" or "normal"))
end

-- Pressed look, like the game's buttons: a little smaller and lower, with
-- the pressed rim
function P.SetPressed(b, down)
    if b.isPressed == down then return end
    b.isPressed = down
    b.visual:SetSize(down and b.size - PRESSED or b.size, down and b.size - PRESSED or b.size)
    b.visual:ClearAllPoints()
    b.visual:SetPoint("CENTER", 0, down and -PRESSED / 2 or 0)
    b.border:SetShown(not down)
    b.pressed:SetShown(down)
end

-- A text badge ("L4") on a slot, where the game puts its button glyphs
function P:AddBadge(b, text, side)
    local badge = CK.NewFrame("Frame", nil, b.over)
    badge:SetSize(24, 24)
    b.side = side
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    atlasOr(bg, "gamepad-actionbar-slot-bg-empty")
    local fs = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(text)
    -- Above every button, so a neighbour never hides a name
    badge:SetFrameLevel(b.over:GetFrameLevel() + 20)
    b.badge = badge
    P.PlaceBadge(b, "outer")
end

-- The badge on the outer side, horizontally (left for L4, right for R4) or
-- vertically (above for a button above the bar's middle, below for one
-- below it), above, below, left, right, or hidden (option)
P.BADGE_PLACES = { "outer", "outer_v", "top", "bottom", "left", "right", "hidden" }

function P.PlaceBadge(b, where, y)
    local badge = b.badge
    if not badge then return end
    if where == "outer_v" and y and y ~= 0 then where = y > 0 and "top" or "bottom" end
    if where == "outer" or where == "outer_v" then where = (b.side or -1) < 0 and "left" or "right" end
    badge:ClearAllPoints()
    badge:SetShown(where ~= "hidden")
    if where == "top" then
        badge:SetPoint("BOTTOM", b, "TOP", 0, -8)
    elseif where == "bottom" then
        badge:SetPoint("TOP", b, "BOTTOM", 0, 8)
    elseif where == "right" then
        badge:SetPoint("LEFT", b, "RIGHT", -8, 0)
    else
        badge:SetPoint("RIGHT", b, "LEFT", 8, 0)
    end
end

-- Cooldowns can be secret values in combat: hand them over untouched
function P.ApplyCooldown(cd, action)
    local kind, value = (action or ""):match("^(%a+):(.+)$")
    local ok
    if kind == "bar" then
        local slot = P:NativeSlot(action)
        if slot and hasAction(slot) then
            if C_ActionBar.GetActionCooldownDuration and cd.SetCooldownFromDurationObject then
                ok = pcall(function() cd:SetCooldownFromDurationObject(C_ActionBar.GetActionCooldownDuration(slot)) end)
            end
            ok = ok or pcall(function()
                local info = C_ActionBar.GetActionCooldown(slot)
                if info and info.isActive then cd:SetCooldown(info.startTime, info.duration, info.modRate) else cd:Clear() end
            end)
        end
    elseif kind == "spell" and C_Spell then
        local id = tonumber(value)
        if C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
            ok = pcall(function() cd:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id)) end)
        end
        ok = ok or pcall(function()
            local info = C_Spell.GetSpellCooldown(id)
            if info and info.isActive ~= false and info.duration and info.duration > 0 then
                cd:SetCooldown(info.startTime, info.duration, info.modRate)
            else
                cd:Clear()
            end
        end)
    elseif kind == "item" and C_Item and C_Item.GetItemCooldown then
        ok = pcall(function()
            local start, duration, enable = C_Item.GetItemCooldown(tonumber(value))
            if enable and duration and duration > 0 then cd:SetCooldown(start, duration) else cd:Clear() end
        end)
    end
    if not ok then cd:Clear() end
end

---------------------------------------------------------------------------
-- Which layer is held, and which inputs are pressed
---------------------------------------------------------------------------
local MOD_DOWN = { SHIFT = IsShiftKeyDown, CTRL = IsControlKeyDown, ALT = IsAltKeyDown }

local function padState()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return nil end
    local id = C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
    return id and C_GamePad.GetDeviceMappedState(id)
end

local function padButtonDown(state, button)
    if not (state and state.buttons and C_GamePad.ButtonBindingToIndex) then return false end
    local index = C_GamePad.ButtonBindingToIndex(button)
    return index ~= nil and state.buttons[index + 1] and true or false
end

-- "", "LT", "RT" or "LTRT": the triggers held (or toggled, Toggle.lua)
function P.HeldLayer()
    if CK.Toggle and CK.Toggle:On() and CK.Toggle.header then return CK.Toggle:Layer() end
    local state = padState()
    local function held(button)
        local mod = CK.Mapping:TriggerModifier(button)
        if mod and MOD_DOWN[mod] and MOD_DOWN[mod]() then return true end
        return padButtonDown(state, button)
    end
    return (held("PADLTRIGGER") and "LT" or "") .. (held("PADRTRIGGER") and "RT" or "")
end

-- Keyboard keys (paddles sent by Steam Input) seen going down by a frame
-- that lets every key through. Each press shows for a moment at least; the
-- release is never waited for (it does not always reach us), the key is
-- read as held from the game itself.
local PRESS_TIME = 0.15
local keyPressed = {}
local function watchKeys()
    if P.keyWatcher or InCombatLockdown() then return end
    local w = CK.NewFrame("Frame", nil, UIParent)
    w:SetSize(1, 1)
    w:SetPoint("TOPLEFT")
    w:EnableKeyboard(true)
    w:SetPropagateKeyboardInput(true)
    w:SetScript("OnKeyDown", function(_, key) keyPressed[key] = GetTime() + PRESS_TIME end)
    P.keyWatcher = w
end

local function inputDown(key, state, now)
    if not key then return false end
    if (keyPressed[key] or 0) > now then return true end
    if IsKeyDown and IsKeyDown(key) then return true end
    return key:find("^PAD") ~= nil and padButtonDown(state, key)
end

-- Our secure buttons (spells, items, macros) tell when they are clicked
local flashed = {}
function P:NotifyPress(inputId)
    flashed[inputId] = GetTime() + PRESS_TIME
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- The action shown: the one the held layer runs
function P:ShownAction(id, layer)
    return CK.Mapping:EffectiveAction(CK.Mapping.BY_ID[id], layer or "")
end

local function hasAnyAction(id)
    for _, layer in ipairs(CK.Mapping.LAYERS) do
        if CK.Mapping:Get(id, layer) then return true end
    end
end

-- L3 / R3: shown with what the game does with them (autorun, ping...) when
-- nothing of ours is on them
local STICKS = { L3 = true, R3 = true }

function P:NativeStick(id, layer)
    if not STICKS[id] then return nil end
    local M = CK.Mapping
    local input = M.BY_ID[id]
    local name, icon
    if layer ~= "" and M:State(input, layer) == "native" then name, icon = M:NativeInfo(input, layer) end
    if not name and M:State(input, "") == "native" then name, icon = M:NativeInfo(input, "") end
    return name, icon
end

function P:UpdateButton(b, cooldown, layer, state)
    local action = self:ShownAction(b.id, layer or "")
    if action then
        P.SetIcon(b.icon, CK.Mapping:ActionIcon(action))
    else
        local _, icon = self:NativeStick(b.id, layer or "")
        P.SetIcon(b.icon, icon)
    end
    local slot = action and action:find("^bar:") and self:NativeSlot(action)
    if slot and hasAction(slot) then
        local usable, noMana = (C_ActionBar.IsUsableAction or IsUsableAction)(slot)
        if usable then
            b.icon:SetVertexColor(1, 1, 1)
        elseif noMana then
            b.icon:SetVertexColor(0.5, 0.5, 1)
        else
            b.icon:SetVertexColor(0.4, 0.4, 0.4)
        end
        local ok, count = pcall(C_ActionBar.GetActionDisplayCount, slot)
        b.count:SetText(ok and count or "")
    else
        b.icon:SetVertexColor(1, 1, 1)
        local id = action and tonumber(action:match("^item:(%d+)$") or "")
        b.count:SetText(id and C_Item.GetItemCount and C_Item.GetItemCount(id) or "")
    end
    -- Out of range: the whole spell in red (option)
    local Range = CK.Range
    if Range and Range.On() then
        local out
        if slot and hasAction(slot) then
            out = Range.InRange(slot) == false
        else
            local spell = action and tonumber(action:match("^spell:(%d+)$") or "")
            if spell and C_Spell and C_Spell.IsSpellInRange and UnitExists("target") then
                out = C_Spell.IsSpellInRange(spell, "target") == false
            end
        end
        if out then b.icon:SetVertexColor(Range.RED[1], Range.RED[2], Range.RED[3]) end
    end
    if cooldown or action ~= b.action or slot ~= b.slot then
        b.action, b.slot = action, slot
        P.ApplyCooldown(b.cooldown, action)
    end
end

-- Always one of the fixed places (an older free place goes to the nearest)
function P:Position(id)
    local nearestPlace = P.NearestPlace
    local pos = settings().extraPos[id]
    if type(pos) ~= "table" or type(pos.x) ~= "number" or type(pos.y) ~= "number" then pos = P.DEFAULT_POS[id] end
    if settings().extraFree then return pos.x, pos.y end
    return nearestPlace(SIDE[id], pos.x, pos.y)
end

-- In the compact layout the game puts every bar on the bottom one: its side
-- anchors move there, and so do the buttons (anchoring plain frames to the
-- game's frames changes nothing for them)
function P:Layout()
    local f = self.frame
    if not f then return end
    local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    for _, id in ipairs(P.EXTRA) do
        local b = f.buttons[id]
        local x, y = self:Position(id)
        b:ClearAllPoints()
        local anchor = unit and (SIDE[id] < 0 and unit.LeftCenteredAnchor or unit.RightCenteredAnchor)
        if anchor then
            b:SetPoint("CENTER", anchor, "CENTER", x, y)
        else
            b:SetPoint("CENTER", f, "CENTER", x + SIDE[id] * 195, y)
        end
        -- Its name follows its place (outer side, up / down)
        P.PlaceBadge(b, settings().badgePlace or "outer", y)
    end
end

-- Shown with the game's gamepad action bar: the buttons that do something
-- (all of them while placing)
function P:UpdateVisibility()
    local f = self.frame
    if not f then return end
    local bar = GamepadMainActionBarFrame
    for _, id in ipairs(P.EXTRA) do
        local show
        if STICKS[id] then
            show = settings().features.showSticks
        else
            show = hasAnyAction(id)
        end
        local input = CK.Mapping.BY_ID[id]
        f.buttons[id]:SetShown(CK.Mapping:InputEnabled(input) and (self.placing or show) or false)
    end
    local on = enabled() and settings().features.extraDisplay
    f:SetShown((self.placing or (on and bar ~= nil and bar:IsVisible())) and true or false)
end

function P:Refresh(cooldown)
    local f = self.frame
    if not (f and f:IsShown()) then return end
    local layer = P.HeldLayer()
    for _, id in ipairs(P.EXTRA) do
        local b = f.buttons[id]
        if b:IsShown() then self:UpdateButton(b, cooldown, layer) end
    end
end

-- Every frame: the pressed look follows the input
function P:UpdatePressed()
    local f = self.frame
    local state = padState()
    local now = GetTime()
    for _, id in ipairs(P.EXTRA) do
        local b = f.buttons[id]
        if b:IsShown() then
            local key = CK.Mapping:InputKey(CK.Mapping.BY_ID[id])
            P.SetPressed(b, inputDown(key, state, now) or (flashed[id] or 0) > now)
        end
    end
end

function P:AttachToBar()
    local bar = GamepadMainActionBarFrame
    if not bar or self.attached then return end
    self.attached = true
    local f = self.frame
    -- Anchored to the game's bar, never parented to it nor changing it
    f:ClearAllPoints()
    f:SetPoint("CENTER", bar, "CENTER")
    bar:HookScript("OnShow", function() P:UpdateVisibility() end)
    bar:HookScript("OnHide", function() P:UpdateVisibility() end)
end

local function tooltip(b)
    if P.placing then return end
    local layer = P.HeldLayer()
    local action = P:ShownAction(b.id, layer)
    GameTooltip:SetOwner(b, SIDE[b.id] < 0 and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    local slot = action and action:find("^bar:") and P:NativeSlot(action)
    if slot and hasAction(slot) then
        GameTooltip:SetAction(slot)
    else
        local name = CK.Mapping:ActionName(action) or P:NativeStick(b.id, layer)
        GameTooltip:SetText(name or L.MAP_FREE, 1, 1, 1)
    end
    local key = CK.Mapping:InputKey(CK.Mapping.BY_ID[b.id])
    GameTooltip:AddLine(format("%s: %s", b.id, GetBindingText and GetBindingText(key) or key), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function P:BuildFrame()
    if self.frame then return end
    local f = CK.NewFrame("Frame", nil, UIParent)
    f:SetSize(1, 1)
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 211)
    -- Above the game's gamepad bar (LOW): buttons and names placed over its
    -- top and bottom bars stay visible
    f:SetFrameStrata("MEDIUM")
    f.buttons = {}
    for _, id in ipairs(P.EXTRA) do
        local b = self:CreateSlot(f, SIZE)
        b.id = id
        self:AddBadge(b, id, SIDE[id])
        b.ring = b.over:CreateTexture(nil, "OVERLAY")
        b.ring:SetPoint("TOPLEFT", -6, 6)
        b.ring:SetPoint("BOTTOMRIGHT", 6, -6)
        atlasOr(b.ring, "gamepad-actionbar-circleslot-border-selected", "Interface\\Minimap\\MiniMap-TrackingBorder")
        b.ring:SetVertexColor(1, 0.85, 0.3)
        b.ring:Hide()
        b:EnableMouse(true)
        b:SetScript("OnEnter", function(self) P.SetHover(self, true); tooltip(self) end)
        b:SetScript("OnLeave", function(self) P.SetHover(self, false); GameTooltip:Hide() end)
        b:SetScript("OnHide", function(self) P.SetHover(self, false); P.SetPressed(self, false) end)
        b:SetScript("OnMouseDown", function(self)
            if not P.placing then return end
            P:SelectForPlacement(self.id)
            if settings().extraFree then P:StartDrag(self) end
        end)
        b:SetScript("OnMouseUp", function() P.drag = nil end)
        f.buttons[id] = b
    end
    local elapsed, cooldownPending = 0, false
    f:SetScript("OnUpdate", function(_, dt)
        P:UpdatePressed()
        if P.drag then P:Drag() end
        elapsed = elapsed + dt
        local periodic = elapsed >= 0.1
        if not periodic and not cooldownPending then return end
        if periodic then
            elapsed = 0
            -- Same scale and fading as the game's bar
            local bar = GamepadMainActionBarFrame
            if bar then
                f:SetScale(bar:GetEffectiveScale() / UIParent:GetEffectiveScale())
                f:SetAlpha(P.placing and 1 or bar:GetEffectiveAlpha() / math.max(0.01, UIParent:GetEffectiveAlpha()))
            end
        end
        local cooldown = cooldownPending
        cooldownPending = false
        P:Refresh(cooldown)
    end)
    f:SetScript("OnShow", function()
        cooldownPending = false
        P:Refresh(true)
    end)
    f:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    f:RegisterEvent("BAG_UPDATE_COOLDOWN")
    f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    -- Related cooldown events often arrive together; paint once next frame.
    f:SetScript("OnEvent", function() cooldownPending = true end)
    f:Hide()
    self.frame = f
    self:Layout()
    self:AttachToBar()
end

-- Settings changed: layout, what is shown
function P:Apply()
    if not self.frame then return end
    self:Layout()
    self:UpdateVisibility()
    self:Refresh(true)
end

---------------------------------------------------------------------------
-- Placing the extra buttons, on the HUD (from the configuration's Gamepad
-- tab): each one goes on a fixed place around the bar's controls (two
-- columns on the outer side, two rows above and two below). The D-pad goes
-- from place to place, onto a taken place the two buttons swap; LB / RB pick
-- the button, Y mirrors the other side, X puts it back. With the mouse: click
-- a button, then one of the places shown.
---------------------------------------------------------------------------
P.PLACES = {}
for _, x in ipairs({ -182, -234 }) do
    for _, y in ipairs({ 52, 26, 0, -26, -52 }) do P.PLACES[#P.PLACES + 1] = { x = x, y = y } end
end
-- Two rows above and two below, the outer ones a little further away
for _, y in ipairs({ 117, 78, -78, -117 }) do
    for _, x in ipairs({ -143, -104, -65, -26 }) do P.PLACES[#P.PLACES + 1] = { x = x, y = y } end
end

-- The places on a side (the right side mirrors the left one)
local function sidePlace(side, place)
    return side < 0 and place.x or -place.x, place.y
end

local function nearestPlace(side, x, y)
    local best, bx, by
    for _, place in ipairs(P.PLACES) do
        local px, py = sidePlace(side, place)
        local d = (px - x) ^ 2 + (py - y) ^ 2
        if not best or d < best then best, bx, by = d, px, py end
    end
    return bx, by
end
P.NearestPlace = nearestPlace

function P:SetPosition(id, x, y)
    settings().extraPos[id] = { x = x, y = y }
    if settings().extraSymmetric then
        settings().extraPos[PARTNER[id]] = { x = -x, y = y }
    end
end

-- Free placement turned off: each button on the nearest fixed place left
-- (the shown ones first), never two on the same one
function P:SnapAll()
    local saved, taken, list, hidden = settings().extraPos, {}, {}, {}
    for _, id in ipairs(P.EXTRA) do
        local b = self.frame and self.frame.buttons[id]
        if b and b:IsShown() then list[#list + 1] = id else hidden[#hidden + 1] = id end
    end
    for _, id in ipairs(hidden) do list[#list + 1] = id end
    for _, id in ipairs(list) do
        local pos = saved[id]
        if type(pos) ~= "table" or type(pos.x) ~= "number" or type(pos.y) ~= "number" then pos = P.DEFAULT_POS[id] end
        local best, bx, by
        for _, place in ipairs(P.PLACES) do
            local px, py = sidePlace(SIDE[id], place)
            local d = (px - pos.x) ^ 2 + (py - pos.y) ^ 2
            if not taken[px .. "," .. py] and (not best or d < best) then best, bx, by = d, px, py end
        end
        if bx then
            taken[bx .. "," .. by] = true
            saved[id] = { x = bx, y = by }
        end
    end
end

-- Onto a place: the button already there (same side) takes the old place
function P:MoveTo(id, x, y)
    local ox, oy = self:Position(id)
    for _, other in ipairs(P.EXTRA) do
        if other ~= id and SIDE[other] == SIDE[id] then
            local px, py = self:Position(other)
            if px == x and py == y then self:SetPosition(other, ox, oy) end
        end
    end
    self:SetPosition(id, x, y)
end

local DIRS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local FREE_STEP = 4

-- Free placement with the mouse: the button follows the cursor while held
function P:StartDrag(b)
    local x, y = self:Position(b.id)
    local cx, cy = GetCursorPosition()
    self.drag = { id = b.id, x = x, y = y, cx = cx, cy = cy, scale = b:GetEffectiveScale() }
end

function P:Drag()
    local d = self.drag
    if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
        self.drag = nil
        return
    end
    local cx, cy = GetCursorPosition()
    self:SetPosition(d.id, math.floor(d.x + (cx - d.cx) / d.scale + 0.5), math.floor(d.y + (cy - d.cy) / d.scale + 0.5))
    self:Layout()
end

function P:Step(id, dir)
    local x, y = self:Position(id)
    local dx, dy = DIRS[dir][1], DIRS[dir][2]
    -- Free placement: a few pixels at a time (held, the D-pad repeats)
    if settings().extraFree then
        self:SetPosition(id, x + dx * FREE_STEP, y + dy * FREE_STEP)
        return
    end
    local best, bx, by
    for _, place in ipairs(P.PLACES) do
        local px, py = sidePlace(SIDE[id], place)
        local vx, vy = px - x, py - y
        local along = vx * dx + vy * dy
        local across = math.abs(vx * dy - vy * dx)
        if along > 0 and across <= along * 1.8 + 20 then
            local score = along + across * 2
            if not best or score < best then best, bx, by = score, px, py end
        end
    end
    if best then self:MoveTo(id, bx, by) end
end

---------------------------------------------------------------------------
-- The game's gamepad bar moves too, by steps: only its place on the screen
-- changes, out of combat, and only once the player moved it (the extra
-- buttons follow, they hang on its anchors)
---------------------------------------------------------------------------
local BAR_STEP_X, BAR_STEP_Y = 40, 20

function P:BarOffset()
    local off = settings().barOffset
    return off and off.x or 0, off and off.y or 0
end

function P:ApplyBarOffset()
    local bar = GamepadMainActionBarFrame
    local x, y = self:BarOffset()
    if not bar or (x == 0 and y == 0 and not self.barMoved) then return end
    if InCombatLockdown() then
        self.pendingBar = true
        return
    end
    self.pendingBar = false
    -- The game's own place (MainActionBarFrame.xml), read once
    if not self.barPoint then
        local point, relativeTo, relativePoint, px, py = bar:GetPoint(1)
        if point and relativeTo == UIParent and type(px) == "number" then
            self.barPoint = { point, relativePoint, px, py }
        else
            self.barPoint = { "BOTTOM", "BOTTOM", 0, 110 }
        end
    end
    local p = self.barPoint
    bar:ClearAllPoints()
    bar:SetPoint(p[1], UIParent, p[2], p[3] + x * BAR_STEP_X, p[4] + y * BAR_STEP_Y)
    self.barMoved = true
end

function P:MoveBar(dx, dy)
    local x, y = self:BarOffset()
    local w, h = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
    local maxX = math.max(0, math.floor((w / 2 - 340) / BAR_STEP_X))
    local maxY = math.max(0, math.floor((h - 340) / BAR_STEP_Y))
    x = math.max(-maxX, math.min(maxX, x + dx))
    y = math.max(-5, math.min(maxY, y + dy))
    settings().barOffset = { x = x, y = y }
    self:ApplyBarOffset()
end

-- What can be placed: the bar, then each extra button
P.PLACE_ORDER = { "BAR", "L4", "L5", "L3", "R4", "R5", "R3", "TL1", "TL2", "TL3", "TL4", "TR1", "TR2", "TR3", "TR4" }

-- Placing works in two steps: the D-pad chooses an element (the bar or a
-- button, by where it is on the screen), A picks it up; then the D-pad moves
-- it, A puts it down, B puts it back where it was
local GOLD_RING, GRAB_RING = { 1, 0.85, 0.3 }, { 0.45, 1, 0.45 }

function P:SelectForPlacement(id)
    self.placeSelected = id
    self.grabbed = nil
    self:RenderPlacementRings()
    self:RenderPlacement()
end

function P:RenderPlacementRings()
    local id = self.placeSelected
    local color = self.grabbed and GRAB_RING or GOLD_RING
    for _, other in ipairs(P.EXTRA) do
        local ring = self.frame.buttons[other].ring
        ring:SetShown(other == id)
        ring:SetVertexColor(color[1], color[2], color[3])
    end
    if self.barRing then
        self.barRing:SetShown(id == "BAR")
        self.barRing.slice:SetVertexColor(color[1], color[2], color[3])
    end
    -- The places only matter for a button being moved
    for _, m in ipairs(self.markers or {}) do m:SetShown(id ~= "BAR" and not settings().extraFree) end
end

-- Center of an element on the screen
local function screenCenter(id)
    local f = id == "BAR" and GamepadMainActionBarFrame or P.frame.buttons[id]
    if not f then return nil end
    local x, y = f:GetCenter()
    if not x then return nil end
    local scale = f:GetEffectiveScale()
    return x * scale, y * scale
end

-- The nearest element in a D-pad direction
function P:SelectToward(dir)
    local fx, fy = screenCenter(self.placeSelected)
    if not fx then return end
    local dx, dy = DIRS[dir][1], DIRS[dir][2]
    local best, bestScore
    local order = GamepadMainActionBarFrame and P.PLACE_ORDER or P.EXTRA
    for _, id in ipairs(order) do
        local x, y = screenCenter(id)
        local shown = id == "BAR" or (self.frame.buttons[id] and self.frame.buttons[id]:IsShown())
        if id ~= self.placeSelected and x and shown then
            local vx, vy = x - fx, y - fy
            local along = vx * dx + vy * dy
            local across = math.abs(vx * dy - vy * dx)
            if along > 0 and across <= along * 2 + 40 then
                local score = along + across * 2
                if not bestScore or score < bestScore then best, bestScore = id, score end
            end
        end
    end
    if best then self:SelectForPlacement(best) end
end

function P:Grab()
    local id = self.placeSelected
    if id == "BAR" then
        local x, y = self:BarOffset()
        self.grabbed = { bar = true, x = x, y = y }
    else
        local all = {}
        for _, other in ipairs(P.EXTRA) do
            local ox, oy = self:Position(other)
            all[other] = { x = ox, y = oy }
        end
        self.grabbed = { all = all, symmetric = settings().extraSymmetric }
    end
    self:RenderPlacementRings()
    self:RenderPlacement()
end

-- B while moving: everything back where it was
function P:CancelGrab()
    local g, id = self.grabbed, self.placeSelected
    if not g then return end
    if g.bar then
        settings().barOffset = { x = g.x, y = g.y }
        self:ApplyBarOffset()
    else
        for other, pos in pairs(g.all) do settings().extraPos[other] = { x = pos.x, y = pos.y } end
        settings().extraSymmetric = g.symmetric
    end
    self.grabbed = nil
    self:Layout()
    self:RenderPlacementRings()
    self:RenderPlacement()
end

-- The places, shown while placing (dotted rings, clickable)
function P:BuildMarkers()
    if self.markers then return end
    self.markers = {}
    for _, side in ipairs({ -1, 1 }) do
        for _, place in ipairs(P.PLACES) do
            local m = CK.NewFrame("Button", nil, self.frame)
            m:SetSize(30, 30)
            m:SetFrameLevel(math.max(1, self.frame:GetFrameLevel() - 1))
            local ring = m:CreateTexture(nil, "BACKGROUND")
            ring:SetAllPoints()
            atlasOr(ring, "gamepad-actionbar-circleslot-border-normal", "Interface\Minimap\MiniMap-TrackingBorder")
            ring:SetAlpha(0.35)
            m.side = side
            m.x, m.y = sidePlace(side, place)
            m:SetScript("OnClick", function(self)
                local id = P.placeSelected
                if id and SIDE[id] == self.side then
                    P:MoveTo(id, self.x, self.y)
                    P:Layout()
                end
            end)
            m:Hide()
            self.markers[#self.markers + 1] = m
        end
    end
end

function P:LayoutMarkers()
    if not self.markers then return end
    local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    for _, m in ipairs(self.markers) do
        m:ClearAllPoints()
        local anchor = unit and (m.side < 0 and unit.LeftCenteredAnchor or unit.RightCenteredAnchor)
        if anchor then
            m:SetPoint("CENTER", anchor, "CENTER", m.x, m.y)
        else
            m:SetPoint("CENTER", self.frame, "CENTER", m.x + m.side * 195, m.y)
        end
    end
end

function P:StartPlacement()
    self:BuildFrame()
    self.placing = true
    if not self.banner then
        local banner = CK.NewFrame("Frame", nil, UIParent)
        banner:SetSize(620, 58)
        banner:SetPoint("TOP", 0, -90)
        banner:SetFrameStrata("DIALOG")
        CK.Config.panel(banner)
        banner.title = CK.UIKit.text(banner, 14)
        banner.title:SetPoint("TOP", 0, -10)
        banner.title:SetTextColor(unpack(CK.UIKit.C.gold))
        banner.title:SetText(L.PLACE_TITLE)
        banner.help = CK.UIKit.text(banner, 11)
        banner.help:SetPoint("BOTTOM", 0, 10)
        banner.help:SetTextColor(unpack(CK.UIKit.C.btn))
        self.banner = banner
    end
    self:BuildMarkers()
    self:LayoutMarkers()
    -- A gold frame around the game's bar while it is the one placed
    local bar = GamepadMainActionBarFrame
    if bar and not self.barRing then
        local ring = CK.NewFrame("Frame", nil, UIParent)
        ring:SetPoint("TOPLEFT", bar, "TOPLEFT", -6, 6)
        ring:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
        ring:SetFrameStrata("HIGH")
        ring.slice = CK.UIKit.nineSlice(ring, "ck_select", 128, 32, 10, 10, "OVERLAY")
        ring:Hide()
        self.barRing = ring
    end
    self.banner:Show()
    self:UpdateVisibility()
    self:Layout()
    self:SelectForPlacement(self.placeSelected or (bar and "BAR" or "L4"))
end

function P:StopPlacement()
    if not self.placing then return end
    self.placing = false
    if self.banner then self.banner:Hide() end
    if self.barRing then self.barRing:Hide() end
    for _, m in ipairs(self.markers or {}) do m:Hide() end
    for _, id in ipairs(P.EXTRA) do self.frame.buttons[id].ring:Hide() end
    self:Apply()
end

function P:RenderPlacement()
    local g = function(key) return CK:GlyphMarkup(key, 16) end
    local id = self.placeSelected
    local name = id == "BAR" and L.PLACE_BAR or id
    if self.grabbed then name = name .. " - " .. L.PLACE_MOVING end
    self.banner.title:SetText(L.PLACE_TITLE .. "  |cffffffff" .. name .. "|r")
    local parts
    if self.grabbed then
        parts = { g("DPAD_UP") .. " " .. (id == "BAR" and L.MAP_P_MOVE or L.PLACE_P_PLACE) }
        if id ~= "BAR" then
            local sym = settings().extraSymmetric and L.ON or L.OFF
            parts[#parts + 1] = g("Y") .. " " .. format(L.PLACE_P_SYM, sym)
        end
        parts[#parts + 1] = g("X") .. " " .. L.PLACE_P_RESET
        parts[#parts + 1] = g("A") .. " " .. L.PLACE_P_DROP
        parts[#parts + 1] = g("B") .. " " .. L.PLACE_P_CANCEL
    else
        parts = {
            g("DPAD_UP") .. " " .. L.PLACE_P_SELECT, g("A") .. " " .. L.PLACE_P_GRAB,
            g("LB") .. g("RB") .. " " .. L.PLACE_P_BUTTON, g("B") .. " " .. L.PLACE_P_DONE,
        }
    end
    self.banner.help:SetText(table.concat(parts, "    "))
end

function P:PlacementPress(name)
    local id = self.placeSelected
    if not self.grabbed then
        if DIRS[name] then
            self:SelectToward(name)
        elseif name == "A" then
            self:Grab()
        elseif name == "LB" or name == "RB" then
            local order = GamepadMainActionBarFrame and P.PLACE_ORDER or P.EXTRA
            -- The ones shown only (a touchpad button turned off is not)
            local shown = {}
            for _, other in ipairs(order) do
                if other == "BAR" or (self.frame.buttons[other] and self.frame.buttons[other]:IsShown()) then
                    shown[#shown + 1] = other
                end
            end
            local index = 1
            for i, other in ipairs(shown) do
                if other == id then index = i end
            end
            self:SelectForPlacement(shown[(index - 1 + (name == "LB" and -1 or 1)) % #shown + 1])
        elseif name == "B" then
            self:StopPlacement()
            CK.Config:EndPlacement()
        end
        return
    end
    -- Moving the element picked up
    if name == "A" then
        self.grabbed = nil
        self:RenderPlacementRings()
    elseif name == "B" then
        self:CancelGrab()
        return
    elseif id == "BAR" then
        if DIRS[name] then
            self:MoveBar(DIRS[name][1], DIRS[name][2])
        elseif name == "X" then
            settings().barOffset = { x = 0, y = 0 }
            self:ApplyBarOffset()
        end
    elseif DIRS[name] then
        self:Step(id, name)
    elseif name == "Y" then
        settings().extraSymmetric = not settings().extraSymmetric
        if settings().extraSymmetric then
            for _, other in ipairs(P.EXTRA) do
                if SIDE[other] == SIDE[id] then self:SetPosition(other, self:Position(other)) end
            end
        end
    elseif name == "X" then
        local pos = P.DEFAULT_POS[id]
        self:MoveTo(id, pos.x, pos.y)
    end
    self:Layout()
    self:RenderPlacement()
end

function P:Init()
    self:BuildFrame()
    watchKeys()
    self:Apply()
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_REGEN_ENABLED" then
            watchKeys()
            if P.pendingBar then P:ApplyBarOffset() end
        elseif event == "PLAYER_ENTERING_WORLD" then
            P:ApplyBarOffset()
        elseif name == "Blizzard_GamepadActionBars" then
            P:ApplyBarOffset()
            -- The game's gamepad bars may load later (gamepad interface turned on)
            P:AttachToBar()
            P:Apply()
            CK.Mapping:Apply()
        end
    end)
end

---------------------------------------------------------------------------
-- /ec keys: every key and gamepad button the game receives, for 15 seconds,
-- and which pad buttons act as Shift / Ctrl / Alt
---------------------------------------------------------------------------
local DETECT_TIME = 15

-- "[Shift Alt | LT RT]": the modifiers held and the triggers the gamepad's
-- state shows held (for /ec keys: what a paddle's layer is read from)
function CK:HeldText()
    local mods = {}
    if IsShiftKeyDown() then mods[#mods + 1] = "Shift" end
    if IsControlKeyDown() then mods[#mods + 1] = "Ctrl" end
    if IsAltKeyDown() then mods[#mods + 1] = "Alt" end
    local state = padState()
    local pads = {}
    if padButtonDown(state, "PADLTRIGGER") then pads[#pads + 1] = "LT" end
    if padButtonDown(state, "PADRTRIGGER") then pads[#pads + 1] = "RT" end
    return format("[%s | %s%s]", #mods > 0 and table.concat(mods, " ") or "-",
        #pads > 0 and table.concat(pads, " ") or "-", state and "" or " (no gamepad state)")
end

function CK:DetectKeys()
    if InCombatLockdown() then
        self:BlockedByCombat()
        return
    end
    local f = self.detectFrame
    if not f then
        f = CK.NewFrame("Frame", nil, UIParent)
        f:EnableKeyboard(true)
        f:SetScript("OnKeyDown", function(frame, key)
            -- Let the key do its usual job as well
            if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
            -- With what the game sees held: a paddle's layers depend on it
            local line = key .. "  " .. CK:HeldText()
            if not frame.seen[line] then
                frame.seen[line] = true
                CK:Print(L.DETECT_KEY, line)
            end
        end)
        if f.EnableGamePadButton then
            f:SetScript("OnGamePadButtonDown", function(frame, button)
                if not frame.seen[button] then
                    frame.seen[button] = true
                    CK:Print(L.DETECT_PAD, button)
                end
                return true
            end)
        end
        self.detectFrame = f
    end
    f.seen = {}
    if not InCombatLockdown() then f:SetPropagateKeyboardInput(true) end
    if f.EnableGamePadButton then f:EnableGamePadButton(true) end
    f:Show()
    self:Print(L.DETECT_START, DETECT_TIME)
    self:Print("Shift = %s, Ctrl = %s, Alt = %s", tostring(GetCVar("GamePadEmulateShift")),
        tostring(GetCVar("GamePadEmulateCtrl")), tostring(GetCVar("GamePadEmulateAlt")))
    local token = {}
    f.token = token
    C_Timer.After(DETECT_TIME, function()
        if f.token ~= token then return end
        f:Hide()
        if f.EnableGamePadButton and not InCombatLockdown() then f:EnableGamePadButton(false) end
        CK:Print(L.DETECT_END)
    end)
end
