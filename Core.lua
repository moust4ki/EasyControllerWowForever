local ADDON, CK = ...
_G.ControllerKeyboard = CK

CK.ADDON = ADDON
CK.Dicts = CK.Dicts or {}

---------------------------------------------------------------------------
-- Localisation: English is the base (Locales/enUS.lua), each client
-- language overrides it (Locales/<locale>.lua, loaded before this file);
-- the one picked in the panel (settings.uiLang) over it once the settings
-- are read (InitDB)
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

-- Every language's texts (Locales/<locale>.lua), by the game's name of it,
-- and English as loaded: a language put over English again when it is
-- changed (the one picked in the panel, InitDB)
local LOCALES = CK.LOCALES or {}
local ENGLISH = {}
for key, value in pairs(L) do ENGLISH[key] = value end

-- The game reads these when its key bindings are shown
local function bindingNames()
    BINDING_HEADER_CONTROLLERKEYBOARD = "Easy Controller - Forever"
    BINDING_NAME_CONTROLLERKEYBOARD_TOGGLE = L.BINDING_TOGGLE
    BINDING_NAME_CONTROLLERKEYBOARD_MAP = L.BINDING_MAP
    BINDING_NAME_CONTROLLERKEYBOARD_CONFIG = L.BINDING_CONFIG
    _G["BINDING_NAME_CLICK ControllerKeyboardWheelToggle:LeftButton"] = L.WHEEL_NAME
    _G["BINDING_NAME_CLICK ControllerKeyboardUsableToggle:LeftButton"] = L.USABLE_WHEEL_NAME
    _G["BINDING_NAME_CLICK ControllerKeyboardPhrasesToggle:LeftButton"] = L.PHRASES_NAME
    BINDING_NAME_CONTROLLERKEYBOARD_AH_SCAN = L.AH_BINDING
    BINDING_NAME_CONTROLLERKEYBOARD_AH_POST = L.AH_POST_BINDING
end

-- English has no file of its own (it is the base): a language all the same
-- where one is picked
local function knownLocale(locale)
    return locale == "enUS" or LOCALES[locale] ~= nil
end

-- The texts of `locale` over English (a language without a file of its own,
-- none: English). CK.locale, what is on screen, follows
function CK:ApplyLocale(locale)
    if locale == self.locale then return false end
    for key in pairs(L) do L[key] = nil end
    for key, value in pairs(ENGLISH) do L[key] = value end
    for key, value in pairs(LOCALES[locale or ""] or {}) do L[key] = value end
    self.locale = locale
    bindingNames()
    return true
end

-- The addon's languages (Home › Look › Language), each in its own words;
-- the suggestions and the keyboard layout that go with them
CK.UI_LANGUAGES = {
    { locale = "enUS", name = "English", lang = "en", layout = "qwerty" },
    { locale = "frFR", name = "Français", lang = "fr", layout = "azerty" },
    { locale = "deDE", name = "Deutsch", lang = "de", layout = "qwertz" },
    { locale = "esES", name = "Español", lang = "es", layout = "qwerty_es" },
    { locale = "itIT", name = "Italiano", lang = "it", layout = "qwerty_it" },
    { locale = "ruRU", name = "Русский", lang = "ru", layout = "russian", cyrillic = true },
}
local UI_LANGUAGE_OF = {}
for _, lang in ipairs(CK.UI_LANGUAGES) do UI_LANGUAGE_OF[lang.locale] = lang end

-- A language's name where one is chosen: a picked one in its own words,
-- the client's after "Auto" (none: the client's own name of its language)
function CK:LanguageName(locale)
    for _, lang in ipairs(CK.UI_LANGUAGES) do
        if lang.locale == locale then return lang.name end
    end
    local client = GetLocale()
    for _, lang in ipairs(CK.UI_LANGUAGES) do
        if lang.locale == client then client = lang.name break end
    end
    return format(L.LANG_AUTO, client)
end

-- The language asked for: the one picked, else the client's
function CK:UILocale()
    local picked = self.db and self.db.settings.uiLang
    return (picked and knownLocale(picked) and picked) or GetLocale()
end

-- The language picked (Home › Look, /ec ui): nil, the client's. Its texts
-- come with the next loading of the interface: those of the windows that
-- are open were read when they were built. The keyboard's letters follow
-- at once (suggestions, layout) when the language left wrote with other
-- ones: Russian and the Latin languages
function CK:SetUILanguage(locale)
    local s = self.db.settings
    s.uiLang = locale and knownLocale(locale) and locale or nil
    local of = UI_LANGUAGE_OF[self:UILocale()]
    if of and (of.cyrillic and true or false) ~= (self:GetLanguage().cyrillic and true or false) then
        s.lang, s.kbLayout = of.lang, of.layout
        self:ApplyLanguage()
        CK.Predict:Load()
        if self.frame then self:UpdateMethod() end
    end
    self:ApplyFont()
end

CK:ApplyLocale(GetLocale())

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
    lang = ({ frFR = "fr", deDE = "de", esES = "es", esMX = "es", itIT = "it", ruRU = "ru" })[GetLocale()] or "en",
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
        -- Quest mobs: the count beside their health bar (QuestPlates.lua)
        questPlates = true,
        extraDisplay = true, showSticks = true, configShortcut = true,
        -- Out of range: the whole spell in red on the gamepad bar (Range.lua)
        rangeTint = false,
        -- A trigger pressed alone switches its bar (Toggle.lua); back to the
        -- top bar when leaving combat
        triggerToggle = false, toggleCombatRelease = true,
        -- The game's red messages at a key press: their text hidden, their
        -- voice silenced, the useful ones kept (QuietErrors.lua)
        hideErrorText = false, muteErrorVoice = false,
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
        -- The stick that aims them: "left" or "right" (a party spell's: the right)
        aimStick = "left",
        -- Aimed with the right stick: letting it go uses what it aims at
        -- (asked; off: a press confirms, nothing used by accident)
        stickRelease = false,
        -- The usable items' wheel: the items hidden from it ({ [item ID] =
        -- true }, false once shown again); the hearthstone by default
        usableHidden = { [6948] = true },
        -- The usable items' wheel itself (off: its key does nothing)
        usableEnabled = true,
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
        itIT = "qwerty_it", ruRU = "russian" })[GetLocale()] or "qwerty",
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
    -- "auto" (the controller's), "xbox", "playstation", "switch"; a style
    -- picked sets the game's own icons too (Glyphs.lua). Auto on a new
    -- install; an update keeps the one it had (the game untouched)
    glyphStyle = "auto",
    -- The gamepad UI's centre dot (Reticle.lua): "game", "color", "cycle", "hidden"
    reticle = { mode = "game", color = 1 },
    -- Auction house prices (AuctionPrices.lua): off unless turned on; the
    -- gold coin in the bags on the items better sold there. The prices
    -- themselves: ControllerKeyboardPrices, for every character
    auction = { enabled = false, marks = true, ignored = {}, disenchant = true },
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

-- A number the addon may compute with, else nil. Since the game's build of
-- 2 November 2026 the places and sizes of some of its frames (the gamepad
-- bar's buttons) can be secret values for addons: any sum with one stops
-- the code (reported: errors while placing the bar).
function CK.Plain(v)
    if type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

-- A text the game gives, when it is one: not secret, not empty
local function plainText(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v) == "string" and v ~= "" then return v end
end
CK.PlainText = plainText

-- The player's realm's number, in its GUID ("Player-6942-000689C3")
function CK.RealmID()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "player")
    guid = ok and plainText(guid)
    return guid and tonumber(guid:match("^Player%-(%d+)%-")) or nil
end

-- A realm's name seen with its number: kept, for when the game gives none
function CK.RememberRealm(id, name)
    local db = CK.db
    if not (db and type(id) == "number" and plainText(name)) then return end
    if type(db.realmNames) ~= "table" then db.realmNames = {} end
    db.realmNames[id] = name
end

-- The player's realm as the game writes it in full names ("Classic Beta
-- PvP" -> "ClassicBetaPvP"). The game's build of 2026-11-20 may give no
-- realm name at all (reported: a character's profile not found at login,
-- its wheels and buttons gone): then the name last seen with the realm's
-- number, kept in the account's file. nil when never seen.
function CK.Realm()
    local name
    if GetNormalizedRealmName then
        local ok, v = pcall(GetNormalizedRealmName)
        name = ok and plainText(v) or nil
    end
    if not name and GetRealmName then
        local ok, v = pcall(GetRealmName)
        v = ok and plainText(v)
        name = v and plainText((v:gsub("[%s%-]", ""))) or nil
    end
    local id = CK.RealmID()
    if name then
        CK.RememberRealm(id, name)
        return name
    end
    local names = id and CK.db and CK.db.realmNames
    return type(names) == "table" and plainText(names[id]) or nil
end

-- The item an item tooltip shows: its link (its random suffix kept), else
-- its ID. A recipe's gives the item it makes as its link, the recipe as its
-- ID (reported: a pattern's tooltip had the crafted bracers' auction
-- prices, the pattern posted at its own): the ID then
function CK.TooltipItemLink(tooltip, data)
    local function plain(v) return not (issecretvalue and issecretvalue(v)) and v or nil end
    local id = type(data) == "table" and CK.Plain(data.id) or nil
    local link = type(data) == "table" and plain(data.hyperlink) or nil
    if type(link) ~= "string" then link = nil end
    if link and id and tonumber(link:match("item:(%d+)")) ~= id then link = nil end
    if not link and id then link = "item:" .. id end
    if not link and tooltip and tooltip.GetItem then
        local ok, _, shown = pcall(tooltip.GetItem, tooltip)
        if ok and type(shown) == "string" and plain(shown) then link = shown end
    end
    return link
end

-- The game's gamepad UI on (its gamepad bars shown); true when the game
-- can't tell. Our buttons beside its bar go with it (reported: the bag
-- counter stayed on screen with the gamepad UI turned off)
function CK.GamepadUI()
    local util = InputUtil
    if util and util.IsGamepadUIEnabled then
        local ok, on = pcall(util.IsGamepadUIEnabled)
        if ok and on == false then return false end
    end
    return true
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
    -- A language without its file here (an old copy of the folder): the client's
    if s.uiLang ~= nil and not knownLocale(s.uiLang) then s.uiLang = nil end
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
    -- The usable items' wheel's hidden items: { [item ID] = true / false }
    local hiddenItems = tbl(s.wheel, "usableHidden")
    for k, v in pairs(hiddenItems) do
        if type(k) ~= "number" or type(v) ~= "boolean" then hiddenItems[k] = nil end
    end
end

-- The minimap labels are gone (1.20: the game no longer lets addons move
-- the minimap's hover point, so its dots can't be read): their settings
-- and the buttons given to them ("wheel:minimap", in the settings and in
-- every profile) dropped, those buttons free again
local function dropAction(t, action, depth)
    if type(t) ~= "table" or depth > 8 then return end
    for k, v in pairs(t) do
        if v == action then
            t[k] = nil
        elseif type(v) == "table" then
            dropAction(v, action, depth + 1)
        end
    end
end

function CK.DropMinimapLabels(db)
    db.settings.minimapLabels = nil
    dropAction(db.settings, "wheel:minimap", 0)
    dropAction(db.profiles, "wheel:minimap", 0)
end

function CK:InitDB()
    -- No saved settings yet: a new install (the first launch guide)
    local fresh = type(ControllerKeyboardDB) ~= "table"
    if fresh then ControllerKeyboardDB = {} end
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
    CK.DropMinimapLabels(db)
    -- The first launch guide (Guide.lua): shown to a new install only
    if type(db.onboarding) ~= "table" then db.onboarding = { seen = not fresh, version = 1 } end
    -- v2: auto-open no longer requires the gamepad to be the active input
    if (tonumber(db.version) or 1) < 2 then
        db.settings.onlyWithGamepad = false
        db.pos = nil
        db.version = 2
    end
    -- v3: a Russian client gets the suggestions and the layout of its
    -- language, as on a new install (the addon had no Russian before, they
    -- were the English ones), when nothing else was chosen
    if (tonumber(db.version) or 1) < 3 then
        if GetLocale() == "ruRU" and db.settings.lang == "en" and db.settings.kbLayout == "qwerty" then
            db.settings.lang, db.settings.kbLayout = "ru", "russian"
        end
        db.version = 3
    end
    self.db = db
    -- The language picked (Home › Look) over the client's, then the panel's
    -- pages, titled in it
    self:ApplyLocale(self:UILocale())
    if CK.DefinePages then CK.DefinePages() end
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
-- UTF-8 helpers (French accents, Russian letters)
---------------------------------------------------------------------------
local UTF8_2 = "[\195\197][\128-\191]"     -- U+00C0-U+017F, 2 bytes

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

-- Russian, U+0410-U+044F: each small letter its capital's number and 32, as
-- a-z and A-Z. In UTF-8: А-П (D0 90-9F) and а-п (D0 B0-BF) share their first
-- byte, Р-Я (D0 A0-AF) and р-я (D1 80-8F) don't; Ё (D0 81) and ё (D1 91)
local CYR_LOWER, CYR_UPPER = {}, {}
for b = 144, 175 do
    local upper, lower = string.char(208, b), string.char(208, b + 32)
    if b >= 160 then lower = string.char(209, b - 32) end
    CYR_LOWER[upper], CYR_UPPER[lower] = lower, upper
end
CYR_LOWER["\208\129"], CYR_UPPER["\209\145"] = "\209\145", "\208\129"

function CK.Lower(s)
    return (s:gsub("[A-Z]", ASCII_LOWER):gsub(UTF8_2, LOWER):gsub("\208[\129\144-\175]", CYR_LOWER))
end

function CK.Upper(s)
    return (s:gsub("[a-z]", ASCII_UPPER):gsub(UTF8_2, UPPER):gsub("\208[\176-\191]", CYR_UPPER)
        :gsub("\209[\128-\143\145]", CYR_UPPER))
end

-- Lowercase and strip accents: "Été" -> "ete", "Ёлка" -> "елка" (ё as е: a word
-- is found, and sorted, with either, as in dictionaries)
function CK.Normalize(s)
    return (CK.Lower(s):gsub(UTF8_2, STRIP):gsub("\209\145", "\208\181"))
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
    -- Russian is written with other letters than the Latin ones: the
    -- daisywheel's letters follow (Wheel.lua), and so does the font the addon
    -- writes with (Options.lua)
    { key = "ru", name = "Русский", dicts = { "ruRU" }, accents = "ru", cyrillic = true, letters = "ru" },
    { key = "ruen", name = "Русский + English", dicts = { "ruRU", "enUS" }, accents = "ru", cyrillic = true,
        letters = "ru" },
}

-- 12 characters per language: the accents first, then useful punctuation.
-- Russian has no accents: the one letter its letters have no room for on the
-- daisywheel (33), then punctuation (the letters of that layer take its keys)
CK.ACCENTS = {
    fr = { "é", "è", "ê", "à", "â", "ç", "ù", "û", "î", "ô", "ë", "ï" },
    en = { "é", "è", "à", "ç", "'", "?", "!", "-", "&", "$", "ë", "ï" },
    de = { "ä", "ö", "ü", "ß", "?", "!", "'", "-", "€", "&", "§", "_" },
    es = { "á", "é", "í", "ó", "ú", "ñ", "ü", "¿", "¡", "'", "-", "ç" },
    it = { "à", "è", "é", "ì", "ò", "ù", "ó", "í", "ú", "'", "?", "!" },
    ru = { "ъ", ".", ",", "?", "!", "-", "«", "»", "…", "—", "_", "&" },
}

-- Russian on screen: the texts (the language picked, else the client's), or
-- the keyboard's suggestions
function CK:Cyrillic()
    local ui = self.db and self.db.settings.uiLang or GetLocale()
    if ui == "ruRU" then return true end
    return self:GetLanguage().cyrillic and true or false
end

-- The input method in use shows letters that are not the Latin ones: the
-- daisywheel's Russian ones (the language's), the split keyboard's Russian
-- layout. A quick second press on 123 swaps them for the Latin ones
-- (Message.lua): a slash command, a name written in Latin letters
function CK:OtherLetters()
    if self:GetMethod().key == "stick" then return self.db.settings.kbLayout == "russian" end
    return self:GetLanguage().letters ~= nil
end

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
    -- (Russian: the font may follow, Options.lua)
    self:ApplyFont()
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
