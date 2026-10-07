local _, CK = ...

local P = {}
CK.Predict = P

local USER_WEIGHT = 12     -- score per time the player used a word
local BIGRAM_WEIGHT = 25   -- per time the word followed the previous word
local TRIGRAM_WEIGHT = 40  -- per time the word followed the two previous words
local START_WEIGHT = 20    -- per time a message started with the word
local WOW_SCORE = 36       -- score of the WoW chat vocabulary (~ rank 250)

-- Filler for the next-word bar when nothing better is known
local FALLBACK = {
    fr = { "et", "de", "pour", "le", "la", "à", "un" },
    en = { "and", "the", "to", "for", "a", "in", "with" },
    de = { "und", "die", "der", "zu", "für", "ein", "mit" },
    es = { "y", "de", "para", "el", "la", "un", "con" },
    it = { "e", "di", "per", "il", "la", "un", "con" },
}

local entries = {}         -- word -> { word, norm, dict }
local buckets = {}         -- first normalized byte -> array of entries
local numEntries = 0
local builtinNext = {}     -- word -> { follower -> score }
local builtinStarts = {}   -- word -> score

local function rankScore(rank)
    -- rank 1 -> 60, 10 -> 50, 100 -> 40, 1000 -> 30, 10000 -> 20
    return 60 - 10 * math.log10(rank)
end

local function addEntry(word, dictScore)
    local e = entries[word]
    if e then
        if dictScore and dictScore > e.dict then e.dict = dictScore end
        return e
    end
    local norm = CK.Normalize(word)
    if norm == "" then return end
    e = { word = word, norm = norm, dict = dictScore or 0 }
    entries[word] = e
    numEntries = numEntries + 1
    local key = norm:sub(1, 1)
    local bucket = buckets[key]
    if not bucket then
        bucket = {}
        buckets[key] = bucket
    end
    bucket[#bucket + 1] = e
    return e
end

-- Spaces are matched with an explicit class (space, tab, CR, LF), never with
-- %s: depending on the locale %s also matches byte 0xA0, the second byte of
-- "a grave" in UTF-8, which cut words like "citta" (with an accent) in two
local function loadNextWords(data)
    local rank = 0
    for word in (data.starts or ""):gmatch("[^ \t\r\n]+") do
        rank = rank + 1
        builtinStarts[word] = math.max(builtinStarts[word] or 0, 40 - 2 * (rank - 1))
    end
    for head, list in pairs(data.next or {}) do
        local t = builtinNext[head] or {}
        builtinNext[head] = t
        rank = 0
        for word in list:gmatch("[^ \t\r\n]+") do
            rank = rank + 1
            t[word] = math.max(t[word] or 0, math.max(15, 45 - 3 * (rank - 1)))
        end
    end
end

function P:Load()
    wipe(entries)
    wipe(buckets)
    wipe(builtinNext)
    wipe(builtinStarts)
    numEntries = 0

    for lang, enabled in pairs(CK.db.settings.dicts) do
        if enabled then
            local list = CK.Dicts[lang]
            if list then
                local rank = 0
                for word in list:gmatch("[^ \t\r\n]+") do
                    rank = rank + 1
                    addEntry(word, rankScore(rank))
                end
            else
                CK:Print(CK.L.NO_DICT, lang)
            end
            if CK.NextWords and CK.NextWords[lang] then
                loadNextWords(CK.NextWords[lang])
            end
        end
    end
    if CK.Dicts.wow then
        for word in CK.Dicts.wow:gmatch("[^ \t\r\n]+") do
            addEntry(word, WOW_SCORE)
        end
    end
    for word in pairs(CK.db.words) do
        addEntry(word)
    end
end

function P:NumEntries()
    return numEntries
end

-- Every word known, lowercase, with its weight (the dictionary's, plus the
-- player's use): ConsolePort's keyboard ranks them its own way
function P:EachWord(fn)
    local words = CK.db.words
    local seen = {}
    for word, e in pairs(entries) do
        local lower = CK.Lower(word)
        local weight = e.dict + USER_WEIGHT * (words[word] or 0)
        if not seen[lower] or seen[lower] < weight then seen[lower] = weight end
    end
    for word, weight in pairs(seen) do fn(word, weight) end
end

---------------------------------------------------------------------------
-- Tokens and context
---------------------------------------------------------------------------
-- Lowercase tokens of a sentence; elisions are tokens of their own:
-- "J'ai un groupe" -> { "j'", "ai", "un", "groupe" }
function P.Tokenize(sentence)
    local tokens = {}
    for token in sentence:gmatch("[%a\128-\255][%a\128-\255'%-]*") do
        token = CK.Lower(token):gsub("^\194[\161\191]", "")
        local elided, rest = token:match("^(%a%a?')(.+)$")
        if elided then
            tokens[#tokens + 1] = elided
            token = rest
        end
        if not token:match("^%a%a?'$") then
            token = token:gsub("['%-]+$", "")
        end
        if token ~= "" then tokens[#tokens + 1] = token end
    end
    return tokens
end

-- Context of the word being typed, from the text before it:
-- { start = true } at the beginning of a message or sentence,
-- otherwise { prev = last word, prev2 = the one before }
function P:Context(before)
    before = before:gsub("|c%x%x%x%x%x%x%x%x|H[^|]+|h[^|]*|h|r", " "):gsub("|H[^|]+|h[^|]*|h", " ")
    local sentence = before:match("([^%.!%?]*)$") or ""
    local tokens = P.Tokenize(sentence)
    local n = #tokens
    if n == 0 then return { start = true } end
    return { prev = tokens[n], prev2 = tokens[n - 1] }
end

local function isElision(word)
    return word:sub(-1) == "'"
end

---------------------------------------------------------------------------
-- Suggestions
---------------------------------------------------------------------------
-- Keep the best `n` words in `out` (sorted by descending score)
local function consider(out, scores, n, word, score)
    local count = #out
    for i = 1, count do
        if out[i] == word then return end
    end
    if count >= n and score <= scores[count] then return end
    local pos = count + 1
    while pos > 1 and scores[pos - 1] < score do
        pos = pos - 1
    end
    table.insert(out, pos, word)
    table.insert(scores, pos, score)
    if #out > n then
        out[n + 1] = nil
        scores[n + 1] = nil
    end
end

local function applyCase(word, prefix)
    if not CK.IsUpperInitial(prefix) then return word end
    if #prefix > 1 and prefix == CK.Upper(prefix) then
        return CK.Upper(word)
    end
    return CK.Capitalize(word)
end

-- Bonus of `word` in this context: the player's habits (starts, pairs and
-- triplets of words) plus the built-in French sequences
local function contextBonus(ctx, word)
    local db = CK.db
    local bonus = 0
    if ctx.start then
        bonus = bonus + START_WEIGHT * (db.starts[word] or 0) + (builtinStarts[word] or 0)
    elseif ctx.prev then
        local b = db.bigrams[ctx.prev]
        if b and b[word] then bonus = bonus + BIGRAM_WEIGHT * b[word] end
        if ctx.prev2 then
            local t = db.trigrams[ctx.prev2 .. " " .. ctx.prev]
            if t and t[word] then bonus = bonus + TRIGRAM_WEIGHT * t[word] end
        end
        local nb = builtinNext[ctx.prev]
        if nb and nb[word] then bonus = bonus + nb[word] end
    end
    return bonus
end

-- Words that may follow in this context (nothing typed yet)
local function contextCandidates(ctx)
    local db = CK.db
    local set = {}
    local function addAll(t)
        if t then for word in pairs(t) do set[word] = true end end
    end
    if ctx.start then
        addAll(db.starts)
        addAll(builtinStarts)
    elseif ctx.prev then
        addAll(db.bigrams[ctx.prev])
        if ctx.prev2 then addAll(db.trigrams[ctx.prev2 .. " " .. ctx.prev]) end
        addAll(builtinNext[ctx.prev])
    end
    return set
end

-- prefix: the word being typed (may be ""), ctx: from P:Context()
function P:Query(prefix, ctx, n)
    local out, scores = {}, {}
    local words = CK.db.words
    ctx = ctx or { start = true }

    if prefix == "" then
        -- Predict the next word, iPhone style
        for word in pairs(contextCandidates(ctx)) do
            local e = entries[word]
            local score = contextBonus(ctx, word) + 0.1 * (e and e.dict or 0)
            consider(out, scores, n, word, score)
        end
        if not ctx.start then
            local fallback = FALLBACK[CK:GetLanguage().accents] or FALLBACK.en
            for i = 1, #fallback do
                consider(out, scores, n, fallback[i], -i)
            end
        end
        return out
    end

    local norm = CK.Normalize(prefix)
    local lower = CK.Lower(prefix)
    local bucket = buckets[norm:sub(1, 1)]
    if not bucket then return out end

    local len = #norm
    for i = 1, #bucket do
        local e = bucket[i]
        if e.word ~= lower and e.norm:sub(1, len) == norm then
            local score = e.dict + USER_WEIGHT * (words[e.word] or 0) + contextBonus(ctx, e.word)
            consider(out, scores, n, e.word, score)
        end
    end

    for i = 1, #out do
        out[i] = applyCase(out[i], prefix)
    end
    return out
end

---------------------------------------------------------------------------
-- Learning
---------------------------------------------------------------------------
local lastMsg, lastTime

local function bump(t, key, sub)
    local inner = t[key]
    if not inner then
        inner = {}
        t[key] = inner
    end
    inner[sub] = (inner[sub] or 0) + 1
end

function P:LearnMessage(msg)
    local db = CK.db
    if not (db and db.settings.learn) or type(msg) ~= "string" then return end

    -- SendChatMessage and C_ChatInfo.SendChatMessage may both be hooked
    local now = GetTime()
    if msg == lastMsg and now == lastTime then return end
    lastMsg, lastTime = msg, now

    msg = msg:gsub("|H.-|h.-|h", " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

    local words = db.words
    for sentence in msg:gmatch("[^%.!%?]+") do
        local tokens = P.Tokenize(sentence)
        for i, token in ipairs(tokens) do
            if #token > 30 then break end
            if not isElision(token) and #token >= 2 then
                words[token] = (words[token] or 0) + 1
                addEntry(token)
            end
            if i == 1 then
                db.starts[token] = (db.starts[token] or 0) + 1
            end
            local prev, prev2 = tokens[i - 1], tokens[i - 2]
            if prev then bump(db.bigrams, prev, token) end
            if prev2 then bump(db.trigrams, prev2 .. " " .. prev, token) end
        end
    end
end

function P:NumLearned()
    local n = 0
    for _ in pairs(CK.db.words) do n = n + 1 end
    return n
end

-- Drop the least used words when the table grows too big
function P:Prune()
    local db = CK.db
    local words = db.words
    local max = db.settings.maxWords
    local n = self:NumLearned()
    if n > max then
        local ranked = {}
        for word in pairs(words) do ranked[#ranked + 1] = word end
        table.sort(ranked, function(a, b)
            if words[a] ~= words[b] then return words[a] < words[b] end
            return a < b
        end)
        -- Remove only the excess, even when many words share a count.
        for i = 1, math.min(n, n - max) do words[ranked[i]] = nil end
    end

    -- Short words ("a", "y") and elisions ("j'") are never stored in `words`
    -- but are kept as context
    local function known(word)
        return words[word] or #word <= 2 or isElision(word)
    end
    local function pruneInner(t)
        local empty = true
        for word in pairs(t) do
            if known(word) then empty = false else t[word] = nil end
        end
        return empty
    end
    for prev, t in pairs(db.bigrams) do
        if not known(prev) or pruneInner(t) then db.bigrams[prev] = nil end
    end
    for key, t in pairs(db.trigrams) do
        local a, b = key:match("^([^ \t\r\n]+) ([^ \t\r\n]+)$")
        if not (a and known(a) and known(b)) or pruneInner(t) then db.trigrams[key] = nil end
    end
    for word in pairs(db.starts) do
        if not known(word) then db.starts[word] = nil end
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
-- Always suggested first, in this order. The short English commands work in
-- every client language (/ra = raid; /r = reply to the last whisper).
local PINNED_COMMANDS = { "/reload", "/p", "/ra", "/g", "/w" }

-- Suggested after the pinned ones and the player's own commands (most used first)
local BUILTIN_COMMANDS = {
    "/r", "/ec", "/ec lock", "/s", "/y", "/e", "/inv",
    "/roll", "/afk", "/dnd", "/who", "/dance", "/sit", "/played", "/follow",
    "/assist", "/target", "/logout", "/camp", "/ec debug", "/ec auto",
    "/ec learn", "/ec lang", "/ec scale", "/ec reset", "/ec stats", "/ec invert",
    "/ec pad", "/ec forget",
}

-- Commands followed by a message: never learn their argument
local CHAT_COMMANDS = {
    ["/s"] = true, ["/say"] = true, ["/p"] = true, ["/party"] = true, ["/g"] = true,
    ["/guild"] = true, ["/o"] = true, ["/w"] = true, ["/whisper"] = true, ["/t"] = true,
    ["/tell"] = true, ["/r"] = true, ["/reply"] = true, ["/y"] = true, ["/yell"] = true,
    ["/e"] = true, ["/me"] = true, ["/emote"] = true, ["/ra"] = true, ["/raid"] = true,
    ["/rw"] = true, ["/i"] = true, ["/bg"] = true,
}

function P:LearnCommand(text)
    local db = CK.db
    if not (db and db.settings.learn) then return end
    local cmd, rest = text:match("^(/[^ \t\r\n]+)[ \t\r\n]*(.-)[ \t\r\n]*$")
    if not cmd or #cmd > 30 then return end
    cmd = CK.Lower(cmd)
    local commands = db.commands
    commands[cmd] = (commands[cmd] or 0) + 1
    -- "/ec lock": remember a single short argument, not chat messages
    local arg = rest:match("^([^ \t\r\n]+)$")
    if arg and #arg <= 15 and not CHAT_COMMANDS[cmd] and not cmd:match("^/%d+$") then
        local full = cmd .. " " .. CK.Lower(arg)
        commands[full] = (commands[full] or 0) + 1
    end
end

-- /reload, /p, /ra, /g, /w first, then learned commands by use, then common ones
function P:QueryCommands(text, n)
    local lower = CK.Lower(text)
    local out, seen = {}, {}
    local function add(cmd)
        if #out < n and not seen[cmd] and cmd ~= lower and cmd:sub(1, #lower) == lower then
            seen[cmd] = true
            out[#out + 1] = cmd
        end
    end
    for _, cmd in ipairs(PINNED_COMMANDS) do add(cmd) end
    local commands = CK.db.commands
    local learned = {}
    for cmd in pairs(commands) do learned[#learned + 1] = cmd end
    table.sort(learned, function(a, b) return commands[a] > commands[b] end)
    for _, cmd in ipairs(learned) do add(cmd) end
    for _, cmd in ipairs(BUILTIN_COMMANDS) do add(cmd) end
    return out
end

function P:Forget()
    wipe(CK.db.words)
    wipe(CK.db.bigrams)
    wipe(CK.db.trigrams)
    wipe(CK.db.starts)
    wipe(CK.db.commands)
    self:Load()
end
