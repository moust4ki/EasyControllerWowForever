local _, CK = ...
local L = CK.L

-- Module "supplies": one round button per resource, in the style of the
-- gamepad bar: free bag slots, the equipped ammunition, the class reagents
-- (soul shards, powders, candles, poisons...) and any item the player adds.
-- Each shows its count; under its "low" threshold it glows, stronger and
-- faster down to its "critical" one, where the glow is red. One bar of
-- buttons, placed freely (mouse drag while unlocked, or the D-pad) from the
-- game's gamepad bar and at its scale, growing in one of 4 directions, and
-- a click opens the bags. Nothing of the game's is changed.
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

-- The ammo equipped, nil when none: an empty slot answers 0 in WoW Forever
-- (a row named "item:0" showed for characters without ammo)
local function ammoID()
    local id = GetInventoryItemID and GetInventoryItemID("player", AMMO_SLOT)
    if type(id) ~= "number" or id <= 0 then return nil end
    return id
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
        add("ammo", "ammo", ammo, ammo and itemName(ammo) or L.SUP_AMMO,
            ammo and (GetInventoryItemTexture("player", AMMO_SLOT) or itemIcon(ammo)) or "Interface\\Icons\\INV_Ammo_Arrow_01",
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
    -- Whose buttons these are, and where to change or hide them (players
    -- didn't know what the buttons over the bars were)
    local shortcut = CK.Mapping.ChordLabel and CK.Mapping:ChordLabel(CK.db.settings.shortcut) or ""
    GameTooltip:AddLine(format(L.SUP_TIP_ADDON, L.TAB_ALERTS .. " › " .. L.SEC_SUPPLIES, shortcut), 0.2, 0.8, 1, true)
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
    -- Dragged with the mouse; the game's bar's scale followed
    bar:SetScript("OnUpdate", function(_, dt) S:OnUpdate(dt) end)
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
    b.count:SetPoint("BOTTOM", 0, 3)
    -- The count on a pill (reported: orange or red on the brown bag, hard to
    -- read): dark, orange then red with the level, a dark edge; above the
    -- rim, under the count. Its width follows the count (see fill)
    b.badgeArea = CK.NewFrame("Frame", nil, b.over)
    b.badgeArea:SetSize(18, 17)
    b.badgeArea:SetPoint("CENTER", b.count, "CENTER", 0, 0)
    b.badge = CK.ConfigKit.Box(b.over, 4, 1, "ARTWORK", 3)
    b.badge:SetPoints(b.badgeArea)
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
        if not settings().locked and not InCombatLockdown() then S:StartDrag() end
    end)
    click:SetScript("OnDragStop", function() S.drag = nil end)
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

---------------------------------------------------------------------------
-- Its place, from the game's gamepad bar (asked: the same place on a PC and
-- on a handheld or a TV of another resolution, and the size following the
-- bar's). Saved as where its first button's middle is from the bar's bottom
-- middle (where the game anchors its bar), in the bar's units: it follows
-- the bar wherever Edit Mode puts it, grows with it, and that first button
-- stays put whatever the count, the size or the direction. The bar's place
-- is never read (secret to addons since the game's build of 2 November
-- 2026), it is only anchored to: moved by steps, and by the mouse's own way.
---------------------------------------------------------------------------
local DEFAULT_Y = 220   -- the default place: above the game's bar's bottom middle
local NO_BAR_Y = 110    -- no gamepad bar: where its bottom middle usually is
-- From the edge the bar grows from, toward its first button's middle
local EDGE = { LEFT = { 1, 0 }, RIGHT = { -1, 0 }, TOP = { 0, -1 }, BOTTOM = { 0, 1 } }

local function gameBar() return GamepadMainActionBarFrame end

-- The game's bar's scale, for ours (1 without it)
local function barScale()
    local gb = gameBar()
    local k = gb and gb.GetEffectiveScale and CK.Plain(gb:GetEffectiveScale())
    local u = CK.Plain(UIParent:GetEffectiveScale())
    if k and u and k > 0 and u > 0 then return k / u end
    return 1
end
S.BarScale = barScale

local function layoutOf()
    local s = settings()
    return DIRECTION[s.layout] or DIRECTION.right, SIZES[s.size] or SIZES[2]
end

local function savedPlace()
    local p = settings().barPos
    if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then return p end
end

function S:Place()
    local bar = self.bar
    if not bar or InCombatLockdown() then return end
    local d, size = layoutOf()
    local k = barScale()
    if math.abs((bar:GetScale() or 1) - k) > 0.001 then bar:SetScale(k) end
    self.scale = k
    local gb = gameBar()
    local to, baseY = gb or UIParent, gb and 0 or NO_BAR_Y
    local place = savedPlace()
    bar:ClearAllPoints()
    if place then
        local e = EDGE[d.anchor]
        bar:SetPoint(d.anchor, to, "BOTTOM", place.x - e[1] * size / 2, baseY + place.y - e[2] * size / 2)
    else
        -- Not moved yet: centred above the bar
        bar:SetPoint("BOTTOM", to, "BOTTOM", 0, baseY + DEFAULT_Y)
    end
end

-- Where its first button's middle is now, from the game's bar's bottom
-- middle (the default place: from its size and count, as Place puts it)
function S:CurrentPlace()
    local place = savedPlace()
    if place then return place.x, place.y end
    local d, size = layoutOf()
    local length = self.length or size
    local w, h = d.x ~= 0 and length or size, d.x ~= 0 and size or length
    local e = EDGE[d.anchor]
    local fx = d.anchor == "LEFT" and -w / 2 or d.anchor == "RIGHT" and w / 2 or 0
    local fy = d.anchor == "TOP" and h or d.anchor == "BOTTOM" and 0 or h / 2
    return fx + e[1] * size / 2, DEFAULT_Y + fy + e[2] * size / 2
end

function S:MoveTo(x, y)
    settings().barPos = { x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
    self:Place()
end

-- The mouse: its way since the press, in the bar's units
function S:StartDrag()
    local x, y = self:CurrentPlace()
    local cx, cy = GetCursorPosition()
    self.drag = { x = x, y = y, cx = cx, cy = cy, scale = self.bar:GetEffectiveScale() }
end

function S:Drag()
    local d = self.drag
    if InCombatLockdown() or not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
        self.drag = nil
        return
    end
    local cx, cy = GetCursorPosition()
    self:MoveTo(d.x + (cx - d.cx) / d.scale, d.y + (cy - d.cy) / d.scale)
end

function S:OnUpdate(dt)
    if self.drag then self:Drag() end
    self.sinceScale = (self.sinceScale or 0) + dt
    if self.sinceScale < 0.5 then return end
    self.sinceScale = 0
    -- The game's bar resized (Move / size, the interface's scale): ours too
    if math.abs(barScale() - (self.scale or 1)) > 0.001 then self:Place() end
end

-- The game's bar's bottom middle on the screen (UIParent's units), when
-- the game lets addons read it
local function gameBarBottom()
    local gb = gameBar()
    if not gb then return UIParent:GetWidth() / 2, NO_BAR_Y end
    local plain, k = CK.Plain, barScale()
    local l, r, b = plain(gb:GetLeft()), plain(gb:GetRight()), plain(gb:GetBottom())
    if l and r and b then return (l + r) / 2 * k, b * k end
    local point, rel, relPoint, x, y = gb:GetPoint(1)
    x, y = plain(x), plain(y)
    if x and y and rel == UIParent and point == "BOTTOM" and relPoint == "BOTTOM" then
        return UIParent:GetWidth() / 2 + x * k, y * k
    end
end

-- A place saved before 1.20, from the screen's edges: where its first
-- button was then, from the game's bar, when the bar's place can be read;
-- else the default place
function S:ConvertOldPlace(length)
    local s = settings()
    local old = s.pos
    s.pos = nil
    if type(old) ~= "table" or type(old.point) ~= "string" or type(old.x) ~= "number" or type(old.y) ~= "number" then
        return
    end
    local d, size = layoutOf()
    local P, W, H = old.point, UIParent:GetWidth(), UIParent:GetHeight()
    local w, h = d.x ~= 0 and length or size, d.x ~= 0 and size or length
    local fx = P:find("LEFT") and 0 or P:find("RIGHT") and 1 or 0.5
    local fy = P:find("BOTTOM") and 0 or P:find("TOP") and 1 or 0.5
    -- The bar then (scale 1), its first button at the edge it grows from
    local left, bottom = fx * W + old.x - fx * w, fy * H + old.y - fy * h
    local ax = d.anchor == "LEFT" and left or d.anchor == "RIGHT" and left + w or left + w / 2
    local ay = d.anchor == "BOTTOM" and bottom or d.anchor == "TOP" and bottom + h or bottom + h / 2
    local e = EDGE[d.anchor]
    local cx, cy = ax + e[1] * size / 2, ay + e[2] * size / 2
    local ok, bx, by = pcall(gameBarBottom)
    if not (ok and bx and by) then return end
    local k = barScale()
    s.barPos = { x = math.floor((cx - bx) / k + 0.5), y = math.floor((cy - by) / k + 0.5) }
end

function S:Enabled()
    return CK.db and settings().enabled
end

-- The count's pill by level: above "low" (dark, white count), "low"
-- (orange, dark count), "critical" (red, white count)
local BADGE = {
    [0] = { fill = { 0.05, 0.04, 0.03 }, alpha = 0.8, text = { 1, 1, 1 } },
    [1] = { fill = { 0.94, 0.54, 0.11 }, alpha = 1, text = { 0.1, 0.05, 0 } },
    [2] = { fill = { 0.83, 0.16, 0.12 }, alpha = 1, text = { 1, 1, 1 } },
}
local BADGE_EDGE = { 0, 0, 0 }

-- What a slot shows: icon, count, glow
local function fill(b, r, severity, level)
    b.resource = r
    CK.Paddles.SetIcon(b.icon, r.icon)
    b.count:SetText(r.count)
    local look = BADGE[level] or BADGE[0]
    b.count:SetTextColor(look.text[1], look.text[2], look.text[3])
    if b.badge then
        b.badge:SetColors(look.fill, look.alpha, BADGE_EDGE, 1)
        b.badgeArea:SetWidth(math.max(18, (b.count:GetStringWidth() or 0) + 8))
        -- Lower on the small buttons (32 px), not to hide the icon
        b.badgeArea:SetHeight((b.size or 40) < 40 and 15 or 17)
    end
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
        if before and level > before and CK.Vibration and r.cfg.on then
            CK.Vibration:Fire(r.kind == "bags" and "lowSpace" or "lowStock")
        end
        self.levels[r.key] = level
        if r.cfg.on then list[#list + 1] = { r = r, severity = severity, level = level } end
    end

    local size = SIZES[s.size] or SIZES[2]
    -- Shown with the game's gamepad bar, the gamepad UI on (reported: the bag
    -- counter stayed with the gamepad UI off); always while it is moved
    local gb = GamepadMainActionBarFrame
    local withBar = CK.GamepadUI() and not (gb and gb.IsShown and not gb:IsShown())
    local layout = table.concat({ tostring(s.enabled), #list, size, s.layout, tostring(withBar) }, ":")
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
    local length = math.max(1, #list * (size + 8) - 8)
    self.length = length
    if s.pos ~= nil and not savedPlace() then self:ConvertOldPlace(length) end
    -- The default place (centred above the game's bar) kept from its first
    -- drawing on: its first button stays put as resources come and go
    if not savedPlace() then
        local x, y = self:CurrentPlace()
        s.barPos = { x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
    end
    for i, item in ipairs(list) do
        local b = self:Button(i)
        resize(b, size)
        local offset = (i - 1) * (size + 8)
        for _, frame in ipairs({ b, b.click }) do
            frame:ClearAllPoints()
            frame:SetPoint(d.anchor, bar, d.anchor, d.x * offset, d.y * offset)
            frame:Show()
        end
        fill(b, item.r, item.severity, item.level)
    end
    for i = #list + 1, #bar.buttons do
        bar.buttons[i]:Hide()
        bar.buttons[i].click:Hide()
    end
    if d.x ~= 0 then bar:SetSize(length, size) else bar:SetSize(size, length) end
    self:Place()
    bar:SetShown((#list > 0 and withBar) or self.moving or false)
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
    self.placeFrom = savedPlace()
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
        local x, y = self:CurrentPlace()
        self:MoveTo(x + MOVES[name][1] * STEP, y + MOVES[name][2] * STEP)
    elseif name == "X" then
        settings().barPos = nil
        self:Place()
    elseif name == "A" or name == "B" then
        if name == "B" then
            settings().barPos = self.placeFrom
            self:Place()
        end
        self:StopPlacement()
        CK.Config:EndPlacement()
        if name == "A" then CK.Config:Toast(L.TOAST_POS_SAVED) end
    end
end

function S:ResetPosition()
    settings().pos = nil
    settings().barPos = nil
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
        "UNIT_INVENTORY_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED" }) do
        pcall(f.RegisterEvent, f, event)
    end
    local queued
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
        -- After a fight: the layout that waited
        if event == "PLAYER_REGEN_ENABLED" and not S.pendingLayout then return end
        if queued then return end
        queued = true
        C_Timer.After(0.1, function()
            queued = false
            S:Refresh()
        end)
    end)
    -- The game's gamepad bar shown or hidden, its gamepad UI turned on or
    -- off (no event of the game's says it: looked at twice a second): ours
    -- and the extra buttons follow (in combat: once it ends)
    local gb = GamepadMainActionBarFrame
    if gb and gb.HookScript then
        gb:HookScript("OnShow", function() S:Refresh() end)
        gb:HookScript("OnHide", function() S:Refresh() end)
    end
    local was, since = CK.GamepadUI(), 0
    f:SetScript("OnUpdate", function(_, dt)
        since = since + dt
        if since < 0.5 then return end
        since = 0
        local now = CK.GamepadUI()
        if now == was then return end
        was = now
        S:Refresh()
        if CK.Paddles and CK.Paddles.UpdateVisibility then CK.Paddles:UpdateVisibility() end
    end)
    self:Refresh()
end
