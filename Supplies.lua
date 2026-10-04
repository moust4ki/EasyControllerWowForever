local _, CK = ...
local L = CK.L

-- Module "supplies": one round button per resource, in the style of the
-- gamepad bar: free bag slots, the equipped ammunition, the class reagents
-- (soul shards, powders, candles, poisons...) and any item the player adds.
-- Each shows its count; under its "low" threshold it glows, stronger and
-- faster down to its "critical" one, where the glow is red. One bar of
-- buttons, placed freely (mouse drag while unlocked, or the D-pad), growing
-- in one of 4 directions, and a click opens the bags. Nothing of the game's
-- is changed.
local S = {}
CK.Supplies = S

-- Class reagents (item IDs), tracked once seen in the bags
S.REAGENTS = {
    WARLOCK = { 6265, 5565, 16583 },
    MAGE = { 17020, 17031, 17032, 17056 },
    PRIEST = { 17028, 17029, 17056 },
    PALADIN = { 17033, 21177 },
    DRUID = { 17034, 17035, 17036, 17037, 17038, 22147, 17026, 17021, 22148 },
    SHAMAN = { 17030, 17057, 17058 },
    ROGUE = { 5140, 5530, 6947, 6949, 6950, 8926, 8927, 8928, 2892, 2893, 8984, 8985, 20844,
        3775, 3776, 5237, 6951, 9186, 10918, 10920, 10921, 10922 },
}
-- Thresholds { low, critical } and the D-pad's step, by kind
local DEFAULTS = {
    bags = { 4, 1, 1 },
    ammo = { 200, 50, 25 },
    shard = { 3, 1, 1 },
    item = { 5, 1, 1 },
}
local SOUL_SHARD = 6265
local BAG_ICON = "Interface\\Icons\\INV_Misc_Bag_08"
local AMMO_SLOT = INVSLOT_AMMO or 0
local SIZES = { 32, 40, 48 }
local ORANGE, RED = { 1, 0.55, 0.1 }, { 1, 0.12, 0.08 }

local function settings() return CK.db.settings.supplies end

---------------------------------------------------------------------------
-- Resources: { key, kind, id, name, icon, count }
---------------------------------------------------------------------------
local function itemCount(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
    return GetItemCount and GetItemCount(id) or 0
end

local function itemName(id)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name or ("item:" .. id)
end

local function itemIcon(id)
    return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
end

local function freeBagSlots()
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n, family = C_Container.GetContainerNumFreeSlots(bag)
        -- Quivers, ammo pouches, soul bags... hold one kind of item only
        if n and (family == nil or family == 0) then free = free + n end
    end
    return free
end

local function ammoID()
    if not GetInventoryItemID then return end
    local ok, id = pcall(GetInventoryItemID, "player", AMMO_SLOT)
    if ok and type(id) == "number" and id > 0 then return id end
end

local function knownIcon(icon)
    if type(icon) == "number" then return icon > 0 and icon ~= 134400 end
    return type(icon) == "string" and icon ~= "" and not icon:lower():find("inv_misc_questionmark", 1, true)
end

-- The two built-in HUD counters are opt-in, including older saved settings.
-- Their existing resource records still retain thresholds; other resources
-- continue to use their individual tracking switches.
function S:ResourceEnabled(resource)
    if resource.kind == "bags" then return settings().showBags == true end
    if resource.kind == "ammo" then return settings().showAmmo == true end
    return resource.cfg.on
end

-- The list the bar and the Supplies tab show, in order
function S:Resources()
    local s = settings()
    local list = {}
    local function add(key, kind, id, name, icon, count)
        local cfg = s.list[key]
        if not cfg then
            local d = DEFAULTS[kind] or DEFAULTS.item
            cfg = { on = true, low = d[1], critical = d[2] }
            s.list[key] = cfg
        end
        list[#list + 1] = { key = key, kind = kind, id = id, name = name, icon = icon, count = count, cfg = cfg }
    end
    add("bags", "bags", nil, L.SUP_BAGS, BAG_ICON, freeBagSlots())
    local _, class = UnitClass("player")
    local ammo = ammoID()
    if ammo or class == "HUNTER" then
        local icon
        if ammo then icon = GetInventoryItemTexture("player", AMMO_SLOT) or itemIcon(ammo)
        else icon = "Interface\\Icons\\INV_Ammo_Arrow_01" end
        add("ammo", "ammo", ammo, ammo and itemName(ammo) or L.SUP_AMMO, icon,
            ammo and (GetInventoryItemCount("player", AMMO_SLOT) or 0) or 0)
    end
    local seen = {}
    for _, id in ipairs(S.REAGENTS[class] or {}) do
        local key = "item:" .. id
        local count = itemCount(id)
        -- A reagent the player carries is followed from then on
        if (count > 0 or s.list[key]) and not seen[id] then
            seen[id] = true
            add(key, id == SOUL_SHARD and "shard" or "item", id, itemName(id), itemIcon(id), count)
        end
    end
    for _, id in ipairs(s.custom) do
        if not seen[id] then
            seen[id] = true
            add("item:" .. id, "item", id, itemName(id), itemIcon(id), itemCount(id))
            list[#list].custom = true
        end
    end
    return list
end

-- 0 above "low", 1 at "critical" or below, in between linearly
function S.Severity(count, cfg)
    if count <= cfg.critical then return 1 end
    if count >= cfg.low then return 0 end
    return (cfg.low - count) / math.max(1, cfg.low - cfg.critical)
end

function S.Step(kind)
    return (DEFAULTS[kind] or DEFAULTS.item)[3]
end

-- Thresholds from the Supplies tab: critical never above low
function S:SetThreshold(cfg, which, value)
    value = math.max(0, value)
    cfg[which] = value
    if which == "low" and cfg.critical > value then cfg.critical = value end
    if which == "critical" and cfg.low < value then cfg.low = value end
    self:Refresh()
end

---------------------------------------------------------------------------
-- The bar
---------------------------------------------------------------------------
local glows = setmetatable({}, { __mode = "k" })   -- button -> its glow
S.glows = glows

local function glowFor(b)
    if glows[b] then return glows[b] end
    local glow = b:CreateTexture(nil, "BACKGROUND", nil, -3)
    glow:SetPoint("CENTER")
    glow:SetTexture(CK.UIKit.TEX .. "ck_slot_glow")
    glow:SetBlendMode("ADD")
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    glow.pulse, glow.alpha = pulse, alpha
    glows[b] = glow
    return glow
end

-- The glow grows with the severity: bigger, brighter, faster, orange to red
local function setGlow(b, severity)
    if severity <= 0 then
        if glows[b] then
            glows[b].pulse:Stop()
            glows[b]:Hide()
        end
        return
    end
    local glow = glowFor(b)
    -- Just around the slot's rim (the texture's ring is at its edge)
    local size = b.size * (1.1 + 0.15 * severity)
    glow:SetSize(size, size)
    glow:SetVertexColor(ORANGE[1] + (RED[1] - ORANGE[1]) * severity, ORANGE[2] + (RED[2] - ORANGE[2]) * severity,
        ORANGE[3] + (RED[3] - ORANGE[3]) * severity)
    local level = math.floor(severity * 4 + 0.5)
    if glow.level ~= level then
        glow.level = level
        glow.pulse:Stop()
        glow.alpha:SetFromAlpha(0.15 + 0.25 * severity)
        glow.alpha:SetToAlpha(0.5 + 0.5 * severity)
        glow.alpha:SetDuration(1.1 - 0.6 * severity)
    end
    glow:Show()
    if not glow.pulse:IsPlaying() then glow.pulse:Play() end
end

local function tooltip(owner, b)
    local r = b.resource
    if not r or S.moving then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(r.name, 1, 1, 1)
    GameTooltip:AddLine(format(L.SUP_TIP_COUNT, r.count), 1, 0.82, 0)
    GameTooltip:AddLine(format(L.SUP_TIP_THRESHOLDS, r.cfg.low, r.cfg.critical), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L.SUP_TIP_CLICK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function S:BuildBar()
    if self.bar then return end
    local bar = CK.NewFrame("Frame", "ControllerKeyboardSupplies", UIParent)
    bar:SetSize(1, 1)
    bar:SetFrameStrata("MEDIUM")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar.buttons = {}
    -- The gold frame shown while it is moved with the D-pad
    bar.ring = CK.NewFrame("Frame", nil, bar)
    bar.ring:SetPoint("TOPLEFT", -8, 8)
    bar.ring:SetPoint("BOTTOMRIGHT", 8, -8)
    CK.UIKit.nineSlice(bar.ring, "ck_select", 128, 32, 10, 10, "OVERLAY")
    bar.ring:Hide()
    self.bar = bar
    self:Place()
end

-- A slot, and over it a secure button: a click presses the game's own
-- backpack button, like a click of the player's (opening the bags from an
-- addon's code is forbidden in gamepad mode). Created out of combat only.
local BACKPACK = "MainMenuBarBackpackButton"

function S:Button(i)
    local bar = self.bar
    local b = bar.buttons[i]
    if b then return b end
    b = CK.Paddles:CreateSlot(bar, SIZES[2])
    b.count:ClearAllPoints()
    b.count:SetPoint("BOTTOM", 0, 1)
    local click = CK.NewFrame("Button", "ControllerKeyboardSupplyButton" .. i, bar, "SecureActionButtonTemplate")
    click:SetSize(b.size, b.size)
    click:SetFrameLevel(b:GetFrameLevel() + 10)
    click:RegisterForClicks("LeftButtonUp")
    -- Acts on the release, the click it gets (the game's default for its
    -- action buttons is the press, which never comes here)
    click:SetAttribute("useOnKeyDown", false)
    click:RegisterForDrag("LeftButton")
    if _G[BACKPACK] then
        click:SetAttribute("type", "click")
        click:SetAttribute("clickbutton", _G[BACKPACK])
    end
    click:SetScript("OnEnter", function(self) tooltip(self, b) end)
    click:SetScript("OnLeave", function() GameTooltip:Hide() end)
    click:SetScript("OnDragStart", function()
        if not settings().locked and not InCombatLockdown() then bar:StartMoving() end
    end)
    click:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        S:SavePosition()
    end)
    b.click = click
    bar.buttons[i] = b
    return b
end

-- Size of a slot and of the button that takes its clicks
local function resize(b, size)
    b.click:SetSize(size, size)
    if b.size == size then return end
    b.size = size
    b:SetSize(size, size)
    b.visual:SetSize(size, size)
end

-- The 4 ways the bar grows from its first button
S.DIRECTIONS = {
    { key = "right", x = 1, y = 0, anchor = "LEFT" },
    { key = "left", x = -1, y = 0, anchor = "RIGHT" },
    { key = "down", x = 0, y = -1, anchor = "TOP" },
    { key = "up", x = 0, y = 1, anchor = "BOTTOM" },
}
local DIRECTION = {}
for _, d in ipairs(S.DIRECTIONS) do DIRECTION[d.key] = d end
-- Before 1.2: "row" and "column"
local OLD_LAYOUT = { row = "right", column = "down" }

function S:Place()
    local bar = self.bar
    local pos = settings().pos
    bar:ClearAllPoints()
    if type(pos) == "table" and pos.point then
        bar:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 330)
    end
end

-- The bar held by the edge it grows from (UIParent's same point), where its
-- first button is now: that button stays put whatever the count, the size or
-- the direction
function S:HoldEdge(point)
    local bar = self.bar
    local ref = bar.buttons and bar.buttons[1]
    if not (ref and ref:IsShown() and ref:GetLeft()) then return end
    local l, b, w, h = ref:GetLeft(), ref:GetBottom(), ref:GetWidth(), ref:GetHeight()
    local fx = point == "LEFT" and 0 or point == "RIGHT" and 1 or 0.5
    local fy = point == "BOTTOM" and 0 or point == "TOP" and 1 or 0.5
    local x = l + w * fx - UIParent:GetWidth() * fx
    local y = b + h * fy - UIParent:GetHeight() * fy
    local current, _, _, cx, cy = bar:GetPoint(1)
    if current == point and math.abs((cx or 0) - x) < 1 and math.abs((cy or 0) - y) < 1 then return end
    bar:ClearAllPoints()
    bar:SetPoint(point, UIParent, point, x, y)
    self:SavePosition()
end

function S:SavePosition()
    local point, _, _, x, y = self.bar:GetPoint(1)
    settings().pos = { point = point, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

function S:Enabled()
    return CK.db and settings().enabled
end

-- What a slot shows: icon, count, glow
local function fill(b, r, severity, level)
    b.resource = r
    CK.Paddles.SetIcon(b.icon, r.icon)
    b.count:SetText(r.count)
    b.count:SetTextColor(1, level == 2 and 0.25 or (level == 1 and 0.65 or 1), level > 0 and 0.2 or 1)
    setGlow(b, severity)
end

-- Counts, glows and the vibration when a resource gets lower. The buttons'
-- number, places and sizes only change out of combat (the game locks its
-- secure buttons in combat): until then the ones there show what they can.
function S:Refresh()
    if not CK.db then return end
    local s = settings()
    s.layout = OLD_LAYOUT[s.layout] or s.layout
    local list = {}
    self.levels = self.levels or {}
    for _, r in ipairs(s.enabled and self:Resources() or {}) do
        local severity = S.Severity(r.count, r.cfg)
        local level = severity >= 1 and 2 or (severity > 0 and 1 or 0)
        -- Worse than before: a vibration (not when the addon starts)
        local before = self.levels[r.key]
        local ready, on = knownIcon(r.icon), self:ResourceEnabled(r)
        if ready and before and level > before and CK.Vibration and on then
            CK.Vibration:Fire(r.kind == "bags" and "lowSpace" or "lowStock")
        end
        self.levels[r.key] = ready and level or nil
        if ready and on then list[#list + 1] = { r = r, severity = severity, level = level } end
    end

    local size = SIZES[s.size] or SIZES[2]
    local layout = table.concat({ tostring(s.enabled), #list, size, s.layout }, ":")
    if InCombatLockdown() then
        if self.bar then
            for i, item in ipairs(list) do
                local b = self.bar.buttons[i]
                if b and b:IsShown() then fill(b, item.r, item.severity, item.level) end
            end
        end
        self.pendingLayout = layout ~= self.layout or nil
        return
    end
    self.pendingLayout = nil
    if not s.enabled then
        if self.bar then self.bar:Hide() end
        self.layout = layout
        return
    end
    self:BuildBar()
    local bar = self.bar
    local d = DIRECTION[s.layout] or DIRECTION.right
    local changed = layout ~= self.layout
    if changed then self:HoldEdge(d.anchor) end
    for i, item in ipairs(list) do
        local b = self:Button(i)
        if changed then
            resize(b, size)
            local offset = (i - 1) * (size + 8)
            for _, frame in ipairs({ b, b.click }) do
                frame:ClearAllPoints()
                frame:SetPoint(d.anchor, bar, d.anchor, d.x * offset, d.y * offset)
                frame:Show()
            end
        end
        fill(b, item.r, item.severity, item.level)
    end
    if changed then
        for i = #list + 1, #bar.buttons do
            bar.buttons[i]:Hide()
            bar.buttons[i].click:Hide()
        end
        local length = math.max(1, #list * (size + 8) - 8)
        if d.x ~= 0 then bar:SetSize(length, size) else bar:SetSize(size, length) end
    end
    bar:SetShown(#list > 0 or self.moving or false)
    self.layout = layout
end

---------------------------------------------------------------------------
-- Moving with the D-pad (from the Supplies tab: the panel steps aside)
---------------------------------------------------------------------------
local MOVES = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local STEP = 10

function S:StartPlacement()
    self:BuildBar()
    self.moving = true
    -- Where it was: B puts it back
    self.placeFrom = settings().pos
    if not self.banner then
        local banner = CK.NewFrame("Frame", nil, UIParent)
        banner:SetSize(560, 58)
        banner:SetPoint("TOP", 0, -90)
        banner:SetFrameStrata("DIALOG")
        CK.Config.panel(banner)
        banner.title = CK.UIKit.text(banner, 14)
        banner.title:SetPoint("TOP", 0, -10)
        banner.title:SetTextColor(unpack(CK.UIKit.C.gold))
        banner.title:SetText(L.SUP_MOVE)
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
    self.bar.ring:Show()
    self:Refresh()
end

function S:StopPlacement()
    if not self.moving then return end
    self.moving = false
    if self.banner then self.banner:Hide() end
    if self.bar then self.bar.ring:Hide() end
    self:Refresh()
end

function S:PlacementPress(name)
    if InCombatLockdown() then return end
    if MOVES[name] then
        local point, _, _, x, y = self.bar:GetPoint(1)
        self.bar:ClearAllPoints()
        self.bar:SetPoint(point, UIParent, point, x + MOVES[name][1] * STEP, y + MOVES[name][2] * STEP)
        self:SavePosition()
    elseif name == "X" then
        settings().pos = nil
        self:Place()
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

function S:ResetPosition()
    settings().pos = nil
    if self.bar then self:Place() end
end

-- An item of the bags followed too
function S:AddItem(id)
    local s = settings()
    for _, other in ipairs(s.custom) do
        if other == id then return end
    end
    s.custom[#s.custom + 1] = id
    self:Refresh()
end

function S:RemoveItem(id)
    local s = settings()
    for i, other in ipairs(s.custom) do
        if other == id then table.remove(s.custom, i) end
    end
    s.list["item:" .. id] = nil
    self:Refresh()
end

-- The items of the bags not followed yet: { id, name, icon, count }
function S:BagItems()
    local tracked, list, seen = {}, {}, {}
    for _, r in ipairs(self:Resources()) do
        if r.id then tracked[r.id] = true end
    end
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not tracked[id] and not seen[id] then
                seen[id] = true
                list[#list + 1] = { id = id, name = itemName(id), icon = itemIcon(id), count = itemCount(id) }
            end
        end
    end
    table.sort(list, function(a, b)
        if strcmputf8i then return strcmputf8i(a.name, b.name) < 0 end
        return a.name < b.name
    end)
    return list
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function S:Init()
    local f = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
        "UNIT_INVENTORY_CHANGED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "PLAYER_REGEN_ENABLED" }) do
        pcall(f.RegisterEvent, f, event)
    end
    local queued
    f:SetScript("OnEvent", function(_, event, unit, success)
        if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
        if (event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT") and success == false then return end
        -- After a fight: the layout that waited
        if event == "PLAYER_REGEN_ENABLED" and not S.pendingLayout then return end
        if queued then return end
        queued = true
        C_Timer.After(0.1, function()
            queued = false
            S:Refresh()
        end)
    end)
    self:Refresh()
end
