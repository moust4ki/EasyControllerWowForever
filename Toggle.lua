local _, CK = ...

-- Trigger toggle (Home > Gamepad, off by default). A trigger pressed alone,
-- with no other button while it is held, switches its bar on; pressed again,
-- back to the top bar. LT then RT: the bottom bar. A trigger held with a
-- button works as before, its bar back once it is released.
--
-- The game shows and uses a trigger's bar while the trigger's key is held
-- only (the GAMEPADLEFTMOD / GAMEPADRIGHTMOD bindings), which an addon can't
-- keep down. With the option on, the triggers are bound to our secure
-- buttons, which keep the state on a secure header. While a bar is on (held
-- or toggled), the header binds the keys of the bar and the other buttons
-- (every modifier the triggers add) to what that layer runs: the game's bar
-- button, or what the player put there. A click goes through a relay that
-- "/click"s it on the press (as the game's binding does) and tells a
-- trigger held that it was used: released then, it was held, not toggled.
-- Meant for the game's compact action bar (one bar shown): the game keeps
-- showing its top bar, so the bar on's icons are drawn over it, each on the
-- icon of the game's button. With the option off, nothing of this is made
-- or bound.
local T = {}
CK.Toggle = T

local function settings() return CK.db.settings end

local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local TRIGGERS = { LT = "PADLTRIGGER", RT = "PADRTRIGGER" }
local LAYERS = { "LT", "RT", "LTRT" }

-- On, in the Gamepad extras module
function T:On()
    local s = CK.db and settings()
    return s and s.features.triggerToggle == true and s.modules.mapping and true or false
end

---------------------------------------------------------------------------
-- The secure side
---------------------------------------------------------------------------
-- A trigger's button: down, its bar held; up, a press alone switches its
-- bar on or off (a trigger pressed while the other is held uses that one)
local TRIGGER = [[
    local t = self:GetAttribute("ck-trigger")
    local other = t == "LT" and "RT" or "LT"
    if down then
        owner:SetAttribute("ck-held-" .. t, true)
        owner:SetAttribute("ck-used-" .. t, nil)
        if owner:GetAttribute("ck-held-" .. other) then owner:SetAttribute("ck-used-" .. other, true) end
    else
        owner:SetAttribute("ck-held-" .. t, nil)
        if not owner:GetAttribute("ck-used-" .. t) then
            owner:SetAttribute("ck-on-" .. t, not owner:GetAttribute("ck-on-" .. t) or nil)
        end
    end
    owner:RunAttribute("ck-apply")
    return false
]]

-- A key pressed while a bar is on: the triggers held were used
local RELAY = [[
    if owner:GetAttribute("ck-held-LT") then owner:SetAttribute("ck-used-LT", true) end
    if owner:GetAttribute("ck-held-RT") then owner:SetAttribute("ck-used-RT", true) end
]]

-- The layer on (held or toggled) into the keys' bindings
local APPLY = [[
    local lt = self:GetAttribute("ck-on-LT") or self:GetAttribute("ck-held-LT")
    local rt = self:GetAttribute("ck-on-RT") or self:GetAttribute("ck-held-RT")
    local layer = (lt and "LT" or "") .. (rt and "RT" or "")
    self:SetAttribute("ck-layer", layer)
    if layer == self:GetAttribute("ck-bound") then return end
    self:SetAttribute("ck-bound", layer)
    local n = self:GetAttribute("ck-n") or 0
    for i = 1, n do self:ClearBinding(self:GetAttribute("ck-key-" .. i)) end
    if layer == "" then return end
    for i = 1, n do
        local key, slot = self:GetAttribute("ck-key-" .. i), self:GetAttribute("ck-slot-" .. i)
        local kind = self:GetAttribute("ck-" .. layer .. "-" .. slot .. "-t")
        local value = self:GetAttribute("ck-" .. layer .. "-" .. slot)
        if kind == "click" then
            self:SetBindingClick(true, key, value)
        elseif kind == "cmd" then
            self:SetBinding(true, key, value)
        end
    end
]]

function T:Build()
    if self.header or InCombatLockdown() then return end
    local h = CK.NewFrame("Frame", "ControllerKeyboardToggle", UIParent, "SecureHandlerBaseTemplate")
    h:SetAttribute("ck-apply", APPLY)
    self.header = h
    self.triggers = {}
    for t in pairs(TRIGGERS) do
        local b = CK.NewFrame("Button", "ControllerKeyboardToggle" .. t, nil, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetAttribute("ck-trigger", t)
        SecureHandlerWrapScript(b, "OnClick", h, TRIGGER)
        b:Hide()
        self.triggers[t] = b
    end
    self.relays = {}
end

-- A relay: "/click" the target on the press, the triggers held told
function T:Relay(id, target, button)
    local r = self.relays[id]
    if not r then
        r = CK.NewFrame("Button", "ControllerKeyboardToggleRelay" .. id, nil, "SecureActionButtonTemplate")
        r:RegisterForClicks("AnyDown")
        r:SetAttribute("useOnKeyDown", true)
        r:SetAttribute("type", "macro")
        SecureHandlerWrapScript(r, "OnClick", self.header, RELAY)
        r:Hide()
        self.relays[id] = r
    end
    r:SetAttribute("macrotext", "/click " .. target .. " " .. (button or "LeftButton") .. " true")
    return r
end

-- What a layer runs on an input: what we bound on that key, else for a bar
-- button the game's button of that bar; nothing (the key alone) otherwise
function T:SetTarget(slot, input, layer)
    local M, h = CK.Mapping, self.header
    local combo = M:Combo(input, layer)
    local kind, name, button
    if combo then kind, name, button = M:BindingOf(combo) end
    -- Off the bar, only what the player put there: a game function we only
    -- kept on a layer of a replaced button (LB's targeting, held) stays on
    -- its own key, as the game binds it
    if kind and not input.bar and M.taken[combo] and not M:GetReplaced(input.id, layer) then kind = nil end
    if not kind and input.bar then
        local native = M:NativeBarButton(input, layer)
        name = native and native:GetName()
        if name then kind, button = "click", "LeftButton" end
    end
    local value
    if kind == "click" then
        value = self:Relay(layer .. input.id, name, button):GetName()
    elseif kind == "cmd" then
        value = name
    end
    h:SetAttribute("ck-" .. layer .. "-" .. slot .. "-t", value and kind or nil)
    h:SetAttribute("ck-" .. layer .. "-" .. slot, value)
end

-- Out of combat, after the mapping's bindings (it calls this): off, or a
-- window has the focus: nothing bound; on: the triggers and what each layer
-- runs, then the layer on bound again
function T:Apply()
    if InCombatLockdown() then
        self.pending = true
        return
    end
    self.pending = false
    local M = CK.Mapping
    if not self.header then
        if not self:On() then return end
        self:Build()
    end
    local h = self.header
    ClearOverrideBindings(h)
    h:SetAttribute("ck-bound", nil)
    h:SetAttribute("ck-held-LT", nil)
    h:SetAttribute("ck-held-RT", nil)
    self.keys = {}
    if not self:On() then
        h:SetAttribute("ck-on-LT", nil)
        h:SetAttribute("ck-on-RT", nil)
    end
    -- What shows: only while the option is on
    if self:On() and not self.view then self:BuildView() end
    if self.view then self.view:SetShown(self:On()) end
    if not (self:On() and M:CoreActive()) then
        h:SetAttribute("ck-layer", "")
        h:SetAttribute("ck-n", 0)
        self:Refs(false)
        return
    end
    local n, slot = 0, 0
    for _, input in ipairs(M.INPUTS) do
        if input.key and not (input.layer or input.paddle) then
            slot = slot + 1
            for _, layer in ipairs(LAYERS) do self:SetTarget(slot, input, layer) end
            for _, prefix in ipairs(PREFIXES) do
                n = n + 1
                h:SetAttribute("ck-key-" .. n, prefix .. input.key)
                h:SetAttribute("ck-slot-" .. n, slot)
                self.keys[prefix .. input.key] = true
            end
        end
    end
    h:SetAttribute("ck-n", n)
    for t, key in pairs(TRIGGERS) do
        for _, prefix in ipairs(PREFIXES) do
            SetOverrideBindingClick(h, true, prefix .. key, self.triggers[t]:GetName(), "LeftButton")
        end
    end
    self:Refs(true)
    SecureHandlerExecute(h, [[self:RunAttribute("ck-apply")]])
end

-- The paddles' routers read the layer from the header while it is on
function T:Refs(on)
    for _, r in pairs(CK.Mapping.routers or {}) do
        if on then
            SecureHandlerSetFrameRef(r, "toggle", self.header)
        else
            r:SetAttribute("frameref-toggle", nil)
        end
    end
end

-- The panel's shortcut held (Mapping:Suspend): its second key left to the
-- game until the next apply
function T:Unbind(key)
    if not (self.header and self.keys) or InCombatLockdown() then return end
    for _, prefix in ipairs(PREFIXES) do
        if self.keys[prefix .. key] then SetOverrideBinding(self.header, true, prefix .. key, nil) end
    end
end

-- A key the header binds while a bar is on (the mapping's repair leaves it)
function T:Holds(combo)
    return self.header and self.keys and self.keys[combo] and self:Layer() ~= "" or false
end

-- "", "LT", "RT", "LTRT": the bar on, held or toggled
function T:Layer()
    if not (self.header and self:On()) then return "" end
    return self.header:GetAttribute("ck-layer") or ""
end

-- Leaving combat: back to the top bar (option)
function T:Release()
    if not (self.header and self:On()) or InCombatLockdown() then return end
    self.header:SetAttribute("ck-on-LT", nil)
    self.header:SetAttribute("ck-on-RT", nil)
    SecureHandlerExecute(self.header, [[self:RunAttribute("ck-apply")]])
end

---------------------------------------------------------------------------
-- What shows, in the compact layout: the bar on's icons over the top bar
-- the game keeps showing
---------------------------------------------------------------------------
local BAR_KEYS = { "a", "b", "x", "y", "up", "down", "left", "right" }
-- The usual crop of an action icon, if the game's can't be read
local ICON_CROP = 0.08
local SQUARE = { up = true, down = true, left = true, right = true }

-- The inputs by their key on the bar ("a", "up"...)
local inputsByBar
local function byBar()
    if not inputsByBar then
        inputsByBar = {}
        for _, input in ipairs(CK.Mapping.INPUTS) do
            if input.bar then inputsByBar[input.bar] = input end
        end
    end
    return inputsByBar
end

local function barFrame(bar)
    local main = GamepadMainActionBarFrame
    local bars = main and main.PageUnit and main.PageUnit.actionBars
    return bars and bars[bar .. "Bar"]
end

function T:BuildView()
    local v = CK.NewFrame("Frame", nil, UIParent)
    v:SetFrameStrata("HIGH")
    v:Hide()
    -- The bar's 8 icons over the top bar's buttons
    v.slots = {}
    for _, key in ipairs(BAR_KEYS) do
        local s = CK.NewFrame("Frame", nil, v)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetAllPoints()
        if not SQUARE[key] then
            local mask = s:CreateMaskTexture()
            mask:SetAllPoints(s.icon)
            -- The game's own circle (its buttons use this mask)
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("CircleMask") then
                mask:SetAtlas("CircleMask")
            else
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            end
            s.icon:AddMaskTexture(mask)
        end
        -- The game's frame of the button (its ring), drawn again over ours
        s.frame = s:CreateTexture(nil, "OVERLAY")
        s.cooldown = CK.NewFrame("Cooldown", nil, s, "CooldownFrameTemplate")
        s.cooldown:SetAllPoints()
        s.cooldown:SetDrawEdge(false)
        s.count = s:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        s.count:SetPoint("BOTTOMRIGHT", -2, 2)
        s.key = key
        v.slots[key] = s
    end
    local elapsed = 0
    v:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.05 then return end
        elapsed = 0
        T:Draw()
    end)
    self.view = v
end

function T:Draw()
    local v = self.view
    local layer = self:Layer()
    local bar = layer ~= "" and CK.Mapping.LAYER_BAR[layer]
    local frame = bar and barFrame(bar)
    local compact = GetCVarBool and GetCVarBool("GamepadUseCompactActionBar")
    if not (frame and compact) then
        for _, s in pairs(v.slots) do s:Hide() end
        return
    end
    local P = CK.Paddles
    for key, s in pairs(v.slots) do
        local over = P:NativeButton("bar:top:" .. key)
        local input = byBar()[key]
        local action = input and CK.Mapping:GetReplaced(input.id, layer) or ("bar:" .. bar .. ":" .. key)
        if over and over:IsVisible() then
            -- Where the game shows its icon: inside its mask (3 px in from
            -- the button), else on its icon (the button also holds its glyph)
            local area = (over.CircleMask and over.CircleMask:IsShown() and over.CircleMask)
                or (over.SquareMask and over.SquareMask:IsShown() and over.SquareMask) or over.icon or over
            s:ClearAllPoints()
            s:SetAllPoints(area)
            -- Its ring, over our icon as over the game's
            local normal = over.GetNormalTexture and over:GetNormalTexture()
            local atlas = normal and normal.GetAtlas and normal:GetAtlas()
            if atlas then
                s.frame:SetAtlas(atlas)
                s.frame:ClearAllPoints()
                s.frame:SetAllPoints(normal)
            end
            s.frame:SetShown(atlas ~= nil)
            local icon = CK.Mapping:ActionIcon(action)
            s.icon:SetTexture(icon)
            -- The game's crop of its icons (their dark edges cut off)
            local ul, ur, ll, lr, a1, a2, a3, a4
            if over.icon and over.icon.GetTexCoord then ul, ur, ll, lr, a1, a2, a3, a4 = over.icon:GetTexCoord() end
            if type(ul) == "number" and type(a4) == "number" then
                s.icon:SetTexCoord(ul, ur, ll, lr, a1, a2, a3, a4)
            else
                s.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
            end
            s.icon:SetShown(icon ~= nil)
            local slot = action:find("^bar:") and P:NativeSlot(action)
            local count = slot and C_ActionBar and C_ActionBar.GetActionDisplayCount and select(2, pcall(C_ActionBar.GetActionDisplayCount, slot))
            s.count:SetText(type(count) == "string" and count or "")
            P.ApplyCooldown(s.cooldown, action)
            s:Show()
        else
            s:Hide()
        end
    end
end

---------------------------------------------------------------------------
function T:Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function()
        if T.pending then T:Apply() end
        if settings().features.toggleCombatRelease then T:Release() end
    end)
    -- A game window, our panel or the chat keyboard takes the keys: the
    -- triggers and the bar keys back to them, and ours again after
    local function refresh()
        if T.header and not InCombatLockdown() then T:Apply() end
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("Gamepad.RefreshFrameFocus", function() C_Timer.After(0, refresh) end, T)
    end
    hooksecurefunc(CK.Config, "Open", refresh)
    hooksecurefunc(CK.Config, "Close", refresh)
    hooksecurefunc(CK, "Open", refresh)
    hooksecurefunc(CK, "Close", refresh)
end
