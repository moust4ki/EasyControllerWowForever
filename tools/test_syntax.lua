-- Every file the TOC lists, read as the game's Lua (5.1) reads it. The tests
-- run on LuaJIT, which takes more than the game: a name (a key of a table, a
-- variable) written with any letter, `goto` and `::labels::`, the `\x`, `\z`
-- and `\u{}` escapes of strings. In the game, each is a file that does not
-- load at all (reported: a Russian alias's key kept Chat.lua from loading,
-- with it every /ec command and the panel). Outside the comments and the
-- strings: ASCII only, no `goto`. In the strings: the escapes of 5.1.
-- Run from the addon root, any Lua 5.1: luajit tools/test_syntax.lua
local problems, files = {}, 0

local function scan(name, src)
    -- A long bracket's level where one opens at `pos`, else nil
    local function levelAt(pos)
        local level = src:match("^%[(=*)%[", pos)
        return level and #level or nil
    end
    local function fail(at, what)
        local _, before = src:sub(1, at):gsub("\n", "")
        problems[#problems + 1] = string.format("%s:%d: %s", name, before + 1, what)
    end

    local i, n = 1, #src
    while i <= n do
        local c = src:sub(i, i)
        if c == "-" and src:sub(i + 1, i + 1) == "-" then
            -- A comment
            local level = levelAt(i + 2)
            if level then
                local close = "]" .. string.rep("=", level) .. "]"
                local last = src:find(close, i + 4 + level, true)
                if not last then fail(i, "a comment never closed") break end
                i = last + #close
            else
                local endOfLine = src:find("\n", i, true)
                i = endOfLine or n + 1
            end
        elseif c == '"' or c == "'" then
            -- A string
            local first = i
            i = i + 1
            while true do
                local d = src:sub(i, i)
                if i > n or d == "\n" or d == "\r" then fail(first, "a string never closed on its line") break end
                if d == c then i = i + 1 break end
                if d == "\\" then
                    local e = src:sub(i + 1, i + 1)
                    if e == "x" or e == "z" or e == "u" then
                        fail(i, "an escape of Lua 5.2 and LuaJIT, that Lua 5.1 reads as its letter: \\" .. e)
                    end
                    -- (5.1 passes over the one character after the backslash)
                    i = i + 2
                else
                    i = i + 1
                end
            end
        elseif levelAt(i) then
            -- A long string
            local level = levelAt(i)
            local close = "]" .. string.rep("=", level) .. "]"
            local last = src:find(close, i + 2 + level, true)
            if not last then fail(i, "a string never closed") break end
            i = last + #close
        elseif c:byte() >= 128 then
            fail(i, "a character that is not ASCII, outside a string and a comment (a name?)")
            while i <= n and src:byte(i) >= 128 do i = i + 1 end
        elseif c == ":" and src:sub(i + 1, i + 1) == ":" then
            fail(i, "a label (::name::), not Lua 5.1")
            -- (the whole label, not its end as another one)
            local label = src:match("^::%s*[A-Za-z_][A-Za-z0-9_]*%s*::", i)
            i = i + (label and #label or 2)
        else
            local word = src:match("^[A-Za-z_][A-Za-z0-9_]*", i)
            if word then
                if word == "goto" then fail(i, "goto, not Lua 5.1") end
                i = i + #word
            else
                i = i + 1
            end
        end
    end
end

local toc = assert(io.open("EasyController.toc", "rb")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    local file = line:match("^(.*%.lua)%s*$")
    if file and not line:match("^%s*#") then
        files = files + 1
        local f = assert(io.open(file:gsub("\\", "/"), "rb"), file)
        scan(file, f:read("*a"))
        f:close()
    end
end
assert(files > 0, "no file found in the TOC")
for _, p in ipairs(problems) do print("FAIL " .. p) end
print(string.format("%d files read as the game's Lua 5.1 reads them, %d problems", files, #problems))
assert(#problems == 0, #problems .. " file(s) the game's Lua would not load as written")
