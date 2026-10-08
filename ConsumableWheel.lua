local _, CK = ...
local L = CK.L

-- Module "consumables wheel": a key of its own (Gamepad tab, or the game's key
-- bindings) opens a wheel of consumables from the bags, drawn in the style of
-- the game's own radial menu (Claude Design): as many sections as the page
-- holds items (2 items: two halves, 5: five sections), up to 8 a page, LB /
-- RB turn the pages (up to 3). Food, drink,
-- health and mana potions, healthstone, mana gem, bandages, buff food,
-- elixirs and flasks, scrolls. Its key opens it, the left stick chooses (the
-- choice stays when it goes back to the middle; the right stick is the
-- game's, for its own wheels), A uses, B cancels; the D-pad and the
-- mouse work too. While it is open it takes the sticks, like the game's own
-- wheels: the camera and the character stay still. In the middle of the
-- screen (or placed with the mouse or the D-pad).
--
-- Secure code only acts on keys: A reads the left stick from the game's
-- gamepad state. The choice stays when the stick goes back to the middle:
-- noted by our drawing code out of combat, and in combat by the left
-- stick's direction keys, which the game sends while the wheel is open
-- (its GamePadStickAxisButtons setting, on only then).
--
-- It works in combat: the wheel, its slots and the keys it takes while open
-- are secure frames and snippets run by the game (its restricted
-- environment), so a press does what a click of the player's would. The
-- items in the slots can only change out of combat (a rule of the game): the
-- wheel is filled from the bags then. The pictures (icons, counts, cooldowns,
-- the selection ring) are ours, drawn over it.
--
-- The same wheel also shows the player's own wheels (MyWheels.lua): each has
-- a key of its own, 8 slots on one page, spells, items or macros. The open
-- wheel is the "wheel" attribute: "c" (consumables) or "1" to "8".
--
-- And the party spells' wheels ("p" and the spell's ID): a spell put on a
-- key from the Gamepad tab's Party list opens a small wheel like the game's
-- flyouts (hunter aspects), centred on the button that holds the spell (the
-- spell drawn in its middle): the party's members around it, each always in
-- the same place (you at the bottom, member 1 on the left, then clockwise),
-- only those who are there, their portraits and names. Aimed with the right
-- stick (like the game's flyouts), at the nearest member there; the key
-- held, aimed, let go casts the spell on that member, the target kept (the
-- slot's button has its unit); a short press leaves it open: aim, then A.
-- Drawn by its own frame (`pview`): the big wheel's drawing stays as it is.
local W = {}
CK.ConsumableWheel = W

local SEGMENTS, PAGES = 8, 3
W.MY_MAX = 8
local MAX = SEGMENTS * PAGES
local AIM = 0.5     -- the stick aims past half its course
-- The wheel's art (Claude Design, design/radial/wheel/geometry.json): 512 x
-- 512, its crown from 75 to 213 from the middle. Like the game's radial
-- menu: the icons a little inside the crown's middle, each name beside its
-- icon on the outer side (GameFontNormal, 80 x 40)
local WHEEL_SIZE, ICON_RADIUS, SLOT = 512, 128, 46
local LABEL_W, LABEL_H, LABEL_GAP = 80, 40, 60
-- The section overlays (highlight, veil) cut to their section: { width,
-- height, x, y } with x, y their centre from the wheel's (y up), for section
-- 1 (tools/wheel_textures.py)
local OVERLAY = {
    [1] = { 512, 512, 0, 0 },
    [2] = { 512, 256, 0, 110 },
    [3] = { 512, 256, 0, 130 },
    [4] = { 512, 256, 0, 137 },
    [5] = { 256, 256, 0, 140 },
    [6] = { 256, 256, 0, 142 },
    [7] = { 256, 256, 0, 142 },
    [8] = { 256, 256, 0, 143 },
}
-- The banner under the wheel, sized for its two lines
local BANNER_W, BANNER_H = 360, 64
-- A party spell's wheel: its members' places (you, then party1 to party4),
-- their direction from the middle: you at the bottom, then clockwise every
-- fifth of a turn (member 1 on the left)
local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local PARTY_RADIUS, PARTY_SLOT, PARTY_CENTER, PARTY_BASE = 62, 38, 44, 196
local PARTY_DIRS = {}
for i = 1, #PARTY_UNITS do
    local a = math.pi + (i - 1) * 2 * math.pi / #PARTY_UNITS
    PARTY_DIRS[i] = { math.sin(a), math.cos(a) }
end
W.PARTY_DIRS = PARTY_DIRS
local function isParty(wid) return type(wid) == "string" and wid:sub(1, 1) == "p" end
W.isParty = isParty
-- The right stick's direction keys (sent with the game's
-- GamePadStickAxisButtons setting): letting the stick go casts
local PARTY_STICK_KEYS = "PADRSTICKUP,PADRSTICKDOWN,PADRSTICKLEFT,PADRSTICKRIGHT,"
local STICK_DIR_KEYS = {}
for _, side in ipairs({ "L", "R" }) do
    for _, dir in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do STICK_DIR_KEYS["PAD" .. side .. "STICK" .. dir] = true end
end
local TEX = "Interface\\AddOns\\EasyController\\textures\\"
-- Slot `i` of a page of `n`: clockwise from the top, its angle (radians,
-- clockwise from 12 o'clock) and its direction (x right, y up)
local function slotAngle(i, n) return (i - 1) * 2 * math.pi / n end
local function slotDir(i, n)
    local a = slotAngle(i, n)
    return math.sin(a), math.cos(a)
end
W.slotDir = slotDir

-- The wheel's kinds, in its order
W.CATEGORIES = { "food", "drink", "healthPotion", "manaPotion", "healthstone", "manaGem", "bandage",
    "buffFood", "elixir", "scroll" }
local CATEGORY_INDEX = {}
for i, c in ipairs(W.CATEGORIES) do CATEGORY_INDEX[c] = i end
-- Not usable in combat (the game's rule): greyed there
local OUT_OF_COMBAT = { food = true, drink = true, buffFood = true }

local HEALTHSTONES = {}
for _, id in ipairs({ 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 }) do
    HEALTHSTONES[id] = true
end
local MANA_GEMS = { [5514] = true, [5513] = true, [8007] = true, [8008] = true }
-- The game's own spells, by ID: their names are in the client's language
local SPELL_FOOD, SPELL_DRINK, SPELL_WELL_FED, SPELL_FIRST_AID = 433, 430, 19705, 746

local function settings() return CK.db.settings.wheel end

---------------------------------------------------------------------------
-- What goes in the wheel
---------------------------------------------------------------------------
local spellNames
local function names()
    if not spellNames then
        local get = C_Spell and C_Spell.GetSpellName or function(id) return (GetSpellInfo(id)) end
        spellNames = { food = get(SPELL_FOOD), drink = get(SPELL_DRINK), wellFed = get(SPELL_WELL_FED),
            firstAid = get(SPELL_FIRST_AID) }
    end
    return spellNames
end

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

local function tooltipText(id)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return "" end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    local parts = {}
    if ok and type(data) == "table" and data.lines then
        for _, line in ipairs(data.lines) do
            local text = line.leftText
            if type(text) == "string" and not secret(text) then parts[#parts + 1] = text end
        end
    end
    return table.concat(parts, "\n"):lower()
end

-- The kind of an item, or nil (not for the wheel)
function W.Category(id)
    if HEALTHSTONES[id] then return "healthstone" end
    if MANA_GEMS[id] then return "manaGem" end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
    local spell = C_Item.GetItemSpell and C_Item.GetItemSpell(id)
    local n = names()
    -- Bandages: by their First Aid spell, whatever class the client gives them
    if (spell and spell == n.firstAid) or (classID == 0 and subClassID == 7) then return "bandage" end
    -- Raw fish and the like: trade goods the game lets you eat or drink
    if classID ~= 0 and spell and (spell == n.food or spell == n.drink) then
        return spell == n.drink and "drink" or "food"
    end
    if classID ~= 0 then return nil end
    if not spell then return nil end
    if subClassID == 4 then return "scroll" end
    if subClassID == 2 or subClassID == 3 then return "elixir" end
    if subClassID == 5 or spell == n.food or spell == n.drink then
        if spell == n.drink then return "drink" end
        local text = tooltipText(id)
        if n.wellFed and text:find(n.wellFed:lower(), 1, true) then return "buffFood" end
        return "food"
    end
    local text = tooltipText(id)
    if text:find((MANA or "mana"):lower(), 1, true) then return "manaPotion" end
    if text:find((HEALTH or "health"):lower(), 1, true) then return "healthPotion" end
    if subClassID == 1 or subClassID == 13 then return "elixir" end
end

-- Why an item of the bags is not in the wheel (for /ec wheel), or nil
function W.Reason(id)
    local cat = W.Category(id)
    if not cat then
        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
        local spell = C_Item.GetItemSpell and C_Item.GetItemSpell(id)
        return format("- (class %s/%s, use: %s)", tostring(classID), tostring(subClassID), tostring(spell))
    end
    if not settings().categories[cat] then return cat .. ": " .. L.WHEEL_DIAG_OFF end
    local get = C_Item.GetItemInfo or GetItemInfo
    local _, _, _, _, minLevel = get(id)
    if minLevel and minLevel > (UnitLevel("player") or 0) then return cat .. ": " .. format(L.WHEEL_DIAG_LEVEL, minLevel) end
    return nil, cat
end

---------------------------------------------------------------------------
-- The sticks while the wheel is open, and just after
---------------------------------------------------------------------------
function W:TakeSticks(frame, on)
    if frame.EnableGamePadStick then pcall(frame.EnableGamePadStick, frame, on) end
end

-- The stick that aims the open wheel: the left one, the right one for a
-- party spell's
local function aimStick(wheel)
    if not wheel then return 1 end
    return wheel:GetAttribute(isParty(wheel:GetAttribute("wheel")) and "ck-pstick" or "ck-stick") or 1
end

-- How far the stick that aims the wheel is pushed now (0 to 1)
local function aimLength()
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[aimStick(W.frame)]
    return stick and stick.len or 0
end

-- After the wheel closes with its stick still pushed, the sticks are kept a
-- moment, so the character doesn't walk off (or stand up from eating): until
-- that stick is let go, at most HOLD_MAX. Players lost the character and the
-- camera for seconds when they kept pushing (to walk on) or another stick or
-- axis of their pad never read as let go: only the aiming stick counts now,
-- and only for a moment.
local HOLD_MAX = 0.4

function W:BuildHold()
    local hold = CK.NewFrame("Frame", nil, UIParent)
    hold:SetAllPoints(UIParent)
    hold:Hide()
    hold.elapsed = 0
    hold:SetScript("OnGamePadStick", function() end)
    hold:SetScript("OnShow", function(self)
        self.elapsed = 0
        W:TakeSticks(self, true)
    end)
    hold:SetScript("OnHide", function(self) W:TakeSticks(self, false) end)
    hold:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed > HOLD_MAX or aimLength() < 0.2 then self:Hide() end
    end)
    self.hold = hold
end

function W:HoldSticks()
    if aimLength() >= 0.2 then self.hold:Show() end
end

-- What happened on the last openings and presses, for /ec wheel
local log = {}
function W:Log(what)
    local view, wheel = self.view, self.frame
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[aimStick(wheel)]
    local taken = view and view.IsGamePadStickEnabled and view:IsGamePadStickEnabled()
    log[#log + 1] = format("%s: %s, combat %s, sticks taken %s, left stick %.2f, A = %s, aimed %s",
        date("%H:%M:%S"), what, tostring(InCombatLockdown()), tostring(taken), stick and stick.len or 0,
        tostring(GetBindingAction("PAD1", true)), tostring(self.aimed))
    while #log > 8 do table.remove(log, 1) end
end

-- /ec wheel: what is in it, what is not and why
function W:Diagnose()
    local wheel = self.frame
    CK:Print(L.WHEEL_DIAG, wheel and wheel:GetAttribute("ck-c-total") or 0, wheel and wheel:GetAttribute("ck-c-pages") or 0,
        tostring(settings().enabled), tostring(InCombatLockdown()), tostring(self.pending or false))
    local seen = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not seen[id] then
                seen[id] = true
                local why, cat = W.Reason(id)
                local name = C_Item.GetItemNameByID(id) or ("item:" .. id)
                if cat then
                    DEFAULT_CHAT_FRAME:AddMessage(format("  |cff40ff40+|r %s: %s", name, L["WHEEL_CAT_" .. cat:upper()]))
                elseif not why:find("^%- %(class 7") and not why:find("^%- %(class [1-9]%d*/") then
                    DEFAULT_CHAT_FRAME:AddMessage(format("  |cff9d9a8c-|r %s %s", name, why))
                end
            end
        end
    end
    for _, line in ipairs(log) do DEFAULT_CHAT_FRAME:AddMessage("  |cff9d9a8c" .. line .. "|r") end
end

-- The best first: required level, then item level
-- The best first: required level, then item level. Nil for an item above
-- the player's level (the game won't let it be used)
local function rank(id)
    local get = C_Item.GetItemInfo or GetItemInfo
    local _, _, _, itemLevel, minLevel = get(id)
    if minLevel and minLevel > (UnitLevel("player") or 0) then return nil end
    return (minLevel or 0) * 1000 + (itemLevel or 0)
end

-- { id, cat }: the best of each kind, then the other variants (an option),
-- at most 12, each next to its kind
function W:Scan()
    local s = settings()
    local byKind, seen = {}, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not seen[id] then
                seen[id] = true
                local cat = W.Category(id)
                local value = cat and s.categories[cat] and rank(id)
                if value then
                    byKind[cat] = byKind[cat] or {}
                    table.insert(byKind[cat], { id = id, cat = cat, rank = value })
                end
            end
        end
    end
    local items = {}
    for _, cat in ipairs(W.CATEGORIES) do
        local list = byKind[cat]
        if list then
            table.sort(list, function(a, b) return a.rank > b.rank end)
            if #items < MAX then items[#items + 1] = list[1] end
        end
    end
    if s.variants then
        for _, cat in ipairs(W.CATEGORIES) do
            for i = 2, #(byKind[cat] or {}) do
                if #items < MAX then items[#items + 1] = byKind[cat][i] end
            end
        end
    end
    table.sort(items, function(a, b)
        if a.cat ~= b.cat then return CATEGORY_INDEX[a.cat] < CATEGORY_INDEX[b.cat] end
        return a.rank > b.rank
    end)
    return items
end

---------------------------------------------------------------------------
-- The secure part. The wheel frame owns the keys it takes while open (A,
-- B, LB / RB, with every modifier a trigger may add); its snippets read the
-- left stick from the game's gamepad state when A is pressed. Each slot
-- direction is a unit vector ("ck-x3", "ck-y3"): the aimed slot is the
-- closest one. Nothing is remembered: the stick back in the middle aims at
-- nothing.
---------------------------------------------------------------------------
local PREFIXES = ",SHIFT-,CTRL-,ALT-,CTRL-SHIFT-,ALT-SHIFT-,ALT-CTRL-,ALT-CTRL-SHIFT-,"

-- A page of the open wheel into the 8 slots' buttons, from the wheel's
-- attributes: "ck-c-2-5" is the consumables wheel ("c"; the player's: "1"
-- to "8"), page 2, slot 5; "-t" its kind (item, spell, macro), "-u" its unit
-- "-n": how many the page holds; the slots' buttons go around the wheel in
-- as many sections ("ck-x5-2": slot 2 of 5's direction). A party spell's
-- wheel: each member's own place ("ck-pdx-2"), nearer the middle; a member
-- who isn't there gets no button
local APPLY_PAGE = [[
    local wid = owner:GetAttribute("wheel") or "c"
    local party = strsub(wid, 1, 1) == "p"
    local key = "ck-" .. wid .. "-" .. (owner:GetAttribute("page") or 1) .. "-"
    local n = owner:GetAttribute(key .. "n") or 0
    local radius = owner:GetAttribute(party and "ck-pradius" or "ck-radius")
    for i = 1, 8 do
        local b = owner:GetFrameRef("slot" .. i)
        local kind, value = owner:GetAttribute(key .. i .. "-t"), owner:GetAttribute(key .. i)
        local unit = owner:GetAttribute(key .. i .. "-u")
        b:SetAttribute("type", kind)
        b:SetAttribute("item", kind == "item" and value or nil)
        b:SetAttribute("spell", kind == "spell" and value or nil)
        b:SetAttribute("macro", kind == "macro" and value or nil)
        b:SetAttribute("unit", unit)
        if kind and i <= n and (not party or UnitExists(unit)) then
            local x = owner:GetAttribute(party and ("ck-pdx-" .. i) or ("ck-x" .. n .. "-" .. i))
            local y = owner:GetAttribute(party and ("ck-pdy-" .. i) or ("ck-y" .. n .. "-" .. i))
            b:ClearAllPoints()
            b:SetPoint("CENTER", owner, "CENTER", radius * x, radius * y)
            b:Show()
        else
            b:Hide()
        end
    end
]]

-- LB / RB: the previous or next page
local PAGE = [[
    if not down then return false end
    local pages = owner:GetAttribute("ck-" .. (owner:GetAttribute("wheel") or "c") .. "-pages") or 1
    if pages < 2 then return false end
    owner:SetAttribute("page", ((owner:GetAttribute("page") or 1) - 1 + (button == "LB" and -1 or 1)) % pages + 1)
    ]] .. APPLY_PAGE .. [[
    return false
]]

-- `slot`: the slot the left stick points at now (past half its course), else
-- 0. A party spell's wheel: the right stick, the nearest member there
local AIMED = [[
    local slot = 0
    local state = GetGamePadState()
    local aimWid = owner:GetAttribute("wheel") or "c"
    local aimParty = strsub(aimWid, 1, 1) == "p"
    local stick = state and state.sticks
        and state.sticks[owner:GetAttribute(aimParty and "ck-pstick" or "ck-stick") or 1]
    local n = owner:GetAttribute("ck-" .. aimWid .. "-" .. (owner:GetAttribute("page") or 1) .. "-n") or 0
    if n > 0 and stick and stick.len and stick.len > ]] .. AIM .. [[ then
        local bestDot = -2
        for i = 1, n do
            if not aimParty then
                local dot = stick.x * owner:GetAttribute("ck-x" .. n .. "-" .. i) + stick.y * owner:GetAttribute("ck-y" .. n .. "-" .. i)
                if dot > bestDot then slot, bestDot = i, dot end
            elseif owner:GetFrameRef("slot" .. i):IsShown() then
                local dot = stick.x * owner:GetAttribute("ck-pdx-" .. i) + stick.y * owner:GetAttribute("ck-pdy-" .. i)
                if dot > bestDot then slot, bestDot = i, dot end
            end
        end
    end
    -- An empty slot (after a page's last item, or left empty in a wheel of
    -- the player's): nothing
    if slot > 0 and not owner:GetFrameRef("slot" .. slot):IsShown() then slot = 0 end
]]

-- Opening: shown, the sticks taken from the camera and the character (like
-- the game's own wheels), the keys it uses taken while it is open
local SHOW = [[
    owner:SetAttribute("page", 1)
    ]] .. APPLY_PAGE .. [[
    owner:Show()
    for prefix in gmatch(owner:GetAttribute("ck-prefixes"), "([^,]*),") do
        owner:SetBindingClick(true, prefix .. "PAD1", "ControllerKeyboardWheelUse")
        owner:SetBindingClick(true, prefix .. "PAD2", "ControllerKeyboardWheelClose")
        owner:SetBindingClick(true, prefix .. "PADLSHOULDER", "ControllerKeyboardWheelPage", "LB")
        owner:SetBindingClick(true, prefix .. "PADRSHOULDER", "ControllerKeyboardWheelPage", "RB")
    end
    owner:SetBindingClick(true, "ESCAPE", "ControllerKeyboardWheelClose")
    -- A party spell's wheel: the right stick's direction keys, to see it let go
    if strsub(owner:GetAttribute("wheel") or "c", 1, 1) == "p" then
        owner:SetAttribute("ck-aim", 0)
        for key in gmatch(owner:GetAttribute("ck-pstickkeys"), "([^,]+),") do
            owner:SetAttribute("ck-held-" .. key, 0)
            for prefix in gmatch(owner:GetAttribute("ck-prefixes"), "([^,]*),") do
                owner:SetBindingClick(true, prefix .. key, "ControllerKeyboardWheelLetGo", key)
            end
        end
    end
]]

local HIDE = [[
    owner:Hide()
    owner:ClearBindings()
]]

-- A wheel's key (its "ck-wheel"): opens or closes it, on its press (a key
-- bound to it sends a press and a release; a router sends one click on the
-- press, no "down", and its release as a "ckup" click). Another wheel open:
-- this one takes its place. The release: with the hold option (Wheels >
-- Opening), what the stick aims at is used (its slot's button clicked, which
-- closes the wheel), the stick in the middle closes it; else let pass.
-- A party spell's wheel always: the stick in the middle leaves it open (a
-- short press: aim, then A).
--
-- A party spell's wheel opens on its button (its key's "ck-ax", "ck-ay": the
-- button's centre on the screen, else where the wheels go), the wheel frame
-- made small (never pushed back by the screen's edges); the next other wheel
-- puts it back where the wheels go ("ck-home-*", set by Place).
local TOGGLE = [[
    local wid = self:GetAttribute("ck-wheel") or "c"
    local party = strsub(wid, 1, 1) == "p"
    local release = (button and strsub(button, 1, 4) == "ckup") or (not down and self:GetAttribute("ck-down"))
    self:SetAttribute("ck-down", down and true or false)
    if release then
        if not ((party or owner:GetAttribute("ck-hold")) and owner:IsShown() and owner:GetAttribute("wheel") == wid) then
            return false
        end
        ]] .. AIMED .. [[
        if slot < 1 then
            if not party then
                ]] .. HIDE .. [[
            end
            return false
        end
        -- Clicked on this release
        self:SetAttribute("useOnKeyDown", false)
        return "s" .. slot
    end
    if owner:IsShown() and owner:GetAttribute("wheel") == wid then
        ]] .. HIDE .. [[
    elseif (owner:GetAttribute("ck-" .. wid .. "-total") or 0) > 0 then
        local homeP = owner:GetAttribute("ck-home-p") or "CENTER"
        if party then
            local ax, ay = self:GetAttribute("ck-ax"), self:GetAttribute("ck-ay")
            owner:SetWidth(2)
            owner:SetHeight(2)
            owner:ClearAllPoints()
            if ax and ay then
                owner:SetPoint("CENTER", "$parent", "BOTTOMLEFT", ax, ay)
            else
                owner:SetPoint(homeP, "$parent", homeP, owner:GetAttribute("ck-home-x") or 0, owner:GetAttribute("ck-home-y") or 0)
            end
            owner:SetAttribute("ck-moved", true)
            owner:SetAttribute("ck-opener", self:GetName())
        elseif owner:GetAttribute("ck-moved") then
            owner:SetWidth(owner:GetAttribute("ck-home-w"))
            owner:SetHeight(owner:GetAttribute("ck-home-h"))
            owner:ClearAllPoints()
            owner:SetPoint(homeP, "$parent", homeP, owner:GetAttribute("ck-home-x") or 0, owner:GetAttribute("ck-home-y") or 0)
            owner:SetAttribute("ck-moved", nil)
        end
        owner:SetAttribute("wheel", wid)
        ]] .. SHOW .. [[
    end
    return false
]]

-- A: the item the left stick points at; the stick in the middle: nothing
local USE = [[
    if not down then return false end
    ]] .. AIMED .. [[
    if slot < 1 then return false end
    return "s" .. slot, true
]]

-- A party spell's wheel: the right stick's direction keys (their name comes
-- as the click's button). A press aims (the stick a little out: the nearest
-- member there); a release aims again, then, once no direction is held any
-- more (the stick let go), casts on the member aimed, like the game's
-- flyouts. Rolling round the rim keeps a direction held: nothing is cast.
local LET_GO = [[
    local wid = owner:GetAttribute("wheel") or "c"
    if not (owner:IsShown() and strsub(wid, 1, 1) == "p" and owner:GetAttribute("ck-held-" .. button)) then
        return false
    end
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[owner:GetAttribute("ck-pstick") or 2]
    local len = stick and stick.len or 0
    if len > 0.2 then
        local best, bestDot = nil, -2
        for i = 1, 5 do
            if owner:GetFrameRef("slot" .. i):IsShown() then
                local dot = stick.x * owner:GetAttribute("ck-pdx-" .. i) + stick.y * owner:GetAttribute("ck-pdy-" .. i)
                if dot > bestDot then best, bestDot = i, dot end
            end
        end
        if best then owner:SetAttribute("ck-aim", best) end
    end
    if down then
        owner:SetAttribute("ck-held-" .. button, 1)
        return false
    end
    owner:SetAttribute("ck-held-" .. button, 0)
    for key in gmatch(owner:GetAttribute("ck-pstickkeys"), "([^,]+),") do
        if owner:GetAttribute("ck-held-" .. key) == 1 then return false end
    end
    -- Still out at the rim (between two directions): not let go
    if len >= 0.9 then return false end
    local slot = owner:GetAttribute("ck-aim") or 0
    if slot < 1 or not owner:GetFrameRef("slot" .. slot):IsShown() then return false end
    return "s" .. slot, true
]]

-- After a use (A, or a click on a slot): the wheel closes
local DONE = HIDE

local CLOSE = HIDE .. " return false"

-- A button for the wheel's keys: a secure action button, its OnClick
-- wrapped by the wheel
local function keyButton(name, wheel, pre, post, ...)
    local b = CK.NewFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    if ... then b:RegisterForClicks(...) else b:RegisterForClicks("AnyDown") end
    b:SetAttribute("useOnKeyDown", true)
    b:Hide()
    SecureHandlerWrapScript(b, "OnClick", wheel, pre, post)
    return b
end

local function atlas(texture, name, fallback)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
        texture:SetAtlas(name, true)
        return true
    end
    if fallback then fallback(texture) end
end

function W:Build()
    if self.frame then return end
    local wheel = CK.NewFrame("Frame", "ControllerKeyboardWheel", UIParent, "SecureHandlerBaseTemplate")
    wheel:SetSize(WHEEL_SIZE, 600)
    wheel:SetFrameStrata("DIALOG")
    wheel:Hide()
    wheel:SetAttribute("wheel", "c")
    wheel:SetAttribute("page", 1)
    wheel:SetMovable(true)
    wheel:SetClampedToScreen(true)
    wheel:EnableMouse(true)
    wheel:RegisterForDrag("LeftButton")
    wheel:SetScript("OnDragStart", function(self)
        if not settings().locked and not InCombatLockdown() then self:StartMoving() end
    end)
    wheel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        W:SavePosition()
    end)
    wheel:SetAttribute("ck-prefixes", PREFIXES)
    -- Each slot's direction from the middle, for each number of sections
    for n = 1, SEGMENTS do
        for i = 1, n do
            local x, y = slotDir(i, n)
            wheel:SetAttribute("ck-x" .. n .. "-" .. i, x)
            wheel:SetAttribute("ck-y" .. n .. "-" .. i, y)
        end
    end
    wheel:SetAttribute("ck-radius", ICON_RADIUS)
    -- A party spell's wheel: its members' places, its size
    wheel:SetAttribute("ck-pradius", PARTY_RADIUS)
    for i, d in ipairs(PARTY_DIRS) do
        wheel:SetAttribute("ck-pdx-" .. i, d[1])
        wheel:SetAttribute("ck-pdy-" .. i, d[2])
    end
    wheel:SetAttribute("ck-pstickkeys", PARTY_STICK_KEYS)
    wheel:SetAttribute("ck-home-w", WHEEL_SIZE)
    wheel:SetAttribute("ck-home-h", 600)
    self.frame = wheel
    self:Place()

    -- The wheel's key: its press (and a shared paddle key's single click)
    local toggle = keyButton("ControllerKeyboardWheelToggle", wheel, TOGGLE, nil, "AnyDown", "AnyUp")
    toggle:SetAttribute("ck-wheel", "c")
    -- On a release (hold option): the slot aimed at ("s3")
    toggle:SetAttribute("type", "click")
    self.toggle = toggle
    -- The key of each wheel of the player's
    self.myToggles = {}
    for n = 1, W.MY_MAX do
        local t = keyButton("ControllerKeyboardMyWheel" .. n, wheel, TOGGLE, nil, "AnyDown", "AnyUp")
        t:SetAttribute("ck-wheel", tostring(n))
        t:SetAttribute("type", "click")
        self.myToggles[n] = t
    end
    -- The party spells' keys: made when a key gets one (PartyToggle)
    self.partyToggles = {}
    local use = keyButton("ControllerKeyboardWheelUse", wheel, USE, DONE)
    use:SetAttribute("type", "click")
    use:HookScript("OnClick", function(_, _, down) if down ~= false then W:Log("A") end end)
    self.use = use
    keyButton("ControllerKeyboardWheelClose", wheel, CLOSE)
    -- The stick direction keys: their presses and releases move the choice

    keyButton("ControllerKeyboardWheelPage", wheel, PAGE)
    -- A party spell's wheel: the right stick let go (its direction keys'
    -- presses and releases; the cast on a release)
    local letGo = keyButton("ControllerKeyboardWheelLetGo", wheel, LET_GO, DONE, "AnyDown", "AnyUp")
    letGo:SetAttribute("type", "click")
    letGo:SetAttribute("useOnKeyDown", false)
    self.letGo = letGo

    -- What is drawn: the game's radial menu art, under the slots' buttons
    local view = CK.NewFrame("Frame", nil, wheel)
    view:SetAllPoints()
    self.view = view
    -- The sticks: taken by this plain frame of ours while it shows (with the
    -- wheel), like the game's own wheels, so the character and the camera
    -- don't move (and food can be eaten: not while moving). Turned on each
    -- time it shows; its stick script is needed for the game to give it them.
    view:SetScript("OnGamePadStick", function() W:Track() end)
    -- The wheel in as many sections as the page holds (set when drawn)
    local bg = view:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("CENTER")
    bg:SetSize(WHEEL_SIZE, WHEEL_SIZE)
    bg:SetTexture(TEX .. "ck_wheel_bg_8")
    view.bg = bg
    -- The aimed section
    view.highlight = view:CreateTexture(nil, "BORDER")
    view.highlight:Hide()
    -- Under the wheel, the game's banner: the aimed item (or what to do);
    -- below it, the pages and the help
    view.bottom = view:CreateTexture(nil, "BACKGROUND")
    view.bottom:SetPoint("TOP", bg, "BOTTOM", 0, 8)
    atlas(view.bottom, "gamepad-radial-menu-bottomtext", function(t)
        t:SetColorTexture(0, 0, 0, 0.5)
    end)
    view.bottom:SetSize(BANNER_W, BANNER_H)
    view.name = view:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    view.name:SetPoint("TOP", view.bottom, "TOP", 0, -12)
    view.name:SetWidth(BANNER_W - 30)
    view.name:SetWordWrap(false)
    view.count = view:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    view.count:SetPoint("TOP", view.name, "BOTTOM", 0, -4)
    view.count:SetWidth(BANNER_W - 30)
    view.count:SetWordWrap(false)
    view.help = view:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.help:SetPoint("TOP", view.bottom, "BOTTOM", 0, -4)
    view.pages = view:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.pages:SetPoint("TOP", view.help, "BOTTOM", 0, -4)
    view:SetScript("OnUpdate", function() W:Track() end)
    view:SetScript("OnShow", function()
        W:TakeSticks(view, true)
        W.hold:Hide()
        W:Paint()
        W:Log("open")
    end)
    -- Closed with a stick still pushed: held until it is let go, so the
    -- character doesn't walk off (or stand up from eating)
    view:SetScript("OnHide", function() W:HoldSticks() end)
    -- Closed (its keys let go in its secure code, which our binding hooks
    -- don't see): the replaced buttons it held back are bound again
    wheel:HookScript("OnHide", function()
        C_Timer.After(0, function()
            if not InCombatLockdown() and CK.Mapping then CK.Mapping:Repair() end
            -- A party spell's wheel closed: the frame back where the wheels
            -- go, the stick's direction keys given back
            if not wheel:IsShown() then
                W:Unmove()
                if not InCombatLockdown() then W:StickKeys(false) end
            end
        end)
    end)
    self:BuildHold()

    self.segments, self.buttons = {}, {}
    for i = 1, SEGMENTS do
        local ix, iy = slotDir(i, SEGMENTS)
        ix, iy = ICON_RADIUS * ix, ICON_RADIUS * iy
        local seg = {}
        -- The grey veil over a section that can't be used
        seg.disabled = view:CreateTexture(nil, "ARTWORK", nil, 2)
        seg.disabled:Hide()
        -- The item: a round slot of the gamepad bar's, its name further out
        -- (both placed for the page's count when drawn)
        seg.slot = CK.Paddles:CreateSlot(view, SLOT)
        seg.slot:SetPoint("CENTER", bg, "CENTER", ix, iy)
        seg.slot:Hide()
        seg.label = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        seg.label:SetSize(LABEL_W, LABEL_H)
        seg.label:SetJustifyH("CENTER")
        seg.label:SetJustifyV("MIDDLE")
        seg.label:SetWordWrap(true)
        self.segments[i] = seg
        -- The slot's own secure button: clicked by a stick, A, the key ("s3"),
        -- or the mouse
        local b = CK.NewFrame("Button", "ControllerKeyboardWheelSlot" .. i, wheel, "SecureActionButtonTemplate")
        b:SetSize(SLOT + 14, SLOT + 14)
        -- On the wheel frame (the background's center): a protected frame can't
        -- be anchored to a texture
        b:SetPoint("CENTER", wheel, "CENTER", ix, iy)
        b:RegisterForClicks("AnyUp")
        b:SetAttribute("useOnKeyDown", false)
        b:SetScript("OnEnter", function(self)
            local entry = W:PageItems()[i]
            if not entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if entry.party then
                GameTooltip:SetUnit(entry.unit)
            elseif entry.kind == "item" then
                GameTooltip:SetItemByID(entry.id)
            elseif entry.kind == "spell" and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(entry.id)
            else
                GameTooltip:SetText(W.EntryName(entry), 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        SecureHandlerWrapScript(b, "OnClick", wheel, "return nil, true", DONE)
        b:HookScript("OnClick", function()
            W:Log("use " .. i)
            W:NoteMeal(i)
        end)
        b:Hide()
        SecureHandlerSetFrameRef(wheel, "slot" .. i, b)
        use:SetAttribute("*clickbutton-s" .. i, b)
        letGo:SetAttribute("*clickbutton-s" .. i, b)
        self.toggle:SetAttribute("*clickbutton-s" .. i, b)
        for _, t in ipairs(self.myToggles) do t:SetAttribute("*clickbutton-s" .. i, b) end

        self.buttons[i] = b
    end
    self:BuildParty(wheel)
end

-- A party spell's wheel's drawing, over the wheel (the big wheel's drawing
-- hidden meanwhile): a round base like the game's flyouts, the spell in the
-- middle, the members there around it, the aimed one pointed at like the
-- game's flyouts do; above it, a banner: the spell, the member aimed (or
-- what to do), the help
function W:BuildParty(wheel)
    local pv = CK.NewFrame("Frame", nil, wheel)
    pv:SetPoint("CENTER")
    pv:SetSize(PARTY_BASE, PARTY_BASE)
    pv:Hide()
    self.pview = pv
    pv.base = pv:CreateTexture(nil, "BACKGROUND")
    pv.base:SetPoint("CENTER")
    pv.base:SetSize(PARTY_BASE, PARTY_BASE)
    if not atlas(pv.base, "gamepad-flyout-circular-base") then
        pv.base:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        pv.base:SetVertexColor(0, 0, 0, 0.6)
    end
    pv.base:SetSize(PARTY_BASE, PARTY_BASE)
    -- The aimed member: the game's selection wedge and arrow, turned to it
    pv.indicator = pv:CreateTexture(nil, "BACKGROUND", nil, 2)
    pv.indicator:SetPoint("CENTER")
    atlas(pv.indicator, "gamepad-flyout-selection-indicator")
    pv.indicator:SetWidth(36)
    pv.indicator:Hide()
    pv.arrow = pv:CreateTexture(nil, "OVERLAY")
    pv.arrow:SetSize(21, 35)
    atlas(pv.arrow, "gamepad-largecursor")
    pv.arrow:SetSize(21, 35)
    pv.arrow:Hide()
    -- The spell, where its button is
    pv.center = CK.Paddles:CreateSlot(pv, PARTY_CENTER)
    pv.center:SetPoint("CENTER")
    pv.members = {}
    for i, d in ipairs(PARTY_DIRS) do
        local seg = {}
        seg.slot = CK.Paddles:CreateSlot(pv, PARTY_SLOT)
        seg.slot:SetPoint("CENTER", pv, "CENTER", PARTY_RADIUS * d[1], PARTY_RADIUS * d[2])
        seg.slot:Hide()
        -- The name against the portrait, outward: beside it on the sides,
        -- above it at the top, under it at the bottom
        seg.label = pv:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        seg.label:SetWordWrap(false)
        if math.abs(d[1]) > 0.8 then
            local right = d[1] > 0
            seg.label:SetJustifyH(right and "LEFT" or "RIGHT")
            seg.label:SetPoint(right and "LEFT" or "RIGHT", seg.slot, right and "RIGHT" or "LEFT", right and 3 or -3, 0)
        else
            local up = d[2] > 0
            seg.label:SetJustifyH("CENTER")
            seg.label:SetPoint(up and "BOTTOM" or "TOP", seg.slot, up and "TOP" or "BOTTOM", 0, up and 1 or -1)
        end
        pv.members[i] = seg
    end
    -- Above it: the banner (the spell, the member aimed), the help
    pv.banner = pv:CreateTexture(nil, "BACKGROUND")
    pv.banner:SetPoint("BOTTOM", pv, "TOP", 0, 6)
    atlas(pv.banner, "gamepad-radial-menu-bottomtext", function(t) t:SetColorTexture(0, 0, 0, 0.5) end)
    pv.banner:SetSize(280, 56)
    pv.name = pv:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pv.name:SetPoint("TOP", pv.banner, "TOP", 0, -10)
    pv.name:SetWidth(250)
    pv.name:SetWordWrap(false)
    pv.count = pv:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pv.count:SetPoint("TOP", pv.name, "BOTTOM", 0, -4)
    pv.count:SetWidth(250)
    pv.count:SetWordWrap(false)
    pv.help = pv:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pv.help:SetPoint("BOTTOM", pv.banner, "TOP", 0, 2)
end

---------------------------------------------------------------------------
-- Filling it (out of combat only): the items by page, in the wheel's
-- attributes, and page 1 in the slots' buttons
---------------------------------------------------------------------------
-- The game names its sticks: "Movement" (left), "Camera" (right)
local function stickIndex(name, default)
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    if state and C_GamePad.StickIndexToConfigName then
        for i = 1, state.stickCount or 0 do
            if C_GamePad.StickIndexToConfigName(i - 1) == name then return i end
        end
    end
    return default
end

---------------------------------------------------------------------------
-- Staying seated while eating or drinking (Wheels > Consumables, on by
-- default), and still while bandaging (its own option): the sticks are kept
-- for the whole meal or bandage, so a stick still pushed from aiming the
-- wheel, or nudged, doesn't stand the character up and waste the food or
-- the bandage (reported). Pushed far for a quarter of a second, the
-- character gets up (half a second all the way was too long, reported).
-- The game gives a frame the sticks all together (taking them only while
-- the left stick moved was too late, the character moved at once: checked
-- in game): the addon turns the camera itself from the right stick
-- meanwhile, at the game's gamepad camera speeds (reported: no looking
-- around while eating). Never in combat.
---------------------------------------------------------------------------
local SEATED_PUSH, SEATED_TIME = 0.8, 0.25
local CAMERA_REST = 0.15
-- The auras of eating and drinking, by name: the game's own Food and
-- Drink, and the use of each food or drink a wheel used
local mealNames, mealBase = {}, false
local spellName = C_Spell and C_Spell.GetSpellName or GetSpellInfo

local function eating()
    if not mealBase then
        mealBase = true
        for _, id in ipairs({ 433, 430 }) do
            local name = spellName and spellName(id)
            if name then mealNames[name] = true end
        end
    end
    local find = AuraUtil and AuraUtil.FindAuraByName
    for name in pairs(mealNames) do
        if find then
            if find(name, "player", "HELPFUL") then return true end
        elseif C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
            if C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL") then return true end
        end
    end
    return false
end
W.Eating = eating

-- Bandaging: the First Aid channel, by name (the game's, and the use of each
-- bandage a wheel used)
local bandageNames, bandageBase = {}, false
local function bandaging()
    if not bandageBase then
        bandageBase = true
        local name = spellName and spellName(746)
        if name then bandageNames[name] = true end
    end
    local channel = UnitChannelInfo and UnitChannelInfo("player")
    return channel ~= nil and bandageNames[channel] == true
end
W.Bandaging = bandaging

-- Held now, as the options say
local function seatedNow()
    local s = settings()
    return (s.staySeated and eating()) or (s.stillBandaging and bandaging()) or false
end
W.SeatedNow = seatedNow

-- A food, drink or bandage used from a wheel: its use's name
function W:NoteMeal(slot)
    local entry = self:PageItems()[slot]
    if not (entry and entry.kind == "item" and entry.id) then return end
    local cat = entry.cat or W.Category(entry.id)
    local names = (cat == "food" or cat == "drink" or cat == "buffFood") and mealNames
        or (cat == "bandage" and bandageNames) or nil
    if not names then return end
    local name = C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(entry.id)
    if type(name) == "string" and name ~= "" then names[name] = true end
end

local function moveLength()
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[stickIndex("Movement", 1)]
    return stick and stick.len or 0
end

-- The right stick, read while the sticks are kept
local function cameraStick()
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[stickIndex("Camera", 2)]
    if not stick then return 0, 0 end
    return stick.x or 0, stick.y or 0
end

local function cameraSpeed(cvar)
    local value = tonumber(GetCVar and GetCVar(cvar))
    return (value and value > 0) and value or 1
end

-- One axis of the camera: the game's move started, its speed changed, or
-- stopped (the game's camera functions, allowed to addons: checked in game).
-- Both axes the other way round from the move functions' names, as the
-- game's own camera stick does (checked in game: both were inverted)
local AXES = {
    yaw = { neg = "MoveViewRightStart", pos = "MoveViewLeftStart", negStop = "MoveViewRightStop",
        posStop = "MoveViewLeftStop", cvar = "GamePadCameraYawSpeed" },
    pitch = { neg = "MoveViewUpStart", pos = "MoveViewDownStart", negStop = "MoveViewUpStop",
        posStop = "MoveViewDownStop", cvar = "GamePadCameraPitchSpeed" },
}

local function turn(frame, name, value)
    local axis = AXES[name]
    local dir = (value > CAMERA_REST and 1) or (value < -CAMERA_REST and -1) or 0
    local speed = dir ~= 0 and math.abs(value) * cameraSpeed(axis.cvar) or 0
    local was = frame.camera[name]
    if was.dir == dir and math.abs(was.speed - speed) < 0.05 then return end
    if was.dir ~= dir and was.dir ~= 0 then
        local stop = _G[was.dir < 0 and axis.negStop or axis.posStop]
        if stop then stop() end
    end
    if dir ~= 0 then
        local start = _G[dir < 0 and axis.neg or axis.pos]
        if start then start(speed) end
    end
    was.dir, was.speed = dir, speed
end

local function stopCamera(frame)
    for name, axis in pairs(AXES) do
        if frame.camera and frame.camera[name].dir ~= 0 then
            for _, fn in ipairs({ axis.negStop, axis.posStop }) do
                if _G[fn] then _G[fn]() end
            end
        end
    end
    frame.camera = { yaw = { dir = 0, speed = 0 }, pitch = { dir = 0, speed = 0 } }
end
W.SeatedCamera = function(frame)
    local x, y = cameraStick()
    turn(frame, "yaw", x)
    turn(frame, "pitch", y)
end

-- A menu or window that needs the sticks: the game's radial menu (Start),
-- a game window with the gamepad's focus (the map...), the addon's own
-- keyboard, wheels or panel. The sticks are left to it meanwhile (reported:
-- the radial menu couldn't be used while eating), taken back after.
local function sticksWanted()
    if GamepadRadial and GamepadRadial:IsShown() then return true end
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if manager and manager.GetActiveFrame and manager:GetActiveFrame() then return true end
    if CK.IsOpen and CK:IsOpen() then return true end
    if ControllerKeyboardWheel and ControllerKeyboardWheel:IsShown() then return true end
    return CK.Config and CK.Config.IsOpen and CK.Config:IsOpen() or false
end
W.SticksWanted = sticksWanted

function W:BuildSeated()
    if self.seated then return end
    local f = CK.NewFrame("Frame", nil, UIParent)
    f:SetAllPoints(UIParent)
    f:Hide()
    f.pushed = 0
    f:SetScript("OnGamePadStick", function() end)
    local function take(frame, on)
        if frame.taken == on then return end
        frame.taken = on
        W:TakeSticks(frame, on)
    end
    f:SetScript("OnShow", function(frame)
        frame.pushed, frame.taken = 0, false
        stopCamera(frame)
        take(frame, true)
    end)
    f:SetScript("OnHide", function(frame)
        stopCamera(frame)
        take(frame, false)
    end)
    f:SetScript("OnUpdate", function(frame, elapsed)
        if InCombatLockdown() or not seatedNow() then
            frame:Hide()
            return
        end
        -- A menu open: the sticks are its own, nothing counted
        if sticksWanted() then
            stopCamera(frame)
            take(frame, false)
            frame.pushed = 0
            return
        end
        take(frame, true)
        local len = moveLength()
        if len >= SEATED_PUSH then frame.pushed = frame.pushed + elapsed else frame.pushed = 0 end
        if frame.pushed >= SEATED_TIME then
            -- Pushed on purpose: up, and not held again for this meal
            frame.released = true
            frame:Hide()
        else
            -- Looking around meanwhile
            W.SeatedCamera(frame)
        end
    end)
    local events = CK.NewFrame("Frame")
    for _, event in ipairs({ "UNIT_AURA", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
        if events.RegisterUnitEvent then
            events:RegisterUnitEvent(event, "player")
        else
            events:RegisterEvent(event)
        end
    end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_DISABLED" then
            f:Hide()
            return
        end
        if unit and unit ~= "player" then return end
        if not seatedNow() then
            f.released = nil
            return
        end
        if not f.released and not f:IsShown() and not InCombatLockdown() then f:Show() end
    end)
    self.seated, self.seatedEvents = f, events
end

-- A wheel's pages ({ page = { [slot] = entry } }) into its attributes
local function store(wheel, wid, pages, unitOf)
    local total = 0
    for page = 1, PAGES do
        local list = pages[page] or {}
        wheel:SetAttribute("ck-" .. wid .. "-" .. page .. "-n", #list)
        for i = 1, SEGMENTS do
            local e = list[i]
            local key = "ck-" .. wid .. "-" .. page .. "-" .. i
            wheel:SetAttribute(key .. "-t", e and e.kind or nil)
            wheel:SetAttribute(key, e and (e.kind == "item" and ("item:" .. e.id)
                or e.kind == "spell" and CK.Mapping.SpellCast(e.id) or e.name) or nil)
            wheel:SetAttribute(key .. "-u", e and unitOf and unitOf(e) or nil)
            if e then total = total + 1 end
        end
    end
    local count = 0
    for page in pairs(pages) do count = math.max(count, page) end
    wheel:SetAttribute("ck-" .. wid .. "-pages", math.max(1, count))
    wheel:SetAttribute("ck-" .. wid .. "-total", total)
    return total
end

-- What the open wheel's page holds, into the slots' buttons (as the snippet)
function W:ApplyPage()
    local wheel = self.frame
    local wid = wheel:GetAttribute("wheel") or "c"
    local party = isParty(wid)
    local key = "ck-" .. wid .. "-" .. (wheel:GetAttribute("page") or 1) .. "-"
    local n = wheel:GetAttribute(key .. "n") or 0
    for i, b in ipairs(self.buttons) do
        local unit = wheel:GetAttribute(key .. i .. "-u")
        if party and PARTY_DIRS[i] then
            b:ClearAllPoints()
            b:SetPoint("CENTER", wheel, "CENTER", PARTY_RADIUS * PARTY_DIRS[i][1], PARTY_RADIUS * PARTY_DIRS[i][2])
        elseif i <= n then
            local x, y = slotDir(i, n)
            b:ClearAllPoints()
            b:SetPoint("CENTER", wheel, "CENTER", ICON_RADIUS * x, ICON_RADIUS * y)
        end
        local kind, value = wheel:GetAttribute(key .. i .. "-t"), wheel:GetAttribute(key .. i)
        b:SetAttribute("type", kind)
        b:SetAttribute("item", kind == "item" and value or nil)
        b:SetAttribute("spell", kind == "spell" and value or nil)
        b:SetAttribute("macro", kind == "macro" and value or nil)
        b:SetAttribute("unit", unit)
        b:SetShown(kind ~= nil and i <= n and (not party or UnitExists(unit) and true or false))
    end
end

-- A party spell's wheel: one page, you then the party's members
local function partyPages(id)
    local list = {}
    for i, unit in ipairs(PARTY_UNITS) do list[i] = { kind = "spell", id = id, unit = unit, party = true } end
    return { [1] = list }
end

function W:StoreParty(id)
    local pages = partyPages(id)
    store(self.frame, "p" .. id, pages, function(e) return e.unit end)
    self.lists = self.lists or {}
    self.lists["p" .. id] = pages
end

-- Where a key's button is on the screen, its centre in UIParent's units: the
-- game's bar button it takes the place of in that layer, or our extra button
-- (back paddles, L3 / R3); nil for a key with none shown
function W.ButtonCenter(comboId)
    local M = CK.Mapping
    local inputId, layer = (comboId or ""):match("^(%w+):(%a*)$")
    local input = inputId and M and M.BY_ID[inputId]
    if not input then return nil end
    local f
    if input.bar then
        local bar = M.LAYER_BAR[layer]
        f = bar and CK.Paddles:NativeButton("bar:" .. bar .. ":" .. input.bar)
    else
        local extra = CK.Paddles.frame and CK.Paddles.frame.buttons
        f = extra and extra[inputId]
    end
    if not (f and f.IsVisible and f:IsVisible() and f.GetCenter) then return nil end
    local x, y = f:GetCenter()
    if not (x and y) then return nil end
    local scale = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    return x * scale, y * scale
end

-- Each party spell's key: where its wheel opens (out of combat). On its
-- button, moved in just enough to stay whole on the screen (a button near
-- an edge: you at the bottom, your name under you)
local PARTY_MARGIN = PARTY_RADIUS + PARTY_SLOT / 2 + 16
function W:PlaceParty(t)
    if InCombatLockdown() then return end
    local x, y = W.ButtonCenter(t.ckCombo)
    if x and y then
        local w, h = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
        if w > 2 * PARTY_MARGIN then x = math.min(math.max(x, PARTY_MARGIN), w - PARTY_MARGIN) end
        if h > 2 * PARTY_MARGIN then y = math.min(math.max(y, PARTY_MARGIN), h - PARTY_MARGIN) end
    end
    t:SetAttribute("ck-ax", x and math.floor(x + 0.5) or nil)
    t:SetAttribute("ck-ay", y and math.floor(y + 0.5) or nil)
end

function W:PlacePartyKeys()
    for _, t in pairs(self.partyToggles or {}) do self:PlaceParty(t) end
end

-- The key of a party spell's wheel ("wheel:party:<spell ID>") on a button
-- ("UP:LT", its input and layer: where it opens): made the first time a key
-- gets it (the Gamepad tab's bindings, out of combat)
function W:PartyToggle(id, comboId)
    self:Build()
    comboId = comboId or ""
    local key = id .. "|" .. comboId
    local t = self.partyToggles[key]
    if not t then
        t = keyButton("ControllerKeyboardPartyWheel" .. id .. "_" .. comboId:gsub("[^%w]", ""), self.frame, TOGGLE, nil,
            "AnyDown", "AnyUp")
        t:SetAttribute("ck-wheel", "p" .. id)
        t:SetAttribute("type", "click")
        for i, b in ipairs(self.buttons) do t:SetAttribute("*clickbutton-s" .. i, b) end
        t.ckCombo, t.ckSpell = comboId, id
        self.partyToggles[key] = t
        self:StoreParty(id)
        self.frame:SetAttribute("ck-pstick", stickIndex("Camera", 2))
    end
    self:PlaceParty(t)
    return t
end

function W:Fill()
    if not CK.db then return end
    if InCombatLockdown() then
        self.pending = true
        return
    end
    self.pending = nil
    self:Build()
    local wheel = self.frame
    -- Hold its key to show it, let go to use what the stick aims at (option)
    wheel:SetAttribute("ck-hold", settings().hold and true or nil)
    self.lists = {}
    -- The consumables: by kind, 8 a page
    local items = settings().enabled and self:Scan() or {}
    local pages = {}
    for n, item in ipairs(items) do
        local page = math.floor((n - 1) / SEGMENTS) + 1
        pages[page] = pages[page] or {}
        pages[page][(n - 1) % SEGMENTS + 1] = { kind = "item", id = item.id, cat = item.cat }
    end
    -- Bandages on yourself
    store(wheel, "c", pages, function(e) return e.cat == "bandage" and "player" or nil end)
    self.lists.c = pages
    -- The player's own: one page, each slot where it was put
    for n = 1, W.MY_MAX do
        -- Its filled slots in their order, one after the other: the wheel has
        -- as many sections
        local entries, list = CK.MyWheels and CK.MyWheels:Entries(n) or {}, {}
        for slot = 1, SEGMENTS do
            if entries[slot] then list[#list + 1] = entries[slot] end
        end
        local own = { [1] = list }
        for _, e in pairs(own[1]) do
            if e.kind == "item" and not e.cat then
                local ok, cat = pcall(W.Category, e.id)
                e.cat = ok and cat or nil
            end
        end
        store(wheel, tostring(n), own, function(e) return e.cat == "bandage" and "player" or nil end)
        self.lists[tostring(n)] = own
    end
    -- The party spells' (their names follow the spell book's ranks), and
    -- where each key's button is
    for _, t in pairs(self.partyToggles) do self:StoreParty(t.ckSpell) end
    self:PlacePartyKeys()
    wheel:SetAttribute("ck-stick", stickIndex("Movement", 1))
    wheel:SetAttribute("ck-pstick", stickIndex("Camera", 2))
    -- The open wheel emptied: closed
    local open = wheel:GetAttribute("wheel") or "c"
    if wheel:IsShown() and (wheel:GetAttribute("ck-" .. open .. "-total") or 0) == 0 then
        wheel:Hide()
        ClearOverrideBindings(wheel)
    end
    if wheel:IsShown() then
        local pages = wheel:GetAttribute("ck-" .. open .. "-pages") or 1
        if (wheel:GetAttribute("page") or 1) > pages then wheel:SetAttribute("page", pages) end
    else
        wheel:SetAttribute("page", 1)
    end
    self:ApplyPage()
    self.items = items
    self:Paint()
end

function W:PageItems()
    local wheel = self.frame
    local pages = wheel and self.lists and self.lists[wheel:GetAttribute("wheel") or "c"]
    return pages and pages[wheel:GetAttribute("page") or 1] or {}
end

---------------------------------------------------------------------------
-- An entry: { kind = "item", id, cat } (consumables), or in the player's
-- wheels { kind = "item" | "spell", id } / { kind = "macro", name }
---------------------------------------------------------------------------
function W.EntryName(e)
    if e.kind == "item" then return C_Item.GetItemNameByID(e.id) or ("item:" .. e.id) end
    if e.kind == "spell" then return CK.Mapping.SpellName(e.id) or ("spell:" .. e.id) end
    return e.name
end

function W.EntryIcon(e)
    if e.kind == "item" then return C_Item.GetItemIconByID(e.id) end
    if e.kind == "spell" then
        return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e.id)
            or (GetSpellTexture and GetSpellTexture(e.id))
    end
    local _, icon = GetMacroInfo(e.name)
    return icon
end

local function entryCooldown(e)
    if e.kind == "item" then return C_Container.GetItemCooldown(e.id) end
    if e.kind == "spell" then
        local get = C_Spell and C_Spell.GetSpellCooldown or GetSpellCooldown
        local start, duration = get(e.id)
        if type(start) == "table" then return start.startTime, start.duration end
        return start, duration
    end
end

-- Greyed: an item not in the bags (or food in combat), a spell the game
-- says can't be cast now
local function entryUnusable(e, combat)
    if e.kind == "item" then
        local count = C_Item.GetItemCount and C_Item.GetItemCount(e.id) or 0
        return count == 0 or (combat and OUT_OF_COMBAT[e.cat] or false)
    end
    if e.kind == "spell" then
        local usable = C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
        return usable and not usable(e.id) or false
    end
    return false
end

---------------------------------------------------------------------------
-- Drawing: the page's items (icons, names, counts, cooldowns, the veil on
-- what can't be used now), the pages' dots, the highlight on the aimed
-- segment (a stick, or the D-pad's choice), the aimed item's name
---------------------------------------------------------------------------
function W:Paint()
    if not (self.frame and self.lists) then return end
    local combat = InCombatLockdown()
    local page = self.frame:GetAttribute("page") or 1
    self.painted, self.paintedWheel = page, self.frame:GetAttribute("wheel") or "c"
    -- A party spell's wheel: drawn by its own frame
    if isParty(self.paintedWheel) then return self:PaintParty() end
    if self.pview then self.pview:Hide() end
    self.view:SetAlpha(1)
    local list = self:PageItems()
    local n = math.max(1, math.min(SEGMENTS, #list))
    self.view.bg:SetTexture(TEX .. format("ck_wheel_bg_%d", n))
    self.paintedCount = n
    for i, seg in ipairs(self.segments) do
        local item = list[i]
        seg.slot:SetShown(item ~= nil)
        seg.label:SetShown(item ~= nil)
        if item then
            W:PlaceSection(seg, i, n)
            CK.Paddles.SetIcon(seg.slot.icon, W.EntryIcon(item))
            seg.slot.count:SetText(item.kind == "item" and (C_Item.GetItemCount and C_Item.GetItemCount(item.id) or 0) or "")
            seg.label:SetText(W.EntryName(item) or "")
            local unusable = entryUnusable(item, combat)
            seg.slot.icon:SetDesaturated(unusable)
            seg.disabled:SetShown(unusable)
            -- Its name in the game's colours: gold, grey when it can't be used
            local color = unusable and DISABLED_FONT_COLOR or NORMAL_FONT_COLOR
            if color then seg.label:SetTextColor(color:GetRGB()) end
            pcall(function()
                local start, duration = entryCooldown(item)
                if start and duration and duration > 0 then
                    seg.slot.cooldown:SetCooldown(start, duration)
                else
                    seg.slot.cooldown:Clear()
                end
            end)
        else
            seg.disabled:Hide()
        end
    end
    -- LB  o * o  RB, with more than one page
    local pages = self.frame:GetAttribute("ck-" .. self.paintedWheel .. "-pages") or 1
    local g = function(key) return CK:GlyphMarkup(key, 14) end
    if pages > 1 then
        local dots = {}
        for p = 1, pages do
            dots[#dots + 1] = format("|A:gamepad-radialgamemenu-cursorbg-%s:11:11|a", p == page and "neutral" or "inactive")
        end
        self.view.pages:SetText(g("LB") .. " " .. table.concat(dots, " ") .. " " .. g("RB"))
    else
        self.view.pages:SetText("")
    end
    local h = function(key) return CK:GlyphMarkup(key, 14) end
    self.view.help:SetText(format("%s %s   %s %s   %s %s", h("LS"), L.WHEEL_AIM, h("A"), L.WHEEL_USE, h("B"), L.WHEEL_CLOSE))
    -- Not "nothing aimed" (nil): the banner is written, even the first time
    self.aimed = false
    self:Track()
end

-- An overlay (highlight, veil) on section `i` of `n`: cut to section 1, so
-- turned about its own centre, then put where that centre goes
function W:PlaceOverlay(texture, kind, i, n)
    local o = OVERLAY[n]
    local a = slotAngle(i, n)
    local x, y = o[3] * math.cos(a) + o[4] * math.sin(a), -o[3] * math.sin(a) + o[4] * math.cos(a)
    texture:SetTexture(TEX .. format("ck_wheel_%s_%d", kind, n))
    texture:SetSize(o[1], o[2])
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", self.view.bg, "CENTER", x, y)
    texture:SetRotation(-a)
end

-- A section's icon and name, for a page of `n`
function W:PlaceSection(seg, i, n)
    local dx, dy = slotDir(i, n)
    seg.slot:ClearAllPoints()
    seg.slot:SetPoint("CENTER", self.view.bg, "CENTER", ICON_RADIUS * dx, ICON_RADIUS * dy)
    -- The name beside the icon, on the outer side, as the game's menu puts
    -- it: beside it on the sides, above / below at the top and bottom, 30
    -- across and 45 up / down on the diagonals
    local ox, oy
    if math.abs(dx) > 0.8 then
        ox, oy = (dx > 0 and 1 or -1) * (LABEL_GAP + 4), 0
    elseif math.abs(dx) < 0.3 then
        ox, oy = 0, (dy > 0 and 1 or -1) * LABEL_GAP
    else
        ox, oy = (dx > 0 and 30 or -30), (dy > 0 and 45 or -45)
    end
    seg.label:ClearAllPoints()
    seg.label:SetPoint("CENTER", seg.slot, "CENTER", ox, oy)
    self:PlaceOverlay(seg.disabled, "off", i, n)
end

function W:Aimed()
    local wheel = self.frame
    local list = self:PageItems()
    local n = math.min(SEGMENTS, #list)
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[wheel:GetAttribute("ck-stick") or 1]
    if n > 0 and stick and stick.len and stick.len > AIM then
        local best, bestDot = nil, -2
        for i = 1, n do
            local x, y = slotDir(i, n)
            local dot = stick.x * x + stick.y * y
            if dot > bestDot then best, bestDot = i, dot end
        end
        return best and list[best] and best or nil
    end
end

function W:Track()
    if not self.frame then return end
    if not self.frame:IsShown() then self.ticked = nil end
    -- A page turned (LB / RB, secure), another wheel's key: draw it
    if (self.frame:GetAttribute("page") or 1) ~= self.painted
        or (self.frame:GetAttribute("wheel") or "c") ~= self.paintedWheel then
        self.ticked = nil
        return self:Paint()
    end
    if isParty(self.paintedWheel) then return self:TrackParty() end
    local i = self:Aimed()
    if i == self.aimed then return end
    self.aimed = i
    local item = i and self:PageItems()[i]
    local view = self.view
    view.highlight:SetShown(item ~= nil)
    local mine = tonumber(self.paintedWheel)
    if not item then
        self.ticked = nil
        -- A wheel of the player's: its name
        view.name:SetText(mine and CK.MyWheels and CK.MyWheels:Name(mine) or L.WHEEL_NOTHING)
        view.count:SetText(mine and L.MYWHEEL_NOTHING_HINT or L.WHEEL_NOTHING_HINT)
        return
    end
    self:PlaceOverlay(view.highlight, "sel", i, self.paintedCount or SEGMENTS)
    view.name:SetText(W.EntryName(item) or "")
    if item.kind == "item" then
        local count = C_Item.GetItemCount and C_Item.GetItemCount(item.id) or 0
        view.count:SetText(format("%s  -  %d", item.cat and L["WHEEL_CAT_" .. item.cat:upper()] or L.WHEEL_KIND_ITEM, count))
    else
        view.count:SetText(item.kind == "spell" and L.WHEEL_KIND_SPELL or L.WHEEL_KIND_MACRO)
    end
    if CK.Vibration and self.frame:IsShown() and i ~= self.ticked then
        self.ticked = i
        CK.Vibration:Fire("wheelTick")
    end
end

---------------------------------------------------------------------------
-- A party spell's wheel's drawing (its own frame, `pview`)
---------------------------------------------------------------------------
-- A member's place: their portrait and name in their class's colour
-- (greyed when dead or offline: a resurrection is cast on them too); a
-- member who isn't there: nothing at all
local function paintMember(seg, item)
    local unit = item and item.unit
    local here = unit and UnitExists(unit) and true or false
    seg.slot:SetShown(here)
    seg.label:SetShown(here)
    if not here then return end
    SetPortraitTexture(seg.slot.icon, unit)
    seg.slot.icon:SetTexCoord(0, 1, 0, 1)
    seg.slot.icon:Show()
    local away = (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) or (UnitIsConnected and not UnitIsConnected(unit))
    seg.slot.icon:SetDesaturated(away and true or false)
    -- The name as the game gives it (never read by our code: it could be one
    -- the game hides from addons in combat)
    seg.label:SetText(UnitName(unit))
    local _, class = UnitClass(unit)
    local color = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or NORMAL_FONT_COLOR
    if away then color = DISABLED_FONT_COLOR or color end
    if color then seg.label:SetTextColor(color.r, color.g, color.b) end
end

function W:PaintParty()
    local pv = self.pview
    if not pv then return end
    self.view:SetAlpha(0)
    pv:Show()
    -- Drawn on events too while closed: only open does it move or take the
    -- stick's keys. Out of combat, right on its button (it may have moved
    -- since it was set)
    local open = self.frame:IsShown()
    local opener = self.frame:GetAttribute("ck-opener")
    local t = opener and _G[opener]
    if open and t and not InCombatLockdown() then
        self:PlaceParty(t)
        local x, y = t:GetAttribute("ck-ax"), t:GetAttribute("ck-ay")
        if x and y then
            self.frame:ClearAllPoints()
            self.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end
    end
    -- Its stick let go casts: the stick's direction keys on
    if open then self:StickKeys(true) end
    local list = self:PageItems()
    local spell = list[1]
    CK.Paddles.SetIcon(pv.center.icon, spell and W.EntryIcon(spell))
    pcall(function()
        local start, duration = entryCooldown(spell)
        if start and duration and duration > 0 then
            pv.center.cooldown:SetCooldown(start, duration)
        else
            pv.center.cooldown:Clear()
        end
    end)
    for i, seg in ipairs(pv.members) do
        local ok = pcall(paintMember, seg, list[i])
        if not ok then seg.slot:Hide() seg.label:Hide() end
    end
    local h = function(key) return CK:GlyphMarkup(key, 14) end
    pv.help:SetText(format("%s %s   %s %s   %s %s", h("RS"), L.WHEEL_AIM, h("A"), L.PARTY_CAST, h("B"), L.WHEEL_CLOSE))
    -- Not "nothing aimed" (nil): the banner is written, even the first time
    self.aimed = false
    self:TrackParty()
end

-- The member the right stick points at (past half its course): the nearest
-- one there, as the secure code picks
function W:AimedParty()
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[aimStick(self.frame)]
    if not (stick and stick.len and stick.len > AIM) then return nil end
    local list = self:PageItems()
    local best, bestDot
    for i, d in ipairs(PARTY_DIRS) do
        local item = list[i]
        if item and UnitExists(item.unit) then
            local dot = stick.x * d[1] + stick.y * d[2]
            if not bestDot or dot > bestDot then best, bestDot = i, dot end
        end
    end
    return best
end

function W:TrackParty()
    local pv = self.pview
    local i = self:AimedParty()
    if i == self.aimed then return end
    self.aimed = i
    local list = self:PageItems()
    local item = i and list[i]
    for j, seg in ipairs(pv.members) do seg.slot.pressed:SetShown(j == i) end
    pv.indicator:SetShown(item ~= nil)
    pv.arrow:SetShown(item ~= nil)
    pv.name:SetText(list[1] and W.EntryName(list[1]) or "")
    if not item then
        self.ticked = nil
        pv.count:SetText(L.PARTY_HINT)
        return
    end
    -- Turned to the member, as the game's flyouts turn theirs (angles
    -- clockwise from the top)
    local a = math.pi + (i - 1) * 2 * math.pi / #PARTY_DIRS
    pv.indicator:SetRotation(math.pi - a)
    pv.arrow:SetRotation(math.pi / 2 - a)
    pv.arrow:ClearAllPoints()
    pv.arrow:SetPoint("CENTER", pv, "CENTER", 38 * PARTY_DIRS[i][1], 38 * PARTY_DIRS[i][2])
    pv.count:SetText(UnitName(item.unit))
    if CK.Vibration and self.frame:IsShown() and i ~= self.ticked then
        self.ticked = i
        CK.Vibration:Fire("wheelTick")
    end
end

---------------------------------------------------------------------------
-- Its place: the middle of the screen, or where it was put (the mouse while
-- unlocked, or the D-pad from the Wheel tab; out of combat)
---------------------------------------------------------------------------
function W:Place()
    local pos = settings().pos
    local wheel = self.frame
    wheel:ClearAllPoints()
    if type(pos) == "table" and pos.point then
        wheel:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        wheel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    self:NoteHome()
end

-- Where the wheels go, for the secure code: a party spell's wheel opened on
-- its button, the next other wheel goes back there
function W:NoteHome()
    local wheel = self.frame
    local point, _, _, x, y = wheel:GetPoint(1)
    wheel:SetAttribute("ck-home-p", point or "CENTER")
    wheel:SetAttribute("ck-home-x", x or 0)
    wheel:SetAttribute("ck-home-y", y or 0)
end

-- Back where the wheels go, its size back (out of combat)
function W:Unmove()
    local wheel = self.frame
    if not (wheel and wheel:GetAttribute("ck-moved")) or InCombatLockdown() then return end
    wheel:SetSize(WHEEL_SIZE, 600)
    wheel:SetAttribute("ck-moved", nil)
    self:Place()
end

function W:SavePosition()
    local point, _, _, x, y = self.frame:GetPoint(1)
    settings().pos = { point = point, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
    self:NoteHome()
end

function W:ResetPosition()
    settings().pos = nil
    if self.frame and not InCombatLockdown() then self:Place() end
end

local MOVES = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }

function W:StartPlacement()
    if InCombatLockdown() then return end
    self:Build()
    self:Unmove()
    self.moving = true
    -- Where it was: B puts it back
    self.placeFrom = settings().pos
    if not self.banner then
        local banner = CK.NewFrame("Frame", nil, UIParent)
        banner:SetSize(560, 58)
        banner:SetPoint("TOP", 0, -90)
        banner:SetFrameStrata("FULLSCREEN_DIALOG")
        CK.Config.panel(banner)
        banner.title = CK.UIKit.text(banner, 14)
        banner.title:SetPoint("TOP", 0, -10)
        banner.title:SetTextColor(unpack(CK.UIKit.C.gold))
        banner.title:SetText(L.WHEEL_MOVE)
        banner.help = CK.UIKit.text(banner, 11)
        banner.help:SetPoint("BOTTOM", 0, 10)
        banner.help:SetTextColor(unpack(CK.UIKit.C.btn))
        self.banner = banner
    end
    local g = function(key) return CK:GlyphMarkup(key, 16) end
    self.banner.help:SetText(table.concat({
        g("DPAD_UP") .. " " .. L.MAP_P_MOVE, g("X") .. " " .. L.PLACE_P_RESET, g("A") .. " " .. L.PLACE_P_DONE,
        g("B") .. " " .. L.PLACE_P_CANCEL,
    }, "    "))
    self.banner:Show()
    self.frame:Show()
end

function W:StopPlacement()
    if not self.moving then return end
    self.moving = false
    if self.banner then self.banner:Hide() end
    if not InCombatLockdown() then
        self.frame:Hide()
        ClearOverrideBindings(self.frame)
    end
end

function W:PlacementPress(name)
    if InCombatLockdown() then return end
    if MOVES[name] then
        local point, _, _, x, y = self.frame:GetPoint(1)
        self.frame:ClearAllPoints()
        self.frame:SetPoint(point, UIParent, point, x + MOVES[name][1] * 10, y + MOVES[name][2] * 10)
        self:SavePosition()
    elseif name == "X" then
        self:ResetPosition()
    elseif name == "A" or name == "B" then
        if name == "B" then
            settings().pos = self.placeFrom
            self:Place()
        end
        self:StopPlacement()
        CK.Config:EndPlacement()
        if name == "A" then CK.Config:Toast(L.TOAST_POS_SAVED) end
    end
end

---------------------------------------------------------------------------
-- Game settings earlier versions changed, given back as they were: the
-- stick direction keys (GamePadStickAxisButtons: kept on, they broke the
-- game's own stick wheels) and the camera speeds
---------------------------------------------------------------------------
local function setCVar(name, value)
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    return pcall(set, name, value)
end

-- A party spell's wheel open now
function W:PartyOpen()
    local wheel = self.frame
    return wheel and wheel:IsShown() and isParty(wheel:GetAttribute("wheel")) or false
end

-- The game's stick direction keys (GamePadStickAxisButtons), for a party
-- spell's wheel (letting the stick go casts): on while one is open, and for
-- a whole fight when a party spell is on a button (the game refuses the
-- setting in combat: turned on as the fight starts); the player's own
-- value given back after. Kept on, they close the game's own flyouts as
-- soon as their stick moves: the shield below keeps them away meanwhile.
function W:StickKeys(on)
    if InCombatLockdown() then return end
    local s = settings()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local ok, current = pcall(get, "GamePadStickAxisButtons")
    if not ok or current == nil then return end
    if on then
        if tostring(current) ~= "1" then
            if s.stickButtonsWas == nil then s.stickButtonsWas = tostring(current) end
            setCVar("GamePadStickAxisButtons", "1")
        end
    elseif s.stickButtonsWas ~= nil then
        setCVar("GamePadStickAxisButtons", s.stickButtonsWas)
        s.stickButtonsWas = nil
    end
    self:UpdateShield()
end

-- The game's flyouts (spells such as the hunter's aspects, the pet's): they
-- close on any button, the stick's direction keys too. While those keys are
-- on by us and one of them is open, a frame of ours, above them, keeps the
-- direction keys from them (and lets every other button through)
local FLYOUTS = { "GamepadSpellFlyout", "GamepadPetActionFlyout", "GamepadPetSpellFlyout" }

function W:FlyoutOpen()
    for _, name in ipairs(FLYOUTS) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() then return true end
    end
    return false
end

function W:UpdateShield()
    local shield = self.shield
    if not shield then
        shield = CK.NewFrame("Frame", nil, UIParent)
        shield:SetFrameStrata("FULLSCREEN_DIALOG")
        shield:SetSize(1, 1)
        shield:SetPoint("CENTER")
        shield:Hide()
        shield:SetScript("OnGamePadButtonDown", function(_, key) return not STICK_DIR_KEYS[key] end)
        shield:SetScript("OnShow", function(f) if f.EnableGamePadButton then pcall(f.EnableGamePadButton, f, true) end end)
        shield:SetScript("OnHide", function(f) if f.EnableGamePadButton then pcall(f.EnableGamePadButton, f, false) end end)
        self.shield = shield
    end
    for _, name in ipairs(FLYOUTS) do
        local f = _G[name]
        if f and f.HookScript and not (self.hookedFlyouts or {})[name] then
            self.hookedFlyouts = self.hookedFlyouts or {}
            self.hookedFlyouts[name] = true
            f:HookScript("OnShow", function() W:UpdateShield() end)
            f:HookScript("OnHide", function() W:UpdateShield() end)
        end
    end
    shield:SetShown(settings().stickButtonsWas ~= nil and self:FlyoutOpen())
end

function W:RestoreSettings()
    if InCombatLockdown() then return end
    local s = settings()
    -- (kept while a party spell's wheel is open: given back when it closes)
    if s.stickButtonsWas ~= nil and not self:PartyOpen() then
        setCVar("GamePadStickAxisButtons", s.stickButtonsWas)
        s.stickButtonsWas = nil
    end
    if s.camera then
        for cvar, value in pairs(s.camera) do setCVar(cvar, value) end
        s.camera = nil
    end
    self:UpdateShield()
end

-- The action the Gamepad tab puts on an input ("wheel:consumables",
-- "wheel:3", "wheel:party:2061"): its key opens that wheel. `comboId`: that
-- input and layer ("UP:LT")
function W:Toggle(which, comboId)
    -- The quick phrases window, given like a wheel (Phrases.lua)
    if which == "phrases" and CK.Phrases then return CK.Phrases:ToggleButton() end
    -- A party spell ("party:<spell ID>"): its small wheel, on that button
    local spell = type(which) == "string" and tonumber(which:match("^party:(%d+)$"))
    if spell then return self:PartyToggle(spell, comboId) end
    self:Build()
    local n = tonumber(which)
    return n and self.myToggles[n] or self.toggle
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function W:Init()
    self:RestoreSettings()
    self:BuildSeated()
    -- In combat (a /reload there) the game would block their setup: made
    -- when it ends (Fill waits for it)
    if not InCombatLockdown() then self:Build() end
    local f = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP",
        "PLAYER_REGEN_DISABLED", "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED", "SPELLS_CHANGED", "UPDATE_MACROS",
        "SPELL_UPDATE_COOLDOWN", "GROUP_ROSTER_UPDATE" }) do
        pcall(f.RegisterEvent, f, event)
    end
    local queued
    f:SetScript("OnEvent", function(_, event)
        -- The party changed while a party spell's wheel is open: its members
        -- drawn again (their buttons too, out of combat)
        if event == "GROUP_ROSTER_UPDATE" then
            local wheel = W.frame
            if wheel and wheel:IsShown() and isParty(wheel:GetAttribute("wheel")) then
                if not InCombatLockdown() then W:ApplyPage() end
                W:Paint()
            end
            return
        end
        -- Combat starts: each party spell's key opens on its button as it is
        -- now; with a party spell on a button, the stick's direction keys on
        -- for the fight (the game refuses the setting in combat)
        if event == "PLAYER_REGEN_DISABLED" then
            W:PlacePartyKeys()
            if CK.Mapping and CK.Mapping.HasPartySpells and CK.Mapping:HasPartySpells() then W:StickKeys(true) end
        end
        if event == "PLAYER_REGEN_DISABLED" or event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
            W:Paint()
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then W:RestoreSettings() end
        if event == "PLAYER_REGEN_ENABLED" and not W.pending then
            W:Paint()
            return
        end
        if queued then return end
        queued = true
        C_Timer.After(0.2, function()
            queued = false
            if InCombatLockdown() then
                W.pending = true
                W:Paint()
            else
                W:Fill()
            end
        end)
    end)
    self:Fill()
end
