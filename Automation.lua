local _, CK = ...
local L = CK.L

-- Module "automation": at a merchant, the grey (poor quality) items of the
-- bags are sold by themselves, then the equipment is repaired (with the
-- guild's money first when the guild allows it and the player wants it).
-- Only the game's own merchant functions, out of combat; a line in the chat
-- says what it brought and what it cost.
local A = {}
CK.Automation = A

local POOR = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
-- One sale at a time: the server takes them in turn
local SELL_GAP = 0.15

local function settings() return CK.db.settings end

local function money(amount)
    local coins = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
    if coins then return coins(amount) end
    if GetMoneyString then return GetMoneyString(amount) end
    return format("%dg %ds %dc", math.floor(amount / 10000), math.floor(amount / 100) % 100, amount % 100)
end

local function itemPrice(item)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    return get and select(11, get(item)) or 0
end

local function excluded(bag)
    local ok, flagged = pcall(function()
        if bag == 0 then
            return C_Container.GetBackpackSellJunkDisabled and C_Container.GetBackpackSellJunkDisabled()
        end
        local flag = Enum and Enum.BagSlotFlags and Enum.BagSlotFlags.ExcludeJunkSell
        return flag and C_Container.GetBagSlotFlag and C_Container.GetBagSlotFlag(bag, flag)
    end)
    return ok and flagged or false
end

-- The grey items of the bags a merchant buys: { bag, slot, link, value }
function A:Junk()
    local list = {}
    -- The quest items known even with their module off: never sold
    local QI = CK.QuestItems
    if QI and not settings().modules.questItems then
        pcall(QI.ScanBags, QI)
        pcall(QI.ScanQuests, QI)
    end
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, (not excluded(bag)) and C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == POOR and not info.hasNoValue and not info.isLocked
                and not (CK.QuestItems and CK.QuestItems:IsQuestItem(info.itemID)) then
                list[#list + 1] = { bag = bag, slot = slot, link = info.hyperlink,
                    value = (itemPrice(info.hyperlink or info.itemID) or 0) * (info.stackCount or 1) }
            end
        end
    end
    return list
end

-- Sold one after the other; then onDone
function A:SellJunk(onDone)
    if self.selling then return end
    local list = self:Junk()
    if #list == 0 then
        if onDone then
            local tries = 0
            local function settled()
                if not self.atMerchant or InCombatLockdown() then return end
                tries = tries + 1
                for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
                    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        if info and info.isLocked and tries < 20 then return C_Timer.After(0.1, settled) end
                    end
                end
                onDone()
            end
            settled()
        end
        return
    end
    self.selling = true
    local sold, total, i = 0, 0, 0
    local soldItems = {}
    local start = GetMoney()
    local function step()
        i = i + 1
        local item = list[i]
        if not item or not self.atMerchant or InCombatLockdown() then
            self.selling = false
            -- The merchant pays a moment after each sale: once the items
            -- sold left the bags, what was paid (an item whose price was
            -- unknown when listed counts too), then onDone
            local tries = 0
            local function paid()
                tries = tries + 1
                local waiting = GetMoney() < start + total
                for _, s in ipairs(soldItems) do
                    local info = C_Container.GetContainerItemInfo(s.bag, s.slot)
                    if info and info.hyperlink == s.link then waiting = true end
                end
                if waiting and tries < 20 and self.atMerchant and not InCombatLockdown() then
                    return C_Timer.After(0.1, paid)
                end
                if sold > 0 then CK:Print(L.MSG_JUNK_SOLD, sold, money(math.max(total, GetMoney() - start))) end
                if onDone and self.atMerchant and not InCombatLockdown() then onDone() end
            end
            paid()
            return
        end
        -- Still that item there (nothing moved meanwhile)
        local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
        if info and info.hyperlink == item.link and not info.isLocked then
            C_Container.UseContainerItem(item.bag, item.slot)
            -- Its price unknown when listed (item data not loaded yet): read
            -- again now, for the total in the chat
            local value = item.value
            if value == 0 then value = (itemPrice(info.hyperlink or info.itemID) or 0) * (info.stackCount or 1) end
            sold, total = sold + 1, total + value
            soldItems[#soldItems + 1] = { bag = item.bag, slot = item.slot, link = item.link }
        end
        C_Timer.After(SELL_GAP, step)
    end
    step()
end

-- What the guild lets the player take for repairs (-1: no limit)
local function guildFunds()
    if not (CanGuildBankRepair and CanGuildBankRepair()) then return 0 end
    local allowed = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
    local bank = GetGuildBankMoney and GetGuildBankMoney() or 0
    if allowed == -1 then return bank end
    return math.min(allowed, bank)
end

function A:Repair()
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end
    if settings().automation.guildRepair and guildFunds() >= cost then
        RepairAllItems(true)
        CK:Print(L.MSG_REPAIRED_GUILD, money(cost))
    elseif GetMoney() >= cost then
        RepairAllItems()
        CK:Print(L.MSG_REPAIRED, money(cost))
    else
        CK:Print(L.MSG_REPAIR_SHORT, money(cost))
    end
end

function A:Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("MERCHANT_SHOW")
    f:RegisterEvent("MERCHANT_CLOSED")
    f:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then
            A.atMerchant = false
            return
        end
        A.atMerchant = true
        if InCombatLockdown() then return end
        local mods = settings().modules
        -- The junk's money first: it can pay for the repair
        local function repair()
            if settings().modules.autoRepair then A:Repair() end
        end
        if mods.sellJunk then
            A:SellJunk(repair)
        else
            repair()
        end
    end)
end
