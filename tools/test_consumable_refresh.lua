-- Run from the addon root with Lua 5.1: lua tools/test_consumable_refresh.lua
local passed, failed = 0, 0
local function check(name, test)
    local ok, err = pcall(test)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

local function fixture()
    local state = { combat = false, shown = false, renders = 0, fills = 0, timers = {}, attrs = {} }
    local CK = { L = setmetatable({}, { __index = function(_, key) return key end }),
        db = { settings = { wheel = { enabled = true, variants = true, categories = {} } } },
        GlyphMarkup = function(_, key) return key end }
    format, gmatch = string.format, string.gmatch
    InCombatLockdown = function() return state.combat end
    C_GamePad = nil
    C_Timer = { After = function(_, callback) state.timers[#state.timers + 1] = callback end }
    CreateFrame = function()
        return { RegisterEvent = function() end, SetScript = function(_, event, callback)
            if event == "OnEvent" then state.event = callback end
        end }
    end
    assert(loadfile("ConsumableWheel.lua"))("EasyController", CK)
    local w = CK.ConsumableWheel
    state.build, state.apply = w.Build, w.ApplyPage
    w.frame = {
        IsShown = function() return state.shown end,
        Show = function() state.shown = true end, Hide = function() state.shown = false end,
        SetAttribute = function(_, key, value) state.attrs[key] = value end,
        GetAttribute = function(_, key) return state.attrs[key] end,
        SetBindingClick = function() end, ClearBindings = function() end,
        GetFrameRef = function(_, key) return w.buttons[tonumber(key:match("%d+"))] end,
    }
    local inert = setmetatable({}, { __index = function() return function() end end })
    w.view = { bg = { SetTexture = function() state.renders = state.renders + 1 end },
        pages = inert, help = inert }
    w.segments, w.lists = {}, { c = {} }
    w.Track, w.Build, w.RestoreSettings, w.ApplyPage = function() end, function() end, function() end, function() end
    state.flush = function()
        local timers = state.timers
        state.timers = {}
        for _, callback in ipairs(timers) do callback() end
    end
    return w, state, CK
end

local function bagFixture()
    local w, state, CK = fixture()
    NUM_BAG_SLOTS = 0
    C_Container = {
        GetContainerNumSlots = function() return 2 end,
        GetContainerItemID = function(_, slot) return slot == 1 and 100 or 101 end,
    }
    C_Item = { GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 4 end }
    C_Spell = { GetSpellName = function(id) return "spell" .. id end }
    state.entries = { [1] = { kind = "item", id = 200 }, [3] = { kind = "item", id = 300 } }
    CK.MyWheels = { Entries = function(_, id) return id == 1 and state.entries or {} end }
    return w, state, CK
end

check("hidden wheels skip painting and visible wheels still paint", function()
    local w, state = fixture()
    w:Paint()
    assert(state.renders == 0, "a hidden wheel was repainted")
    state.shown = true
    w:Paint()
    assert(state.renders == 1, "a visible wheel must still paint")
end)

check("unrelated item events do not rebuild and relevant events stay coalesced", function()
    local w, state = fixture()
    w.itemIDs = { [100] = true, [200] = true }
    w.Fill = function() state.fills = state.fills + 1 end
    w:Init()
    state.event(nil, "GET_ITEM_INFO_RECEIVED", 999)
    assert(#state.timers == 0 and state.fills == 1, "unrelated item data scheduled a rebuild")
    state.event(nil, "GET_ITEM_INFO_RECEIVED", 100)
    state.event(nil, "GET_ITEM_INFO_RECEIVED", 200)
    assert(#state.timers == 1)
    state.flush()
    assert(state.fills == 2)
end)

check("bag changes during combat wait until combat ends", function()
    local w, state = fixture()
    w.Fill = function() assert(not state.combat); state.fills = state.fills + 1; w.pending = nil end
    w:Init()
    state.combat = true
    state.event(nil, "BAG_UPDATE_DELAYED")
    state.flush()
    assert(w.pending and state.fills == 1 and state.renders == 0)
    state.combat = false
    state.event(nil, "PLAYER_REGEN_ENABLED")
    state.flush()
    assert(not w.pending and state.fills == 2)
end)

check("cooldowns update visible wheels without rebuilding contents", function()
    local w, state = fixture()
    w.Fill = function() state.fills = state.fills + 1 end
    w:Init()
    state.event(nil, "SPELL_UPDATE_COOLDOWN")
    assert(state.renders == 0 and state.fills == 1)
    state.shown = true
    state.event(nil, "BAG_UPDATE_COOLDOWN")
    assert(state.renders == 1 and state.fills == 1 and #state.timers == 0)
end)

check("fill tracks bag and custom-wheel items including uncached ones", function()
    local w, state, CK = bagFixture()
    w:Fill()
    assert(w.itemIDs and w.itemIDs[100] and w.itemIDs[101] and w.itemIDs[200] and w.itemIDs[300])
    assert(not w.itemIDs[999])
    assert(w.lists["1"][1][2].id == 300, "default slot packing must remain unchanged")
    assert(state.attrs["ck-1-1-2"] == "item:300")
    CK.db.settings.wheel.enabled = false
    w:Fill()
    assert(not w.itemIDs[100] and w.itemIDs[200])
end)

check("direct fills in combat preserve contents and item tracking", function()
    local w, state = fixture()
    local original = { [200] = true }
    w.itemIDs = original
    state.combat = true
    w:Fill()
    assert(w.pending and w.itemIDs == original and next(state.attrs) == nil)
end)

local function upvalue(fn, wanted)
    for i = 1, 100 do
        local name, value = debug.getupvalue(fn, i)
        if name == wanted then return value end
        if not name then break end
    end
    error("missing upvalue " .. wanted)
end

check("fixed custom slots share eight directions with secure use and empty slots do nothing", function()
    local w, state, CK = bagFixture()
    CK.db.settings.wheel.fixedSlots = true
    w.buttons = {}
    for i = 1, 8 do
        local b = { attrs = {}, shown = false }
        b.SetAttribute = function(self, key, value) self.attrs[key] = value end
        b.GetAttribute = function(self, key) return self.attrs[key] end
        b.Show = function(self) self.shown = true end
        b.Hide = function(self) self.shown = false end
        b.IsShown = function(self) return self.shown end
        b.SetShown = function(self, value) self.shown = value end
        b.ClearAllPoints = function() end
        b.SetPoint = function(self, _, _, _, x, y) self.x, self.y = x, y end
        w.buttons[i] = b
    end
    state.attrs["ck-prefixes"], state.attrs["ck-radius"] = ",", 128
    for n = 1, 8 do for i = 1, n do
        local x, y = w.slotDir(i, n)
        state.attrs["ck-x" .. n .. "-" .. i], state.attrs["ck-y" .. n .. "-" .. i] = x, y
    end end
    w:Fill()
    assert(state.attrs["ck-1-1-n"] == 8 and state.attrs["ck-1-total"] == 2)
    assert(state.attrs["ck-1-1-3"] == "item:300" and state.attrs["ck-1-1-2"] == nil)
    local toggle = assert(loadstring("return function(self, owner, button, down) " .. upvalue(state.build, "TOGGLE") .. " end"))()
    local use = assert(loadstring("return function(self, owner, button, down) " .. upvalue(state.build, "USE") .. " end"))()
    local activator = { attrs = { ["ck-wheel"] = "1" },
        GetAttribute = function(self, key) return self.attrs[key] end,
        SetAttribute = function(self, key, value) self.attrs[key] = value end }
    toggle(activator, w.frame, nil, true)
    assert(w.buttons[1]:IsShown() and not w.buttons[2]:IsShown() and w.buttons[3]:IsShown())
    assert(math.abs(w.buttons[3].x - 128) < 0.001 and math.abs(w.buttons[3].y) < 0.001)
    local stick = { x = 1, y = 0, len = 1 }
    GetGamePadState = function() return { sticks = { stick } } end
    C_GamePad = { GetDeviceMappedState = GetGamePadState }
    assert(w:Aimed() == 3 and use(nil, w.frame, nil, true) == "s3")
    stick.x, stick.y = 0.707, 0.707
    assert(w:Aimed() == nil and use(nil, w.frame, nil, true) == false)
    w:Paint()
    assert(w.paintedCount == 8)
    state.entries[3] = nil
    w.ApplyPage = state.apply
    w:Fill()
    assert(not w.buttons[3]:IsShown() and w.buttons[3].attrs.type == nil and w.buttons[3].attrs.item == nil)
    stick.x, stick.y = 1, 0
    assert(w:Aimed() == nil and use(nil, w.frame, nil, true) == false)
end)

assert(failed == 0, failed .. " consumable refresh regression tests failed")
print(passed .. " consumable refresh regression tests passed")
