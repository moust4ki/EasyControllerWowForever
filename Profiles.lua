local _, CK = ...
local L = CK.L

-- Profiles: each character its own buttons and paddles, its own wheels,
-- supplies and consumables wheel categories, or the account's (shared). The
-- rest (the paddles' keys, the look, the keyboard...) stays the account's.
--
-- The account's values stay in settings, as before; each character's are
-- kept in ControllerKeyboardDB.profiles["Name-Realm"] (in the account's
-- file, so another character's can be copied). At login, a character on its
-- own profile has its tables put in settings in place of the account's,
-- which come back before the game saves (logout, reload): every module keeps
-- reading settings as it always did. On first load, each character starts
-- from a copy of the configuration: nothing is lost, and a player with one
-- character never has to look at this.
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

local function defaults(name)
    local d = CK.DEFAULTS
    if name == "myWheels" then return copy(d.myWheels) end
    if name == "supplies.list" then return {} end
    if name == "supplies.custom" then return {} end
    if name == "wheel.categories" then return copy(d.wheel.categories) end
    return {}
end

function Pr:Key()
    local name = UnitName and UnitName("player")
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
    if not (name and name ~= "" and realm and realm ~= "") then return nil end
    return name .. "-" .. realm
end

function Pr:Profile()
    return self.key and CK.db.profiles[self.key]
end

function Pr:IsOwn()
    local p = self:Profile()
    return p and p.mode == "character" or false
end

-- The tables in use back where they belong (a module may have put a new
-- table in settings): this character's, or the account's
function Pr:Collect()
    local p = self:Profile()
    if not (p and self.shared) then return end
    for i, f in ipairs(FIELDS) do
        local t, k = slot(f[2])
        if p.mode == "character" then p.data[f[1]] = t[k] else self.shared[i] = t[k] end
    end
end

-- This character's tables (or the account's) into settings
function Pr:Activate()
    local p = self:Profile()
    if not (p and self.shared) then return end
    for i, f in ipairs(FIELDS) do
        local t, k = slot(f[2])
        if p.mode == "character" then
            if p.data[f[1]] == nil then p.data[f[1]] = copy(self.shared[i]) end
            t[k] = p.data[f[1]]
        else
            t[k] = self.shared[i]
        end
    end
    -- A broken entry in its file never stops the addon
    CK.CleanEntries(CK.db.settings)
end

-- At login, before the modules start
function Pr:Init()
    local db = CK.db
    if type(db.profiles) ~= "table" then db.profiles = {} end
    local key = self:Key()
    if not key then return end
    self.key = key
    self.shared = {}
    for i, f in ipairs(FIELDS) do
        local t, k = slot(f[2])
        self.shared[i] = t[k]
    end
    -- Other characters' profiles broken in the file: left out
    for k, p in pairs(db.profiles) do
        if type(k) ~= "string" or type(p) ~= "table" or type(p.data) ~= "table" then db.profiles[k] = nil end
    end
    local p = db.profiles[key]
    if type(p) ~= "table" then
        -- First load with profiles: a copy of the configuration
        local data = {}
        for i, f in ipairs(FIELDS) do data[f[1]] = copy(self.shared[i]) end
        p = { mode = "character", data = data }
        db.profiles[key] = p
    end
    if p.mode ~= "shared" then p.mode = "character" end
    p.name = UnitName("player")
    p.realm = (GetRealmName and GetRealmName()) or ""
    p.class = select(2, UnitClass("player"))
    self:Activate()
end

-- Before the game saves: the account's values back in settings, this
-- character's kept in its profile
function Pr:Store()
    if not (self:Profile() and self.shared) then return end
    self:Collect()
    for i, f in ipairs(FIELDS) do
        local t, k = slot(f[2])
        t[k] = self.shared[i]
    end
end

-- Everything that reads them, again
local function refresh()
    local M = CK.Mapping
    M:Apply()
    CK.Paddles:Apply()
    if CK.MyWheels then CK.MyWheels:UpdateBindingNames() end
    if CK.ConsumableWheel then CK.ConsumableWheel:Fill() end
    if CK.Supplies then CK.Supplies:Refresh() end
    CK.Config:Render()
end

function Pr:SetMode(mode)
    if CK:BlockedByCombat() then return end
    local p = self:Profile()
    if not p or p.mode == mode then return end
    self:Collect()
    p.mode = mode
    self:Activate()
    refresh()
end

-- This character's configuration from another one's (its own, or the
-- account's if it uses the shared one)
function Pr:CopyFrom(key)
    if CK:BlockedByCombat() then return end
    local p, src = self:Profile(), CK.db.profiles[key]
    if not (p and src and key ~= self.key) then return end
    self:Collect()
    local data = {}
    for i, f in ipairs(FIELDS) do
        local from = src.mode == "character" and src.data and src.data[f[1]]
        if from == nil then from = self.shared[i] end
        data[f[1]] = copy(from)
    end
    p.data, p.mode = data, "character"
    self:Activate()
    refresh()
end

-- This character's configuration emptied
function Pr:Reset()
    if CK:BlockedByCombat() then return end
    local p = self:Profile()
    if not p then return end
    self:Collect()
    local data = {}
    for _, f in ipairs(FIELDS) do data[f[1]] = defaults(f[1]) end
    p.data, p.mode = data, "character"
    self:Activate()
    refresh()
end

-- The other characters known (logged in once with profiles), by name
function Pr:Others()
    local list = {}
    for key, p in pairs(CK.db.profiles or {}) do
        if key ~= self.key and type(p) == "table" then list[#list + 1] = { key = key, p = p } end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

local function nameOf(entry)
    local p = entry.p
    local name = type(p.name) == "string" and p.name or entry.key
    local realm = type(p.realm) == "string" and p.realm or ""
    local text = name .. (realm ~= "" and (" - " .. realm) or "")
    local color = type(p.class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
    if color and color.colorStr then text = "|c" .. color.colorStr .. text .. "|r" end
    return text
end

---------------------------------------------------------------------------
-- The Profiles tab: apart, so a player with one character never needs it
---------------------------------------------------------------------------
local Config = CK.Config

local function characterRows(b)
    b.info(L.TIP_SEC_PROFILE)
    b.header(L.HDR_PROFILE_THIS)
    local p = Pr:Profile()
    if not p then
        b.info(L.PROFILE_UNKNOWN)
        return
    end
    b.choice({ id = "p_mode", label = L.LBL_PROFILE_MODE, tip = L.TIP_PROFILE_MODE,
        text = function() return p.mode == "character" and L.PROFILE_OWN or L.PROFILE_SHARED end,
        step = function() Pr:SetMode(p.mode == "character" and "shared" or "character") end })
    b.button({ id = "p_reset", label = L.LBL_PROFILE_RESET, danger = true, armedLabel = L.LBL_PRESS_AGAIN, verb = L.V_EMPTY,
        disabled = p.mode ~= "character", tip = L.TIP_PROFILE_RESET,
        func = function()
            Pr:Reset()
            Config:Toast(L.TOAST_PROFILE_RESET)
        end })
end

local function copyRows(b)
    b.info(L.TIP_SEC_PROFILE_COPY)
    local others = Pr:Others()
    if #others == 0 then
        b.info(L.PROFILE_NO_OTHER)
        return
    end
    b.header(L.HDR_PROFILE_COPY)
    for _, entry in ipairs(others) do
        local name = nameOf(entry)
        b.button({ id = "p_copy_" .. entry.key, label = name, danger = true, armedLabel = L.LBL_PRESS_AGAIN, verb = L.V_COPY,
            tip = format(L.TIP_PROFILE_COPY, name),
            func = function()
                Pr:CopyFrom(entry.key)
                Config:Toast(format(L.TOAST_PROFILE_COPIED, name))
            end })
    end
end

Config.pages.profiles = Config.NewRailPage({
    key = "profiles",
    sections = {
        { key = "character", label = L.SEC_PROFILE, tip = L.TIP_SEC_PROFILE, rows = characterRows },
        { key = "copy", label = L.SEC_PROFILE_COPY, tip = L.TIP_SEC_PROFILE_COPY, rows = copyRows },
    },
})
