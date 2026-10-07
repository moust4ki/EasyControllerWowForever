local _, CK = ...

-- Profiles: each character its own buttons and paddles, its own wheels,
-- supplies and consumables wheel categories, on its own, with no option
-- (players asked: a character's settings must never touch another one's).
-- The rest (the paddles' keys, the look, the keyboard...) stays the
-- account's.
--
-- The account's values stay in settings, as before; each character's are
-- kept in ControllerKeyboardDB.profiles["Name-Realm"] (in the account's
-- file). At login, the character's tables are put in settings in place of
-- the account's, which come back before the game saves (logout, reload):
-- every module keeps reading settings as it always did. On its first load
-- a character starts from a copy of the account's configuration, the one
-- from before profiles (nothing is lost on an update); nothing changes it
-- any more, so a character started later never gets another's. The spells
-- of such a copy this character doesn't have are left out (a new druid got
-- the rogue's: see DropForeignSpells).
--
-- A character's profiles (asked: a druid's healing and its feral buttons):
-- up to 5 sets of its buttons, its replaced buttons and its wheels, one in
-- use; its supplies and consumables wheel categories are the same for all
-- of them. Kept in its own entry only, never offered to another character.
-- The one in use lives in p.data (as before profiles had sets); the others
-- in p.sets[i].data. A new one starts empty. Switched by hand (Home ›
-- Profiles, /ec profile <name>) or with the talents (primary / secondary,
-- an option), out of combat only (in combat: once it ends).
local Pr = {}
CK.Profiles = Pr
Pr.MAX_SETS = 5

-- What follows the character: { name, path in settings }
local FIELDS = {
    { "mapping", { "mapping" } },
    { "replaced", { "replaced" } },
    { "myWheels", { "myWheels" } },
    { "supplies.list", { "supplies", "list" } },
    { "supplies.custom", { "supplies", "custom" } },
    { "wheel.categories", { "wheel", "categories" } },
}

local function slot(path)
    local t = CK.db.settings
    for i = 1, #path - 1 do t = t[path[i]] end
    return t, path[#path]
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

-- The realm as the game writes it in a character's full name ("Classic Beta
-- PvP" -> "ClassicBetaPvP"), the same at every login: a key that changed
-- would give the character a new profile
local function realmKey()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(realm) == "string" and realm ~= "" then return realm end
    realm = GetRealmName and GetRealmName()
    if type(realm) ~= "string" or realm == "" then return nil end
    return (realm:gsub("[%s%-]", ""))
end

-- The character's full name: WoW Forever gives a first name and a surname
-- (UnitName's second value there; "Fraicheur Rog", "Fraicheur Hunt"). With
-- the first name alone every "Fraicheur ..." had one profile, shared
-- (reported: a bind removed on the warlock was gone on the shaman too).
local function fullName()
    if not UnitName then return nil end
    -- (both values: "UnitName and UnitName(...)" would keep the first only)
    local name, surname = UnitName("player")
    if not (type(name) == "string" and name ~= "") then return nil end
    if type(surname) == "string" and surname ~= "" then return name .. " " .. surname, name end
    return name, name
end

-- The key, the full name, the first name
function Pr:Key()
    local full, first = fullName()
    local realm = realmKey()
    if not (full and realm) then return nil end
    return full .. "-" .. realm, full, first, realm
end

function Pr:Profile()
    return self.key and CK.db.profiles[self.key]
end

-- The tables in use back in the character's profile (a module may have put
-- a new table in settings)
function Pr:Collect()
    local p = self:Profile()
    if not (p and self.shared) then return end
    for _, f in ipairs(FIELDS) do
        local t, k = slot(f[2])
        p.data[f[1]] = t[k]
    end
end

-- The character's tables into settings
function Pr:Activate()
    local p = self:Profile()
    if not (p and self.shared) then return end
    for i, f in ipairs(FIELDS) do
        local t, k = slot(f[2])
        if p.data[f[1]] == nil then p.data[f[1]] = copy(self.shared[i]) end
        t[k] = p.data[f[1]]
    end
    -- A broken entry in its file never stops the addon
    CK.CleanEntries(CK.db.settings)
end

---------------------------------------------------------------------------
-- The sets of a character
---------------------------------------------------------------------------
local SET_FIELDS = { "mapping", "replaced", "myWheels" }

local function setField(f, v)
    if type(v) ~= "table" then v = {} end
    if f == "myWheels" and type(v.list) ~= "table" then v.list = {} end
    return v
end

local function findSet(p, id)
    for i, set in ipairs(p.sets or {}) do
        if set.id == id then return set, i end
    end
end

-- The fields in use put away in the set in use, the other set's taken
local function swap(p, id)
    local current, target = findSet(p, p.active), findSet(p, id)
    if not target then return false end
    if current then
        local data = {}
        for _, f in ipairs(SET_FIELDS) do data[f] = p.data[f] end
        current.data = data
    end
    local data = target.data or {}
    for _, f in ipairs(SET_FIELDS) do p.data[f] = setField(f, data[f]) end
    target.data = nil
    p.active = id
    return true
end

local function newName(p)
    local used = {}
    for _, set in ipairs(p.sets) do used[set.name] = true end
    local n = #p.sets + 1
    while used[format(CK.L.PROFILE_NAME_N, n)] do n = n + 1 end
    return format(CK.L.PROFILE_NAME_N, n)
end

-- A character's sets as they should be (the first load: what it has is
-- its first one; a broken file: nothing it uses is lost)
function Pr:InitSets(p)
    local list, seen, maxId = {}, {}, 0
    for _, set in ipairs(type(p.sets) == "table" and p.sets or {}) do
        if type(set) == "table" and type(set.id) == "number" and not seen[set.id] and #list < Pr.MAX_SETS then
            seen[set.id] = true
            if type(set.name) ~= "string" or set.name == "" then set.name = format(CK.L.PROFILE_NAME_N, #list + 1) end
            if set.data ~= nil and type(set.data) ~= "table" then set.data = nil end
            list[#list + 1] = set
            if set.id > maxId then maxId = set.id end
        end
    end
    p.sets = list
    if not seen[p.active] then
        -- What it uses: a profile of its own (never one dropped for it)
        maxId = maxId + 1
        table.insert(list, 1, { id = maxId, name = newName(p) })
        seen[maxId] = true
        p.active = maxId
    end
    -- The one in use lives in p.data
    findSet(p, p.active).data = nil
    p.nextSet = math.max(tonumber(p.nextSet) or 0, maxId + 1)
    if type(p.specSets) ~= "table" then p.specSets = {} end
    for group, id in pairs(p.specSets) do
        if not seen[id] then p.specSets[group] = nil end
    end
    p.auto = p.auto == true
end

-- The talents in use: 1 (primary), 2 (secondary), nil when not known
function Pr:SpecGroup()
    local info = C_SpecializationInfo
    local get = info and info.GetActiveSpecGroup
    local ok, group = false, nil
    if get then ok, group = pcall(get) end
    if not (ok and type(group) == "number") and GetActiveTalentGroup then ok, group = pcall(GetActiveTalentGroup) end
    return ok and type(group) == "number" and group or nil
end

-- At login, before the modules start
function Pr:Init()
    local db = CK.db
    if type(db.profiles) ~= "table" then db.profiles = {} end
    local key, full, first, realm = self:Key()
    if not key then return end
    self.key = key
    self.shared = {}
    for i, f in ipairs(FIELDS) do
        local t, k = slot(f[2])
        self.shared[i] = t[k]
    end
    -- Profiles broken in the file: left out
    for k, p in pairs(db.profiles) do
        if type(k) ~= "string" or type(p) ~= "table" or type(p.data) ~= "table" then db.profiles[k] = nil end
    end
    local name = full
    local p = db.profiles[key]
    if not p and full == first then
        -- Saved under the realm with its spaces (a login where the game gave
        -- no other name): the same character
        for k, other in pairs(db.profiles) do
            if other.name == name and type(other.realm) == "string" and k == name .. "-" .. other.realm then
                p, db.profiles[k] = other, nil
                db.profiles[key] = p
                break
            end
        end
    end
    local legacy = full ~= first and db.profiles[first .. "-" .. realm]
    if not p and legacy then
        -- Saved by the first name alone (up to 1.11.6), shared by every
        -- character with that first name: each one starts from a copy of
        -- it, what it had kept, its own from now on
        local data = {}
        for _, f in ipairs(FIELDS) do data[f[1]] = copy(legacy.data[f[1]]) end
        p = { data = data, copied = true }
        db.profiles[key] = p
        legacy.firstNameOnly = true
    end
    if not p then
        -- First load with profiles: a copy of the account's configuration
        local data = {}
        for i, f in ipairs(FIELDS) do data[f[1]] = copy(self.shared[i]) end
        p = { data = data, copied = true }
        db.profiles[key] = p
    elseif p.mode == "shared" then
        -- On the shared settings (1.9 to 1.11.1): its own from now on, a copy
        -- of what it used
        for i, f in ipairs(FIELDS) do p.data[f[1]] = copy(self.shared[i]) end
        p.copied = true
    end
    p.mode = "character"
    p.firstNameOnly = nil
    p.name = name
    p.realm = (GetRealmName and GetRealmName()) or ""
    p.class = select(2, UnitClass("player"))
    self:InitSets(p)
    -- With the talents (option): the one of the talents in use
    local want = p.auto and p.specSets[self:SpecGroup() or 0]
    if want and want ~= p.active then swap(p, want) end
    self:Activate()
    -- The modules start after: they read the settings as they are then
    self:DropForeignSpells(false)
end

-- Everything that reads the character's settings, read again
local function reread()
    CK.Mapping:Apply()
    CK.Paddles:Apply()
    if CK.MyWheels and CK.MyWheels.UpdateBindingNames then CK.MyWheels:UpdateBindingNames() end
    if CK.ConsumableWheel then CK.ConsumableWheel:Fill() end
    if CK.Supplies then CK.Supplies:Refresh() end
end

-- The names of the spells in the character's spell book (by name: a lower
-- rank still counts); nil while the book is not read yet
local function knownSpells()
    local SB = C_SpellBook
    if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) then
        return nil
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local names, any = {}, false
    for line = 1, SB.GetNumSpellBookSkillLines() or 0 do
        local info = SB.GetSpellBookSkillLineInfo(line)
        if info and info.itemIndexOffset and info.numSpellBookItems then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = SB.GetSpellBookItemInfo(i, bank)
                if item and item.name then
                    names[item.name] = true
                    any = true
                end
            end
        end
    end
    return any and names or nil
end

-- A spell this character doesn't have (one whose name the game doesn't
-- give is kept: nothing to tell)
local function foreign(action, names)
    local id = type(action) == "string" and tonumber(action:match("^spell:(%d+)$"))
    local name = id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return type(name) == "string" and not names[name]
end

-- A profile started from a copy (the old profile of the first name, the
-- account's configuration): the spells in it this character doesn't have
-- left out, once its spell book is read (reported: a new druid, Fraicheur
-- Drood, got Stealth and Stoneform on its paddles, from the old profile of
-- every "Fraicheur ...", the rogue's). Only once: a spell the character
-- loses later (talents...) keeps its button.
function Pr:DropForeignSpells(reload)
    local p = self:Profile()
    if not (p and p.copied) then return end
    local names = knownSpells()
    if not names then return end
    p.copied = nil
    local s, dropped = CK.db.settings, 0
    for _, assigned in ipairs({ s.mapping, s.replaced }) do
        if type(assigned) == "table" then
            for k, action in pairs(assigned) do
                if foreign(action, names) then
                    assigned[k] = nil
                    dropped = dropped + 1
                end
            end
        end
    end
    local wheels = type(s.myWheels) == "table" and s.myWheels.list
    for _, w in ipairs(type(wheels) == "table" and wheels or {}) do
        if type(w) == "table" and type(w.slots) == "table" then
            for i, action in pairs(w.slots) do
                if foreign(action, names) then
                    w.slots[i] = nil
                    dropped = dropped + 1
                end
            end
        end
    end
    if dropped > 0 and reload then reread() end
end

-- The character's sets: { id, name, active, primary, secondary }
function Pr:Sets()
    local p = self:Profile()
    local out = {}
    if not (p and p.sets) then return out end
    for _, set in ipairs(p.sets) do
        out[#out + 1] = { id = set.id, name = set.name, active = set.id == p.active,
            primary = p.specSets[1] == set.id, secondary = p.specSets[2] == set.id }
    end
    return out
end

function Pr:ActiveSet()
    local p = self:Profile()
    local set = p and p.sets and findSet(p, p.active)
    return set and set.id, set and set.name
end

function Pr:SetName(id)
    local p = self:Profile()
    local set = p and p.sets and findSet(p, id)
    return set and set.name
end

-- Everything open on the old one: shown again from the new one
local function afterSwitch()
    reread()
    if CK.MyWheels and CK.MyWheels.open and CK.MyWheels.CloseEditor then CK.MyWheels:CloseEditor() end
    if CK.Config and CK.Config.IsOpen and CK.Config:IsOpen() then CK.Config:Render() end
end

-- Another set in use. In combat (its buttons are secure): once it ends
function Pr:SetActive(id, quiet)
    local p = self:Profile()
    if not (p and self.shared and p.sets and findSet(p, id)) then return false end
    if id == p.active then
        self.pending = nil
        return true
    end
    if InCombatLockdown() then
        self.pending = id
        CK:Print(CK.L.PROFILE_AFTER_COMBAT, findSet(p, id).name)
        return false
    end
    self.pending = nil
    self:Collect()
    swap(p, id)
    self:Activate()
    afterSwitch()
    if not quiet then
        local name = findSet(p, id).name
        if CK.Config and CK.Config.IsOpen and CK.Config:IsOpen() then
            CK.Config:Toast(format(CK.L.PROFILE_ON, name))
        else
            CK:Print(CK.L.PROFILE_ON, name)
        end
    end
    return true
end

-- A new set, empty (asked: from nothing), put in use
function Pr:CreateSet()
    local p = self:Profile()
    if not (p and p.sets) or #p.sets >= Pr.MAX_SETS or InCombatLockdown() then return nil end
    local id = p.nextSet
    p.nextSet = id + 1
    local data = {}
    for _, f in ipairs(SET_FIELDS) do data[f] = setField(f, nil) end
    p.sets[#p.sets + 1] = { id = id, name = newName(p), data = data }
    self:SetActive(id)
    return id
end

function Pr:RenameSet(id, name)
    local p = self:Profile()
    local set = p and p.sets and findSet(p, id)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if not set or name == "" then return false end
    set.name = name:sub(1, 40)
    return true
end

-- A set deleted (never the last one); the one in use: another in its place
function Pr:DeleteSet(id)
    local p = self:Profile()
    if not (p and p.sets) or #p.sets <= 1 or InCombatLockdown() then return false end
    local set, index = findSet(p, id)
    if not set then return false end
    if id == p.active then
        local other = p.sets[index == 1 and 2 or 1]
        if not self:SetActive(other.id, true) then return false end
        set, index = findSet(p, id)
    end
    table.remove(p.sets, index)
    for group, setId in pairs(p.specSets) do
        if setId == id then p.specSets[group] = nil end
    end
    return true
end

-- With the talents: on, and the set of each talent group
function Pr:Auto()
    local p = self:Profile()
    return p and p.auto or false
end

function Pr:SetAuto(on)
    local p = self:Profile()
    if not p then return end
    p.auto = on and true or false
    if p.auto then self:FollowTalents() end
end

function Pr:SpecSet(group)
    local p = self:Profile()
    return p and p.specSets and p.specSets[group]
end

function Pr:SetSpecSet(group, id)
    local p = self:Profile()
    if not (p and p.specSets) then return end
    p.specSets[group] = id and findSet(p, id) and id or nil
    if p.auto and group == self:SpecGroup() then self:FollowTalents() end
end

-- The set of the talents in use (option on)
function Pr:FollowTalents()
    local p = self:Profile()
    local want = p and p.auto and p.specSets[self:SpecGroup() or 0]
    if want then self:SetActive(want) end
end

-- The character not known at login (its name or realm not given yet): its
-- profile once the world is loaded, and everything that reads it again
function Pr:Retry()
    if self.key or not CK.db then return end
    self:Init()
    if not self.key then return end
    reread()
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("SPELLS_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(f.RegisterEvent, f, "ACTIVE_TALENT_GROUP_CHANGED")
    f:SetScript("OnEvent", function(_, event)
        if event == "ACTIVE_TALENT_GROUP_CHANGED" then
            Pr:FollowTalents()
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            if Pr.pending then Pr:SetActive(Pr.pending) end
            return
        end
        Pr:Retry()
        Pr:DropForeignSpells(true)
    end)
end

-- /ec profile: the character recognised, whether its settings are its own,
-- and what each character holds (players can tell in one line)
local function count(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

local function summary(data)
    local wheels = type(data.myWheels) == "table" and data.myWheels.list
    return format(CK.L.PROFILE_DIAG_LINE, count(data.mapping), count(data.replaced), count(wheels))
end

function Pr:Diagnose()
    local L = CK.L
    local p = self:Profile()
    if not p then
        CK:Print(L.PROFILE_DIAG_OFF)
    else
        local s = CK.db.settings
        CK:Print(L.PROFILE_DIAG_ON, self.key, summary({ mapping = s.mapping, replaced = s.replaced, myWheels = s.myWheels }))
        for _, set in ipairs(p.sets or {}) do
            local data = set.id == p.active and { mapping = s.mapping, replaced = s.replaced, myWheels = s.myWheels } or set.data or {}
            DEFAULT_CHAT_FRAME:AddMessage(format("  %s %s: %s", set.id == p.active and ">" or "-", set.name, summary(data)))
        end
    end
    local others = {}
    for key, other in pairs(CK.db.profiles or {}) do
        if key ~= self.key and type(other) == "table" and type(other.data) == "table" and not other.firstNameOnly then
            others[#others + 1] = "  " .. key .. ": " .. summary(other.data)
        end
    end
    table.sort(others)
    for _, line in ipairs(others) do DEFAULT_CHAT_FRAME:AddMessage(line) end
    CK:Print(L.PROFILE_DIAG_BAR)
end

-- Before the game saves: the account's values back in settings, the
-- character's kept in its profile. Done first at logout (Chat.lua): the
-- account's configuration must never be saved with a character's in it.
function Pr:Store()
    if not (self:Profile() and self.shared) then return end
    self:Collect()
    for i, f in ipairs(FIELDS) do
        local t, k = slot(f[2])
        t[k] = self.shared[i]
    end
end
