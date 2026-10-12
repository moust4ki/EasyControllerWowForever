local _, CK = ...

-- Trigger toggle (Home > Gamepad, off by default). A trigger pressed alone,
-- with no other button while it is held, switches its bar on; pressed again,
-- back to the top bar. LT then RT, or both together: the bottom bar. A trigger held with a
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
-- bar on or off. Both pressed together (one down while the other is, no
-- other button): once both are let go, the bottom bar on, or the top bar
-- back if it was on (reported: the bar of one of them came on instead)
local TRIGGER = [[
    local t = self:GetAttribute("ck-trigger")
    local other = t == "LT" and "RT" or "LT"
    if down then
        owner:SetAttribute("ck-held-" .. t, true)
        owner:SetAttribute("ck-used-" .. t, nil)
        if owner:GetAttribute("ck-held-" .. other) then owner:SetAttribute("ck-both", true) end
    else
        owner:SetAttribute("ck-held-" .. t, nil)
        if owner:GetAttribute("ck-both") then
            if not owner:GetAttribute("ck-held-" .. other) then
                owner:SetAttribute("ck-both", nil)
                if not owner:GetAttribute("ck-used-" .. t) and not owner:GetAttribute("ck-used-" .. other) then
                    local bottom = owner:GetAttribute("ck-on-LT") and owner:GetAttribute("ck-on-RT")
                    owner:SetAttribute("ck-on-LT", not bottom or nil)
                    owner:SetAttribute("ck-on-RT", not bottom or nil)
                end
            end
        elseif not owner:GetAttribute("ck-used-" .. t) then
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

-- The layer on (held or toggled; both triggers pressed together: the
-- bottom bar until both are let go) into the keys' bindings
local APPLY = [[
    local both = self:GetAttribute("ck-both")
    local lt = self:GetAttribute("ck-on-LT") or self:GetAttribute("ck-held-LT") or both
    local rt = self:GetAttribute("ck-on-RT") or self:GetAttribute("ck-held-RT") or both
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

-- A relay: "/click" the target on the press, the triggers held told. The
-- game's bar button: a click on the mapping's relay to it instead (no macro:
-- a macro in the game's slot doesn't run from a macro, see RELAY_SLOT).
function T:Relay(id, target, button, macro, delegate)
    local r = self.relays[id]
    if not r then
        r = CK.NewFrame("Button", "ControllerKeyboardToggleRelay" .. id, nil, "SecureActionButtonTemplate")
        r:RegisterForClicks("AnyDown")
        r:SetAttribute("useOnKeyDown", true)
        r:SetScript("PreClick", function(btn, _, down)
            if down ~= false and btn.ckInput then T:Pressed(btn.ckInput) end
        end)
        SecureHandlerWrapScript(r, "OnClick", self.header, RELAY)
        r:Hide()
        self.relays[id] = r
    end
    if delegate then
        r:SetAttribute("type", "click")
        r:SetAttribute("clickbutton", delegate)
        r:SetAttribute("macrotext", nil)
    else
        r:SetAttribute("type", "macro")
        r:SetAttribute("clickbutton", nil)
        r:SetAttribute("macrotext", macro or ("/click " .. target .. " " .. (button or "LeftButton") .. " true"))
    end
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
    -- The game's bar button (the stance bar's in a stance), or one of the
    -- mapping's relays to it: a click on the mapping's relay to that button
    local bar = kind == "click" and M.relayBars[name]
    if not kind and input.bar then
        local native = M:NativeBarButton(input, layer)
        name = native and native:GetName()
        if name then kind, button, bar = "click", "LeftButton", M:BarAction(input, layer) end
    end
    local value
    if kind == "click" and M:IsRouter(name) then
        -- A routed button: its router itself, which reads the layer on (a
        -- "/click" to it would be a macro, and a macro in the game's slot
        -- doesn't run from a macro)
        value = name
    elseif kind == "click" then
        local r = self:Relay(layer .. input.id, name, button, nil, bar and M.BarRelay(bar) or nil)
        r.ckInput = input.id
        value = r:GetName()
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
    h:SetAttribute("ck-both", nil)
    self.keys = {}
    if not self:On() then
        h:SetAttribute("ck-on-LT", nil)
        h:SetAttribute("ck-on-RT", nil)
    end
    -- What shows: only while the option is on
    if self:On() and not self.view then self:BuildView() end
    if self.view then self.view:SetShown(self:On()) end
    -- (off: the game's buttons of its bars visible again, whatever hid ours)
    if self.view and not self:On() then self:ShowGame() end
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
-- What shows. In the compact layout: the bar on's icons over the top bar
-- the game keeps showing. Without it (every bar shown, asked: nothing said
-- which one was on), the game's look of its active bar: the game gives it
-- to the bar of a trigger held (its buttons larger and further apart, its
-- trigger icon lit once, the other bars small); with the toggle no trigger
-- is held, so the game gives it to the top bar. While a bar is on, the top
-- bar's and that bar's buttons are drawn here in the game's own layout,
-- that bar large, the top bar small, and the game's own buttons of those
-- two bars made invisible (their alpha only: allowed in combat, nothing
-- moved, still the game's). A trigger really held: the game's own look.
---------------------------------------------------------------------------
local BAR_KEYS = { "a", "b", "x", "y", "up", "down", "left", "right" }
-- The usual crop of an action icon, if the game's can't be read
local ICON_CROP = 0.08
local SQUARE = { up = true, down = true, left = true, right = true }
-- The game's layout of a bar's buttons (Blizzard_GamepadActionBars,
-- ActionBarStyles.lua): from the bar's centre, small and large (active)
local LAYOUT = {
    small = { round = 30, square = 32,
        left = { -92, 0 }, up = { -58, 17 }, right = { -24, 0 }, down = { -58, -17 },
        x = { 25, 0 }, y = { 55, 18 }, b = { 85, 0 }, a = { 55, -18 } },
    large = { round = 38, square = 40,
        left = { -119, 0 }, up = { -75, 23 }, right = { -31, 0 }, down = { -75, -23 },
        x = { 32, 0 }, y = { 70, 23 }, b = { 108, 0 }, a = { 70, -23 } },
}
-- Its icon inside its mask, 3 px in from the button
local MASK_INSET = 3
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

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

-- The game's trigger icon under the bar of a trigger held (LT, RT, LT + RT),
-- where ours goes: the game never sees the triggers held while ours take
-- them, so it shows none (reported: nothing said which bar was on)
local GAME_TRIGGER_ICON = { LT = "LeftIcon", RT = "RightIcon", LTRT = "CenteredIcons" }
local TRIGGER_SIZE, PLUS_GAP = 24, 4
-- The game's light on the active bar's trigger icon, per its button icons
-- (letters, shapes, Switch): a flash (1 to 0 in 0.3 s) and a glow behind
-- (0.7 to 0.2 in 0.5 s, kept while the bar is on, gone in 0.33 s after)
local HALO_SUFFIX = { Shapes = "-ps", Reverse = "-switch" }
local HALO_TOP, HALO_BEHIND = 62, 88

-- A button of ours: the icon on a dark slot (round or square), the game's
-- ring over it, a cooldown, a count
local function newSlot(parent, key)
    local s = CK.NewFrame("Frame", nil, parent)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetAllPoints()
    s.round = not SQUARE[key]
    -- Under the icon, a dark slot: an empty one never shows the game's
    -- icon below it (reported: seen "through")
    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    s.bg:SetColorTexture(0.03, 0.03, 0.03, 1)
    if s.round then
        local bgMask = s:CreateMaskTexture()
        bgMask:SetAllPoints(s.bg)
        bgMask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        s.bg:AddMaskTexture(bgMask)
        local mask = s:CreateMaskTexture()
        mask:SetAllPoints(s.icon)
        -- A whole circle, black past its edge (the game's CircleMask atlas
        -- needs the game's clamp, or it stretches into a cross)
        mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        s.icon:AddMaskTexture(mask)
    end
    -- The game's frame of the button (its ring), drawn again over ours
    s.frame = s:CreateTexture(nil, "OVERLAY")
    s.cooldown = CK.NewFrame("Cooldown", nil, s, "CooldownFrameTemplate")
    s.cooldown:SetAllPoints()
    s.cooldown:SetDrawEdge(false)
    -- On a round button, a round swipe (a square one showed its corners)
    if s.round then
        s.cooldown:SetSwipeTexture(MASK)
        if s.cooldown.SetUseCircularEdge then s.cooldown:SetUseCircularEdge(true) end
    end
    s.count = s:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    s.count:SetPoint("BOTTOMRIGHT", -2, 2)
    s.key = key
    s.tint = { 1, 1, 1 }
    s:Hide()
    return s
end

-- The game's light on a trigger icon: its glow behind the icon, its flash
-- over it (frames of ours at the icon's strata, one under it, one above)
local function newHalo()
    local h = {}
    h.back = CK.NewFrame("Frame", nil, UIParent)
    h.back:SetSize(HALO_BEHIND, HALO_BEHIND)
    h.behind = h.back:CreateTexture(nil, "BACKGROUND")
    h.behind:SetAllPoints()
    h.front = CK.NewFrame("Frame", nil, UIParent)
    h.front:SetSize(HALO_TOP, HALO_TOP)
    h.top = h.front:CreateTexture(nil, "OVERLAY")
    h.top:SetAllPoints()
    local function anim(frame, region, from, to, duration, done)
        local group = frame:CreateAnimationGroup()
        if group.SetToFinalAlpha then group:SetToFinalAlpha(true) end
        local a = group:CreateAnimation("Alpha")
        a:SetTarget(region)
        a:SetFromAlpha(from)
        a:SetToAlpha(to)
        a:SetDuration(duration)
        if done then group:SetScript("OnFinished", done) end
        return group
    end
    h.flash = anim(h.front, h.top, 1, 0, 0.3, function() h.front:Hide() end)
    h.rise = anim(h.back, h.behind, 0.7, 0.2, 0.5)
    h.fade = anim(h.back, h.behind, 0.2, 0, 0.33, function() h.back:Hide() end)
    h.back:Hide()
    h.front:Hide()
    return h
end

function T:BuildView()
    local v = CK.NewFrame("Frame", nil, UIParent)
    v:SetFrameStrata("HIGH")
    v:Hide()
    -- The bar on's 8 buttons (compact: over the top bar's), and the top
    -- bar's (every bar shown: small)
    v.slots, v.topSlots = {}, {}
    for _, key in ipairs(BAR_KEYS) do
        v.slots[key] = newSlot(v, key)
        v.topSlots[key] = newSlot(v, key)
    end
    -- The trigger of the bar on: LT, RT or LT + RT, in the button style
    -- picked (Home > Look)
    local t = CK.NewFrame("Frame", nil, v)
    t:SetSize(TRIGGER_SIZE, TRIGGER_SIZE)
    t.first = t:CreateTexture(nil, "ARTWORK")
    t.first:SetSize(TRIGGER_SIZE, TRIGGER_SIZE)
    t.plus = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t.plus:SetText("+")
    t.second = t:CreateTexture(nil, "ARTWORK")
    t.second:SetSize(TRIGGER_SIZE, TRIGGER_SIZE)
    t:Hide()
    v.trigger = t
    -- The game's light on the bar on's trigger icon (two: LT + RT)
    v.halos = { newHalo(), newHalo() }
    -- Every bar shown: the game's active bar background, on the bar on
    v.focus = v:CreateTexture(nil, "BACKGROUND")
    v.focus:Hide()
    local elapsed = 0
    v:SetScript("OnUpdate", function(_, dt)
        local now = GetTime()
        for _, s in pairs(v.slots) do
            if s.pressedUntil then T:PaintPressed(s, now) end
        end
        elapsed = elapsed + dt
        if elapsed < 0.05 then return end
        elapsed = 0
        T:Draw()
    end)
    -- The option off (or anything hiding it): the game's own back
    v:SetScript("OnHide", function()
        T:ShowGame()
        T:Halo(nil)
    end)
    self.view = v
end

-- A key of the bar on pressed (its router or its relay tells): its icon
-- pressed in, like the game's buttons, each press shown (reported: no press
-- shown at all with the option on)
local PRESS_TIME, GAP = 0.15, 0.05
function T:PaintPressed(s, now)
    local down = now >= (s.pressAt or 0) and now < (s.pressedUntil or 0)
    if s.isPressed == down then return end
    s.isPressed = down
    s.icon:ClearAllPoints()
    local r, g, b = s.tint[1], s.tint[2], s.tint[3]
    if down then
        s.icon:SetPoint("TOPLEFT", 2, -3)
        s.icon:SetPoint("BOTTOMRIGHT", -2, 1)
        s.icon:SetVertexColor(r * 0.8, g * 0.8, b * 0.8)
    else
        s.icon:SetAllPoints()
        s.icon:SetVertexColor(r, g, b)
    end
end

function T:Pressed(inputId)
    local v = self.view
    local input = CK.Mapping.BY_ID[inputId]
    local s = v and v:IsShown() and input and input.bar and v.slots[input.bar]
    if not (s and s:IsShown()) then return end
    local now = GetTime()
    s.pressAt = (s.pressedUntil or 0) > now and now + GAP or now
    s.pressedUntil = s.pressAt + PRESS_TIME
    self:PaintPressed(s, now)
end

-- The game's buttons (and textures) made invisible, their alpha before kept
local hidden = {}
function T:HideGame(region, keep)
    if hidden[region] == nil then hidden[region] = region:GetAlpha() or 1 end
    region:SetAlpha(0)
    keep[region] = true
end

-- Those not kept hidden this time back as they were (none kept: all)
function T:ShowGame(keep)
    for region, alpha in pairs(hidden) do
        if not (keep and keep[region]) then
            region:SetAlpha(alpha)
            hidden[region] = nil
        end
    end
end
T.hidden = hidden

-- Where the game shows a button's icon: inside its mask (3 px in from the
-- button), else on its icon (the button also holds its glyph)
local function iconArea(button)
    local function shown(region) return type(region) == "table" and region.IsShown and region:IsShown() and region end
    return shown(button.CircleMask) or shown(button.SquareMask) or (type(button.icon) == "table" and button.icon) or button
end

-- What a slot shows: an action's icon (cropped as the game crops its own,
-- tinted as the game tints its button's: unusable, out of mana), the
-- game's ring, the count, the cooldown
local function paint(s, over, action, tinted)
    local P = CK.Paddles
    local normal = over.GetNormalTexture and over:GetNormalTexture()
    local atlas = normal and normal.GetAtlas and normal:GetAtlas()
    if atlas then s.frame:SetAtlas(atlas) end
    s.frame:SetShown(atlas ~= nil)
    local icon = CK.Mapping:ActionIcon(action)
    if type(icon) == "table" then
        -- (the game's own pictures: jump, interact... an atlas)
        P.SetIcon(s.icon, icon)
    else
        s.icon:SetTexture(icon)
        -- The game's crop of its icons (their dark edges cut off). The whole
        -- icon (the game's is larger than its mask, which hides the edges;
        -- ours fills the mask: they showed, reported, square and round):
        -- cropped
        local ul, ur, ll, lr, a1, a2, a3, a4
        if over.icon and over.icon.GetTexCoord then ul, ur, ll, lr, a1, a2, a3, a4 = over.icon:GetTexCoord() end
        local whole = ul == 0 and ur == 0 and a3 == 1 and a4 == 1
        if type(ul) == "number" and type(a4) == "number" and not whole then
            s.icon:SetTexCoord(ul, ur, ll, lr, a1, a2, a3, a4)
        else
            s.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        end
    end
    s.icon:SetShown(icon ~= nil)
    -- The game's tint of its icon, on ours (the action is the button's own)
    local r, g, b = 1, 1, 1
    if tinted and action:find("^bar:") and over.icon and over.icon.GetVertexColor then
        local cr, cg, cb = over.icon:GetVertexColor()
        if type(cr) == "number" and type(cg) == "number" and type(cb) == "number" then r, g, b = cr, cg, cb end
    end
    s.tint[1], s.tint[2], s.tint[3] = r, g, b
    if not s.isPressed then s.icon:SetVertexColor(r, g, b) end
    local slot = action:find("^bar:") and P:NativeSlot(action)
    local count = slot and C_ActionBar and C_ActionBar.GetActionDisplayCount and select(2, pcall(C_ActionBar.GetActionDisplayCount, slot))
    s.count:SetText(type(count) == "string" and count or "")
    P.ApplyCooldown(s.cooldown, action)
    s:Show()
end

-- A slot where the game's button would be in the other state (large or
-- small): from that button, by the difference of the game's two layouts
-- (the button's own place, a stance bar's in a stance, pressed in or not)
local function place(s, over, to)
    local from = over.collapsed == false and LAYOUT.large or LAYOUT.small
    local target, current = LAYOUT[to], from
    local d = target[s.key]
    local c = current[s.key]
    local size = target[s.round and "round" or "square"]
    s:ClearAllPoints()
    s:SetPoint("CENTER", over, "CENTER", d[1] - c[1], d[2] - c[2])
    s:SetSize(size - 2 * MASK_INSET, size - 2 * MASK_INSET)
    s.frame:ClearAllPoints()
    s.frame:SetPoint("CENTER", s, "CENTER")
    s.frame:SetSize(size, size)
end

-- The game's active look given to the bar on: its buttons large, the top
-- bar's small, the game's own of both invisible
function T:DrawActive(layer, bar)
    local v = self.view
    local P = CK.Paddles
    local keep = {}
    for _, list in ipairs({ { v.slots, bar, layer, "large" }, { v.topSlots, "top", "", "small" } }) do
        local slots, which, l, to = list[1], list[2], list[3], list[4]
        for key, s in pairs(slots) do
            local over = P:LiveButton("bar:" .. which .. ":" .. key)
            if over and over:IsVisible() then
                local input = byBar()[key]
                local action = input and CK.Mapping:GetReplaced(input.id, l) or ("bar:" .. which .. ":" .. key)
                place(s, over, to)
                paint(s, over, action, true)
                self:HideGame(over, keep)
            else
                s:Hide()
            end
        end
    end
    -- The game's background of its active bar (Edit Mode: highlight), from
    -- the top bar to the bar on
    local top, on = barFrame("top"), barFrame(bar)
    local focus = top and top.BackgroundFocus
    if focus and focus.IsShown and focus:IsShown() and on and on.IsVisible and on:IsVisible() and focus.GetAtlas and focus:GetAtlas() then
        local tx, ty = top:GetCenter()
        local fx, fy = focus:GetCenter()
        local w, h = focus:GetSize()
        v.focus:SetAtlas(focus:GetAtlas())
        v.focus:ClearAllPoints()
        v.focus:SetPoint("CENTER", on, "CENTER", (fx or 0) - (tx or 0), (fy or 0) - (ty or 0))
        v.focus:SetSize(w or 0, h or 0)
        v.focus:Show()
        self:HideGame(focus, keep)
    else
        v.focus:Hide()
    end
    self:ShowGame(keep)
end

-- The game's light on the bar on's trigger icon(s): lit when a bar comes
-- on (a flash, a glow kept), put out when it goes; nil: none
function T:Halo(layer)
    local v = self.view
    local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    local icon = layer and unit and unit[GAME_TRIGGER_ICON[layer] or ""]
    if not (icon and icon.IsVisible and icon:IsVisible() and icon:GetCenter()) then layer = nil end
    local sides = layer and (layer == "LTRT" and { "L", "R" } or { layer == "RT" and "R" or "L" }) or {}
    local fresh = layer ~= self.haloLayer
    self.haloLayer = layer
    local suffix
    if layer and InputDeviceIconSetManager then
        local ok, set = pcall(InputDeviceIconSetManager.GetActiveInputDeviceIconSet, InputDeviceIconSetManager)
        suffix = HALO_SUFFIX[ok and set or ""]
    end
    for i, h in ipairs(v.halos) do
        local side = sides[i]
        if not side then
            -- Gone: the glow fades out (the flash is over by itself)
            if fresh and h.back:IsShown() and not h.out then
                h.out = true
                h.rise:Stop()
                h.fade:Play()
            end
            h.flash:Stop()
            h.front:Hide()
        else
            -- At the icon, at its scale and strata: the glow under it, the
            -- flash over it (LT + RT: one at each end of the two icons)
            local scale = (icon:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
            local w, height = icon:GetSize()
            local x = #sides == 2 and (i == 1 and -1 or 1) * math.max(0, ((w or 0) - (height or 0)) / 2) or 0
            local strata = icon.GetFrameStrata and icon:GetFrameStrata()
            local level = icon.GetFrameLevel and icon:GetFrameLevel() or 1
            for _, f in ipairs({ h.back, h.front }) do
                f:SetScale(scale)
                if strata then f:SetFrameStrata(strata) end
                f:ClearAllPoints()
                f:SetPoint("CENTER", icon, "CENTER", x, 0)
            end
            h.back:SetFrameLevel(math.max(0, level - 1))
            h.front:SetFrameLevel(level + 2)
            local key = side .. (suffix or "")
            if h.drawn ~= key then
                h.drawn = key
                h.top:SetAtlas("gamepad-actionbar-fx-trigger" .. side .. "-top" .. (suffix or ""))
                h.behind:SetAtlas("gamepad-actionbar-fx-trigger-behind")
            end
            if fresh then
                h.out = nil
                h.fade:Stop()
                h.back:Show()
                h.rise:Play()
                h.front:Show()
                h.flash:Play()
            end
        end
    end
end

function T:Draw()
    local v = self.view
    local layer = self:Layer()
    local bar = layer ~= "" and CK.Mapping.LAYER_BAR[layer]
    local frame = bar and barFrame(bar)
    local compact = CK.Paddles.CompactBar()
    -- Every bar shown, the game showing the top bar as its active one (no
    -- trigger really held): ours
    local topA = CK.Paddles:NativeButton("bar:top:a")
    local gameTop = topA ~= nil and topA.collapsed == false
    -- At the game's bar's scale (its size, Home > Gamepad): our buttons,
    -- counts and rings as big as its own, its offsets ours
    local main = GamepadMainActionBarFrame
    local k = main and main.GetEffectiveScale and main:GetEffectiveScale() / (UIParent:GetEffectiveScale() or 1)
    if k and k > 0 and math.abs((v:GetScale() or 1) - k) > 0.001 then v:SetScale(k) end
    if frame and not compact and gameTop then
        v.trigger:Hide()
        self:DrawActive(layer, bar)
        self:Halo(layer)
        return
    end
    self:ShowGame()
    self:Halo(nil)
    v.focus:Hide()
    for _, s in pairs(v.topSlots) do s:Hide() end
    if not (frame and compact) then
        for _, s in pairs(v.slots) do s:Hide() end
        v.trigger:Hide()
        return
    end
    self:DrawTrigger(layer)
    local P = CK.Paddles
    for key, s in pairs(v.slots) do
        local over = P:NativeButton("bar:top:" .. key)
        local input = byBar()[key]
        local action = input and CK.Mapping:GetReplaced(input.id, layer) or ("bar:" .. bar .. ":" .. key)
        if over and over:IsVisible() then
            s:ClearAllPoints()
            s:SetAllPoints(iconArea(over))
            -- Its ring, over our icon as over the game's
            local normal = over.GetNormalTexture and over:GetNormalTexture()
            if normal then
                s.frame:ClearAllPoints()
                s.frame:SetAllPoints(normal)
            end
            paint(s, over, action)
        else
            s:Hide()
        end
    end
end

-- Where the game puts its trigger icon for that bar (its own, hidden with
-- the bar), else under the top bar it is drawn over
function T:DrawTrigger(layer)
    local t = self.view.trigger
    local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    local game = unit and unit[GAME_TRIGGER_ICON[layer] or ""]
    local top = barFrame("top")
    local anchor, y = nil, 0
    if game and game.GetCenter and game:GetCenter() then
        anchor = game
    elseif top and top.GetCenter and top:GetCenter() then
        anchor, y = top, -35
    end
    if not anchor then
        t:Hide()
        return
    end
    local scale = anchor.GetEffectiveScale and anchor:GetEffectiveScale()
    local mine = self.view:GetEffectiveScale()
    if scale and mine and mine > 0 then t:SetScale(scale / mine) end
    t:ClearAllPoints()
    t:SetPoint("CENTER", anchor, "CENTER", 0, y)
    t:Show()
    -- The glyphs set again only when the bar or the button style changes
    local st = CK.db.settings
    local key = layer .. "|" .. tostring(st.glyphStyle) .. "|" .. tostring(st.gameGlyphs)
    if t.drawn == key then return end
    t.drawn = key
    local both = layer == "LTRT"
    CK:SetGlyph(t.first, layer == "RT" and "RT" or "LT")
    t.first:ClearAllPoints()
    t.second:ClearAllPoints()
    t.plus:ClearAllPoints()
    if both then
        local width = TRIGGER_SIZE * 2 + PLUS_GAP * 2 + 8
        t:SetWidth(width)
        t.first:SetPoint("LEFT")
        t.plus:SetPoint("LEFT", t.first, "RIGHT", PLUS_GAP, 0)
        t.second:SetPoint("LEFT", t.plus, "RIGHT", PLUS_GAP, 0)
        CK:SetGlyph(t.second, "RT")
    else
        t:SetWidth(TRIGGER_SIZE)
        t.first:SetPoint("CENTER")
    end
    t.plus:SetShown(both)
    t.second:SetShown(both)
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
