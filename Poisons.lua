local _, CK = ...
local L = CK.L

-- The poison menu (asked): a rogue's poison counters, on the bag counters'
-- bar (Supplies.lua), become one button. A click opens the poisons carried,
-- a click on one shows the two weapons, a click on a weapon applies it: the
-- game's own way, the item used then the weapon's slot as its target, in
-- one secure click. Open, chosen and closed by secure snippets, so it works
-- in combat too; what it holds changes out of combat only. Its glow and
-- count are those of the poison closest to running out. Off: one counter
-- a poison, as before.
local P = {}
CK.Poisons = P

-- Strongest first, by kind: Instant, Deadly, Crippling, Mind-numbing, Wound
-- (the rogue's in Supplies.REAGENTS, the powders apart)
P.IDS = { 8928, 8927, 8926, 6950, 6949, 6947, 20844, 8985, 8984, 2893, 2892, 3776, 3775,
    9186, 6951, 5237, 10922, 10921, 10920, 10918 }
local RANK = {}
for i, id in ipairs(P.IDS) do RANK[id] = i end
function P.IsPoison(id) return id ~= nil and RANK[id] ~= nil end

local MAIN, OFF = INVSLOT_MAINHAND or 16, INVSLOT_OFFHAND or 17
local WEAPON_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
local GAP = 8
local LABEL = 12     -- under a weapon: its hand's name
local BACKPACK = "MainMenuBarBackpackButton"
P.MAIN, P.OFF = MAIN, OFF

local function settings() return CK.db.settings.supplies end

function P:On()
    if not CK.db or settings().poisonMenu ~= true then return false end
    local _, class = UnitClass("player")
    return class == "ROGUE"
end

-- The weapon in a hand, nil when none (or not a weapon: a held item)
local function weaponIn(slot)
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    if type(id) ~= "number" or id <= 0 then return nil end
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local classID = get and select(6, get(id))
    if classID ~= nil and classID ~= WEAPON_CLASS then return nil end
    return id
end
P.WeaponIn = weaponIn

---------------------------------------------------------------------------
-- What it holds: every poison counter ({ r, severity, level }), the menu's
-- (those carried, strongest first), and the bar's button for them all. It
-- looks like the worst of those followed: its icon, count, colour (the one
-- to buy); none low, the first followed; none followed, the first carried.
---------------------------------------------------------------------------
function P:Group(poisons)
    table.sort(poisons, function(a, b) return RANK[a.r.id] < RANK[b.r.id] end)
    local carried, all, worst = {}, {}, nil
    for _, p in ipairs(poisons) do
        all[p.r.id] = p
        if p.r.count > 0 then carried[#carried + 1] = p end
        if p.r.cfg.on and (not worst or p.severity > worst.severity) then worst = p end
    end
    self.carried, self.all = carried, all
    local ids = {}
    for i, p in ipairs(carried) do ids[i] = p.r.id end
    self.signature = table.concat(ids, ",") .. "/" .. tostring(weaponIn(MAIN) ~= nil) .. tostring(weaponIn(OFF) ~= nil)
    local look = worst or carried[1]
    if not look then return nil end
    return {
        r = { key = "poisons", kind = "poisons", name = L.SUP_POISONS, icon = look.r.icon, count = look.r.count, cfg = look.r.cfg },
        severity = worst and worst.severity or 0, level = worst and worst.level or 0,
    }
end

---------------------------------------------------------------------------
-- Secure snippets (owner: the menu). Never the word for Lua's closures nor
-- braces in them: the game refuses those snippets.
---------------------------------------------------------------------------
-- The button: opens or closes the menu (its right click: the bags)
local TOGGLE = [[
    if button ~= "LeftButton" then return end
    owner:GetFrameRef("mh"):Hide()
    owner:GetFrameRef("oh"):Hide()
    owner:SetAttribute("ck-chosen", nil)
    if owner:IsShown() then owner:Hide() else owner:Show() end
    return false
]]

-- A poison: its weapons beside it (again: hidden)
local PICK = [[
    local mh, oh = owner:GetFrameRef("mh"), owner:GetFrameRef("oh")
    local item = self:GetAttribute("ck-item")
    local again = owner:GetAttribute("ck-chosen") == item and (mh:IsShown() or oh:IsShown())
    mh:Hide()
    oh:Hide()
    owner:SetAttribute("ck-chosen", nil)
    if again or not item then return false end
    owner:SetAttribute("ck-chosen", item)
    local first, second = mh, oh
    if owner:GetAttribute("ck-ohfirst") then first, second = oh, mh end
    local p, rp = owner:GetAttribute("ck-wp"), owner:GetAttribute("ck-wrp")
    local x, y = owner:GetAttribute("ck-wx"), owner:GetAttribute("ck-wy")
    local prev = self
    if first:GetAttribute("ck-has") then
        first:SetAttribute("item", item)
        first:ClearAllPoints()
        first:SetPoint(p, prev, rp, x, y)
        first:Show()
        prev = first
    end
    if second:GetAttribute("ck-has") then
        second:SetAttribute("item", item)
        second:ClearAllPoints()
        second:SetPoint(p, prev, rp, x, y)
        second:Show()
    end
    return false
]]

-- A weapon: the poison applied (the button's own action), then the menu closes
local APPLY = [[
    if not self:GetAttribute("item") then return false end
    return nil, true
]]
local DONE = [[
    owner:SetAttribute("ck-chosen", nil)
    owner:GetFrameRef("mh"):Hide()
    owner:GetFrameRef("oh"):Hide()
    owner:Hide()
]]

---------------------------------------------------------------------------
-- The frames
---------------------------------------------------------------------------
local function hideTip() GameTooltip:Hide() end

local function resizeSlot(b, size)
    if b.size == size then return end
    b.size = size
    b:SetSize(size, size)
    b.visual:SetSize(size, size)
end

-- Time left on a weapon's poison: "28m", "40s"
local function timeLeft(ms)
    ms = CK.Plain(ms)
    if not ms or ms <= 0 then return "" end
    local s = ms / 1000
    if s >= 60 then return format("%dm", math.ceil(s / 60)) end
    return format("%ds", math.ceil(s))
end
P.TimeLeft = timeLeft

function P:Build()
    if self.toggle then return end
    local S = CK.Supplies
    local toggle = CK.NewFrame("Button", "ControllerKeyboardPoisonButton", S.bar, "SecureActionButtonTemplate")
    toggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Acts on the release, the click it gets (as the counters' buttons)
    toggle:SetAttribute("useOnKeyDown", false)
    if _G[BACKPACK] then
        toggle:SetAttribute("type2", "click")
        toggle:SetAttribute("clickbutton", _G[BACKPACK])
    end
    toggle:RegisterForDrag("LeftButton")
    toggle:SetScript("OnEnter", function(b) P:ButtonTooltip(b) end)
    toggle:SetScript("OnLeave", hideTip)
    toggle:SetScript("OnDragStart", function()
        if not settings().locked and not InCombatLockdown() then S:StartDrag() end
    end)
    toggle:SetScript("OnDragStop", function() S.drag = nil end)
    toggle:Hide()

    -- The menu: shown and hidden by the snippets only (no script of ours
    -- on its showing: the snippets go on untouched)
    local menu = CK.NewFrame("Frame", "ControllerKeyboardPoisons", toggle, "SecureHandlerBaseTemplate")
    menu:SetSize(1, 1)
    menu:SetPoint("CENTER", toggle, "CENTER")
    menu:SetFrameStrata("HIGH")
    menu:Hide()
    menu:SetScript("OnUpdate", function(_, dt) P:OnUpdate(dt) end)
    SecureHandlerWrapScript(toggle, "OnClick", menu, TOGGLE)

    self.toggle, self.menu, self.entries, self.weapons = toggle, menu, {}, {}
    for _, inv in ipairs({ MAIN, OFF }) do
        local w = CK.NewFrame("Button", inv == MAIN and "ControllerKeyboardPoisonRight" or "ControllerKeyboardPoisonLeft",
            menu, "SecureActionButtonTemplate")
        w:RegisterForClicks("LeftButtonUp")
        w:SetAttribute("useOnKeyDown", false)
        -- The poison (its "item", set by the snippet), then this hand's slot
        -- as its target: the game's SecureActionButton does both
        w:SetAttribute("type", "item")
        w:SetAttribute("target-slot", inv)
        w.inv = inv
        w.slot = CK.Paddles:CreateSlot(w, 40)
        w.slot:SetPoint("CENTER")
        w.label = CK.UIKit.text(w, 10)
        w.label:SetPoint("TOP", w, "BOTTOM", 0, -1)
        w.label:SetText(inv == MAIN and L.POISON_RIGHT or L.POISON_LEFT)
        w:SetScript("OnEnter", function(b) P:WeaponTooltip(b) end)
        w:SetScript("OnLeave", hideTip)
        w:Hide()
        SecureHandlerWrapScript(w, "OnClick", menu, APPLY, DONE)
        SecureHandlerSetFrameRef(menu, inv == MAIN and "mh" or "oh", w)
        self.weapons[#self.weapons + 1] = w
    end
end

function P:Entry(i, size)
    local e = self.entries[i]
    if not e then
        e = CK.NewFrame("Button", "ControllerKeyboardPoison" .. i, self.menu, "SecureActionButtonTemplate")
        e:RegisterForClicks("LeftButtonUp")
        e:SetAttribute("useOnKeyDown", false)
        e.slot = CK.Supplies.NewSlot(e, size)
        e.slot:SetPoint("CENTER")
        e:SetScript("OnEnter", function(b) P:EntryTooltip(b) end)
        e:SetScript("OnLeave", hideTip)
        SecureHandlerWrapScript(e, "OnClick", self.menu, PICK)
        self.entries[i] = e
    end
    e:SetSize(size, size)
    resizeSlot(e.slot, size)
    return e
end

-- Which way it opens from the button: away from the bar (a bar in a row: a
-- column upward; in a column: a row to the right), the weapons beside the
-- poison chosen (to its right, the left hand's on the left; above it for a
-- row). The other way only when the screen's edge is too near. Where the
-- button is comes from the bar's saved place (the game's bar's place is
-- secret to addons), its bottom middle taken about 110 above the screen's.
-- Returns the poisons' step (x, y), the weapons' anchor { point, relative
-- point, x, y, left hand first }, and the tooltips' sides.
function P.Ways(d, size, index, n)
    local S = CK.Supplies
    local x, y = S:CurrentPlace()
    local k = S.BarScale()
    local step = ((index or 1) - 1) * (size + 8)
    x, y = x + d.x * step, y + d.y * step
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local function fitsRight(length) return W / 2 + (x + size / 2 + length) * k <= W end
    local function fitsUp(length) return 110 + (y + size / 2 + length) * k <= H end
    local pair, line = 2 * (size + GAP), math.max(1, n or 1) * (size + GAP)
    if d.x ~= 0 then
        local right = fitsRight(pair)
        local beside = right and { "LEFT", "RIGHT", GAP, 0, true } or { "RIGHT", "LEFT", -GAP, 0, false }
        return 0, fitsUp(line) and 1 or -1, beside, right and "ANCHOR_LEFT" or "ANCHOR_RIGHT", "ANCHOR_TOP"
    end
    local right, up = fitsRight(line), fitsUp(pair + 2 * LABEL)
    local beside = up and { "BOTTOM", "TOP", 0, GAP + LABEL, false } or { "TOP", "BOTTOM", 0, -(GAP + LABEL), false }
    return right and 1 or -1, 0, beside, up and "ANCHOR_BOTTOM" or "ANCHOR_TOP", right and "ANCHOR_RIGHT" or "ANCHOR_LEFT"
end

-- On the bar's slot for the poisons (nil: none, hidden). Out of combat
-- (Supplies:Refresh lays its bar out then only).
function P:Attach(slot, d, size, index)
    if InCombatLockdown() then return end
    if not slot then
        if self.toggle then
            self.toggle:Hide()
            self.menu:Hide()
        end
        self.shown = nil
        return
    end
    self:Build()
    local t, menu = self.toggle, self.menu
    t:ClearAllPoints()
    t:SetPoint("CENTER", slot, "CENTER")
    t:SetSize(size, size)
    t:SetFrameLevel(slot:GetFrameLevel() + 10)
    t:Show()
    local carried = self.carried or {}
    local vx, vy, beside
    vx, vy, beside, self.entryTip, self.weaponTip = P.Ways(d, size, index, #carried)
    menu:SetAttribute("ck-wp", beside[1])
    menu:SetAttribute("ck-wrp", beside[2])
    menu:SetAttribute("ck-wx", beside[3])
    menu:SetAttribute("ck-wy", beside[4])
    menu:SetAttribute("ck-ohfirst", beside[5])
    -- Other poisons or weapons: no weapon shown for the old ones
    if self.shown ~= self.signature then
        for _, w in ipairs(self.weapons) do w:Hide() end
        menu:SetAttribute("ck-chosen", nil)
    end
    self.shown = self.signature
    for i, p in ipairs(carried) do
        local e = self:Entry(i, size)
        e:ClearAllPoints()
        e:SetPoint("CENTER", t, "CENTER", vx * i * (size + GAP), vy * i * (size + GAP))
        e:SetAttribute("ck-item", "item:" .. p.r.id)
        e.id = p.r.id
        e:Show()
    end
    for i = #carried + 1, #self.entries do
        local e = self.entries[i]
        e:SetAttribute("ck-item", nil)
        e.id = nil
        e:Hide()
    end
    for _, w in ipairs(self.weapons) do
        w:SetSize(size, size)
        resizeSlot(w.slot, size)
        w:SetAttribute("ck-has", weaponIn(w.inv) ~= nil or nil)
        if not w:GetAttribute("ck-has") then w:Hide() end
    end
    self:Update()
end

-- What they show, in combat too: counts, glows, the weapons' poisons
function P:Update()
    if not self.toggle then return end
    local all = self.all or {}
    for _, e in ipairs(self.entries) do
        local p = e.id and all[e.id]
        if p then CK.Supplies.Fill(e.slot, p.r, p.severity, p.level) end
    end
    self:UpdateWeapons()
end

function P:UpdateWeapons()
    if not self.weapons then return end
    local ok, hasMain, mainLeft, _, _, hasOff, offLeft = pcall(GetWeaponEnchantInfo)
    if not ok then hasMain, hasOff = nil, nil end
    for _, w in ipairs(self.weapons) do
        CK.Paddles.SetIcon(w.slot.icon, GetInventoryItemTexture("player", w.inv))
        local has, ms
        if w.inv == MAIN then has, ms = hasMain, mainLeft else has, ms = hasOff, offLeft end
        w.slot.count:SetText(has and timeLeft(ms) or "")
    end
end

-- While open: the poison chosen pressed, the weapons' time left
function P:OnUpdate(dt)
    self.since = (self.since or 1) + dt
    if self.since < 0.2 then return end
    self.since = 0
    local chosen = self.menu:GetAttribute("ck-chosen")
    for _, e in ipairs(self.entries) do
        if e.id then CK.Paddles.SetPressed(e.slot, chosen == "item:" .. e.id) end
    end
    self:UpdateWeapons()
    -- The button's tooltip over the menu: away
    if GameTooltip:GetOwner() == self.toggle and GameTooltip:IsShown() then GameTooltip:Hide() end
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
function P:ButtonTooltip(owner)
    if CK.Supplies.moving or self.menu:IsShown() then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(L.SUP_POISONS, 1, 1, 1)
    local carried = self.carried or {}
    if #carried == 0 then GameTooltip:AddLine(L.POISON_NONE, 0.7, 0.7, 0.7) end
    for _, p in ipairs(carried) do
        GameTooltip:AddDoubleLine(p.r.name, tostring(p.r.count), 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:AddLine(L.POISON_TIP_CLICK, 0.6, 0.6, 0.6)
    if _G[BACKPACK] then GameTooltip:AddLine(L.POISON_TIP_RIGHT, 0.6, 0.6, 0.6) end
    local shortcut = CK.Mapping.ChordLabel and CK.Mapping:ChordLabel(CK.db.settings.shortcut) or ""
    GameTooltip:AddLine(format(L.SUP_TIP_ADDON, L.TAB_ALERTS .. " › " .. L.SEC_SUPPLIES, shortcut), 0.2, 0.8, 1, true)
    GameTooltip:Show()
end

function P:EntryTooltip(e)
    local p = e.id and self.all and self.all[e.id]
    if not p then return end
    GameTooltip:SetOwner(e, self.entryTip or "ANCHOR_LEFT")
    GameTooltip:SetItemByID(e.id)
    GameTooltip:AddLine(format(L.SUP_TIP_COUNT, p.r.count), 1, 0.82, 0)
    GameTooltip:AddLine(L.POISON_TIP_PICK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function P:WeaponTooltip(w)
    GameTooltip:SetOwner(w, self.weaponTip or "ANCHOR_TOP")
    GameTooltip:SetInventoryItem("player", w.inv)
    if GameTooltip:NumLines() == 0 then
        GameTooltip:SetText(w.inv == MAIN and L.POISON_RIGHT or L.POISON_LEFT, 1, 1, 1)
    end
    local item = w:GetAttribute("item")
    local id = type(item) == "string" and tonumber(item:match("^item:(%d+)$"))
    local p = id and self.all and self.all[id]
    if p then GameTooltip:AddLine(format(L.POISON_TIP_APPLY, p.r.name), 0.25, 0.9, 0.25) end
    GameTooltip:Show()
end
