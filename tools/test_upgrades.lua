-- Run from the addon root with Lua 5.1: lua tools/test_upgrades.lua
local tests = 0

local function fixture()
    local items = {
        candidate = { score = 10, level = 20, equipLoc = "INVTYPE_HEAD" },
        worn = { score = 20, level = 30, equipLoc = "INVTYPE_HEAD" },
    }
    local equipment = { [1] = "worn" }
    local CK = { db = { settings = { modules = { upgrades = true } } } }
    C_Item = {
        GetItemInfo = function(link)
            local item = items[link]
            if not item or item.infoPending then return nil end
            return link, link, 1, item.level, 1, "Armor", "Plate", 1,
                item.equipLoc, nil, 0, 4, 4
        end,
        GetItemInfoInstant = function(link)
            local item = items[link]
            return 1, "Armor", "Plate", item and item.equipLoc, nil, 4, 4
        end,
        GetItemStats = function(link)
            local item = items[link]
            if not item or item.statsPending then return nil end
            return { ITEM_MOD_STRENGTH_SHORT = item.score }
        end,
    }
    C_TooltipInfo = { GetBagItem = function() return { lines = {} } end }
    UnitClass = function() return "Warrior", "WARRIOR" end
    UnitLevel = function() return 60 end
    GetInventoryItemLink = function(_, slot) return equipment[slot] end
    GetItemStats = nil
    GetNumTalentTabs = nil
    C_SpecializationInfo = nil
    CanDualWield = function() return true end
    assert(loadfile("Upgrades.lua"))("EasyController", CK)
    return CK.Upgrades, items, equipment
end

local function check(label, callback)
    callback()
    tests = tests + 1
    print("PASS " .. label)
end

local function expect(upgrades, betterExpected, pendingExpected)
    local better, pending = upgrades:IsUpgrade(0, 1, "candidate")
    assert(better == betterExpected, "unexpected upgrade result: " .. tostring(better))
    assert(not not pending == pendingExpected, "unexpected pending result: " .. tostring(pending))
end

check("uncached equipped stats defer the comparison", function()
    local upgrades, items = fixture()
    items.worn.statsPending = true
    expect(upgrades, false, true)
end)

check("uncached equipped item information defers the comparison", function()
    local upgrades, items = fixture()
    items.worn.infoPending = true
    expect(upgrades, false, true)
end)

check("cached upgrades and downgrades keep their result", function()
    local upgrades, items = fixture()
    expect(upgrades, false, false)
    items.candidate.score = 30
    expect(upgrades, true, false)
end)

check("an empty equipment slot is still zero", function()
    local upgrades, _, equipment = fixture()
    equipment[1] = nil
    expect(upgrades, true, false)
end)

check("item level fallback works without the stats API", function()
    local upgrades, items = fixture()
    C_Item.GetItemStats = nil
    expect(upgrades, false, false)
    items.candidate.level = 40
    expect(upgrades, true, false)
    items.worn.infoPending = true
    expect(upgrades, false, true)
end)

check("two hand comparisons wait for the off hand", function()
    local upgrades, items, equipment = fixture()
    items.candidate.equipLoc = "INVTYPE_2HWEAPON"
    items.candidate.score = 15
    items.worn.equipLoc = "INVTYPE_WEAPONMAINHAND"
    items.worn.score = 10
    items.offhand = { score = 10, level = 30, equipLoc = "INVTYPE_SHIELD", statsPending = true }
    equipment[16], equipment[17] = "worn", "offhand"
    expect(upgrades, false, true)
    items.offhand.statsPending = nil
    expect(upgrades, false, false)
    items.candidate.score = 30
    expect(upgrades, true, false)
end)

check("item data arrival retries the visible bag", function()
    local upgrades, items = fixture()
    items.worn.statsPending = true
    local visible = false
    local button = {
        GetBagID = function() return 0 end,
        GetID = function() return 1 end,
        CreateTexture = function()
            return setmetatable({
                Show = function() visible = true end,
                Hide = function() visible = false end,
            }, { __index = function() return function() end end })
        end,
    }
    local bag = {
        IsShown = function() return true end,
        EnumerateValidItems = function() return ipairs({ button }) end,
        UpdateItems = function() end,
    }
    local onEvent
    ContainerFrameCombinedBags = bag
    NUM_CONTAINER_FRAMES = 0
    C_Container = { GetContainerItemLink = function() return "candidate" end }
    hooksecurefunc = function() end
    CreateFrame = function()
        return {
            RegisterEvent = function() end,
            SetScript = function(_, name, handler)
                if name == "OnEvent" then onEvent = handler end
            end,
        }
    end
    upgrades:Init()
    upgrades:Refresh()
    assert(upgrades.waiting and not visible, "pending items must hide the arrow and request a retry")
    items.worn.statsPending = nil
    items.candidate.score = 30
    onEvent(nil, "GET_ITEM_INFO_RECEIVED")
    assert(not upgrades.waiting and visible, "the cache event must recompute and display the upgrade")
end)

print(tests .. " upgrade regression tests passed")
