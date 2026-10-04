local _, CK = ...

-- Module "better items": a green arrow at the bottom right of a bag item
-- that would be better than what is equipped in its slot. Better: a higher
-- score from the item's stats (the game's own list: damage per second,
-- strength, agility, stamina, intellect, spirit, armor, attack and spell
-- power), weighed for the class, and for a hybrid by the talent tree with the
-- most points (healer, tank or damage); the item level when the client gives
-- no stats. Only what the character can wear: no red line in its tooltip
-- (armor type, weapon skill, level, class), and the class's main armor type
-- or the type already worn in that slot (no cloth for a warrior). Rings,
-- trinkets and one-hand weapons are compared with the weaker of the two; a
-- two-hand weapon with both hands.
-- A texture of ours on the bag buttons, like the quest items' border:
-- nothing written in the game's frames.
local U = {}
CK.Upgrades = U

local ARMOR = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
local ARROW_ATLAS = "bags-greenarrow"

-- Where each kind of item goes (inventory slots)
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
-- What a worn two-hand weapon takes the place of
local ONE_HAND = {
    INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true,
}
-- The slots where the armor type counts (a cloak is cloth for everyone)
local ARMOR_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}
-- Each class's armor (cloth 1, leather 2, mail 3, plate 4): its first, then
-- from level 40 the heavier one it learns
local CLASS_ARMOR = {
    WARRIOR = { 3, 4 }, PALADIN = { 3, 4 }, HUNTER = { 2, 3 }, SHAMAN = { 2, 3 },
    ROGUE = { 2 }, DRUID = { 2 }, MONK = { 2 }, DEMONHUNTER = { 2 },
    MAGE = { 1 }, PRIEST = { 1 }, WARLOCK = { 1 }, DEATHKNIGHT = { 4 }, EVOKER = { 3 },
}

local function enabled()
    return CK.db and CK.db.settings.modules.upgrades
end

local function itemInfo(item)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if get then return get(item) end
end

local function subclassOf(item)
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    return get and select(7, get(item))
end

local function itemLevel(link)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local level = C_Item.GetDetailedItemLevelInfo(link)
        if level then return level end
    end
    return select(4, itemInfo(link)) or 0
end

---------------------------------------------------------------------------
-- The score of an item: its stats, weighed for the class (for leveling:
-- what makes the character hit, heal or hold the hardest first)
---------------------------------------------------------------------------
local STAT = {
    str = { "ITEM_MOD_STRENGTH_SHORT" }, agi = { "ITEM_MOD_AGILITY_SHORT" },
    sta = { "ITEM_MOD_STAMINA_SHORT" }, int = { "ITEM_MOD_INTELLECT_SHORT" }, spi = { "ITEM_MOD_SPIRIT_SHORT" },
    ap = { "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_MELEE_ATTACK_POWER_SHORT" },
    rap = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
    sp = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" },
    heal = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
    armor = { "RESISTANCE0_NAME" },
}
local DPS = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
-- dps: a melee weapon's damage per second, rdps: a ranged weapon's (bows,
-- guns, crossbows, thrown, wands)
local SCALES = {
    WARRIOR = { dps = 3, rdps = 0.5, str = 1, agi = 0.6, sta = 0.5, ap = 0.5, armor = 0.01 },
    WARRIOR_TANK = { dps = 1, sta = 1, str = 0.6, agi = 0.5, armor = 0.04 },
    ROGUE = { dps = 3, rdps = 0.5, agi = 1, str = 0.5, sta = 0.4, ap = 0.5 },
    HUNTER = { dps = 0.5, rdps = 3, agi = 1, int = 0.3, sta = 0.5, ap = 0.3, rap = 0.5 },
    MAGE = { rdps = 1, int = 1, sp = 1, sta = 0.6, spi = 0.4 },
    WARLOCK = { rdps = 1, int = 0.8, sp = 1, sta = 0.8, spi = 0.4 },
    PRIEST = { rdps = 1, int = 1, sp = 0.9, heal = 0.6, spi = 0.8, sta = 0.5 },
    PALADIN = { dps = 2.5, str = 1, int = 0.5, sta = 0.5, agi = 0.4, ap = 0.4 },
    PALADIN_HEAL = { int = 1, heal = 0.8, sp = 0.4, spi = 0.4, sta = 0.4 },
    PALADIN_TANK = { dps = 1, sta = 1, str = 0.6, int = 0.3, armor = 0.03 },
    SHAMAN = { dps = 2.5, str = 0.8, agi = 0.7, int = 0.5, sta = 0.5, ap = 0.4 },
    SHAMAN_CASTER = { int = 1, sp = 0.9, heal = 0.5, spi = 0.4, sta = 0.5 },
    DRUID = { agi = 0.9, str = 0.9, sta = 0.6, ap = 0.4, int = 0.3 },
    DRUID_CASTER = { int = 1, sp = 0.9, heal = 0.5, spi = 0.6, sta = 0.4 },
}
-- The talent tree with the most points, for the classes it changes
local TREE_SCALE = {
    WARRIOR = { [3] = "WARRIOR_TANK" },
    PALADIN = { [1] = "PALADIN_HEAL", [2] = "PALADIN_TANK" },
    SHAMAN = { [1] = "SHAMAN_CASTER", [3] = "SHAMAN_CASTER" },
    DRUID = { [1] = "DRUID_CASTER", [3] = "DRUID_CASTER" },
}

-- The client's list of an item's stats (nil: none in this client)
local function getStats()
    return C_Item and C_Item.GetItemStats or GetItemStats
end

-- The talent tree with the most points: its index and its name
local function mainTree()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local ok, spec = pcall(C_SpecializationInfo.GetSpecialization)
        if ok and type(spec) == "number" and spec > 0 then
            local name = C_SpecializationInfo.GetSpecializationInfo
                and select(2, C_SpecializationInfo.GetSpecializationInfo(spec))
            return spec, name
        end
    end
    if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
    local best, bestPoints, bestName = nil, 0, nil
    for i = 1, GetNumTalentTabs() or 0 do
        -- Classic: name, icon, points...; later clients: id, name, text, icon, points...
        local info = { GetTalentTabInfo(i) }
        local modern = type(info[1]) == "number"
        local points = modern and info[5] or info[3]
        if type(points) == "number" and points > bestPoints then
            best, bestPoints, bestName = i, points, modern and info[2] or info[1]
        end
    end
    return best, bestName
end

-- The class's weights, and the talent tree that chose them (a hybrid's)
function U:Scale()
    local _, class = UnitClass("player")
    local tree, treeName = mainTree()
    local variant = tree and TREE_SCALE[class] and TREE_SCALE[class][tree]
    return SCALES[variant or class], TREE_SCALE[class] and treeName or nil
end

-- Compared by their stats (this client gives them, the class has weights)
function U:ByStats()
    return getStats() ~= nil and self:Scale() ~= nil
end

-- How the score is made, for the options' side panel: "Weights for
-- Warrior: Weapon DPS x3, Strength x1..."
function U:ScaleText()
    if not getStats() then return CK.L.UPGRADE_BY_LEVEL end
    local scale, treeName = self:Scale()
    if not scale then return CK.L.UPGRADE_BY_LEVEL end
    local list = {}
    for key, weight in pairs(scale) do list[#list + 1] = { key = key, weight = weight } end
    table.sort(list, function(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.key < b.key
    end)
    local parts = {}
    for _, item in ipairs(list) do
        parts[#parts + 1] = format("%s ×%s", CK.L["ST_" .. item.key:upper()] or item.key, format("%g", item.weight))
    end
    local who = UnitClass("player") or ""
    if treeName then who = who .. " (" .. treeName .. ")" end
    return format(CK.L.UPGRADE_WEIGHTS, who, table.concat(parts, ", "))
end

-- An item's score (nil: no stats from the client)
function U:Score(link, scale)
    local get = getStats()
    if not (get and link and scale) then return nil end
    local ok, stats = pcall(get, link)
    if not ok or type(stats) ~= "table" then return nil end
    local score = 0
    for key, weight in pairs(scale) do
        for _, name in ipairs(STAT[key] or {}) do
            score = score + (tonumber(stats[name]) or 0) * weight
        end
    end
    local dps = tonumber(stats[DPS])
    if dps then
        local equipLoc = select(9, itemInfo(link))
        local ranged = equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN"
        score = score + dps * (ranged and (scale.rdps or 0) or (scale.dps or 0))
    end
    return score
end

local function mainArmor()
    local _, class = UnitClass("player")
    local list = CLASS_ARMOR[class]
    if not list then return nil end
    return (#list > 1 and (UnitLevel("player") or 1) >= 40) and list[2] or list[1]
end

local function isRed(r, g, b)
    return r and r > 0.9 and g < 0.2 and b < 0.2 or false
end

local function colorRed(color)
    if type(color) ~= "table" then return false end
    if color.GetRGB then return isRed(color:GetRGB()) end
    return isRed(color.r, color.g, color.b)
end

-- Wearable: the game writes in red what the character can't use
local scanner
local function wearable(bag, slot)
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
        if ok and type(data) == "table" and data.lines then
            for _, line in ipairs(data.lines) do
                if colorRed(line.leftColor) or colorRed(line.rightColor) then return false end
            end
            return true
        end
    end
    -- An old client: a hidden tooltip of ours
    if not scanner then
        scanner = CreateFrame("GameTooltip", "ControllerKeyboardScanTooltip", nil, "GameTooltipTemplate")
    end
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)
    for i = 1, scanner:NumLines() or 0 do
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local fs = _G["ControllerKeyboardScanTooltip" .. side .. i]
            if fs and fs:IsShown() and fs:GetText() and isRed(fs:GetTextColor()) then return false end
        end
    end
    return true
end

-- Better than what is equipped there (and the item known: false, true when
-- the game hasn't sent its data yet)
function U:IsUpgrade(bag, slot, link)
    local name, _, _, _, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = itemInfo(link)
    if not name then return false, true end
    local slots = SLOTS[equipLoc]
    if not slots then return false end
    if (reqLevel or 0) > (UnitLevel("player") or 1) then return false end
    if equipLoc == "INVTYPE_WEAPON" and not (CanDualWield and CanDualWield()) then slots = { 16 } end
    local getInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    -- A shield or an off-hand item worn: a one-hand weapon is weighed
    -- against the weapon only
    if equipLoc == "INVTYPE_WEAPON" and #slots == 2 and getInstant then
        local off = GetInventoryItemLink("player", 17)
        local offLoc = off and select(4, getInstant(off))
        if offLoc == "INVTYPE_SHIELD" or offLoc == "INVTYPE_HOLDABLE" then slots = { 16 } end
    end
    -- A two-hand weapon worn holds both hands: a one-hand weapon, a shield or
    -- an off-hand item has to beat it whole (the off hand is not empty)
    local mainHand = GetInventoryItemLink("player", 16)
    if mainHand and getInstant and select(4, getInstant(mainHand)) == "INVTYPE_2HWEAPON" and ONE_HAND[equipLoc] then
        slots = { 16 }
    end
    -- The score when the client gives stats, else the item level
    local scale = self:Scale()
    local byScore = scale ~= nil and self:Score(link, scale) ~= nil
    local function measure(l)
        if not l then return 0 end
        -- An occupied slot with uncached data is not an empty slot. Keep
        -- it pending so GET_ITEM_INFO_RECEIVED retries the comparison.
        if not itemInfo(l) then return nil end
        if byScore then return self:Score(l, scale) end
        return itemLevel(l)
    end
    -- The weaker of what is worn there (nothing: anything is better); a
    -- two-hand weapon takes both hands' place
    local weakest, worn
    for _, s in ipairs(slots) do
        local equipped = GetInventoryItemLink("player", s)
        local v = measure(equipped)
        if v == nil then return false, true end
        if not weakest or v < weakest then weakest, worn = v, equipped end
    end
    if equipLoc == "INVTYPE_2HWEAPON" and byScore then
        local offHand = measure(GetInventoryItemLink("player", 17))
        if offHand == nil then return false, true end
        weakest = weakest + offHand
    end
    if classID == ARMOR and ARMOR_SLOTS[equipLoc] and subclassID and subclassID >= 1 and subclassID <= 4 then
        local wornType = worn and subclassOf(worn)
        if subclassID ~= mainArmor() and subclassID ~= wornType then return false end
    end
    -- Clearly better: a score above by a little more than nothing
    local new, old = measure(link), weakest or 0
    if byScore then
        local margin = math.max(0.5, old * 0.02)
        if new <= old + margin then
            -- Scores alike, never lower: the item level decides (on an empty
            -- slot, a score of nothing only for armour, as plain white pieces)
            if new < old - 1e-6 then return false end
            if not worn and new == 0 and not ARMOR_SLOTS[equipLoc] then return false end
            if itemLevel(link) <= (worn and itemLevel(worn) or 0) then return false end
        end
    elseif new <= old then
        return false
    end
    return wearable(bag, slot)
end

---------------------------------------------------------------------------
-- The arrows on the bag buttons
---------------------------------------------------------------------------
local arrows = setmetatable({}, { __mode = "k" })
U.arrows = arrows
local bagFrames = {}

local function arrowFor(button)
    local arrow = arrows[button]
    if not arrow then
        arrow = button:CreateTexture(nil, "OVERLAY", nil, 4)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ARROW_ATLAS) then
            arrow:SetAtlas(ARROW_ATLAS, true)
        else
            -- Our own triangle, pointing up, in green
            arrow:SetTexture("Interface\\AddOns\\EasyController\\textures\\ck_tri")
            arrow:SetTexCoord(0, 1, 1, 0)
            arrow:SetVertexColor(0.25, 1, 0.25)
            arrow:SetSize(14, 14)
        end
        arrow:SetPoint("BOTTOMRIGHT", -1, 1)
        arrows[button] = arrow
    end
    return arrow
end

local waitingFrames = {}

function U:UpdateArrows(frame)
    if not (frame and frame.EnumerateValidItems and frame:IsShown()) then
        if frame then waitingFrames[frame] = nil end
        self.waiting = next(waitingFrames) ~= nil
        return
    end
    local on = enabled()
    local waiting = false
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button.GetBagID and button:GetBagID(), button:GetID()
        local link = on and bag and C_Container.GetContainerItemLink(bag, slot)
        local better, unknown = false, false
        if link then better, unknown = self:IsUpgrade(bag, slot, link) end
        waiting = waiting or unknown
        if better then
            arrowFor(button):Show()
        elseif arrows[button] then
            arrows[button]:Hide()
        end
    end
    waitingFrames[frame] = waiting or nil
    self.waiting = next(waitingFrames) ~= nil
end

function U:Refresh()
    for _, frame in ipairs(bagFrames) do self:UpdateArrows(frame) end
end

function U:HookBags()
    -- Every bag's frame: the backpack's, the bags', the reagent bag's
    local frames = { ContainerFrameCombinedBags }
    local count = NUM_CONTAINER_FRAMES or ((NUM_TOTAL_BAG_FRAMES or 12) + 1)
    for i = 1, count do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    for _, frame in ipairs(frames) do
        if frame and frame.UpdateItems then
            bagFrames[#bagFrames + 1] = frame
            hooksecurefunc(frame, "UpdateItems", function(self) U:UpdateArrows(self) end)
        end
    end
end

function U:Init()
    self:HookBags()
    local f = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
        "GET_ITEM_INFO_RECEIVED", "SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
        pcall(f.RegisterEvent, f, event)
    end
    f:SetScript("OnEvent", function(_, event)
        -- An item's data arrived: only when one was missing
        if event == "GET_ITEM_INFO_RECEIVED" and not U.waiting then return end
        U:Refresh()
        -- A level gained: the game may still give the old one right now
        if event == "PLAYER_LEVEL_UP" then C_Timer.After(1, function() U:Refresh() end) end
    end)
end
