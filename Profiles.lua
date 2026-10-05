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
local Pr = {}
CK.Profiles = Pr

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
    f:SetScript("OnEvent", function()
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
