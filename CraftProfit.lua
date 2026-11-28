local _, CK = ...
local L = CK.L

---------------------------------------------------------------------------
-- The profit of each recipe in the professions window (Comfort › Auction
-- house › Profit in the professions window, off by default; asked). Next to
-- each recipe known, what crafting it to sell brings with everything
-- bought: the reagents in the bags are never counted ("si je l'ai déjà
-- farmé, c'est du gain pur"). Each reagent at the merchant's price when one
-- sells it (noted at his window, for every character of the account), else
-- at the auction house's lowest (the last scan, AuctionPrices.lua); the
-- items made sold 1 copper under the lowest (Post all's rule), less the
-- auction house's cut and the deposit. Green, red when negative (asked), "?"
-- when a price is missing. The details in the crafted item's tooltip (the
-- recipe form's big icon): the form has no room left, its two columns of
-- reagents fill it. Nothing of the game's is changed but its recipe names'
-- width, shortened only as much as our figure needs (put back when off):
-- a text of ours on each row, its list's own callback (the game calls it
-- through a barrier), the tooltip API.
---------------------------------------------------------------------------
local CP = {}
CK.CraftProfit = CP
local AP = CK.AuctionPrices

local PROFESSIONS_ADDON = "Blizzard_Professions"
local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
local ITEM_RECIPE = Enum and Enum.TradeskillRecipeType and Enum.TradeskillRecipeType.Item or 1
local UNLIMITED = -1           -- a merchant's stock that never runs out
local BIND_PICKUP, BIND_QUEST = 1, 4
local LABEL_LEFT = 25          -- where a row's name starts (its skill-up icon's room)
local GAP = 10                 -- between the name (or its count) and our figure
local GREEN, RED, GREY = { 0.25, 0.9, 0.25 }, { 1, 0.25, 0.25 }, { 0.6, 0.6, 0.6 }
local WHITE, GOLD = { 1, 1, 1 }, { 1, 0.82, 0 }

local function settings() return CK.db.settings.auction end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
local function plain(v) return not secret(v) and v or nil end

function CP:On()
    return AP:On() and settings().crafts == true
end

---------------------------------------------------------------------------
-- Merchants' prices: ControllerKeyboardPrices.merchant[itemID] = copper for
-- one, the cheapest seen (a reputation's discount), for every realm: the
-- game tells addons what a merchant pays, never what he asks, outside his
-- window. Only his own stock that never runs out, for money only
---------------------------------------------------------------------------
local function merchantBook()
    AP:Book()
    local all = ControllerKeyboardPrices
    all.merchant = type(all.merchant) == "table" and all.merchant or {}
    return all.merchant
end

function CP:MerchantPrice(id)
    local each = type(id) == "number" and merchantBook()[id]
    return type(each) == "number" and each or nil
end

local function merchantItem(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(i)
        if type(info) ~= "table" then return nil end
        return plain(info.price), plain(info.stackCount), plain(info.numAvailable), plain(info.hasExtendedCost)
    end
    if GetMerchantItemInfo then
        local _, _, price, stack, available, _, _, extended = GetMerchantItemInfo(i)
        return plain(price), plain(stack), plain(available), plain(extended)
    end
end

function CP:NoteMerchant()
    if not (self:On() and GetMerchantNumItems and GetMerchantItemID) then return end
    local book, changed = merchantBook(), false
    for i = 1, GetMerchantNumItems() or 0 do
        local id = plain(GetMerchantItemID(i))
        local price, stack, available, extended = merchantItem(i)
        if type(id) == "number" and type(price) == "number" and price > 0 and not extended
            and available == UNLIMITED and type(stack) == "number" and stack >= 1 then
            local each = price / stack
            if not book[id] or each < book[id] then
                book[id] = each
                changed = true
            end
        end
    end
    if changed then self:Refresh() end
end

---------------------------------------------------------------------------
-- A recipe's numbers
---------------------------------------------------------------------------
local schematics = {}
local function schematicOf(recipeID)
    local s = schematics[recipeID]
    if s == nil then
        local ok, got = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
        s = ok and type(got) == "table" and got or false
        schematics[recipeID] = s
    end
    return s or nil
end

local function itemInfo(id)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get then return nil end
    return get(id)
end

local waiting = {}
-- Its stack size and whether it binds when picked up (nil: not loaded yet,
-- asked to the game)
local function loaded(id)
    local name, _, _, _, _, _, _, stack, _, _, _, _, _, bind = itemInfo(id)
    if not name then
        waiting[id] = true
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return nil
    end
    return plain(stack) or 1, not secret(bind) and (bind == BIND_PICKUP or bind == BIND_QUEST)
end

-- What one of it costs bought, and where: the cheaper of the merchant and
-- the auction house (nil: neither known)
function CP:ReagentCost(id)
    local vendor = self:MerchantPrice(id)
    local auction = type(id) == "number" and AP:Price(id) or nil
    if vendor and (not auction or vendor <= auction) then return vendor, "merchant" end
    if auction then return auction, "auction" end
    return nil
end

-- What one sells for: 1 copper under the lowest listed at the last scan
-- (Post all's rule; whole silver where copper isn't taken), the last price
-- as is when none was listed then; nil: never seen
function CP:SalePrice(id)
    local price, _, listed = AP:Price(id)
    if not price then return nil end
    if not listed then return price end
    local step = AP.PriceStep()
    return math.max(step, math.floor((price - step) / step) * step)
end

-- The deposit for n of it in one auction: the game's own for an item that
-- stacks when it gives it, else the usual 1 silver (Post all's)
local function deposit(id, n, stack)
    local calc = C_AuctionHouse and C_AuctionHouse.CalculateCommodityDeposit
    if calc and stack > 1 then
        local ok, d = pcall(calc, id, AP.DURATION, math.max(1, math.floor(n + 0.5)))
        if ok and type(d) == "number" and not secret(d) then return d end
    end
    return AP.POST_FEE
end

-- A recipe crafted to sell, everything bought: { item, made (on average),
-- each (the sale for one), sale, fees, reagents = { { id, count, each,
-- source } }, profit (nil: a price missing) }. Nil when it makes nothing
-- to sell (an enchantment, an item bound when picked up) or its item isn't
-- loaded yet
function CP:Craft(recipeID)
    local s = type(recipeID) == "number" and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and schematicOf(recipeID)
    if not s or (s.recipeType or ITEM_RECIPE) ~= ITEM_RECIPE or type(s.outputItemID) ~= "number" then return nil end
    local id = s.outputItemID
    local stack, bound = loaded(id)
    if not stack or bound then return nil end
    local made = ((s.quantityMin or 1) + (s.quantityMax or s.quantityMin or 1)) / 2
    if made <= 0 then made = 1 end
    local c = { item = id, made = made, reagents = {} }
    local complete = true
    c.each = self:SalePrice(id)
    if c.each then
        c.sale = c.each * made
        c.fees = c.sale * (1 - AP.CUT) + deposit(id, made, stack)
    else
        complete = false
    end
    local spent = 0
    for _, slot in ipairs(s.reagentSlotSchematics or {}) do
        -- (the basic ones: optional and finishing reagents left out)
        if slot.reagentType == BASIC and type(slot.quantityRequired) == "number" and slot.quantityRequired > 0 then
            local best, from, bestID
            for _, r in ipairs(slot.reagents or {}) do
                local each, source = self:ReagentCost(r.itemID)
                if each and (not best or each < best) then best, from, bestID = each, source, r.itemID end
            end
            local first = slot.reagents and slot.reagents[1]
            local entry = { id = bestID or (first and first.itemID), count = slot.quantityRequired, each = best, source = from }
            c.reagents[#c.reagents + 1] = entry
            if best then spent = spent + best * slot.quantityRequired else complete = false end
        end
    end
    c.spent = spent
    if complete then c.profit = c.sale - c.fees - spent end
    return c
end

---------------------------------------------------------------------------
-- The figure: "+1g 20s", "-35s", "+8c" (two units at most), in the game's
-- own letters for its money
---------------------------------------------------------------------------
local function round(v) return math.floor(v + 0.5) end
-- (the game's letters only when plain: never colour codes over ours)
local function symbol(v, default)
    return type(v) == "string" and v ~= "" and #v <= 4 and not v:find("|", 1, true) and v or default
end

function CP.Short(copper)
    copper = round(copper)
    local sign = copper > 0 and "+" or (copper < 0 and "-" or "")
    copper = math.abs(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local G, S, C = symbol(GOLD_AMOUNT_SYMBOL, "g"), symbol(SILVER_AMOUNT_SYMBOL, "s"), symbol(COPPER_AMOUNT_SYMBOL, "c")
    local parts = {}
    if g > 0 then
        parts[1] = g .. G
        if s > 0 then parts[2] = s .. S end
    elseif s > 0 then
        parts[1] = s .. S
        if c > 0 then parts[2] = c .. C end
    else
        parts[1] = c .. C
    end
    return sign .. table.concat(parts, " ")
end

local function colorOf(profit)
    if profit == nil then return GREY end
    local p = round(profit)
    if p > 0 then return GREEN end
    if p < 0 then return RED end
    return WHITE
end

---------------------------------------------------------------------------
-- The rows of the game's recipe list
---------------------------------------------------------------------------
local texts = setmetatable({}, { __mode = "k" })   -- row -> our figure
local widths = setmetatable({}, { __mode = "k" })  -- row -> its name's width as the game set it

local function recipeOf(row)
    if not row.GetElementData then return nil end
    local ok, node = pcall(row.GetElementData, row)
    if not ok or type(node) ~= "table" then return nil end
    local data = node.GetData and node:GetData() or node
    return type(data) == "table" and type(data.recipeInfo) == "table" and data.recipeInfo or nil
end

local function textOf(row)
    local fs = texts[row]
    if not fs then
        fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        texts[row] = fs
    end
    return fs
end

-- Its name shortened only as much as needed: left of the count (anchored
-- to the name) and of our figure
local function fit(row, fs)
    local label, base = row.Label, widths[row]
    if not (label and base) then return end
    local left = LABEL_LEFT
    local ll, rl = label.GetLeft and label:GetLeft(), row.GetLeft and row:GetLeft()
    if type(ll) == "number" and type(rl) == "number" and not secret(ll) and not secret(rl) then left = ll - rl end
    local count = row.Count and row.Count:IsShown() and row.Count:GetStringWidth() or 0
    local room = row:GetWidth() - left - count - fs:GetStringWidth() - GAP
    label:SetWidth(math.max(20, math.min(base, room)))
end

local function restore(row)
    if texts[row] then texts[row]:Hide() end
    if row.Label and widths[row] then row.Label:SetWidth(widths[row]) end
end

-- One row: after the game's Init (initialised: its name's width is the
-- game's again), or again for new prices
function CP:UpdateRow(row, initialised)
    if type(row) ~= "table" then return end
    if initialised and row.Label then widths[row] = row.Label:GetWidth() end
    local info = self:On() and recipeOf(row)
    local c = info and info.learned and self:Craft(info.recipeID)
    if not c then return restore(row) end
    local fs = textOf(row)
    fs:ClearAllPoints()
    if row.LockedIcon and row.LockedIcon:IsShown() then
        fs:SetPoint("RIGHT", row.LockedIcon, "LEFT", -2, 0)
    else
        fs:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    end
    fs:SetText(c.profit and CP.Short(c.profit) or "?")
    local color = colorOf(c.profit)
    fs:SetTextColor(color[1], color[2], color[3])
    fs:Show()
    fit(row, fs)
end

local function recipeBox()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local list = page and page.RecipeList
    return list and list.ScrollBox
end

-- Every row shown again (an option, new prices, an item loaded)
function CP:Refresh()
    local box = self.hooked and recipeBox()
    if not (box and box.ForEachFrame) then return end
    box:ForEachFrame(function(row) CP:UpdateRow(row, false) end)
end

function CP:Apply()
    self:Refresh()
end

-- Once for a burst (items loaded one by one, the bags changing)
function CP:RefreshSoon(delay)
    if self.refreshing then return end
    self.refreshing = true
    C_Timer.After(delay or 0, function()
        CP.refreshing = nil
        CP:Refresh()
    end)
end

-- The list's own callback, once the game's window is loaded: each row as
-- the game initialises it (a barrier between its code and ours)
function CP:HookList()
    if self.hooked then return end
    local box = recipeBox()
    local event = ScrollBoxListMixin and ScrollBoxListMixin.Event and ScrollBoxListMixin.Event.OnInitializedFrame
    if not (box and box.RegisterCallback and event) then return end
    self.hooked = true
    box:RegisterCallback(event, function(_, row) CP:UpdateRow(row, true) end, self)
    if box.ForEachFrame then box:ForEachFrame(function(row) CP:UpdateRow(row, true) end) end
end

---------------------------------------------------------------------------
-- The details: in the crafted item's tooltip, shown from the recipe form's
-- big icon (the game sets it every frame while it is pointed at)
--   Crafted to sell (everything bought):
--     Auction house (x1)                         49s 99c
--     Cut (5%) and deposit                       -3s 50c
--     Linen Cloth x3 (auction house)                -30c
--     Coarse Thread x1 (merchant)                   -10c
--     Profit                                    +46s 9c
---------------------------------------------------------------------------
local function money(amount)
    local coins = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
    amount = round(amount)
    local sign = amount < 0 and "-" or ""
    amount = math.abs(amount)
    if coins then return sign .. coins(amount) end
    return sign .. CP.Short(amount)
end

local function count(n)
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return format("%.1f", n)
end

function CP:AddLines(tooltip)
    if not self:On() or tooltip ~= GameTooltip or not tooltip.GetOwner then return end
    local owner = tooltip:GetOwner()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    if not (form and owner ~= nil and owner == form.OutputIcon) then return end
    local s = form.recipeSchematic
    local c = type(s) == "table" and self:Craft(s.recipeID)
    if not c then return end
    tooltip:AddLine(L.CP_HEADER, GOLD[1], GOLD[2], GOLD[3])
    local made = count(c.made)
    if c.sale then
        tooltip:AddDoubleLine(format(L.CP_SALE, made), money(c.sale), 1, 1, 1, 1, 1, 1)
        tooltip:AddDoubleLine(L.CP_FEES, money(-c.fees), 1, 1, 1, RED[1], RED[2], RED[3])
    else
        tooltip:AddDoubleLine(format(L.CP_SALE, made), L.AH_NEVER_SEEN, 1, 1, 1, GREY[1], GREY[2], GREY[3])
    end
    for _, r in ipairs(c.reagents) do
        local name = r.id and C_Item.GetItemNameByID and C_Item.GetItemNameByID(r.id)
        if not name and r.id and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.id) end
        local from = r.source == "merchant" and L.CP_FROM_MERCHANT or (r.source == "auction" and L.CP_FROM_AUCTION or "?")
        local left = format(L.CP_REAGENT, name or ("item:" .. tostring(r.id)), count(r.count), from)
        if r.each then
            tooltip:AddDoubleLine(left, money(-r.each * r.count), 1, 1, 1, RED[1], RED[2], RED[3])
        else
            tooltip:AddDoubleLine(left, "?", 1, 1, 1, GREY[1], GREY[2], GREY[3])
        end
    end
    local color = colorOf(c.profit)
    if c.profit then
        local p = round(c.profit)
        tooltip:AddDoubleLine(L.CP_PROFIT, (p > 0 and "+" or "") .. money(p), GOLD[1], GOLD[2], GOLD[3],
            color[1], color[2], color[3])
    else
        tooltip:AddDoubleLine(L.CP_PROFIT, "?", GOLD[1], GOLD[2], GOLD[3], GREY[1], GREY[2], GREY[3])
        tooltip:AddLine(L.CP_MISSING, GREY[1], GREY[2], GREY[3], true)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function CP:Init()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip) CP:AddLines(tooltip) end)
    end
    local f = CreateFrame("Frame")
    self.events = f
    for _, event in ipairs({ "ADDON_LOADED", "MERCHANT_SHOW", "MERCHANT_UPDATE", "GET_ITEM_INFO_RECEIVED" }) do
        pcall(f.RegisterEvent, f, event)
    end
    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == PROFESSIONS_ADDON then CP:HookList() end
        elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
            CP:NoteMerchant()
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            -- An item made by a recipe shown: its rows again
            if waiting[arg1] then
                waiting[arg1] = nil
                CP:RefreshSoon(0.2)
            end
        end
    end)
    -- The game's craftable counts written again (the bags changed), not its
    -- rows: our room left of them again, once it is done
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.RefreshCraftableCount", function()
            CP:RefreshSoon(0)
        end, CP)
    end
    -- Already loaded (a /reload with the window opened once)
    self:HookList()
end
