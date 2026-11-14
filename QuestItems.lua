local _, CK = ...
local L = CK.L

-- Module "quest items": an orange "Quest item: do not sell" line in item
-- tooltips, and a warning (with the buyback reminder) when one is sold to a
-- merchant. Nothing here touches the game's bag or merchant frames: the
-- tooltip is extended through the tooltip API, sales are detected from the
-- buyback list.
--
-- The game itself only marks quest-class items and quest starters. The items
-- a quest asks to collect (cloth, ore, meat...) are ordinary trade goods: they
-- are found by matching the item objectives of the quest log by name.
local QI = {}
CK.QuestItems = QI

local ORANGE = { 1, 0.5, 0.1 }
local QUEST_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
local QUEST_BIND = Enum and Enum.ItemBind and Enum.ItemBind.Quest or 4

local questItemIDs = {}     -- itemID -> true, from the bags' quest info
local objectiveNames = {}   -- item name -> quest title, from the quest objectives
local buyback = {}          -- links in the merchant's buyback list

local function enabled()
    return CK.db and CK.db.settings.modules.questItems
end

local function itemIDFromLink(link)
    if type(link) == "number" then return link end
    return link and tonumber(link:match("item:(%d+)"))
end

local function itemInfo(item)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if get then return get(item) end
end

local function classOf(item)
    if C_Item and C_Item.GetItemInfoInstant then
        return select(6, C_Item.GetItemInfoInstant(item))
    elseif GetItemInfoInstant then
        return select(6, GetItemInfoInstant(item))
    end
end

function QI:IsQuestItem(item)
    if not item then return false end
    local id = itemIDFromLink(item)
    if id and questItemIDs[id] then return true end
    if classOf(item) == QUEST_CLASS then return true end
    local name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = itemInfo(item)
    if bindType == QUEST_BIND then return true end
    return name ~= nil and objectiveNames[name] ~= nil
end

-- The quest that asks for an item (an objective "Linen Cloth: 2/6")
function QI:ObjectiveQuest(item)
    local name = item and itemInfo(item)
    local quest = name and objectiveNames[name]
    return type(quest) == "string" and quest or nil
end

---------------------------------------------------------------------------
-- Bags: items the game knows are for a quest
---------------------------------------------------------------------------
-- The bags worn, the reagent bag included
local NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

function QI:ScanBags()
    -- At a merchant the list only grows: a sold item must still be known
    if not self.atMerchant then wipe(questItemIDs) end
    if not (C_Container and C_Container.GetContainerNumSlots) then return end
    for bag = 0, NUM_BAGS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id then
                local info = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
                if info and (info.isQuestItem or info.questID) then
                    questItemIDs[id] = true
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Quest log: items to collect ("Linen Cloth: 2/6", "2/6 Linen Cloth")
---------------------------------------------------------------------------
local function objectiveItemName(text)
    -- No-break spaces (French "Étoffe de lin : 2/6") become plain spaces.
    -- Explicit space classes: %s also matches the 2nd byte of "à" here.
    local name = text:gsub("\194\160", " "):gsub("\226\128\175", " ")
    name = name:gsub("%d+[ \t]*/[ \t]*%d+", "")
    -- Separators and spaces around the count
    name = name:gsub("^[ \t:]+", ""):gsub("[ \t:]+$", "")
    if name ~= "" then return name end
end

function QI:ScanQuests()
    if not self.atMerchant then wipe(objectiveNames) end
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetQuestObjectives) then return end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            -- Finished objectives too: the items are needed until the quest is turned in
            for _, objective in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                if objective.type == "item" and objective.text then
                    local name = objectiveItemName(objective.text)
                    if name then objectiveNames[name] = info.title or true end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Tooltip line
---------------------------------------------------------------------------
local function feature(name)
    return enabled() and CK.db.settings.features[name]
end

local function addLine(tooltip, link)
    if not feature("questTooltip") or not QI:IsQuestItem(link) then return false end
    local quest = QI:ObjectiveQuest(link)
    tooltip:AddLine(quest and format(L.QUEST_ITEM_FOR, quest) or L.QUEST_ITEM_TIP, ORANGE[1], ORANGE[2], ORANGE[3], true)
    return true
end

function QI:HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
        -- The game shows (and resizes) the tooltip after the post-calls
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
            addLine(tooltip, CK.TooltipItemLink(tooltip, data))
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            if addLine(tooltip, select(2, tooltip:GetItem())) then tooltip:Show() end
        end)
    end
end

-- In WoW Forever's gamepad bags the tooltips can be turned off (right stick):
-- at a merchant, warn when the selection lands on a quest item
function QI:HookBagButtons()
    if not (EventRegistry and EventRegistry.RegisterCallback) then return end
    EventRegistry:RegisterCallback("ContainerFrameItemButton.EnterButton", function(_, button)
        if not (feature("questHoverAlert") and self.atMerchant and GetCVarBool("GamepadDisableTooltips")) then return end
        if not (button and button.GetBagID and C_Container and C_Container.GetContainerItemLink) then return end
        local link = C_Container.GetContainerItemLink(button:GetBagID(), button:GetID())
        if link and self:IsQuestItem(link) and UIErrorsFrame then
            UIErrorsFrame:AddMessage(L.QUEST_ITEM_TIP, ORANGE[1], ORANGE[2], ORANGE[3], 1)
        end
    end, self)
end

---------------------------------------------------------------------------
-- Bags: the items a quest asks to collect (meat, cloth...) get the border
-- the game puts on its own quest items, in orange. Only those: the game
-- already marks the quest items it knows. A texture of ours on each item
-- button, over the game's own (kept in our own table, nothing written in
-- the game's frames).
---------------------------------------------------------------------------
local QUEST_BORDER = TEXTURE_ITEM_QUEST_BORDER or "Interface\\ContainerFrame\\UI-Icon-QuestBorder"
local borders = setmetatable({}, { __mode = "k" })
local bagFrames = {}

local function borderFor(button)
    local border = borders[button]
    if not border then
        border = button:CreateTexture(nil, "OVERLAY", nil, 2)
        if button.IconQuestTexture then
            border:SetAllPoints(button.IconQuestTexture)
        else
            border:SetSize(37, 38)
            border:SetPoint("TOP")
        end
        border:SetTexture(QUEST_BORDER)
        -- The game's gold border, in our orange
        border:SetDesaturated(true)
        border:SetVertexColor(ORANGE[1], ORANGE[2], ORANGE[3])
        borders[button] = border
    end
    return border
end

-- The game draws its own border (or "!") on this bag slot
local function markedByGame(bag, slot)
    local info = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
    return info and (info.isQuestItem or info.questID) and true or false
end

function QI:UpdateBorders(frame)
    if not (frame and frame.EnumerateValidItems and frame:IsShown()) then return end
    local on = feature("questGlow")
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button.GetBagID and button:GetBagID(), button:GetID()
        local id = bag and C_Container.GetContainerItemID(bag, slot)
        local mark = on and id ~= nil and not markedByGame(bag, slot) and self:IsQuestItem(id)
        if mark then
            borderFor(button):Show()
        elseif borders[button] then
            borders[button]:Hide()
        end
    end
end

function QI:RefreshBorders()
    for _, frame in ipairs(bagFrames) do self:UpdateBorders(frame) end
end

function QI:HookBags()
    -- Every bag's frame: the backpack's, the bags', the reagent bag's
    local frames = { ContainerFrameCombinedBags }
    local count = NUM_CONTAINER_FRAMES or ((NUM_TOTAL_BAG_FRAMES or 12) + 1)
    for i = 1, count do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    for _, frame in ipairs(frames) do
        if frame and frame.UpdateItems then
            bagFrames[#bagFrames + 1] = frame
            hooksecurefunc(frame, "UpdateItems", function(self) QI:UpdateBorders(self) end)
        end
    end
end

---------------------------------------------------------------------------
-- Merchant: a sold quest item shows up in the buyback list
---------------------------------------------------------------------------
local function snapshotBuyback()
    wipe(buyback)
    for i = 1, GetNumBuybackItems and GetNumBuybackItems() or 0 do
        local link = GetBuybackItemLink(i)
        if link then buyback[link] = (buyback[link] or 0) + 1 end
    end
end

function QI:CheckSales()
    if not (feature("questSellAlert") and self.atMerchant) then return end
    local now = {}
    for i = 1, GetNumBuybackItems and GetNumBuybackItems() or 0 do
        local link = GetBuybackItemLink(i)
        if link then
            now[link] = (now[link] or 0) + 1
            if now[link] > (buyback[link] or 0) and self:IsQuestItem(link) then
                if UIErrorsFrame then UIErrorsFrame:AddMessage(L.QUEST_ITEM_SOLD_SHORT, ORANGE[1], ORANGE[2], ORANGE[3], 1) end
                CK:Print(L.QUEST_ITEM_SOLD, link)
            end
        end
    end
    buyback = now
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function QI:Init()
    self:HookTooltips()
    self:HookBagButtons()
    self:HookBags()
    local f = CreateFrame("Frame")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("MERCHANT_SHOW")
    f:RegisterEvent("MERCHANT_CLOSED")
    f:RegisterEvent("MERCHANT_UPDATE")
    f:SetScript("OnEvent", function(_, event)
        -- Left the merchant: so, whatever the module's state
        if event == "MERCHANT_CLOSED" then QI.atMerchant = false end
        if not enabled() then return end
        if event == "MERCHANT_SHOW" then
            QI:ScanBags()
            QI:ScanQuests()
            QI.atMerchant = true
            snapshotBuyback()
        elseif event == "MERCHANT_CLOSED" then
            QI.atMerchant = false
            QI:ScanBags()
            QI:ScanQuests()
        elseif event == "MERCHANT_UPDATE" then
            QI:CheckSales()
        elseif event == "QUEST_LOG_UPDATE" then
            QI:ScanQuests()
            -- A quest taken or turned in: other items need the border
            QI:RefreshBorders()
        else
            -- Sales show up in the buyback list after the bag update
            QI:CheckSales()
            QI:ScanBags()
        end
    end)
    self:ScanBags()
    self:ScanQuests()
end
