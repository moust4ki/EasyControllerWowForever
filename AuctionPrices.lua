local _, CK = ...
local L = CK.L

---------------------------------------------------------------------------
-- Auction house prices (Comfort › Auction house, off by default; asked). A
-- button under the game's auction house window (or its key binding) reads
-- the whole house in one go (the game's C_AuctionHouse.ReplicateItems,
-- allowed once in a while): the lowest buyout of each item, for one, how
-- many are listed, when it was seen, and the lowest of each of the last 14
-- days (their median: its usual price), for every character of the account
-- (ControllerKeyboardPrices, by realm and faction). Item tooltips then show
-- them with the merchant's price and where to sell: the auction house when
-- its price less its 5 % cut is more than the merchant's (never for an item
-- bound to the player). Shift (LT) held: for the whole stack. The bags mark
-- with a gold coin the items better sold there. Nothing of the game's is
-- changed: its tooltips are extended through the tooltip API, the coin is
-- a texture of ours on its buttons.
---------------------------------------------------------------------------
local AP = {}
CK.AuctionPrices = AP

local SCAN_EVERY = 15 * 60   -- the game's limit for a whole scan
local CUT = 0.95             -- what the seller gets: the auction house takes 5 %
local POST_FEE = 100         -- what posting one auction costs (1 silver; asked: counted)
local SILVER = 100           -- auction prices go by whole silver (the game's rule)
local DURATION = 2           -- auctions posted for 24 h (1: 12 h, 3: 48 h)
local CHUNK = 500            -- auctions read a frame (never the whole list at once)
local HISTORY_DAYS = 14      -- days of lowest prices kept for the usual price
local WAIT_INFO = 4          -- seconds given to the items not loaded yet
local ANSWER_WAIT = 60       -- seconds for the game's answer
local CAGED_PET = 82800      -- battle pets: one item for every pet, left out
local COIN = "Interface\\MoneyFrame\\UI-GoldIcon"
local GOLD, GREY = { 1, 0.82, 0 }, { 0.6, 0.6, 0.6 }
local GREEN, YELLOW = { 0.25, 0.9, 0.25 }, { 1, 0.82, 0 }

local function settings() return CK.db.settings.auction end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

function AP:On()
    return CK.db ~= nil and settings().enabled == true
end

local function money(amount)
    local coins = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
    if coins then return coins(amount) end
    if GetMoneyString then return GetMoneyString(amount) end
    return format("%dg %ds %dc", math.floor(amount / 10000), math.floor(amount / 100) % 100, amount % 100)
end

---------------------------------------------------------------------------
-- The prices: ControllerKeyboardPrices.realms["Realm-Faction"] = { scanned
-- = server time of the last scan, listed = items then, auctions = how many,
-- items = { [key] = { lowest price for one (copper), server time seen, how
-- many listed then, { [day] = that day's lowest } (the last 14 days) } } }
---------------------------------------------------------------------------
local function realmKey()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or (GetRealmName and GetRealmName())
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if secret(realm) then realm = nil end
    if secret(faction) then faction = nil end
    return tostring(realm or "?") .. "-" .. tostring(faction or "?")
end

function AP:Book()
    if type(ControllerKeyboardPrices) ~= "table" then ControllerKeyboardPrices = {} end
    local all = ControllerKeyboardPrices
    all.version = all.version or 1
    all.realms = type(all.realms) == "table" and all.realms or {}
    local key = realmKey()
    local book = all.realms[key]
    if type(book) ~= "table" then
        book = {}
        all.realms[key] = book
    end
    book.items = type(book.items) == "table" and book.items or {}
    return book
end

-- An item's key: its ID, with its random suffix ("of the Bear": a price of
-- its own) when it has one
function AP.KeyOf(item)
    if type(item) == "number" then return item end
    if type(item) ~= "string" or secret(item) then return nil end
    local id, suffix = item:match("item:(%d+):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:(%-?%d*)")
    id = tonumber(id or item:match("item:(%d+)"))
    if not id then return nil end
    suffix = tonumber(suffix)
    if suffix and suffix ~= 0 then return id .. ":" .. suffix end
    return id
end

local function entryOf(self, item)
    local key = AP.KeyOf(item)
    if not key then return nil end
    local book = self:Book()
    local e = book.items[key]
    if type(e) ~= "table" or type(e[1]) ~= "number" then return nil end
    return e, book
end

-- Its lowest price for one, when it was seen, whether it was listed at the
-- last scan, how many were then (nil: never seen)
function AP:Price(item)
    local e, book = entryOf(self, item)
    if not e then return nil end
    return e[1], e[2], e[2] ~= nil and e[2] == book.scanned, e[3]
end

local function median(list)
    table.sort(list)
    local n = #list
    if n % 2 == 1 then return list[(n + 1) / 2] end
    return math.floor((list[n / 2] + list[n / 2 + 1]) / 2 + 0.5)
end

-- Its usual price: the median of each day's lowest, over the last 14 days
-- (nil: seen on fewer than 2 days)
function AP:Usual(item)
    local e = entryOf(self, item)
    local days = e and type(e[4]) == "table" and e[4]
    if not days then return nil end
    local today, list = math.floor(GetServerTime() / 86400), {}
    for day, low in pairs(days) do
        if type(day) == "number" and day > today - HISTORY_DAYS and type(low) == "number" then list[#list + 1] = low end
    end
    if #list < 2 then return nil end
    return median(list)
end

local function itemInfo(item)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get then return nil end
    return get(item)
end

local function sellPrice(item)
    local price = select(11, itemInfo(item))
    return type(price) == "number" and not secret(price) and price or nil
end

-- Bound to whoever picks it up (or to a quest): never at the auction house
local BIND_PICKUP, BIND_QUEST = 1, 4
local function bindsOnPickup(item)
    local bind = select(14, itemInfo(item))
    return not secret(bind) and (bind == BIND_PICKUP or bind == BIND_QUEST)
end

-- What posting n of it in one auction at `each` brings: less the cut and
-- the posting fee
function AP.Net(each, n)
    return each * (n or 1) * CUT - POST_FEE
end

-- Where to sell n of it (one auction, 1: a single one): "auction" (its
-- price less the cut and the posting fee beats the merchant's) or
-- "merchant"; nil while unknown. Then the two prices for one
function AP:Verdict(item, n)
    n = n or 1
    local price = self:Price(item)
    local vendor = price and sellPrice(item)
    if not vendor then return nil end
    return AP.Net(price, n) > vendor * n and "auction" or "merchant", price, vendor
end

-- "5 min", "3 h", "2 d"
function AP.Age(seen)
    local s = math.max(0, GetServerTime() - (seen or 0))
    if s < 3600 then return format(L.AH_AGE_MIN, math.max(1, math.floor(s / 60))) end
    if s < 86400 then return format(L.AH_AGE_H, math.floor(s / 3600)) end
    return format(L.AH_AGE_D, math.floor(s / 86400))
end

---------------------------------------------------------------------------
-- The tooltip lines
---------------------------------------------------------------------------
local BOUND = {}
local function boundText(text)
    if not next(BOUND) then
        for _, k in ipairs({ "ITEM_SOULBOUND", "ITEM_BIND_QUEST", "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND",
            "ITEM_ACCOUNTBOUND_UNTIL_EQUIP" }) do
            if type(_G[k]) == "string" then BOUND[_G[k]] = true end
        end
    end
    return BOUND[text] == true
end

-- Bound to the player (no auction for it): said by the tooltip's lines
local function bound(data)
    for _, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
        local text = line.leftText
        if type(text) == "string" and not secret(text) and boundText(text) then return true end
    end
    return false
end

-- How many under the tooltip: the stack of the bag slot it is for
local function stackOf(tooltip)
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if not (type(owner) == "table" and owner.GetBagID and owner.GetID and C_Container) then return 1 end
    local ok, info = pcall(function() return C_Container.GetContainerItemInfo(owner:GetBagID(), owner:GetID()) end)
    local n = ok and type(info) == "table" and info.stackCount
    if type(n) ~= "number" or secret(n) or n < 1 then return 1 end
    return n
end

-- Its lines, every item (grey, white, green, trade goods, food...):
--   Auction house (seen 2 h ago, 140 listed)        1g 20s
--   Usual (14-day median)                           1g 05s
--   Merchant                                           13c
--   → Sell at the auction house  (or → Merchant)
-- for one, or with Shift (LT) held for the whole stack. Never seen: "Auction
-- house: never seen". Bound to the player: the merchant only. Returns
-- whether a line was added.
function AP:AddLines(tooltip, data)
    if not self:On() or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then return false end
    local link = data and (data.hyperlink or (data.id and ("item:" .. data.id)))
    if not link and tooltip.GetItem then link = select(2, tooltip:GetItem()) end
    if type(link) ~= "string" or secret(link) or not AP.KeyOf(link) then return false end
    local n = stackOf(tooltip)
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    if secret(shift) or not shift then n = 1 end
    local function value(copper) return money(math.floor(copper * n + 0.5)) end
    local vendor = sellPrice(link)
    local boundHere = bound(data) or bindsOnPickup(link)
    local price, seen, listed, count
    if not boundHere then
        price, seen, listed, count = self:Price(link)
        local label = n > 1 and format(L.AH_PRICE_STACK, n) or L.AH_PRICE
        if not price then
            tooltip:AddDoubleLine(label, L.AH_NEVER_SEEN, GREY[1], GREY[2], GREY[3], GREY[1], GREY[2], GREY[3])
        elseif listed then
            tooltip:AddDoubleLine(format(L.AH_PRICE_SEEN, label, AP.Age(seen), count or 0), value(price),
                GOLD[1], GOLD[2], GOLD[3], 1, 1, 1)
        else
            tooltip:AddDoubleLine(format(L.AH_PRICE_OLD, label, AP.Age(seen)), value(price),
                GREY[1], GREY[2], GREY[3], GREY[1], GREY[2], GREY[3])
        end
        local usual = price and self:Usual(link)
        if usual then
            tooltip:AddDoubleLine(L.AH_USUAL, value(usual), GREY[1], GREY[2], GREY[3], 1, 1, 1)
        end
    end
    if vendor and vendor > 0 then
        tooltip:AddDoubleLine(L.AH_MERCHANT, value(vendor), GOLD[1], GOLD[2], GOLD[3], 1, 1, 1)
    elseif vendor == 0 then
        tooltip:AddDoubleLine(L.AH_MERCHANT, L.AH_NO_MERCHANT, GOLD[1], GOLD[2], GOLD[3], GREY[1], GREY[2], GREY[3])
    end
    -- Where to sell what is under the tooltip (the stack in the bags: one
    -- auction, one fee); an item bound to the player: the merchant, if he
    -- buys it
    local whole = stackOf(tooltip)
    if price and vendor and AP.Net(price, whole) > vendor * whole then
        tooltip:AddLine(L.AH_SELL_AUCTION, GREEN[1], GREEN[2], GREEN[3])
    elseif vendor and vendor > 0 and (price or boundHere) then
        tooltip:AddLine(L.AH_SELL_MERCHANT, YELLOW[1], YELLOW[2], YELLOW[3])
    end
    -- A stack, prices for one: how to see the whole stack's
    if whole > 1 and n == 1 and (price or (vendor and vendor > 0)) then
        tooltip:AddLine(format(L.AH_SHIFT_HINT, whole), GREY[1], GREY[2], GREY[3])
    end
    return true
end

function AP:HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        -- The game shows (and resizes) the tooltip after the post-calls
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            AP:AddLines(tooltip, data)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        -- An older client: its item tooltips' own script
        for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tooltip and tooltip.HookScript then
                tooltip:HookScript("OnTooltipSetItem", function(tt)
                    if AP:AddLines(tt, nil) then tt:Show() end
                end)
            end
        end
    end
end

-- Shift (LT) pressed or let go over an item: its tooltip again, for the
-- stack or for one
function AP:ModifierChanged(key)
    if not (self:On() and type(key) == "string" and key:find("SHIFT")) then return end
    local tt = GameTooltip
    if tt and tt.IsShown and tt:IsShown() and tt.GetItem and select(2, tt:GetItem()) and tt.RefreshData then
        pcall(tt.RefreshData, tt)
    end
end

---------------------------------------------------------------------------
-- Bags: a gold coin on the items better sold at the auction house (a
-- texture of ours on each item button, kept in our own table)
---------------------------------------------------------------------------
local marks = setmetatable({}, { __mode = "k" })
local bagFrames = {}

local function markFor(button)
    local mark = marks[button]
    if not mark then
        mark = button:CreateTexture(nil, "OVERLAY", nil, 3)
        mark:SetSize(13, 13)
        mark:SetPoint("TOPLEFT", 2, -2)
        mark:SetTexture(COIN)
        marks[button] = mark
    end
    return mark
end

-- A bag slot worth an auction: its link and count (nil: no)
function AP:SlotWorthIt(bag, slot)
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not (ok and type(info) == "table") or info.isBound == true then return nil end
    local link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot)
    local count = type(info.stackCount) == "number" and not secret(info.stackCount) and info.stackCount or 1
    if type(link) ~= "string" or secret(link) or bindsOnPickup(link) then return nil end
    if self:Verdict(link, count) ~= "auction" then return nil end
    return link, count, info.itemID
end

function AP:UpdateMarks(frame)
    if not (frame and frame.EnumerateValidItems and frame:IsShown()) then return end
    local on = self:On() and settings().marks
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button.GetBagID and button:GetBagID(), button:GetID()
        local show = false
        if on and bag then show = self:SlotWorthIt(bag, slot) ~= nil end
        if show then
            markFor(button):Show()
        elseif marks[button] then
            marks[button]:Hide()
        end
    end
end

function AP:RefreshMarks()
    for _, frame in ipairs(bagFrames) do self:UpdateMarks(frame) end
end

function AP:HookBags()
    -- Every bag's frame: the backpack's, the bags', the reagent bag's
    local frames = { ContainerFrameCombinedBags }
    local count = NUM_CONTAINER_FRAMES or ((NUM_TOTAL_BAG_FRAMES or 12) + 1)
    for i = 1, count do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    for _, frame in ipairs(frames) do
        if frame and frame.UpdateItems then
            bagFrames[#bagFrames + 1] = frame
            hooksecurefunc(frame, "UpdateItems", function(f) AP:UpdateMarks(f) end)
        end
    end
end

---------------------------------------------------------------------------
-- The scan: asked from the button, the game's answer read a few hundred
-- auctions a frame (tens of thousands on a busy realm), the items not
-- loaded yet given a moment
---------------------------------------------------------------------------
-- Seconds before the game allows another whole scan (0: now)
function AP:Wait()
    local scanned = self:Book().scanned
    if type(scanned) ~= "number" then return 0 end
    return math.max(0, scanned + SCAN_EVERY - GetServerTime())
end

function AP:Scan()
    if self.scanning or not self:On() then return end
    if not (AuctionHouseFrame and AuctionHouseFrame:IsShown() and C_AuctionHouse and C_AuctionHouse.ReplicateItems) then
        return
    end
    local wait = self:Wait()
    if wait > 0 then
        CK:Print(L.AH_TOO_SOON, math.ceil(wait / 60))
        return
    end
    local scan = { stage = "asked" }
    self.scanning = scan
    pcall(self.events.RegisterEvent, self.events, "REPLICATE_ITEM_LIST_UPDATE")
    C_AuctionHouse.ReplicateItems()
    C_Timer.After(ANSWER_WAIT, function()
        if AP.scanning == scan and scan.stage == "asked" then AP:Stop(L.AH_NO_ANSWER) end
    end)
    self:UpdateButton()
end

-- Stopped: said why, nothing kept
function AP:Stop(why)
    if not self.scanning then return end
    self.scanning = nil
    pcall(self.events.UnregisterEvent, self.events, "REPLICATE_ITEM_LIST_UPDATE")
    self.events:SetScript("OnUpdate", nil)
    if why then CK:Print(why) end
    self:UpdateButton()
end

-- The game's answer: read from the next frame on
function AP:Replicated()
    local scan = self.scanning
    if not (scan and scan.stage == "asked") then return end
    pcall(self.events.UnregisterEvent, self.events, "REPLICATE_ITEM_LIST_UPDATE")
    scan.stage = "reading"
    scan.total = C_AuctionHouse.GetNumReplicateItems() or 0
    scan.index, scan.auctions, scan.lowest, scan.count, scan.pending = 0, 0, {}, {}, {}
    self.events:SetScript("OnUpdate", function() AP:ReadSome() end)
end

-- An auction of `count` at `each` for one
local function record(scan, key, each, count)
    local was = scan.lowest[key]
    if not was or each < was then scan.lowest[key] = each end
    scan.count[key] = (scan.count[key] or 0) + count
end

-- One auction (index from 0): its item's key and its buyout for one
local function readOne(scan, i, again)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID, hasAll = C_AuctionHouse.GetReplicateItemInfo(i)
    if type(itemID) ~= "number" or itemID == CAGED_PET or type(count) ~= "number" or count < 1
        or type(buyout) ~= "number" or buyout <= 0 then
        return
    end
    local link = (hasAll or again) and C_AuctionHouse.GetReplicateItemLink(i)
    if type(link) == "string" then
        record(scan, AP.KeyOf(link) or itemID, buyout / count, count)
    elseif again then
        -- Still not loaded: by its ID alone
        record(scan, itemID, buyout / count, count)
    else
        scan.pending[#scan.pending + 1] = i
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    end
    if not again then scan.auctions = scan.auctions + 1 end
end

function AP:ReadSome()
    local scan = self.scanning
    if not (scan and scan.stage == "reading") then return end
    if scan.index < scan.total then
        local last = math.min(scan.total - 1, scan.index + CHUNK - 1)
        for i = scan.index, last do readOne(scan, i, false) end
        scan.index = last + 1
        self:UpdateButton()
        return
    end
    -- The items not loaded yet: a moment, then read again
    if #scan.pending > 0 then
        scan.waitUntil = scan.waitUntil or (GetTime() + WAIT_INFO)
        if GetTime() < scan.waitUntil then return end
        for _, i in ipairs(scan.pending) do readOne(scan, i, true) end
        scan.pending = {}
    end
    self:Finish()
end

function AP:Finish()
    local scan = self.scanning
    self.scanning = nil
    self.events:SetScript("OnUpdate", nil)
    local book = self:Book()
    local now = GetServerTime()
    local today = math.floor(now / 86400)
    local n = 0
    for key, each in pairs(scan.lowest) do
        local price = math.max(1, math.floor(each + 0.5))
        -- Each day's lowest, the last 14 days only
        local old = book.items[key]
        local days = type(old) == "table" and type(old[4]) == "table" and old[4] or {}
        for day in pairs(days) do
            if type(day) ~= "number" or day <= today - HISTORY_DAYS then days[day] = nil end
        end
        if not days[today] or price < days[today] then days[today] = price end
        book.items[key] = { price, now, scan.count[key] or 0, days }
        n = n + 1
    end
    book.scanned, book.listed, book.auctions = now, n, scan.auctions
    CK:Print(L.AH_DONE, n, scan.auctions)
    self:UpdateButton()
    self:RefreshMarks()
end

---------------------------------------------------------------------------
-- The button, under the auction house window (its own frame's child: the
-- gamepad's navigation finds it there)
---------------------------------------------------------------------------
function AP:UpdateButton()
    local b = self.button
    if not b then return end
    b:SetShown(self:On())
    local scan = self.scanning
    if scan then
        local pct = scan.total and scan.total > 0 and math.floor(100 * math.min(scan.index or 0, scan.total) / scan.total) or 0
        b:SetText(format(L.AH_SCANNING, pct))
        b:Disable()
        return
    end
    local wait = self:Wait()
    if wait > 0 then
        b:SetText(format(L.AH_SCAN_WAIT, math.ceil(wait / 60)))
        b:Disable()
    else
        b:SetText(L.AH_SCAN)
        b:Enable()
    end
    self:UpdatePostButton()
end

-- Under the button and in the panel: the last scan of this realm
function AP:StatusText()
    local book = self:Book()
    if type(book.scanned) ~= "number" then return L.AH_NEVER end
    return format(L.AH_STATUS, AP.Age(book.scanned), book.listed or 0)
end

function AP:Button()
    local frame = AuctionHouseFrame
    if not frame then return nil end
    local b = self.button
    if not b then
        b = CK.NewFrame("Button", "ControllerKeyboardAuctionScan", frame, "UIPanelButtonTemplate")
        b:SetSize(200, 24)
        -- Outside the window, under its right corner: its tabs are on the left
        b:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
        b:SetScript("OnClick", function() AP:Scan() end)
        b:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.AH_SCAN, 1, 1, 1)
            GameTooltip:AddLine(L.AH_SCAN_TIP, GOLD[1], GOLD[2], GOLD[3], true)
            GameTooltip:AddLine(AP:StatusText(), GREY[1], GREY[2], GREY[3], true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- The minutes left, counted down while it is shown
        local elapsed = 0
        b:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 1 then return end
            elapsed = 0
            if not AP.scanning then AP:UpdateButton() end
        end)
        self.button = b
    end
    self:PostButton(frame)
    self:UpdateButton()
    return b
end

---------------------------------------------------------------------------
-- Posting (asked): "Post all (12)", left of the scan button, goes through
-- the bag slots worth an auction (the gold coin's), one press each: the
-- game asks a press for every post. Each one's lowest price is checked
-- again first (a search, sent by itself), then it is posted for 24 h at 1
-- silver under it (whole silver: the game's rule; at the same price as the
-- player's own lowest; the last price seen when none is listed), never at
-- a loss against the merchant with the deposit counted.
---------------------------------------------------------------------------
local NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local COMMODITY = Enum and Enum.ItemCommodityStatus and Enum.ItemCommodityStatus.Commodity or 2

function AP:PostQueue()
    local list = {}
    for bag = 0, NUM_BAGS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local link, count, id = self:SlotWorthIt(bag, slot)
            if link then list[#list + 1] = { bag = bag, slot = slot, link = link, count = count, id = id } end
        end
    end
    return list
end

function AP:StartPosting()
    if self.posting or self.scanning or not (self:On() and AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return end
    local queue = self:PostQueue()
    if #queue == 0 then
        CK:Print(L.AH_POST_NOTHING)
        return
    end
    self.posting = { queue = queue, index = 0, posted = 0 }
    self:NextPost()
end

-- The next slot: still there and worth it, its price checked again
function AP:NextPost()
    local p = self.posting
    if not p then return end
    p.index = p.index + 1
    local e = p.queue[p.index]
    if not e then return self:EndPosting() end
    -- (moved, used or sold meanwhile: the next one)
    local link, count = self:SlotWorthIt(e.bag, e.slot)
    if link ~= e.link then return self:NextPost() end
    e.count = count
    e.loc = ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
    e.commodity = C_AuctionHouse.GetItemCommodityStatus(e.loc) == COMMODITY
    e.key = C_AuctionHouse.GetItemKeyFromItem(e.loc)
    p.stage, p.price = "search", nil
    self:SendSearch()
    self:UpdatePostButton()
end

-- The search sent once the game takes messages again
function AP:SendSearch()
    local p = self.posting
    if not (p and p.stage == "search") then return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        p.waiting = true
        return
    end
    p.waiting = nil
    local order = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
    C_AuctionHouse.SendSearchQuery(p.queue[p.index].key, { { sortOrder = order, reverseSort = false } }, true)
end

-- The lowest buyout for one listed now, and whether it is the player's own
local function lowestNow(e)
    if e.commodity then
        for i = 1, math.min(C_AuctionHouse.GetNumCommoditySearchResults(e.id) or 0, 10) do
            local r = C_AuctionHouse.GetCommoditySearchResultInfo(e.id, i)
            if r and type(r.unitPrice) == "number" and r.unitPrice > 0 then return r.unitPrice, r.containsOwnerItem end
        end
    else
        for i = 1, math.min(C_AuctionHouse.GetNumItemSearchResults(e.key) or 0, 10) do
            local r = C_AuctionHouse.GetItemSearchResultInfo(e.key, i)
            if r and type(r.buyoutAmount) == "number" and r.buyoutAmount > 0 then return r.buyoutAmount, r.containsOwnerItem end
        end
    end
end

-- The search's answer: its price, or the next one when no longer worth it
function AP:Searched(itemID)
    local p = self.posting
    local e = p and p.stage == "search" and p.queue[p.index]
    if not e or (itemID and itemID ~= e.id) then return end
    local low, ours = lowestNow(e)
    local price
    if low then
        price = ours and low or (low - SILVER)
    else
        price = self:Price(e.link)
    end
    price = price and math.max(SILVER, math.floor(price / SILVER) * SILVER)
    local deposit
    if e.commodity and C_AuctionHouse.CalculateCommodityDeposit then
        deposit = C_AuctionHouse.CalculateCommodityDeposit(e.id, DURATION, e.count)
    elseif not e.commodity and C_AuctionHouse.CalculateItemDeposit then
        deposit = C_AuctionHouse.CalculateItemDeposit(e.loc, DURATION, e.count)
    end
    if type(deposit) ~= "number" or secret(deposit) then deposit = POST_FEE end
    local vendor = sellPrice(e.link) or 0
    if not price or price * e.count * CUT - deposit <= vendor * e.count then
        CK:Print(L.AH_POST_SKIPPED, e.link)
        return self:NextPost()
    end
    p.stage, p.price = "ready", price
    self:UpdatePostButton()
end

-- A press (the button, its key binding): start, post, or confirm
function AP:PostPress()
    local p = self.posting
    if not p then return self:StartPosting() end
    if p.stage ~= "ready" and p.stage ~= "confirm" then return end
    local e = p.queue[p.index]
    if C_Item and C_Item.DoesItemExist and not C_Item.DoesItemExist(e.loc) then return self:NextPost() end
    local confirm, needs = p.stage == "confirm", false
    if e.commodity then
        if confirm then
            C_AuctionHouse.ConfirmPostCommodity(e.loc, DURATION, e.count, p.price)
        else
            needs = C_AuctionHouse.PostCommodity(e.loc, DURATION, e.count, p.price)
        end
    elseif confirm then
        C_AuctionHouse.ConfirmPostItem(e.loc, DURATION, e.count, nil, p.price)
    else
        needs = C_AuctionHouse.PostItem(e.loc, DURATION, e.count, nil, p.price)
    end
    -- The game warns first (a price far from the usual one): one more press
    if needs == true then
        p.stage = "confirm"
        self:UpdatePostButton()
        return
    end
    p.posted = p.posted + 1
    self:NextPost()
end

function AP:EndPosting(why)
    local p = self.posting
    if not p then return end
    self.posting = nil
    CK:Print(why or format(L.AH_POST_DONE, p.posted))
    self:UpdatePostButton()
end

function AP:UpdatePostButton()
    local b = self.postButton
    if not b then return end
    b:SetShown(self:On())
    local p = self.posting
    if p then
        local n = #p.queue
        if p.stage == "ready" or p.stage == "confirm" then
            b:SetText(format(p.stage == "confirm" and L.AH_POST_CONFIRM or L.AH_POST_NEXT, p.index, n, money(p.price)))
            b:Enable()
        else
            b:SetText(format(L.AH_POST_CHECKING, p.index, n))
            b:Disable()
        end
        return
    end
    local n = (self:On() and not self.scanning) and #self:PostQueue() or 0
    b:SetText(format(L.AH_POST_ALL, n))
    if n > 0 and not self.scanning then b:Enable() else b:Disable() end
end

function AP:PostButton(frame)
    if self.postButton then return self.postButton end
    local b = CK.NewFrame("Button", "ControllerKeyboardAuctionPost", frame, "UIPanelButtonTemplate")
    b:SetSize(200, 24)
    b:SetPoint("RIGHT", self.button, "LEFT", -6, 0)
    b:SetScript("OnClick", function() AP:PostPress() end)
    b:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(format(L.AH_POST_ALL, #AP:PostQueue()), 1, 1, 1)
        GameTooltip:AddLine(L.AH_POST_TIP, GOLD[1], GOLD[2], GOLD[3], true)
        local p = AP.posting
        local e = p and p.price and p.queue[p.index]
        if e then
            GameTooltip:AddLine(format(L.AH_POST_ITEM, e.link, e.count, money(p.price)), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.postButton = b
    return b
end

-- Its key binding: one press, while the auction house is open
function ControllerKeyboard_PostAuction()
    if not AP:On() then
        CK:Print(L.AH_OFF)
    elseif not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
        CK:Print(L.AH_OPEN_FIRST)
    else
        AP:PostPress()
    end
end

-- The option turned on or off (the button made with the window, shown
-- only while the option is on)
function AP:Apply()
    if not self:On() and self.scanning then self:Stop(nil) end
    if not self:On() and self.posting then self.posting = nil end
    if self.button then self:UpdateButton() elseif AuctionHouseFrame then self:Button() end
    self:RefreshMarks()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- The game's auction house window is loaded the first time an auctioneer
-- is spoken to, after the auction house "shows" (reported: no button): the
-- button is made as soon as the window exists (its child: shown with it)
local AH_ADDON = "Blizzard_AuctionHouseUI"

function AP:Init()
    self:HookTooltips()
    self:HookBags()
    local f = CreateFrame("Frame")
    self.events = f
    for _, event in ipairs({ "ADDON_LOADED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "MODIFIER_STATE_CHANGED",
        "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
        "BAG_UPDATE_DELAYED" }) do
        pcall(f.RegisterEvent, f, event)
    end
    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == AH_ADDON and AuctionHouseFrame then AP:Button() end
        elseif event == "AUCTION_HOUSE_SHOW" then
            if AuctionHouseFrame then AP:Button() end
        elseif event == "AUCTION_HOUSE_CLOSED" then
            -- Closed mid-scan: the game's answer is gone with it
            if AP.scanning then AP:Stop(L.AH_CANCELLED) end
            if AP.posting then AP:EndPosting() end
        elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
            AP:Searched(arg1)
        elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
            AP:Searched(type(arg1) == "table" and arg1.itemID or nil)
        elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
            if AP.posting and AP.posting.waiting then AP:SendSearch() end
        elseif event == "BAG_UPDATE_DELAYED" then
            if not AP.posting then AP:UpdatePostButton() end
        elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
            AP:Replicated()
        elseif event == "MODIFIER_STATE_CHANGED" then
            AP:ModifierChanged(arg1)
        end
    end)
    -- Already loaded (a /reload after visiting the auction house)
    if AuctionHouseFrame then self:Button() end
end

-- Its key binding (Bindings.xml; the Gamepad tab's game functions list it
-- too): the scan, while the auction house is open
function ControllerKeyboard_ScanAuctionHouse()
    if not AP:On() then
        CK:Print(L.AH_OFF)
    elseif not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
        CK:Print(L.AH_OPEN_FIRST)
    else
        AP:Scan()
    end
end
