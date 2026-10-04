-- Run from the addon directory: lua tools/test_profile_options.lua (Lua 5.1).
local function noop() end
local function fixture(CK, globals)
    local env = setmetatable(globals or {}, { __index = _G }); env._G = env
    return function(path)
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("EasyController", CK)
    end
end
local function get(rows, id)
    for _, row in ipairs(rows) do if row.id == id then return row end end
    error("Missing row: " .. id)
end

-- Exercise actual rail-page actions and its two-press danger confirmation.
local conflict = false
local combat, active, switched, copied, applied = false, "General", {}, {}, {}
local spells = { { header = "Class" }, { action = "spell:1", name = "Interrupt" }, { action = "spell:2", name = "Heal" } }
local CK = { L = {}, ConfigKit = { C = {} }, db = { settings = { sentinel = true } } }
local loadAddon = fixture(CK, { InCombatLockdown = function() return combat end,
    C_Timer = { After = noop }, format = string.format })
loadAddon("ConfigWindow.lua")
local C = CK.Config
local render = C.Render
C.Render = noop
function C:Toast(message, warn) self.message, self.warn = message, warn end
local page = C.NewRailPage({ key = "home", sections = { { key = "existing", rows = noop } } })
page.picker = { Open = function(self, def) self.def, self.open = def, true end,
    Close = function(self) self.open = false end, IsOpen = function(self) return self.open end }
C.pages.home = page
CK.Mapping = {
    INPUTS = { { id = "LT", layer = true }, { id = "RT", layer = true }, { id = "L4" }, { id = "L5" } },
    Catalog = function(_, tab) assert(tab == "spells"); return spells end,
    ActionName = function(_, action) return action end,
}
CK.Profiles = {
    ready = true,
    ROLES = { { key = "general", name = "General" }, { key = "tank", name = "Tank" }, { key = "healer", name = "Healer" }, { key = "damage", name = "Damage" } },
    ACTION_ROLES = { { key = "interrupt", name = "Interrupt" }, { key = "defensive", name = "Defensive" }, { key = "movement", name = "Movement" }, { key = "heal", name = "Heal" } },
    ActiveName = function() return active end, CharacterName = function() return "Test-Realm" end,
    Has = function(_, role) return role == "general" end,
    Switch = function(self, role)
        switched[#switched + 1] = role
        for _, r in ipairs(self.ROLES) do if r.key == role then active = r.name end end
        return true
    end,
    Sources = function() return { { key = "legacy", name = "Legacy" }, { key = "other", name = "Other / General" } } end,
    CopyFrom = function(_, source) copied[#copied + 1] = source; return true end,
    RolePosition = function(_, role) return role == "interrupt" and "L4" or "L5", "" end,
    RoleAction = function() return "spell:999" end,
    PreviewRole = function(_, role, input, layer, action, replace)
        if conflict and not replace then return false, "An existing binding occupies this button." end
        return action ~= nil, action and (role .. " -> " .. input .. " " .. layer .. (replace and " (replace)" or "")) or "Choose a known spell."
    end,
    ApplyRole = function(_, ...) applied[#applied + 1] = { ... }; return true end,
}
loadAddon("ProfileOptions.lua")
assert(#page.def.sections == 3 and page.def.sections[1].key == "existing", "new sections must append to Home")
page.section = 2; page:Rebuild()
page:Act(get(page.rows, "profile_target"), 1)
assert(#switched == 0, "preview choice must not switch profiles")
page:Rebuild()
page:Act(get(page.rows, "profile_activate"))
assert(switched[1] == "tank" and active == "Tank", "Activate must use the selected profile")
page:Rebuild()
local copy = get(page.rows, "profile_copy")
assert(copy.danger, "Copy must use the existing danger confirmation")
assert(copy.tip:find("personal bindings", 1, true) and copy.tip:find("Shared utility commands keep their current settings.", 1, true), "Copy scope must be explicit")
page:Act(copy)
assert(#copied == 0, "first Copy press must only arm")
page:Act(get(page.rows, "profile_source"), 1)
assert(not C.armed, "changing source must clear its confirmation")
page:Rebuild(); copy = get(page.rows, "profile_copy")
page:Act(copy); assert(#copied == 0)
page:Act(copy); assert(copied[1] == "other", "second Copy press must copy the reviewed source")

page.section = 3
local view = page.def.sections[3].view
assert(view and not page.def.sections[3].rows, "role layout must render cards, not the old generic form")
local _, draft = view:Current()
assert(draft.action == nil and not draft.replace, "unknown spells clear and conflict replacement defaults off")
view:Apply(); assert(#applied == 0, "invalid preview must not apply")
view:Press(page, "A")
assert(page.picker.open and page.picker.def.lists[1].entries() == spells, "card activation must use the existing spell picker")
page.picker.def.onChoose({ action = "spell:999" })
assert(C.warn and page.picker.open, "a stale unknown spell must be rejected")
page.picker.def.onChoose(spells[2]); assert(not page.picker.open and #applied == 0, "choosing a spell only stages it")
view:Apply()
assert(#applied == 1 and applied[1][1] == "interrupt" and applied[1][2] == "L4"
    and applied[1][3] == "" and applied[1][4] == "spell:1" and applied[1][5] == false,
    "Apply must send exactly the reviewed role assignment with preservation by default")
conflict = true; view:Apply(); assert(#applied == 1, "new conflicts must be rechecked at Apply")
view:Press(page, "X"); view.setting = 3; view:Press(page, "A")
view:Press(page, "B"); view:Press(page, "Y")
assert(applied[2][5] == true, "explicit replacement must be forwarded")
view.zone, view.setting = "settings", 1
for i = 1, 6 do
    view:Press(page, "RIGHT")
    local _, current = view:Current()
    assert(current.input == "L4" or current.input == "L5", "triggers must not appear as assignable role buttons")
end
view:Press(page, "B"); view:Press(page, "DOWN")
local _, nextDraft, name = view:Current()
assert(name == "Defensive" and nextDraft.action == nil, "controller navigation must select the next role without saving")
view:Press(page, "UP")
spells = { { action = "spell:2", name = "Heal" } }
local _, stale = view:Current(); assert(stale.action == nil, "newly unlearned spells must clear from drafts")
combat = true; view:Apply(); assert(#applied == 2)
page.section = 2; page:Rebuild(); page:Act(get(page.rows, "profile_activate"))
assert(#switched == 1, "profile activation must remain disabled in combat")
page:Act(get(page.rows, "profile_copy")); page:Act(get(page.rows, "profile_copy"))
assert(#copied == 1, "profile copy must remain disabled in combat")
assert(CK.db.settings.sentinel and next(CK.db.settings, "sentinel") == nil, "draft choices must not write settings")
CK.Profiles.ready = false; page:Rebuild()
assert(#page.rows == 2 and page.rows[2].kind == "info", "unready profiles should show a loading explanation")
local title = { SetText = function(self, text) self.text = text end }
local profile = { SetText = title.SetText }
C.frame = { IsShown = function() return true end, title = title, profile = profile, tabs = {},
    lbGlyph = { Set = noop }, rbGlyph = { Set = noop } }
C.Page = function() return { Render = noop } end
C.RenderHelp = noop
render(C)
assert(title.text == "Easy Controller", "unready profiles must keep the original title")
CK.Profiles.ready = true
render(C)
assert(title.text == "Easy Controller" and profile.text == "Profile: Tank", "the header must show a separate active-profile line")
print("PASS: profile rows, preview/activate, copy confirmation, known-spell picker, role apply, combat guards and active title")

-- The Home > Gamepad total must match effective bindings, not raw tombstones.
local settings = { mapping = { ["L4:"] = false }, replaced = { ["A:"] = false },
    modules = { mapping = true }, features = {}, touchButtons = {} }
local mapCK = { L = setmetatable({ STATUS_YOURS = "%d yours" }, { __index = function(_, key) return key end }),
    db = { settings = settings }, Config = { pages = {} }, ConfigKit = { C = {} },
    Mapping = { CanBeModifier = function() return false end }, Paddles = {} }
mapCK.Profiles = { ready = true, BindingPairs = function(_, kind)
    return pairs(kind == "mapping" and { ["L3:"] = "cmd:TOGGLERUN", ["L5:"] = "spell:1" }
        or { ["X:"] = "cmd:JUMP", ["B:"] = "spell:2" })
end }
fixture(mapCK, { format = string.format, CreateFrame = function()
    return { RegisterEvent = noop, SetScript = noop }
end })("MapWindow.lua")
local status
local builder = setmetatable({ check = function(row) if row.id == "m_map" then status = row.status end end },
    { __index = function() return noop end })
mapCK.MapPage.DisplayRows(builder)
assert(status == "4 yours", "Home total must count effective shared bindings and omit tombstones: " .. tostring(status))
mapCK.Profiles.ready = false
mapCK.MapPage.DisplayRows(builder)
assert(status == "2 yours", "legacy counting must remain unchanged until profiles are ready")
print("PASS: Home Gamepad counts effective profile bindings")