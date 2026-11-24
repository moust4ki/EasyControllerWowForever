-- The translations against English (Locales/enUS.lua): a text of a language
-- keeps English's %s, %d, %% and |c...|r codes (another count would fail a
-- format, or leave a colour open), and its lists English's shape. A text a
-- language leaves out is English: not one of its problems.
-- Run from the addon root with Lua 5.1: luajit tools/test_locales.lua
local function texts(file)
    local CK = { LOCALES = {} }
    local src = assert(io.open("Locales/" .. file, "rb")):read("*a")
    if file == "enUS.lua" then src = src:gsub("CK%.L = {", "CK.LOCALES.enUS = {", 1) end
    assert(loadstring(src, file))("EasyController", CK)
    local _, t = next(CK.LOCALES)
    return t
end

local function marks(s)
    local colours, placeholders = {}, {}
    for code in s:gmatch("|c%x%x%x%x%x%x%x%x") do colours[#colours + 1] = "|c" end
    -- (an end of colour: a "|r" that no letter follows, not the one a
    -- command's choices begin with, "|ru")
    for i = 1, #s do
        if s:sub(i, i + 1) == "|r" and not s:sub(i + 2, i + 2):find("%a") then colours[#colours + 1] = "|r" end
    end
    -- (in their order: format gives its arguments in it)
    for p in s:gmatch("%%%a") do placeholders[#placeholders + 1] = p end
    return table.concat(placeholders, " ") .. " | " .. table.concat(colours, " ")
end

local english = texts("enUS.lua")
local failed, compared, languages = 0, 0, 0
local function compare(key, en, tr)
    if type(en) == "string" and type(tr) == "string" then
        compared = compared + 1
        if marks(en) ~= marks(tr) then
            failed = failed + 1
            print(string.format("FAIL %s.%s: English [%s], translated [%s]", LANG, key, marks(en), marks(tr)))
        end
    elseif type(en) == "table" and type(tr) == "table" then
        if #en ~= #tr then
            failed = failed + 1
            print(string.format("FAIL %s.%s: %d lines in English, %d here", LANG, key, #en, #tr))
        end
        for i = 1, math.min(#en, #tr) do compare(key .. "[" .. i .. "]", en[i], tr[i]) end
    elseif type(en) ~= type(tr) then
        failed = failed + 1
        print(string.format("FAIL %s.%s: a %s in English, a %s here", LANG, key, type(en), type(tr)))
    end
end

local files = {}
local pipe = assert(io.popen('ls Locales/*.lua'))
for file in pipe:lines() do files[#files + 1] = file:match("[^/]+$") end
pipe:close()
table.sort(files)
for _, file in ipairs(files) do
    if file ~= "enUS.lua" then
        LANG = file:gsub("%.lua$", "")
        languages = languages + 1
        local translated = texts(file)
        for key, tr in pairs(translated) do
            local en = english[key]
            if en ~= nil then compare(key, en, tr) end
        end
    end
end
print(string.format("%d languages, %d texts compared against English, %d problems", languages, compared, failed))
assert(failed == 0, failed .. " translation problems")
