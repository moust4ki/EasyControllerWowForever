-- Run from the addon root with Lua 5.1: luajit tools/test_russian.lua
-- (lua tools/test_russian.lua with 5.1): the Russian letters in the addon's
-- texts, keyboards and suggestions.
local passed, failed = 0, 0
local function check(name, test)
    local ok, err = pcall(test)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

local function same(want, got)
    assert(want == got, "expected [" .. tostring(want) .. "], got [" .. tostring(got) .. "]")
end

local function chars(s)
    return select(2, s:gsub("[^\128-\191]", ""))
end

---------------------------------------------------------------------------
-- The addon's files in a stand-in for the game: a frame is a plain object,
-- its methods do nothing; what a text was set to is kept
---------------------------------------------------------------------------
local CLIENT = "enUS"
local METHOD = {}
for name in ([[SetPoint ClearAllPoints SetSize SetWidth SetHeight SetAllPoints SetTexture SetTexCoord
    SetAlpha SetVertexColor SetColorTexture SetRotation SetShown Show Hide SetScript HookScript RegisterEvent
    UnregisterAllEvents RegisterForClicks EnableMouse SetFrameLevel SetFrameStrata SetClampedToScreen SetMovable
    StartMoving StopMovingOrSizing GetPoint SetScale GetWidth GetHeight GetLeft GetBottom SetJustifyH SetJustifyV
    SetWordWrap SetMaxLines SetShadowOffset SetShadowColor SetTextColor SetSpacing SetTextInsets SetAutoFocus
    SetMaxLetters SetFocus ClearFocus IsMouseOver Raise SetParent GetCenter SetDesaturated SetAtlas
    EnableGamePadStick GetAttribute SetAttribute UnregisterEvent SetOwner AddLine AddDoubleLine ClearLines
    AddMessage SetThickness SetStartPoint SetEndPoint SetFont
]]):gmatch("%S+") do METHOD[name] = true end

local function newFrame(kind, name)
    local f = { kind = kind, name = name }
    return setmetatable(f, {
        __index = function(self, key)
            if key == "GetFrameLevel" then return function() return 1 end end
            if key == "GetObjectType" then return function() return self.kind or "Frame" end end
            if key == "GetEffectiveScale" then return function() return 1 end end
            if key == "GetStringWidth" or key == "GetStringHeight" then return function() return 40 end end
            if key == "GetFont" then return function() return "Fonts\\ARIALN.TTF", 12 end end
            if key == "CreateTexture" or key == "CreateFontString" or key == "CreateLine" then
                return function(_, ...) return newFrame(...) end
            end
            if key == "SetText" then return function(self, text) self.text = text end end
            if METHOD[key] then return function() end end
        end,
        __newindex = function(self, key, value)
            if key == "SetText" then rawset(self, "text", value) return end
            rawset(self, key, value)
        end,
    })
end
local env = setmetatable({}, { __index = _G })
env.GetLocale = function() return CLIENT end
env.GetTime = function() return 100 end
env.CreateFrame = function(kind, name) return newFrame(kind, name) end
env.DEFAULT_CHAT_FRAME = newFrame("Frame")
env.wipe = function(t) for k in pairs(t) do t[k] = nil end end
env.format = string.format
env.C_Timer = { After = function() end }
env.GetCVar = function() return "1" end

-- A file of the addon, run as the game runs it
local function run(file, CK)
    local chunk, err = loadfile(file)
    assert(chunk, err)
    setfenv(chunk, env)
    chunk("EasyController", CK)
end

local UIKIT = {
    TEX = "Interface\\AddOns\\EasyController\\textures\\",
    -- (a region's place kept)
    place = function(r, parent, x, y, w, h) r.x, r.y, r.w, r.h = x, y, w, h end,
    nineSlice = function() return newFrame("Slice") end,
    text = function() return newFrame("FontString") end,
    texture = function() return newFrame("Texture") end,
}

-- The addon's core, its texts in the client's language (a new install each
-- time: no settings left by another test)
local function addon(locale)
    CLIENT = locale
    env.ControllerKeyboardDB = nil
    local CK = { Config = { pages = {}, NewRailPage = function(def) return { def = def } end },
        MyWheels = { TabPage = function(_, rail) return rail end, Grid = {} },
        MapPage = { DisplayRows = function() end }, UIKit = UIKIT, NewFrame = newFrame }
    CK.ApplyFont = function() end
    CK.DisplayChar = function(self, ch)
        if self.state.shift or self.state.caps then return CK.Upper(ch) end
        return ch
    end
    run("Locales/enUS.lua", CK)
    run("Locales/frFR.lua", CK)
    run("Locales/deDE.lua", CK)
    run("Locales/esES.lua", CK)
    run("Locales/itIT.lua", CK)
    run("Locales/ruRU.lua", CK)
    run("Core.lua", CK)
    return CK
end

-- ...its panel's pages, its word lists and suggestions
local function started(CK, lang)
    run("Options.lua", CK)
    run("Dict_ruRU_next.lua", CK)
    run("Predict.lua", CK)
    run("Message.lua", CK)
    CK:InitDB()
    if lang then CK:SetLanguage(lang) end
    return CK
end

local ALPHABET = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"

---------------------------------------------------------------------------
-- Letters: case, accents
---------------------------------------------------------------------------
local CK = addon("enUS")

check("Russian letters change case", function()
    same("привет мир ёё", CK.Lower("Привет МИР Ёё"))
    same("ПРИВЕТ МИР ЁЁ", CK.Upper("привет мир ёё"))
    same("абвгдеёжзийклмнопрстуфхцчшщъыьэюя", CK.Lower("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"))
    same("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ", CK.Upper("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"))
    same("привет", CK.Lower("ПРИВЕТ"))
end)

check("the Latin accents still change case", function()
    same("été à çœ", CK.Lower("ÉTÉ À ÇŒ"))
    same("ÉTÉ À ÇŒ", CK.Upper("été à çœ"))
    same("yet", CK.Lower("YET"))
end)

check("ё as е to find a word, the accents stripped", function()
    same("елка", CK.Normalize("Ёлка"))
    same("еще", CK.Normalize("Ещё"))
    same("привет", CK.Normalize("Привет"))
    same("ete", CK.Normalize("Été"))
    same("все", CK.Normalize("Все"))
    same("все", CK.Normalize("Всё"))
end)

check("capital, first letter, words, the end of a word", function()
    same("Привет", CK.Capitalize("привет"))
    same(true, CK.IsUpperInitial("При"))
    same(false, CK.IsUpperInitial("при"))
    same("ё", CK.FirstChar("ёж"))
    same("при", CK.Utf8Sub("привет", 3))
    same("приве", CK.DropLastChar("привет"))
    local words = {}
    for w in ("привет, мир ещё!"):gmatch(CK.WORD_CHARS .. "+") do words[#words + 1] = w end
    same("привет|мир|ещё", table.concat(words, "|"))
end)

check("Russian: 12 characters for the 123 layer, the letter left out first", function()
    same(12, #CK.ACCENTS.ru)
    same("ъ", CK.ACCENTS.ru[1])
    same(33, chars(ALPHABET))
end)

check("the languages: Russian, Russian + English", function()
    local ru, ruen
    for _, lang in ipairs(CK.LANGUAGES) do
        if lang.key == "ru" then ru = lang end
        if lang.key == "ruen" then ruen = lang end
    end
    same("ruRU", ru.dicts[1])
    same("ru", ru.accents)
    same(true, ru.cyrillic)
    same("ru", ru.letters)
    same("enUS", ruen.dicts[2])
    same("English", CK.LANGUAGES[2].name)
    same(nil, CK.LANGUAGES[1].cyrillic)
end)

---------------------------------------------------------------------------
-- The texts: the client's language, the one picked
---------------------------------------------------------------------------
check("a Russian client gets the Russian texts", function()
    local R = addon("ruRU")
    same("Отправить", R.L.SEND)
    same("ruRU", R.locale)
    started(R)
    same("ru", R.db.settings.lang)
    same("russian", R.db.settings.kbLayout)
    same(true, R:Cyrillic())
    same("абв", R.L.LETTERS)
    same("Модули", R.Config.pages.home.def.sections[1].label)
end)

check("another client keeps English, and takes Russian (then the others, whole)", function()
    local E = addon("enUS")
    same("Send", E.L.SEND)
    same("enUS", E.locale)
    same(false, E:Cyrillic())
    started(E)
    same("Modules", E.Config.pages.home.def.sections[1].label)
    E:SetUILanguage("ruRU")
    same("ru", E.db.settings.lang)
    same("russian", E.db.settings.kbLayout)
    -- (as after the reload: the texts when the interface loads)
    E:ApplyLocale(E:UILocale())
    same("Отправить", E.L.SEND)
    same("абв", E.L.LETTERS)
    same("Главная", E.L.TAB_HOME)
    same("Friz Quadrata RU", E.L.FONT_FRIZ_CYR)
    same(30, #E.L.HELP)
    E.DefinePages()
    same("Модули", E.Config.pages.home.def.sections[1].label)
    E:ApplyLocale("enUS")
    same("Send", E.L.SEND)
    same("abc", E.L.LETTERS)
    E.DefinePages()
    same("Modules", E.Config.pages.home.def.sections[1].label)
    E:ApplyLocale("deDE")
    same("Senden", E.L.SEND)
    E:ApplyLocale("ptBR")
    same("Send", E.L.SEND)
    same("Friz Quadrata RU", E.L.FONT_FRIZ_CYR)
end)

check("the panel's pages in the language asked for, on a client of another", function()
    CLIENT = "enUS"
    local E = addon("enUS")
    run("Options.lua", E)
    env.ControllerKeyboardDB = { settings = { uiLang = "ruRU" } }
    E:InitDB()
    same("Модули", E.Config.pages.home.def.sections[1].label)
    same("Ввод", E.Config.pages.keyboard.def.sections[2].label)
    env.ControllerKeyboardDB = nil
end)

check("a language picked brings its letters when the ones left were others'", function()
    local E = addon("enUS")
    started(E)
    E.db.settings.lang, E.db.settings.kbLayout = "fr", "azerty"
    E:SetUILanguage("deDE")
    same("fr", E.db.settings.lang)
    same("azerty", E.db.settings.kbLayout)
    E:SetUILanguage("ruRU")
    same("ru", E.db.settings.lang)
    same("russian", E.db.settings.kbLayout)
    E:SetUILanguage("enUS")
    same("en", E.db.settings.lang)
    same("qwerty", E.db.settings.kbLayout)
    E:SetUILanguage(nil)
    same(nil, E.db.settings.uiLang)
    same("enUS", E:UILocale())
    E:SetUILanguage("xxXX")
    same(nil, E.db.settings.uiLang)
    E.db.settings.uiLang = "ruRU"
    same("ruRU", E:UILocale())
    same(true, E.locale ~= E:UILocale())
end)

check("a language's name where one is chosen", function()
    same("Русский", CK:LanguageName("ruRU"))
    same("English", CK:LanguageName("enUS"))
    same("Auto (English)", CK:LanguageName(nil))
    local P = addon("ptBR")
    same("Auto (ptBR)", P:LanguageName(nil))
    local R = addon("ruRU")
    same("Авто (Русский)", R:LanguageName(nil))
end)

check("a saved file: a Russian client that had the English ones gets Russian", function()
    env.ControllerKeyboardDB = { settings = { lang = "de", kbLayout = "qwertz", uiLang = "xxXX" }, version = 1 }
    local E = addon("enUS")
    env.ControllerKeyboardDB = { settings = { lang = "de", kbLayout = "qwertz", uiLang = "xxXX" }, version = 1 }
    E:InitDB()
    same("de", E.db.settings.lang)
    same(nil, E.db.settings.uiLang)
    same(3, E.db.version)
    local R = addon("ruRU")
    env.ControllerKeyboardDB = { settings = { lang = "en", kbLayout = "qwerty" }, version = 2 }
    R:InitDB()
    same("ru", R.db.settings.lang)
    same("russian", R.db.settings.kbLayout)
    local F = addon("frFR")
    env.ControllerKeyboardDB = { settings = { lang = "en", kbLayout = "qwerty" }, version = 2 }
    F:InitDB()
    same("en", F.db.settings.lang)
    same("qwerty", F.db.settings.kbLayout)
    local R2 = addon("ruRU")
    env.ControllerKeyboardDB = { settings = { lang = "es", kbLayout = "russian" }, version = 2 }
    R2:InitDB()
    same("es", R2.db.settings.lang)
    env.ControllerKeyboardDB = nil
end)

---------------------------------------------------------------------------
-- The fonts: Russian on a client whose fonts have no Russian letters
---------------------------------------------------------------------------
local FORUM = "Interface\\AddOns\\EasyController\\Fonts\\Forum-Regular.ttf"

check("a Latin-only font of the game gives way to the addon's with Russian", function()
    local E = started(addon("enUS"))
    same("Fonts\\FRIZQT__.TTF", E:GetFontPath("friz"))
    same("Fonts\\MORPHEUS.TTF", E:GetFontPath("morpheus"))
    same("Fonts\\ARIALN.TTF", E:GetFontPath("arialn"))
    E:SetLanguage("ru")
    same(FORUM, E:GetFontPath("friz"))
    same(FORUM, E:GetFontPath("morpheus"))
    same(FORUM, E:GetFontPath("chat"))
    same("Fonts\\FRIZQT___CYR.TTF", E:GetFontPath("frizcyr"))
    same("Interface\\AddOns\\EasyController\\Fonts\\Kurale-Regular.ttf", E:GetFontPath("kurale"))
    E:SetLanguage("en")
    same("Fonts\\FRIZQT__.TTF", E:GetFontPath("friz"))
    -- (the texts alone in Russian bring it too)
    E:SetUILanguage("ruRU")
    same(FORUM, E:GetFontPath("arialn"))
end)

check("on a Russian client the game's own font, as before", function()
    local R = started(addon("ruRU"))
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT___CYR.TTF"
    same("Fonts\\FRIZQT___CYR.TTF", R:GetFontPath())
    same("Fonts\\FRIZQT___CYR.TTF", R:GetFontPath("morpheus"))
    env.STANDARD_TEXT_FONT = nil
    same("Fonts\\FRIZQT__.TTF", R:GetFontPath())
    same("Fonts\\FRIZQT___CYR.TTF", R:GetFontPath("frizcyr"))
    same(FORUM, R:GetFontPath("forum"))
end)

check("the font files are there, with their licenses", function()
    for _, file in ipairs({ "Fonts/Forum-Regular.ttf", "Fonts/Kurale-Regular.ttf", "Fonts/OFL-Forum.txt",
        "Fonts/OFL-Kurale.txt" }) do
        local f = assert(io.open(file, "rb"), file .. " is missing")
        local head = f:read(4)
        f:close()
        if file:match("%.ttf$") then same("\0\1\0\0", head) end
    end
end)

---------------------------------------------------------------------------
-- The keyboards
---------------------------------------------------------------------------
local function keyboard(locale, lang)
    local E = started(addon(locale), lang)
    run("Wheel.lua", E)
    run("StickKeyboard.lua", E)
    E.GetMethod = function(self) return self.Methods[self.db.settings.inputMethod or "stick"] end
    local area = newFrame("Frame", "area")
    for _, m in pairs(E.Methods) do
        m.area = area
        m:Build(area)
    end
    return E
end

-- What a set of keys types (the 123 layer's accents as when shown)
local function typedOf(set, E)
    local out = {}
    for _, key in ipairs(set.keys) do
        local ch = key.char
        if key.accent then ch = E:Accents()[key.accent] end
        if ch then
            out[#out + 1] = ch
            assert(key.x >= 0 and key.x + key.w <= 584 and key.y >= 0 and key.y + key.h <= 220, "a key outside the area")
        end
    end
    return table.concat(out)
end

local function missing(text, alphabet)
    local out = {}
    for ch in alphabet:gmatch("[^\128-\191][\128-\191]*") do
        if not text:find(ch, 1, true) then out[#out + 1] = ch end
    end
    return table.concat(out)
end

check("the split keyboard, Russian: each letter once, the letters or the 123 layer", function()
    local E = keyboard("ruRU")
    local sets = E.Methods.stick.sets
    local own, symbols = typedOf(sets.russian, E), typedOf(sets.symbols, E)
    same("", missing(own, ALPHABET:gsub("ъ", "")))
    same(32, chars(own))
    same("", missing(symbols, "ъ"))
    same("1234567890ъ.,?!-«»…—_&œ@/:;()\"%+", symbols)
    -- ЙЦУКЕН, its rows cut at 10: the ends of its rows and ё along Space
    same("йцукенгшщз", own:sub(1, 20))
    same("фывапролдж", own:sub(21, 40))
    same("ячсмитьхэбюё", own:sub(41))
    -- As many keys per row as places for them
    local per = { 0, 0, 0, 0 }
    for _, key in ipairs(sets.russian.keys) do
        local row = key.y == 4 and 1 or key.y == 58 and 2 or key.y == 112 and 3 or 4
        per[row] = per[row] + 1
    end
    same("10|10|9|7", table.concat(per, "|"))
    -- No two keys over each other
    local n = #sets.russian.keys
    for i = 1, n do
        for j = i + 1, n do
            local a, b = sets.russian.keys[i], sets.russian.keys[j]
            assert(a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y, "two keys over each other")
        end
    end
end)

check("the split keyboard, Latin layouts as they were", function()
    local E = keyboard("enUS", "en")
    local sets = E.Methods.stick.sets
    same("", missing(typedOf(sets.qwerty, E), "abcdefghijklmnopqrstuvwxyz"))
    same("", missing(typedOf(sets.azerty, E), "abcdefghijklmnopqrstuvwxyz"))
    same("", missing(typedOf(sets.qwertz, E), "abcdefghijklmnopqrstuvwxyzäöüß"))
    local per = { 0, 0, 0, 0 }
    for _, key in ipairs(sets.qwerty.keys) do
        local row = key.y == 4 and 1 or key.y == 58 and 2 or key.y == 112 and 3 or 4
        per[row] = per[row] + 1
    end
    same("10|10|9|7", table.concat(per, "|"))
    same("qwertyuiopasdfghjkl'zxcvbnm,-.?!", typedOf(sets.qwerty, E))
end)

check("the split keyboard: the Latin letters asked instead, and back", function()
    local E = keyboard("ruRU")
    local M, typed = E.Methods.stick, {}
    E.TypeChar = function(_, ch) typed[#typed + 1] = ch end
    E.UpdateMethod = function() end
    E.state.layer = "letters"
    same(true, E:OtherLetters())
    M:Press(M.sets.russian.keys[1])
    same("й", typed[1])
    -- 123, and at once again: the Latin letters
    E:ToggleSymbols()
    same("symbols", E.state.layer)
    E:ToggleSymbols()
    same("letters", E.state.layer)
    same(true, E.state.latin)
    M:Press(M.sets.russian.keys[1])   -- (the set asked is the Latin one: QWERTY's first key)
    same("q", M:ActiveSet() == M.sets.qwerty and "q" or "?")
    same("abc", E:LettersLabel())
    E:ToggleSymbols()
    E:ToggleSymbols()
    same(false, E.state.latin)
    same("абв", E:LettersLabel())
    -- Slowly: the symbols and back leave the letters as they were
    E:ToggleSymbols()
    E.state.layerAt = E.state.layerAt - 10
    E:ToggleSymbols()
    same("letters", E.state.layer)
    same(false, E.state.latin)
end)

check("the Latin letters asked: not when something was typed on the 123 layer in between", function()
    local E = keyboard("ruRU")
    E.InsertText = function(self, t) self.buffer = t end
    E.UpdateMethod = function() end
    -- 123, a dot, and back at once: the dot, the same letters
    E:ToggleSymbols()
    E:TypeChar(".")
    E:ToggleSymbols()
    same(false, E.state.latin and true or false)
    same(".", E.buffer)
    -- 123, nothing, back: the other letters
    E:ToggleSymbols()
    E:ToggleSymbols()
    same(true, E.state.latin)
end)

check("English picked on a client of another language", function()
    local F = addon("frFR")
    started(F)
    same("frFR", F.locale)
    F:SetUILanguage("enUS")
    same("enUS", F.db.settings.uiLang)
    same("enUS", F:UILocale())
    F:ApplyLocale(F:UILocale())
    same("Send", F.L.SEND)
    F:ApplyLocale("frFR")
    same("Envoyer", F.L.SEND)
    local again = addon("frFR")
    env.ControllerKeyboardDB = F.db
    again:InitDB()
    same("enUS", again.db.settings.uiLang)
    same("enUS", again:UILocale())
end)

check("the split keyboard: nothing of it for the Latin layouts", function()
    local E = keyboard("enUS", "en")
    E.UpdateMethod = function() end
    same(false, E:OtherLetters())
    E:ToggleSymbols()
    E:ToggleSymbols()
    same(nil, E.state.latin)
    same("abc", E:LettersLabel())
end)

check("the daisywheel, Russian: the letters in their alphabet's order, the last one on 123", function()
    local E = keyboard("ruRU")
    local typed = {}
    E.TypeChar = function(_, ch) typed[#typed + 1] = ch end
    local function layer(name)
        typed = {}
        E.state.layer = name
        for petal = 1, 8 do
            for slot = 1, 4 do E:TypeSlot(petal, slot) end
        end
        return table.concat(typed)
    end
    local own = layer("letters")
    same("абвгдеёжзийклмнопрстуфхцчшщыьэюя", own)
    local symbols = layer("symbols")
    same("", missing(symbols, "ъ"))
    same("1234567890+=ъ.,?!-«»…—_&:;()/@\"%", symbols)
    -- The Latin letters asked instead, and back
    E.state.latin = true
    same("abcdefghijklmnopqrstuvwx", layer("letters"):sub(1, 24))
    E.state.latin = false
    same("абвг", layer("letters"):sub(1, 8))
    -- Another language: its letters, its accents
    E:SetLanguage("fr")
    same("abcdefghijklmnopqrstuvwxyz'-.,?!", layer("letters"))
    same("éèêàâçùûîôëï:;()/@\"%", layer("symbols"):sub(13))
    E:SetLanguage("ruen")
    same("абвг", layer("letters"):sub(1, 8))
    same("ъ.,?!-«»…—_&:;()/@\"%", layer("symbols"):sub(13))
end)

check("typing in Russian: shift one capital, twice caps, backspace by the letter", function()
    local E = addon("ruRU")
    run("Message.lua", E)
    E:InitDB()
    E.UpdateMethod = function() end
    E.state.layer = "letters"
    local text
    E.SetText = function(self, t) self.buffer = t; text = t end
    E.TrailingLink = function() return nil end
    E:TypeChar("п")
    same("п", text)
    E:ToggleShift()
    E:TypeChar("р")
    same("пР", text)
    same(false, E.state.shift)
    E:ToggleShift()
    E:ToggleShift()
    same(true, E.state.caps)
    E:TypeChar("и")
    E:TypeChar("в")
    E:TypeChar("е")
    E:TypeChar("т")
    same("пРИВЕТ", text)
    E:ToggleShift()
    same(false, E.state.caps)
    E:TypeChar(" ")
    E:TypeChar("м")
    E:TypeChar("и")
    E:TypeChar("р")
    same("пРИВЕТ мир", text)
    E:Backspace()
    E:Backspace()
    same("пРИВЕТ м", text)
    E:Backspace()
    E:Backspace()
    same("пРИВЕТ", text)
end)

---------------------------------------------------------------------------
-- Suggestions
---------------------------------------------------------------------------

local function predictor(language, words)
    local E = addon("ruRU")
    run("Dict_ruRU_next.lua", E)
    run("Predict.lua", E)
    run("Message.lua", E)
    E:InitDB()
    E.db.settings.lang = language
    if words then E.Dicts.ruRU = words end
    E.Predict:Load()
    return E.Predict, E.db, E
end

check("the words typed are found, the most used first", function()
    local p = predictor("ru", "привет приятель мир ещё еще приз")
    same("привет,приятель,приз", table.concat(p:Query("при", { start = true }, 5), ","))
    same("", table.concat(p:Query("xyz", { start = true }, 5), ","))
    same("", table.concat(p:Query("fgs", { start = true }, 5), ","))
end)

check("ё typed with or without its dots", function()
    local p = predictor("ru", "ещё еще всё все")
    -- (the word typed whole is not offered again: its other spelling is)
    same("ещё,еще", table.concat(p:Query("ещ", { start = true }, 5), ","))
    same("ещё", table.concat(p:Query("еще", { start = true }, 5), ","))
    same("еще", table.concat(p:Query("ещё", { start = true }, 5), ","))
    same("всё", table.concat(p:Query("все", { start = true }, 5), ","))
    same("все", table.concat(p:Query("всё", { start = true }, 5), ","))
    same("всё,все", table.concat(p:Query("вс", { start = true }, 5), ","))
end)

check("the case typed is kept", function()
    local p = predictor("ru", "привет приятель")
    same("Привет,Приятель", table.concat(p:Query("При", { start = true }, 5), ","))
    same("ПРИВЕТ,ПРИЯТЕЛЬ", table.concat(p:Query("ПРИ", { start = true }, 5), ","))
    same("Ещё", table.concat(predictor("ru", "ещё"):Query("Ещ", { start = true }, 5), ","))
end)

check("the next word before anything is typed", function()
    local p = predictor("ru", "привет мир как")
    same("и,не,в,на,я", table.concat(p:Query("", { prev = "незнакомое" }, 5), ","))
    same("как", p:Query("", { prev = "привет" }, 5)[1])
    same("дела", p:Query("", { prev = "как" }, 5)[1])
    same("привет", p:Query("", { start = true }, 5)[1])
    same("и,не,в,на,я", table.concat(predictor("ruen", "hello"):Query("", { prev = "unseen" }, 5), ","))
    same("and,the,to,for,a", table.concat(predictor("en", "hello"):Query("", { prev = "unseen" }, 5), ","))
end)

check("a message is learned: its words, its beginnings, what follows what", function()
    local p, db = predictor("ru", "")
    p:LearnMessage("Я в игре. Кто-то пришёл ещё!")
    -- (a letter alone is no word to offer: it stays what follows)
    same(nil, db.words["я"])
    same(nil, db.words["в"])
    same(1, db.words["кто-то"])
    same(1, db.starts["я"])
    same(1, db.starts["кто-то"])
    same(1, db.bigrams["кто-то"]["пришёл"])
    same("в", p:Query("", { prev = "я" }, 5)[1])
    same("", table.concat(p:Query("я", { start = true }, 5), ","))
    -- (its beginnings: what was typed there weighs most)
    same("я,привет", table.concat(p:Query("", { start = true }, 2), ","))
end)

check("the Russian dictionary: its words, the chat words of the game", function()
    local E = addon("ruRU")
    run("Dict_ruRU.lua", E)
    run("Dict_WoW.lua", E)
    run("Dict_ruRU_next.lua", E)
    run("Predict.lua", E)
    E:InitDB()
    local p, ru, wow = E.Predict, 0, 0
    for _ in E.Dicts.ruRU:gmatch("[^ \t\r\n]+") do ru = ru + 1 end
    for _ in E.Dicts.wow:gmatch("[^ \t\r\n]+") do wow = wow + 1 end
    p:Load()
    assert(ru <= p:NumEntries() and p:NumEntries() <= ru + wow, "entries: " .. p:NumEntries())
    same("привет", p:Query("прив", { start = true }, 5)[1])
    same("спасибо", p:Query("спас", { start = true }, 5)[1])
    assert(("," .. table.concat(p:Query("лф", { start = true }, 5), ",") .. ","):find(",лфг,", 1, true), "лфг not offered")
    same("хил", p:Query("", { prev = "нужен" }, 5)[1])
    -- Russian words only: no name of a film's character, no misprint left
    local n = 0
    for word in E.Dicts.ruRU:gmatch("[^ \t\r\n]+") do
        assert(word:find("^[\208\209][\128-\191]") and not word:find("[^\128-\191\208-\209%-']"),
            "a word not Russian: " .. word)
        n = n + 1
    end
    same(12000, n)
end)

check("commands and names", function()
    local p, _, E = predictor("ru", "")
    same("/reload,/p,/ra,/g,/w", table.concat(p:QueryCommands("/", 5), ","))
    p:LearnCommand("/ec lock")
    same("/ec lock", p:QueryCommands("/ec l", 1)[1])
    E.KnownNames = function() return { "Ёжик", "Волк", "Ястреб" } end
    same("Ёжик,Волк,Ястреб", table.concat(E:QueryNames("", 5), ","))
    same("Ёжик,еж", table.concat(E:QueryNames("еж", 5), ","))
    same("Волк,В", table.concat(E:QueryNames("В", 5), ","))
end)

assert(failed == 0, failed .. " Russian regression tests failed")
print(passed .. " Russian regression tests passed")
