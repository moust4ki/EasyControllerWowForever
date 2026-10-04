-- Run from the addon root with Lua 5.1: lua tools/test_profiles.lua
local passed, failures = 0, {}
local function check(name, run)
    local ok, err = pcall(run)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failures[#failures + 1] = name .. ": " .. tostring(err); print("FAIL " .. failures[#failures]) end
end
-- SavedVariables persist plain fields, not metatables or inherited values.
local function savedCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = savedCopy(item) end
    return result
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function legacyDB()
    return { settings = {
        modules = { mapping = true }, paddles = {}, touchButtons = {}, features = {},
        mapping = { ["L4:"] = "spell:101", ["L5:LT"] = "macro:Tank", ["R4:"] = "item:200",
            ["R5:"] = "wheel:1", ["L3:"] = "cmd:TOGGLEAUTORUN", ["R3:"] = "wheel:consumables" },
        replaced = { ["A:"] = "bar:top:x", ["B:LT"] = "spell:102" },
        myWheels = { list = { { id = 1, name = "Utility", slots = { [1] = "spell:101", [3] = "item:200" } } } },
    } }
end
local function fixture(db, character)
    local state = { combat = false, calls = {}, cvars = {
        GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateAlt = "PADRTRIGGER", GamePadEmulateCtrl = "none" },
        spells = { { action = "spell:101" }, { action = "spell:102" }, { action = "spell:103" } } }
    local CK = { L = {}, db = db or legacyDB() }
    local function record(label)
        state.calls[#state.calls + 1] = { label, CK.Profiles.ready and CK.Profiles.character.active or nil }
    end
    local env = setmetatable({
        UnitFullName = function() return character or "First", "Realm" end,
        GetRealmName = function() return "Realm" end,
        InCombatLockdown = function() return state.combat end,
        GetCVar = function(key) return state.cvars[key] end,
        SetCVar = function(key, value) state.cvars[key] = value end,
        ClearOverrideBindings = function() record("clear-wheel-bindings") end,
        GetBindingAction = function() return "" end,
        format = string.format,
        wipe = function(t) for key in pairs(t) do t[key] = nil end end,
    }, { __index = _G })
    env._G = env
    local function loadAddon(path)
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("EasyController", CK)
    end
    loadAddon("Mapping.lua")
    loadAddon("Profiles.lua")
    CK.MyWheels = { CloseEditor = function() record("close-editor") end,
        UpdateBindingNames = function() record("wheel-names") end }
    CK.ConsumableWheel = { StopPlacement = function() record("stop-placement") end,
        frame = { Hide = function() record("hide-wheel") end }, Fill = function() record("fill-wheel") end }
    CK.Toggle = { Release = function() record("release-toggle") end }
    CK.Paddles = { Apply = function() record("apply-paddles") end, NativeButton = function() return nil end }
    local M = CK.Mapping
    M.Apply = function() record("apply-mapping") end
    M.NativeBinding = function() return nil end
    M.NativeSlot = function() return nil end
    M.Catalog = function(_, kind) assert(kind == "spells"); return state.spells end
    M.ActionName = function(_, action) return action end
    CK.Profiles:Init()
    state.loadAddon, state.env = loadAddon, env
    return CK.Profiles, CK, state
end

check("first import preserves abilities and wheels and shares only utility actions", function()
    local db = legacyDB()
    local original = savedCopy(db.settings)
    local p, CK = fixture(db)
    assert(p:CharacterName() == "First - Realm" and p:ActiveName() == "General")
    assert(CK.Mapping:Get("L4", "") == "spell:101" and CK.Mapping:Get("L5", "LT") == "macro:Tank")
    assert(CK.Mapping:Get("R4", "") == "item:200" and CK.Mapping:Get("R5", "") == "wheel:1")
    assert(CK.Mapping:Get("L3", "") == "cmd:TOGGLEAUTORUN")
    assert(p.data.shared.mapping["L3:"] == "cmd:TOGGLEAUTORUN" and rawget(p:Current().mapping, "L3:") == nil)
    assert(p.data.shared.mapping["R3:"] == "wheel:consumables" and p.data.shared.replaced["A:"] == "bar:top:x")
    assert(not p.data.shared.mapping["L4:"] and not p.data.shared.mapping["R5:"])
    assert(equal(CK.db.settings.myWheels, original.myWheels))
    p:Current().myWheels.list[1].slots[1] = "spell:103"
    assert(p.data.legacy.myWheels.list[1].slots[1] == "spell:101", "legacy backup shares nested data")
end)

check("SavedVariables round trip has one canonical active layout", function()
    local p, CK = fixture()
    assert(rawget(CK.db.settings, "mapping") == nil and rawget(CK.db.settings, "replaced") == nil)
    assert(rawget(CK.db.settings, "myWheels") == nil)
    local saved = savedCopy(CK.db)
    assert(saved.settings.mapping == nil and getmetatable(saved.settings) == nil)
    local p2, CK2 = fixture(saved)
    assert(CK2.Mapping:Get("L3", "") == "cmd:TOGGLEAUTORUN" and CK2.Mapping:Get("L4", "") == "spell:101")
    assert(CK2.db.settings.myWheels.list[1].slots[3] == "item:200")
    assert(p2:Current() == p2.data.characters["First - Realm"].layouts.general)
    assert(rawget(CK2.db.settings, "mapping") == nil and rawget(CK2.db.settings, "myWheels") == nil)
    -- Compatibility writes through the settings API must also target the canonical layout.
    CK2.db.settings.myWheels = { list = {} }
    assert(p2:Current().myWheels == CK2.db.settings.myWheels and rawget(CK2.db.settings, "myWheels") == nil)
end)

check("a second character inherits utilities and starts with an empty class layout", function()
    local p1, first = fixture()
    local p2, second = fixture(savedCopy(first.db), "Second")
    assert(p2:CharacterName() == "Second - Realm")
    assert(next(p2:Current().mapping) == nil and next(p2:Current().replaced) == nil)
    assert(#p2:Current().myWheels.list == 0 and second.Mapping:Get("L4", "") == nil)
    assert(second.Mapping:Get("L3", "") == "cmd:TOGGLEAUTORUN" and second.Mapping:GetReplaced("A", "") == "bar:top:x")
    second.Mapping:Set("L4", "", "spell:103")
    local p3, reopened = fixture(savedCopy(second.db), "First")
    assert(reopened.Mapping:Get("L4", "") == "spell:101", "second character overwrote first character")
    assert(p3.data.characters["Second - Realm"].layouts.general.mapping["L4:"] == "spell:103")
end)

check("new role profiles deep-copy local bindings, wheels and role actions", function()
    local p, CK, state = fixture()
    p:Current().roleActions.interrupt = "spell:101"
    local general = p:Current()
    assert(p:Switch("tank"))
    local tank = p:Current()
    assert(tank ~= general and tank.mapping ~= general.mapping and tank.myWheels ~= general.myWheels)
    assert(tank.myWheels.list[1].slots ~= general.myWheels.list[1].slots and tank.roleActions ~= general.roleActions)
    assert(state.calls[1][1] == "close-editor" and state.calls[1][2] == "general")
    assert(state.calls[#state.calls][2] == "tank", "new profile must be active before secure refresh")
    CK.Mapping:Set("L4", "", "spell:103")
    tank.myWheels.list[1].slots[1], tank.roleActions.interrupt = "spell:103", "spell:103"
    assert(p:Switch("general"))
    assert(CK.Mapping:Get("L4", "") == "spell:101" and p:RoleAction("interrupt") == "spell:101")
    assert(p:Current().myWheels.list[1].slots[1] == "spell:101")
end)

check("clearing a shared utility creates a local tombstone and reads unassigned", function()
    local p, CK = fixture()
    CK.Mapping:Set("L3", "", nil)
    assert(rawget(p:Current().mapping, "L3:") == false and CK.Mapping:Get("L3", "") == nil)
    assert(p.data.shared.mapping["L3:"] == "cmd:TOGGLEAUTORUN")
    for key in p:BindingPairs("mapping") do assert(key ~= "L3:") end
    CK.Mapping:RestoreGameButtons()
    assert(CK.Mapping:GetReplaced("A", "") == nil and CK.Mapping:ReplacedCount() == 0)
    assert(p.data.shared.replaced["A:"] == "bar:top:x")
    local _, second = fixture(savedCopy(CK.db), "Second")
    assert(second.Mapping:Get("L3", "") == "cmd:TOGGLEAUTORUN" and second.Mapping:GetReplaced("A", "") == "bar:top:x")
end)

check("CopyFrom isolates source data and can recover the original imported layout", function()
    local p, CK = fixture()
    assert(p:Switch("tank"))
    p:Current().myWheels.list[1].slots[3] = "item:201"
    assert(p:Switch("healer"))
    assert(p:CopyFrom("First - Realm\ntank"))
    local source = p.character.layouts.tank
    p:Current().myWheels.list[1].slots[3] = "item:202"
    CK.Mapping:Set("L4", "", "spell:103")
    assert(source.myWheels.list[1].slots[3] == "item:201" and source.mapping["L4:"] == "spell:101")
    assert(p:CopyFrom("legacy"))
    assert(p:Current().myWheels.list[1].slots[3] == "item:200" and CK.Mapping:Get("L4", "") == "spell:101")
end)

check("combat switch, copy and role assignment do not mutate data or secure state", function()
    local p, CK, state = fixture()
    local before = savedCopy(CK.db)
    state.combat = true
    assert(not p:Switch("tank"))
    assert(not p:CopyFrom("legacy"))
    assert(not p:ApplyRole("interrupt", "L4", "", "spell:103", true))
    assert(equal(before, savedCopy(CK.db)) and #state.calls == 0)
end)

check("role preview rejects conflicts, unknown spells and unsupported combinations", function()
    local p, CK = fixture()
    assert(not p:PreviewRole("interrupt", "L4", "", "spell:103", false))
    assert(p:PreviewRole("interrupt", "L4", "", "spell:103", true))
    assert(not p:PreviewRole("interrupt", "L4", "", "spell:999", true))
    assert(not p:PreviewRole("interrupt", "L4", "INVALID", "spell:103", true))
    assert(not p:PreviewRole("interrupt", "MISSING", "", "spell:103", true))
    assert(not p:PreviewRole("interrupt", "LT", "", "spell:103", true))
    assert(not p:PreviewRole("missing", "L4", "", "spell:103", true))
    assert(not p:PreviewRole("interrupt", "B", "", "spell:103", false), "native game actions count as conflicts")
    assert(not p:PreviewRole("interrupt", "LB", "LT", "spell:103", true), "reserved class controls must stay reserved")
end)

check("ApplyRole records its position and binds the selected ability in the current profile", function()
    local p, CK = fixture()
    assert(p:ApplyRole("interrupt", "L4", "LT", "spell:103", false))
    local input, layer = p:RolePosition("interrupt")
    assert(input == "L4" and layer == "LT" and p:RoleAction("interrupt") == "spell:103")
    assert(CK.Mapping:Get("L4", "LT") == "spell:103")
    assert(CK.Mapping:EffectiveAction(CK.Mapping.BY_ID.L4, "LT") == "spell:103")
    assert(p:ApplyRole("defensive", "A", "LT", "spell:102", true))
    assert(CK.Mapping:GetReplaced("A", "LT") == "spell:102" and p:RoleAction("defensive") == "spell:102")
end)

check("role assignment cannot silently accept a disabled extra button", function()
    local p, CK = fixture()
    assert(not CK.Mapping:InputEnabled(CK.Mapping.BY_ID.TL1))
    assert(not p:PreviewRole("interrupt", "TL1", "", "spell:103", true), "disabled TL1 was accepted")
end)

check("role assignment cannot silently accept a layer blocked by a shared-key game command", function()
    local p, CK, state = fixture()
    state.cvars.GamePadEmulateAlt = "none"
    CK.Mapping:Set("L4", "", "cmd:TOGGLERUN")
    assert(CK.Mapping:State(CK.Mapping.BY_ID.L4, "RT") == "locked")
    local accepted = p:ApplyRole("interrupt", "L4", "RT", "spell:103", true)
    assert(not accepted or CK.Mapping:EffectiveAction(CK.Mapping.BY_ID.L4, "RT") == "spell:103",
        "accepted role still executes the base game command")
end)

check("disabled mapping refuses role assignments without changing the profile", function()
    local p, CK, state = fixture()
    CK.db.settings.modules.mapping = false
    local before = savedCopy(CK.db)
    assert(not p:ApplyRole("interrupt", "L4", "LT", "spell:103", true), "disabled mapping accepted an assignment")
    assert(equal(before, savedCopy(CK.db)) and #state.calls == 0)
end)

check("real custom-wheel deletion keeps shared utilities masked and other profiles intact", function()
    local p, CK, state = fixture()
    assert(p:Switch("tank"))
    CK.Mapping:Set("L3", "", "wheel:1")
    CK.Mapping:SetReplaced("A", "", "wheel:1")
    CK.ConfigKit, CK.Config = { C = {} }, {}
    CK.ConsumableWheel.MY_MAX = 8
    CK.L.MYWHEEL_DEFAULT = "Wheel %d"
    state.loadAddon("MyWheels.lua")
    local MW = CK.MyWheels
    assert(MW:Get(1) and MW:Bound(1))
    MW:Delete(1)
    assert(MW:Get(1) == nil and MW:Bound(1) == nil)
    assert(CK.Mapping:Get("L3", "") == nil and rawget(p:Current().mapping, "L3:") == false,
        "deleting the local wheel exposed a shared mapping")
    assert(CK.Mapping:GetReplaced("A", "") == nil and rawget(p:Current().replaced, "A:") == false,
        "deleting the local wheel exposed a shared replacement")
    assert(CK.Mapping:Get("R5", "") == nil, "unshared references to the deleted wheel must also clear")
    assert(p.data.shared.mapping["L3:"] == "cmd:TOGGLEAUTORUN" and p.data.shared.replaced["A:"] == "bar:top:x")
    assert(state.env["BINDING_NAME_CLICK ControllerKeyboardMyWheel1:LeftButton"] == "Wheel 1")
    assert(p:Switch("general"))
    assert(MW:Get(1) and MW:Get(1).slots[1] == "spell:101", "deletion leaked into another profile")
    assert(CK.Mapping:Get("L3", "") == "cmd:TOGGLEAUTORUN" and CK.Mapping:Get("R5", "") == "wheel:1")
    assert(state.env["BINDING_NAME_CLICK ControllerKeyboardMyWheel1:LeftButton"] == "Utility")
    assert(p:Switch("tank"))
    assert(MW:Get(1) == nil and CK.Mapping:Get("L3", "") == nil, "switching restored the removed wheel binding")
end)

check("pre-0.5 paddle actions survive active and recoverable import without overriding existing bindings", function()
    local db = legacyDB()
    db.settings.mapping = { ["L5:"] = "spell:102", ["R4:"] = false }
    db.settings.paddles = {
        L4 = { action = "spell:101", cat = "spells" }, L5 = { action = "spell:999", cat = "spells" },
        R4 = { action = "spell:103", cat = "spells" }, R5 = { action = "cmd:TOGGLERUN", cat = "game" },
    }
    local p, CK, state = fixture(db)
    assert(CK.Mapping:Get("L4", "") == "spell:101" and p.data.legacy.mapping["L4:"] == "spell:101")
    assert(CK.Mapping:Get("L5", "") == "spell:102" and p.data.legacy.mapping["L5:"] == "spell:102")
    assert(CK.Mapping:Get("R4", "") == nil and p.data.legacy.mapping["R4:"] == false)
    assert(CK.Mapping:Get("R5", "") == "cmd:TOGGLERUN" and p.data.legacy.mapping["R5:"] == "cmd:TOGGLERUN")
    assert(p.data.shared.mapping["R5:"] == "cmd:TOGGLERUN")
    state.env.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
    state.env.hooksecurefunc = function() end
    CK.Mapping:Init()
    for _, cfg in pairs(CK.db.settings.paddles) do assert(cfg.action == nil and cfg.cat == nil) end
    assert(CK.Mapping:Get("L4", "") == "spell:101" and CK.Mapping:Get("L5", "") == "spell:102")
    assert(CK.Mapping:Get("R4", "") == nil and rawget(p:Current().mapping, "R4:") == false)
    CK.Mapping:Set("L4", "", "spell:103")
    assert(p:CopyFrom("legacy"))
    assert(CK.Mapping:Get("L4", "") == "spell:101" and CK.Mapping:Get("L5", "") == "spell:102")
    assert(CK.Mapping:Get("R4", "") == nil and rawget(p:Current().mapping, "R4:") == false)
end)

check("shared utility edits propagate except through explicit overrides and removal masks", function()
    local p, CK = fixture()
    assert(p:Switch("damage"))
    assert(p:Switch("tank"))
    CK.Mapping:Set("L3", "", "spell:103")
    assert(p:Switch("healer"))
    CK.Mapping:Set("L3", "", nil)
    assert(p:Switch("general"))
    CK.Mapping:Set("L3", "", "cmd:TOGGLEUI")
    assert(p.data.shared.mapping["L3:"] == "cmd:TOGGLEUI" and rawget(p:Current().mapping, "L3:") == nil)
    assert(p:Switch("damage"))
    assert(CK.Mapping:Get("L3", "") == "cmd:TOGGLEUI", "inherited utility did not update")
    assert(p:Switch("tank"))
    assert(CK.Mapping:Get("L3", "") == "spell:103", "shared edit overwrote a personal ability")
    assert(p:Switch("healer"))
    assert(CK.Mapping:Get("L3", "") == nil and rawget(p:Current().mapping, "L3:") == false,
        "shared edit re-enabled an explicitly cleared input")
    local _, second = fixture(savedCopy(CK.db), "Second")
    assert(second.Mapping:Get("L3", "") == "cmd:TOGGLEUI", "new character did not inherit the latest utility")
end)

check("saved reload restores an active non-General profile and its ability roles", function()
    local p, CK = fixture()
    assert(p:Switch("healer"))
    CK.Mapping:Set("L4", "", "spell:103")
    p:Current().myWheels.list[1].name = "Healing"
    assert(p:ApplyRole("heal", "L4", "LT", "spell:102", false))
    local restored, loaded = fixture(savedCopy(CK.db))
    assert(restored.character.active == "healer" and restored:ActiveName() == "Healer")
    assert(loaded.Mapping:Get("L4", "") == "spell:103" and loaded.Mapping:Get("L4", "LT") == "spell:102")
    assert(restored:RoleAction("heal") == "spell:102" and loaded.db.settings.myWheels.list[1].name == "Healing")
    local input, layer = restored:RolePosition("heal")
    assert(input == "L4" and layer == "LT")
    assert(restored.character.layouts.general.mapping["L4:"] == "spell:101")
    assert(rawget(loaded.db.settings, "mapping") == nil and rawget(loaded.db.settings, "myWheels") == nil)
end)

check("copying the legacy layout keeps canonical shared utilities and future updates", function()
    local p, CK = fixture()
    CK.Mapping:Set("L3", "", "cmd:TOGGLEUI")
    CK.Mapping:SetReplaced("A", "", "cmd:TOGGLEWORLDMAP")
    assert(p.data.legacy.mapping["L3:"] == "cmd:TOGGLEAUTORUN")
    assert(p.data.legacy.replaced["A:"] == "bar:top:x")
    assert(p:CopyFrom("legacy"))
    assert(CK.Mapping:Get("L3", "") == "cmd:TOGGLEUI", "legacy copy shadowed the current shared command")
    assert(CK.Mapping:GetReplaced("A", "") == "cmd:TOGGLEWORLDMAP", "legacy copy shadowed the current shared replacement")
    assert(rawget(p:Current().mapping, "L3:") == nil and rawget(p:Current().replaced, "A:") == nil,
        "copied utility commands must not become personal overrides")
    assert(CK.Mapping:Get("L4", "") == "spell:101" and p:Current().myWheels.list[1].slots[1] == "spell:101")
    assert(p:Switch("tank"))
    CK.Mapping:Set("L3", "", "cmd:TOGGLERUN")
    CK.Mapping:SetReplaced("A", "", "cmd:TOGGLEUI")
    assert(p:Switch("general"))
    assert(CK.Mapping:Get("L3", "") == "cmd:TOGGLERUN" and CK.Mapping:GetReplaced("A", "") == "cmd:TOGGLEUI",
        "the copied profile stopped receiving shared utility updates")
end)

assert(#failures == 0, table.concat(failures, "\n"))
print(passed .. " profile regression groups passed")