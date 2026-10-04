-- Run from the addon directory: lua tools/test_supplies.lua (Lua 5.1).
local function noop() end
local settings = { enabled = true, size = 2, layout = "right", custom = {},
    list = { bags = { on = true, low = 4, critical = 1 }, ammo = { on = true, low = 200, critical = 50 } } }
local ammoID, ammoIcon, ammoCount, freeSlots, class, combat = 42, 134400, 1, 12, "WARRIOR", false
local vibrations, requests, timers = {}, {}, {}
local CK = { L = { SUP_BAGS = "Free bag slots", SUP_AMMO = "Ammunition" }, db = { settings = { supplies = settings } },
    Paddles = { SetIcon = function(tex, icon) tex.value = icon end },
    Vibration = { Fire = function(_, key) vibrations[#vibrations + 1] = key end } }
local eventFrame
local env = setmetatable({ format = string.format, NUM_BAG_SLOTS = 4,
    UnitClass = function() return class, class end,
    InCombatLockdown = function() return combat end,
    GetInventoryItemID = function() return ammoID end,
    GetInventoryItemTexture = function() return ammoIcon end,
    GetInventoryItemCount = function() return ammoCount end,
    C_Container = { GetContainerNumFreeSlots = function(bag) return bag == 0 and freeSlots or 0, 0 end },
    C_Item = { GetItemNameByID = function(id) return id == 42 and "Arrows" or "Resource" end,
        GetItemIconByID = function(id) if id == 42 then return ammoIcon end; return 12345 end,
        GetItemCount = function() return 8 end, RequestLoadItemDataByID = function(id) requests[#requests + 1] = id end },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    CreateFrame = function()
        eventFrame = { events = {}, scripts = {},
            RegisterEvent = function(self, event) self.events[event] = true end,
            SetScript = function(self, event, fn) self.scripts[event] = fn end }
        return eventFrame
    end }, { __index = _G })
env._G = env
local function loadAddon(file) local f = assert(loadfile(file)); setfenv(f, env); f("EasyController", CK) end
loadAddon("Supplies.lua")
local S = CK.Supplies
local function region()
    return { shown = true, ClearAllPoints = noop, SetPoint = noop, SetSize = noop,
        Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
        SetShown = function(self, on) self.shown = on end, IsShown = function(self) return self.shown end,
        GetLeft = function() return nil end }
end
S.bar = region(); S.bar.buttons = {}; S.BuildBar = noop
function S:Button(i)
    if self.bar.buttons[i] then return self.bar.buttons[i] end
    local b = region(); b.click, b.visual, b.icon = region(), region(), {}
    b.count = { SetText = function(self, text) self.text = text end, SetTextColor = noop }
    local glow = region(); glow.SetVertexColor = noop
    glow.pulse = { Stop = noop, IsPlaying = function() return false end, Play = noop }
    glow.alpha = { SetFromAlpha = noop, SetToAlpha = noop, SetDuration = noop }
    S.glows[b] = glow; self.bar.buttons[i] = b
    return b
end
local function shown()
    local keys = {}
    if S.bar.shown then
        for _, b in ipairs(S.bar.buttons) do if b.shown then keys[#keys + 1] = b.resource.key end end
    end
    return table.concat(keys, ",")
end
S:Refresh()
assert(shown() == "", "old settings without new switches must not show bag/ammo HUD icons: " .. shown())
assert(settings.list.bags.on and settings.list.ammo.on and settings.list.ammo.low == 200, "legacy resource settings must remain intact")
settings.showBags = true; S:Refresh()
assert(shown() == "bags" and S.bar.buttons[1].count.text == 12, "enabling bags must show its normal free-space count")
settings.showBags, settings.showAmmo = false, true; S:Refresh()
assert(shown() == "", "an enabled ammo indicator must not show the question-mark placeholder")
ammoIcon = 132382; S:Refresh()
assert(shown() == "ammo" and S.bar.buttons[1].count.text == 1, "valid ammo must remain available independently")
assert(settings.showAmmo == true, "refresh must preserve explicit opt-in")
settings.showBags = true; S:Refresh(); assert(shown() == "bags,ammo")
settings.showAmmo = false; S:Refresh(); assert(shown() == "bags")
settings.showBags = false; settings.custom = { 99 }; S:Refresh()
assert(shown() == "item:99", "new counter switches must not hide custom supplies")
settings.list["item:99"].on = false; S:Refresh(); assert(shown() == "", "custom resource switches must still work")
print("PASS: defaults and existing settings, independent opt-in counters, valid ammo and custom-resource preservation")

settings.custom = {}; settings.showAmmo = true
for _, id in ipairs({ 0, -1 }) do
    ammoID = id
    for _, r in ipairs(S:Resources()) do assert(r.kind ~= "ammo", "nonpositive inventory IDs must not become ammo resources") end
end
ammoID, ammoIcon = 42, "Interface\\Icons\\INV_Misc_QuestionMark"
S:Refresh(); assert(shown() == "", "path-based question marks must also stay hidden")
ammoIcon = nil; S:Refresh(); assert(shown() == "", "uncached resource icons must stay hidden")
S:Init(); assert(eventFrame.events.GET_ITEM_INFO_RECEIVED and eventFrame.events.ITEM_DATA_LOAD_RESULT)
eventFrame.scripts.OnEvent(eventFrame, "ITEM_DATA_LOAD_RESULT", 42, false)
assert(#timers == 0, "failed item requests must not repeatedly trigger another refresh")
ammoIcon = 132382
eventFrame.scripts.OnEvent(eventFrame, "ITEM_DATA_LOAD_RESULT", 42, true)
for _, f in ipairs(timers) do f() end; timers = {}
assert(shown() == "ammo", "item-data arrival must retry and reveal a valid resource")
class, ammoID = "HUNTER", nil; S:Refresh()
assert(shown() == "ammo" and S.bar.buttons[1].count.text == 0, "a real hunter's empty ammo warning must remain")
print("PASS: invalid IDs, numeric/path/uncached placeholders, data-event retry and valid empty-ammo warning")

class, ammoID, ammoIcon, ammoCount = "WARRIOR", 42, 132382, 250
settings.showBags, settings.showAmmo = true, false; S:Refresh()
freeSlots = 0; S:Refresh(); assert(shown() == "bags" and vibrations[#vibrations] == "lowSpace")
combat = true; settings.showBags = false; S:Refresh()
assert(S.pendingLayout and S.bar.shown, "secure layout changes must still defer in combat")
combat = false; S:Refresh(); assert(shown() == "" and not S.pendingLayout)
print("PASS: enabled counter alerts and secure combat layout deferral are retained")

-- Render the real Options rows and invoke their real setters.
setmetatable(CK.L, { __index = function(_, key) return key end })
CK.Config = { pages = {}, NewRailPage = function(def) return { def = def } end }
CK.MyWheels = { TabPage = function(_, page) return page end }
loadAddon("Options.lua")
local supplyRows
for _, section in ipairs(CK.Config.pages.alerts.def.sections) do
    if section.key == "supplies" then supplyRows = section.rows end
end
assert(supplyRows, "supplies controls must remain in the Alerts tab")
local function renderRows()
    local rows, counts = {}, {}
    local function add(row)
        if row.id then rows[row.id] = row; counts[row.id] = (counts[row.id] or 0) + 1 end
    end
    supplyRows({ header = noop, check = add, stat = add, choice = add, button = add }, {})
    return rows, counts
end
settings.showBags, settings.showAmmo = nil, nil
local rows, counts = renderRows()
assert(rows.s_bags and rows.s_ammo and counts.s_bags == 1 and counts.s_ammo == 1, "each counter must have exactly one discoverable switch")
assert(not rows.s_bags.get() and not rows.s_ammo.get(), "missing saved switches must render unchecked")
rows.s_bags.set(true)
assert(settings.showBags and not settings.showAmmo and shown() == "bags", "bag option must independently enable its actual HUD")
rows.s_ammo.set(true)
assert(settings.showBags and settings.showAmmo and shown() == "bags,ammo", "ammo option must independently enable its actual HUD")
rows.s_bags.set(false)
assert(shown() == "ammo" and settings.list.bags.on, "bag option must preserve ammo and legacy thresholds")
rows.s_on.set(false)
rows = renderRows()
assert(rows.s_bags.disabled and rows.s_ammo.disabled and not rows.s_bags.get() and rows.s_ammo.get(), "master-off controls must stay discoverable and preserve independent settings")
assert(shown() == "", "master switch must still suppress the whole supplies HUD")
print("PASS: actual Alerts/Supplies row rendering, independent setters and master-switch behavior")
