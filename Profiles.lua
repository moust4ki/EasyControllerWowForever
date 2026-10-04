local _, CK = ...
local P = {}
CK.Profiles = P
P.ROLES = { { key = "general", name = "General" }, { key = "tank", name = "Tank" },
    { key = "healer", name = "Healer" }, { key = "damage", name = "Damage" } }
P.ACTION_ROLES = { { key = "interrupt", name = "Interrupt" }, { key = "defensive", name = "Defensive" },
    { key = "movement", name = "Movement" }, { key = "heal", name = "Emergency heal" } }
local scoped = { mapping = true, replaced = true, myWheels = true }
local defaultPositions = { interrupt = "L4", defensive = "L5", movement = "R4", heal = "R5" }
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end
local function empty() return { mapping = {}, replaced = {}, myWheels = { list = {} }, roleActions = {} } end
local function sharedAction(action)
    return type(action) == "string" and (action:match("^cmd:") or action:match("^bar:top:[abxy]$")
        or action == "wheel:consumables")
end
local function roleName(key)
    for _, r in ipairs(P.ROLES) do if r.key == key then return r.name end end
end

function P:Current() return self.character.layouts[self.character.active] end
function P:CharacterName() return self.characterKey end
function P:ActiveName() return self.ready and roleName(self.character.active) or "General" end
function P:Has(role) return self.ready and self.character.layouts[role] ~= nil end

function P:Attach(layout)
    for _, kind in ipairs({ "mapping", "replaced" }) do
        layout[kind] = layout[kind] or {}
        setmetatable(layout[kind], { __index = self.data.shared[kind] })
    end
    layout.myWheels = layout.myWheels or { list = {} }
    layout.roleActions = layout.roleActions or {}
end

function P:Init()
    if self.ready then return end
    local name, realm = UnitFullName("player")
    realm = realm ~= "" and realm or nil
    realm = realm or GetRealmName()
    if not name or name == "" or not realm or realm == "" then
        error("Easy Controller could not identify this character; profiles were not changed.")
    end
    local db, s = CK.db, CK.db.settings
    if not db.controllerProfiles then
        local legacy = { mapping = copy(s.mapping), replaced = copy(s.replaced), myWheels = copy(s.myWheels) }
        -- Include the pre-0.5 paddle format in the recoverable import too.
        for id, cfg in pairs(s.paddles) do
            local key = id .. ":"
            if cfg.action and legacy.mapping[key] == nil then legacy.mapping[key] = cfg.action end
        end
        db.controllerProfiles = { version = 1, legacy = legacy, characters = {},
            shared = { mapping = {}, replaced = {} }, positions = {} }
        self.importing = true
    end
    self.data, self.characterKey = db.controllerProfiles, name .. " - " .. realm
    local data = self.data
    if not data.characters[self.characterKey] then
        local layout = self.importing and copy(data.legacy) or empty()
        -- Preserve the first character's existing layout and promote only utility
        -- commands. Ability, macro and custom wheel identities stay local.
        if self.importing then
            for _, kind in ipairs({ "mapping", "replaced" }) do
                for key, action in pairs(layout[kind]) do
                    if sharedAction(action) then data.shared[kind][key], layout[kind][key] = action, nil end
                end
            end
        end
        data.characters[self.characterKey] = { active = "general", layouts = { general = layout } }
    end
    self.character = data.characters[self.characterKey]
    for _, layout in pairs(self.character.layouts) do self:Attach(layout) end
    -- Canonical layouts live in controllerProfiles. Existing consumers keep the
    -- settings API, without duplicate saved copies of the active layout.
    for key in pairs(scoped) do rawset(s, key, nil) end
    setmetatable(s, {
        __index = function(_, key) if scoped[key] then return P:Current()[key] end end,
        __newindex = function(t, key, value)
            if scoped[key] then P:Current()[key] = value else rawset(t, key, value) end
        end,
    })
    self.ready, self.importing = true, nil
end

function P:SetBinding(kind, key, action)
    local localBindings, shared = self:Current()[kind], self.data.shared[kind]
    if sharedAction(action) then
        shared[key], localBindings[key] = action, nil
    else
        -- A false entry explicitly restores the game's behavior here, even if
        -- another character has a shared utility on the same combination.
        if action == nil and shared[key] ~= nil then localBindings[key] = false
        else localBindings[key] = action end
    end
end

function P:BindingPairs(kind)
    local effective = {}
    for key, action in pairs(self.data.shared[kind]) do effective[key] = action end
    for key, action in pairs(self:Current()[kind]) do effective[key] = action end
    for key, action in pairs(effective) do if not action then effective[key] = nil end end
    return pairs(effective)
end

function P:ClearBindings(kind)
    local bindings = self:Current()[kind]
    for key in pairs(bindings) do bindings[key] = nil end
    for key in pairs(self.data.shared[kind]) do bindings[key] = false end
end

local function blocked()
    return InCombatLockdown() and "Profiles and role assignments can only change outside combat."
end
function P:BeforeChange()
    CK.MyWheels:CloseEditor()
    local W = CK.ConsumableWheel
    W:StopPlacement()
    if W.frame then W.frame:Hide(); ClearOverrideBindings(W.frame) end
    CK.Toggle:Release()
end
function P:Refresh()
    CK.MyWheels:UpdateBindingNames()
    CK.ConsumableWheel:Fill()
    CK.Mapping:DropSnapshot()
    CK.Mapping:Apply()
    CK.Paddles:Apply()
end
function P:Switch(role)
    local reason = blocked()
    if reason then return false, reason end
    if not self.ready or not roleName(role) then return false, "Unknown profile." end
    if role == self.character.active then return true, "This profile is already active." end
    self:BeforeChange()
    if not self:Has(role) then self.character.layouts[role] = copy(self:Current()) end
    self:Attach(self.character.layouts[role])
    self.character.active = role
    self:Refresh()
    return true, "Active profile: " .. self:ActiveName()
end

function P:Sources()
    local list = { { key = "legacy", name = "Original imported layout" } }
    for character, entry in pairs(self.data.characters) do
        for role in pairs(entry.layouts) do
            if character ~= self.characterKey or role ~= self.character.active then
                list[#list + 1] = { key = character .. "\n" .. role, name = character .. " / " .. roleName(role) }
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end
function P:CopyFrom(key)
    local reason = blocked()
    if reason then return false, reason end
    local character, role = key:match("^(.-)\n(.*)$")
    local source = key == "legacy" and self.data.legacy or
        (self.data.characters[character] and self.data.characters[character].layouts[role])
    if not source then return false, "That layout is no longer available." end
    self:BeforeChange()
    local layout = copy(source)
    for _, kind in ipairs({ "mapping", "replaced" }) do
        for binding, action in pairs(layout[kind]) do
            if sharedAction(action) then layout[kind][binding] = nil end
        end
    end
    self:Attach(layout)
    self.character.layouts[self.character.active] = layout
    self:Refresh()
    return true, "Copied personal bindings and custom wheels. Shared utility commands keep their current settings."
end

function P:RolePosition(role)
    local pos = self.data.positions[role]
    return pos and pos.input or defaultPositions[role], pos and pos.layer or ""
end
function P:RoleAction(role) return self:Current().roleActions[role] end
function P:PreviewRole(role, inputId, layer, action, replace)
    local reason = blocked()
    if reason then return false, reason end
    if not defaultPositions[role] then return false, "Choose an action role." end
    local M, validLayer = CK.Mapping, false
    if not M:Enabled() then return false, "Enable gamepad mapping in Home > Modules first." end
    for _, value in ipairs(M.LAYERS) do if layer == value then validLayer = true end end
    local input = M.BY_ID[inputId]
    if not validLayer or not input or input.layer then return false, "Choose a supported button and layer." end
    if not M:InputEnabled(input) then return false, "Enable this button in Gamepad settings first." end
    local known = false
    for _, entry in ipairs(M:Catalog("spells")) do if entry.action == action then known = true; break end end
    if not known then return false, "Choose an ability from this character's spellbook." end
    local kind
    local state = M:State(input, layer)
    if state == "locked" then return false, "This layer is unavailable. Check its trigger modifier in Gamepad settings." end
    if state == "free" then kind = "mapping"
    elseif M:Replaceable(input, layer) then kind = "replaced"
    else return false, "This combination is reserved by the game. Choose another." end
    if kind == "replaced" and not M:OwnKeys() and not M:CanOwnKeys() then
        return false, "No free trigger modifiers; check Gamepad settings."
    end
    local key = inputId .. ":" .. layer
    local old = self:Current()[kind][key]
    -- A native spell is also an occupied position; never silently replace it.
    local native = kind == "replaced" and M:NativeAction(input, layer) or nil
    local previous = old or native
    if previous and previous ~= action and not replace then
        return false, "Occupied by " .. (M:ActionName(previous) or previous) .. ". Enable Replace existing to continue."
    end
    return true, (M:ActionName(previous) or "Unassigned") .. " -> " .. (M:ActionName(action) or action), kind
end
function P:ApplyRole(role, inputId, layer, action, replace)
    local ok, message, kind = self:PreviewRole(role, inputId, layer, action, replace)
    if not ok then return false, message end
    if kind == "replaced" then CK.Mapping:SetReplaced(inputId, layer, action)
    else CK.Mapping:Set(inputId, layer, action) end
    self.data.positions[role] = { input = inputId, layer = layer }
    self:Current().roleActions[role] = action
    return true, "Assigned " .. role .. ": " .. message
end
