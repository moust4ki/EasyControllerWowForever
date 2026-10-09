local ADDON, CK = ...
_G.ControllerKeyboard = CK

CK.ADDON = ADDON
CK.Dicts = CK.Dicts or {}

---------------------------------------------------------------------------
-- Localisation: English is the base (Locales/enUS.lua), each client
-- language overrides it (Locales/<locale>.lua, loaded before this file);
-- the other languages are then let go
---------------------------------------------------------------------------
-- Updated while the game was running: a /reload doesn't load the files the
-- game didn't know when it started (these). The keys' own names meanwhile,
-- and a word in the chat once in the world
if not CK.L then
    CK.L = setmetatable({}, { __index = function(_, key) return key end })
    local warn = CreateFrame("Frame")
    warn:RegisterEvent("PLAYER_ENTERING_WORLD")
    warn:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffEasy Controller|r: |cffff4040updated while the game was running|r: quit and restart the game (/reload is not enough for new files).")
    end)
end
local L = CK.L

for key, value in pairs(CK.LOCALES and CK.LOCALES[GetLocale()] or {}) do
    L[key] = value
end
CK.LOCALES = nil

BINDING_HEADER_CONTROLLERKEYBOARD = "Easy Controller - Forever"
BINDING_NAME_CONTROLLERKEYBOARD_TOGGLE = L.BINDING_TOGGLE
BINDING_NAME_CONTROLLERKEYBOARD_MAP = L.BINDING_MAP
BINDING_NAME_CONTROLLERKEYBOARD_CONFIG = L.BINDING_CONFIG
_G["BINDING_NAME_CLICK ControllerKeyboardWheelToggle:LeftButton"] = L.WHEEL_NAME
_G["BINDING_NAME_CLICK ControllerKeyboardPhrasesToggle:LeftButton"] = L.PHRASES_NAME

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
CK.DEFAULT_SHORTCUT = { hold = "PADRSHOULDER", press = "PADDDOWN" }

local DEFAULTS = {
    autoOpen = true,
    onlyWithGamepad = false,
    -- The keyboard for the game's other fields too (Fields.lua)
    openFields = true,
    learn = true,
    -- Suggestions and keyboard layout follow the client's language by default
    lang = ({ frFR = "fr", deDE = "de", esES = "es", esMX = "es", itIT = "it" })[GetLocale()] or "en",
    maxWords = 8000,
    numSuggestions = 5,
    scale = 1,
    invertY = false,
    locked = true,
    -- Modules, each one can be turned off
    modules = { keyboard = true, questItems = true, questLinks = true, mapping = true,
        upgrades = true, sellJunk = false, autoRepair = false },
    -- At merchants (Automation.lua): the guild's money first for repairs
    automation = { guildRepair = false },
    -- Gamepad mapping: ["L3:LT"] = "cmd:TOGGLERUN" | "spell:133" | "item:5512" | "macro:Name" | "bar:bottom:a"
    mapping = {},
    -- The game's own buttons replaced, same values
    replaced = {},
    -- Back paddles' learned keys: { key = "F13" }
    paddles = { L4 = {}, L5 = {}, R4 = {}, R5 = {} },
    -- Extra buttons turned on (Home > Gamepad): { TL1 = true, ... }
    touchButtons = {},
    -- The extra buttons anywhere (pixel steps) instead of the fixed places
    extraFree = false,
    -- Each function can be turned off (configuration panel)
    features = {
        drafts = true, linkCapture = true,
        questTooltip = true, questGlow = true, questSellAlert = true, questHoverAlert = true,
        extraDisplay = true, showSticks = true, configShortcut = true,
        -- Out of range: the whole spell in red on the gamepad bar (Range.lua)
        rangeTint = false,
        -- A trigger pressed alone switches its bar (Toggle.lua); back to the
        -- top bar when leaving combat
        triggerToggle = false, toggleCombatRelease = true,
    },
    -- Vibrations: one switch and intensity, then each event { on, pattern }
    -- (Vibration.lua fills the events)
    vibration = { enabled = true, intensity = 0.6, events = {} },
    -- Supplies: the buttons' bar (pos = { point, x, y }, size 1-3), each
    -- resource { on, low, critical } and the items added
    supplies = { enabled = true, locked = true, layout = "right", size = 2, list = {}, custom = {} },
    -- Consumables wheel: its kinds, and the variants beside the best of each
    wheel = {
        enabled = true, variants = true, locked = true,
        -- Every wheel: hold its key to show it, let go to use (off: press)
        hold = false,
        -- Eating or drinking: a stick nudged doesn't stand the character up
        staySeated = true,
        -- Bandaging: the same (its own option)
        stillBandaging = true,
        categories = { food = true, drink = true, healthPotion = true, manaPotion = true, healthstone = true,
            manaGem = true, bandage = true, buffFood = true, elixir = true, scroll = true },
    },
    -- The player's own wheels (MyWheels.lua): { { id, name, slots = { [1-8] = action } } }
    myWheels = { list = {} },
    -- Extra buttons' places ({ x, y } from the game's left / right bar), mirrored
    extraPos = {},
    -- The game's gamepad bar, moved by steps (0, 0: the game's own place)
    barOffset = { x = 0, y = 0 },
    -- Its size (1: the game's), with all it holds and what the addon adds
    barScale = 1,
    -- The configuration panel's shortcut: a button held, another pressed
    shortcut = { hold = "PADRSHOULDER", press = "PADDDOWN" },
    extraSymmetric = true,
    badgePlace = "outer",    -- "R4" on the extra buttons: outer / top / bottom / left / right / hidden
    inputMethod = "wheel",   -- "wheel" (daisywheel) or "stick" (split keyboard)
    petalRings = true,       -- daisywheel: a ring around each group of 4 characters
    kbLayout = ({ frFR = "azerty", deDE = "qwertz", esES = "qwerty_es", esMX = "qwerty_es",
        itIT = "qwerty_it" })[GetLocale()] or "qwerty",
    deadzone = 0.15,         -- split keyboard: sticks dead zone
    stickCurve = "linear",   -- split keyboard: linear / gentle / fast
    magnet = "medium",       -- split keyboard: none / weak / medium / strong
    showLine = true,         -- split keyboard: lines from the centers to the cursors
    showActions = true,
    stickyChannel = true,    -- the channel row also sets the chat's own sticky channel
    -- The quick phrases' bubble at the end of the keyboard's suggestions
    -- (Phrases.lua); the phrases themselves: settings.phrases, nil = defaults
    phrasesChip = true,
    font = "friz",
    glyphStyle = "xbox",
    -- The gamepad UI's centre dot (Reticle.lua): "game", "color", "cycle", "hidden"
    reticle = { mode = "game", color = 1 },
    gameGlyphs = true,
    debug = false,
}
CK.DEFAULTS = DEFAULTS

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil or type(dst[k]) ~= type(v) then
            dst[k] = v
        end
    end
end

-- Entries a saved file may hold broken (edited by hand, an old bug): left
-- out, so a wrong one never stops the addon. The account's settings at
-- load, each character's profile when it is put in use (Profiles.lua).
function CK.CleanEntries(s)
    local function tbl(parent, k)
        if type(parent[k]) ~= "table" then parent[k] = {} end
        return parent[k]
    end
    -- A list kept in place (the profiles hold it), with its good items only
    local function keep(t, items)
        for k in pairs(t) do t[k] = nil end
        for i, v in ipairs(items) do t[i] = v end
    end
    -- ConsolePort's keyboard no longer offered (ConsolePort.lua kept in the
    -- files): chosen before, the daisywheel
    if s.inputMethod == "consoleport" then s.inputMethod = "wheel" end
    -- Buttons: { ["L3:LT"] = "spell:133" } (older names, "L4" or "PAD2",
    -- are moved by Mapping.lua: kept)
    for _, name in ipairs({ "mapping", "replaced" }) do
        local t = tbl(s, name)
        for k, v in pairs(t) do
            -- Start and Select stay the game's (Mapping.lua): what was put
            -- there goes, and the player is told once (at login, Chat.lua)
            local system = type(k) == "string" and (k:find("^START:") or k:find("^SELECT:"))
            if system and type(v) == "string" then
                CK.removedSystem = CK.removedSystem or {}
                CK.removedSystem[k .. "=" .. v] = { key = k, action = v }
            end
            if type(k) ~= "string" or type(v) ~= "string" or system then
                t[k] = nil
            end
        end
    end
    -- Supplies: { [key] = { on, low, critical } }, and the items added
    local sup = tbl(s, "supplies")
    local list = tbl(sup, "list")
    for k, cfg in pairs(list) do
        if type(k) ~= "string" or type(cfg) ~= "table" or type(cfg.low) ~= "number"
            or type(cfg.critical) ~= "number" then
            list[k] = nil
        end
    end
    local custom, seen = {}, {}
    for _, id in ipairs(tbl(sup, "custom")) do
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            custom[#custom + 1] = id
        end
    end
    keep(sup.custom, custom)
    -- Own wheels: { { id, name, slots = { [1-8] = action } } }
    local wheels, used = {}, {}
    for _, w in ipairs(tbl(tbl(s, "myWheels"), "list")) do
        if type(w) == "table" and type(w.id) == "number" and w.id > 0 and not used[w.id] then
            used[w.id] = true
            if type(w.name) ~= "string" then w.name = format(CK.L.MYWHEEL_DEFAULT or "%d", w.id) end
            local slots = {}
            if type(w.slots) == "table" then
                for i = 1, 8 do
                    if type(w.slots[i]) == "string" then slots[i] = w.slots[i] end
                end
            end
            w.slots = slots
            wheels[#wheels + 1] = w
        end
    end
    keep(s.myWheels.list, wheels)
    -- The consumables wheel's kinds
    copyDefaults(DEFAULTS.wheel.categories, tbl(tbl(s, "wheel"), "categories"))
end

function CK:InitDB()
    if type(ControllerKeyboardDB) ~= "table" then ControllerKeyboardDB = {} end
    local db = ControllerKeyboardDB
    if type(db.settings) ~= "table" then db.settings = {} end
    if db.settings.configSection ~= nil and type(db.settings.configSection) ~= "table" then
        db.settings.configSection = nil
    end
    -- Before 0.4.2: dicts = { frFR = bool, enUS = bool } instead of a language
    if db.settings.lang == nil and type(db.settings.dicts) == "table" then
        local d = db.settings.dicts
        db.settings.lang = (d.frFR and d.enUS) and "fren" or (d.enUS and "en") or "fr"
    end
    copyDefaults(DEFAULTS, db.settings)
    CK.CleanEntries(db.settings)
    -- v2: auto-open no longer requires the gamepad to be the active input
    if (tonumber(db.version) or 1) < 2 then
        db.settings.onlyWithGamepad = false
        db.pos = nil
        db.version = 2
    end
    self.db = db
    self:ApplyLanguage()
    for _, key in ipairs({ "words", "commands", "trigrams", "starts", "bigrams" }) do
        if type(db[key]) ~= "table" then db[key] = {} end
    end
    self.db = db
end

function CK:Print(msg, ...)
    if select("#", ...) > 0 then msg = format(msg, ...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffEasy Controller|r: " .. tostring(msg))
end

---------------------------------------------------------------------------
-- UTF-8 helpers (French accents)
---------------------------------------------------------------------------
local UTF8_2 = "[\195\197][\128-\191]"

-- The first n characters of a UTF-8 text (never half a letter)
function CK.Utf8Sub(text, n)
    local count, i = 0, 1
    while i <= #text do
        local b = text:byte(i)
        count = count + 1
        if count > n then return text:sub(1, i - 1) end
        i = i + (b >= 240 and 4 or b >= 224 and 3 or b >= 192 and 2 or 1)
    end
    return text
end

local LOWER = {
    ["À"] = "à", ["Â"] = "â", ["Ä"] = "ä", ["Á"] = "á", ["Ç"] = "ç", ["É"] = "é", ["È"] = "è",
    ["Ê"] = "ê", ["Ë"] = "ë", ["Î"] = "î", ["Ï"] = "ï", ["Í"] = "í", ["Ô"] = "ô", ["Ö"] = "ö",
    ["Ó"] = "ó", ["Ò"] = "ò", ["Ì"] = "ì", ["Ù"] = "ù", ["Û"] = "û", ["Ü"] = "ü", ["Ú"] = "ú", ["Ÿ"] = "ÿ", ["Ñ"] = "ñ",
    ["Œ"] = "œ", ["Æ"] = "æ",
}
local UPPER = {}
for up, low in pairs(LOWER) do UPPER[low] = up end

local STRIP = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["á"] = "a", ["ç"] = "c", ["é"] = "e", ["è"] = "e",
    ["ê"] = "e", ["ë"] = "e", ["î"] = "i", ["ï"] = "i", ["í"] = "i", ["ô"] = "o", ["ö"] = "o",
    ["ó"] = "o", ["ò"] = "o", ["ì"] = "i", ["ß"] = "ss", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ú"] = "u", ["ÿ"] = "y", ["ñ"] = "n",
    ["œ"] = "oe", ["æ"] = "ae",
}

-- string.lower/upper may touch UTF-8 bytes depending on the C locale: only map A-Z
local ASCII_LOWER, ASCII_UPPER = {}, {}
for b = 65, 90 do
    ASCII_LOWER[string.char(b)] = string.char(b + 32)
    ASCII_UPPER[string.char(b + 32)] = string.char(b)
end

function CK.Lower(s)
    return (s:gsub("[A-Z]", ASCII_LOWER):gsub(UTF8_2, LOWER))
end

function CK.Upper(s)
    return (s:gsub("[a-z]", ASCII_UPPER):gsub(UTF8_2, UPPER))
end

-- Lowercase and strip accents: "Été" -> "ete"
function CK.Normalize(s)
    return (CK.Lower(s):gsub(UTF8_2, STRIP))
end

function CK.FirstChar(s)
    return s:match("^[\192-\255][\128-\191]*") or s:sub(1, 1)
end

function CK.IsUpperInitial(s)
    local c = CK.FirstChar(s)
    return c ~= "" and c ~= CK.Lower(c)
end

function CK.Capitalize(s)
    local c = CK.FirstChar(s)
    return CK.Upper(c) .. s:sub(#c + 1)
end

---------------------------------------------------------------------------
-- Languages: dictionaries, and the accents of the 123 layer
---------------------------------------------------------------------------
CK.LANGUAGES = {
    { key = "fr", name = "Français", dicts = { "frFR" }, accents = "fr" },
    { key = "en", name = "English", dicts = { "enUS" }, accents = "en" },
    { key = "de", name = "Deutsch", dicts = { "deDE" }, accents = "de" },
    { key = "es", name = "Español", dicts = { "esES" }, accents = "es" },
    { key = "it", name = "Italiano", dicts = { "itIT" }, accents = "it" },
    { key = "fren", name = "Français + English", dicts = { "frFR", "enUS" }, accents = "fr" },
}

-- 12 characters per language: the accents first, then useful punctuation
CK.ACCENTS = {
    fr = { "é", "è", "ê", "à", "â", "ç", "ù", "û", "î", "ô", "ë", "ï" },
    en = { "é", "è", "à", "ç", "'", "?", "!", "-", "&", "$", "ë", "ï" },
    de = { "ä", "ö", "ü", "ß", "?", "!", "'", "-", "€", "&", "§", "_" },
    es = { "á", "é", "í", "ó", "ú", "ñ", "ü", "¿", "¡", "'", "-", "ç" },
    it = { "à", "è", "é", "ì", "ò", "ù", "ó", "í", "ú", "'", "?", "!" },
}

function CK:GetLanguage()
    local key = self.db and self.db.settings.lang
    for _, lang in ipairs(CK.LANGUAGES) do
        if lang.key == key then return lang end
    end
    return CK.LANGUAGES[2]
end

function CK:Accents()
    return CK.ACCENTS[self:GetLanguage().accents] or CK.ACCENTS.fr
end

-- The dictionaries in use come from the language
function CK:ApplyLanguage()
    local dicts = {}
    for _, key in ipairs(self:GetLanguage().dicts) do dicts[key] = true end
    self.db.settings.dicts = dicts
end

function CK:SetLanguage(key)
    self.db.settings.lang = key
    self:ApplyLanguage()
    CK.Predict:Load()
    if self.frame then self:UpdateMethod() end
end

-- Remove the last UTF-8 character of a string
function CK.DropLastChar(s)
    local i = #s
    while i > 1 do
        local b = s:byte(i)
        if b < 128 or b >= 192 then break end
        i = i - 1
    end
    return s:sub(1, i - 1)
end

-- Letters (ASCII + any UTF-8 byte) form words
CK.WORD_CHARS = "[%a\128-\255]"
