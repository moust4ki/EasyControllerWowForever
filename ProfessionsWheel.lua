local _, CK = ...
local L = CK.L

-- Module "professions wheel" (asked): a wheel filled by itself with the
-- profession windows the character's spell book offers. Crafting first
-- (Alchemy, Blacksmithing, Cooking...), then Smelting and the gathering
-- ones Forever gives a window of their own (Herbalism, Mining, Skinning,
-- Fishing: trainer-taught, their recipes made in it); the tracking of
-- herbs and minerals last (an option, off: a switch, not a window). Fishing
-- itself (the line cast) isn't in it (asked). Only what this character knows,
-- always in the same order, 8 a page. Drawn, opened, aimed and used by the
-- consumables wheel (ConsumableWheel.lua: its wheel "t", its key
-- "CLICK ControllerKeyboardProfessionsToggle"), in combat too; what it
-- holds changes out of combat only (the game's rule: a profession learned
-- in a fight comes in once it ends).
--
-- How a profession's spell is found. A name only one kind of spell has
-- (every "Alchemy" opens Alchemy's window, the classic ranks and this
-- client's own): the game's first rank gives it in the client's language,
-- the spell book is searched by it, so whatever rank the character has
-- comes, and it is cast by that name. A name two kinds share ("Fishing":
-- the line cast and the window; "Mining", "Herbalism", "Skinning":
-- gathering and the window; "Engineering": the window and a salvage of
-- this client's): only the spells of that kind, by ID (every rank, from
-- the client's data), and cast by that ID (a name could cast the other
-- one). Searched where the game keeps them: each profession's own spells
-- (GetProfessions, by skill line), the spell book's lines, and last the
-- game's own search.
local P = {}
CK.ProfessionsWheel = P

-- The wheel's order (SkillLineAbility and SpellEffect, client 1.60.1:
-- each window a "trade skill" effect; the skill line beside it). `spell`:
-- the game's first rank, for its name only. `ids`: the only spells of the
-- kind, cast by ID. This client has no Jewelcrafting nor Inscription (no
-- such skill line). `option`: shown only with that setting on (Wheels ›
-- Professions)
P.KINDS = {
    { key = "alchemy", spell = 2259 },        -- 171
    { key = "blacksmithing", spell = 2018 },  -- 164
    { key = "cooking", spell = 2550 },        -- 185
    -- (not 1235244, "Engineering" too: a salvage, no window)
    { key = "engineering", ids = { 4036, 4037, 4038, 12656, 1240947, 1240958, 1240969, 1240982 } }, -- 202
    { key = "enchanting", spell = 7411 },     -- 333
    { key = "firstAid", spell = 3273 },       -- 129
    { key = "tailoring", spell = 3908 },      -- 197
    { key = "leatherworking", spell = 2108 }, -- 165
    -- Mining's old window (186)
    { key = "smelting", spell = 2656 },
    -- The gathering ones' windows (2944, 2946, 2947, 2943), not their
    -- gathering spells of the same names
    { key = "herbalism", ids = { 1240949, 1240960, 1240971, 1240984 } },
    { key = "mining", ids = { 1240951, 1240962, 1240973, 1240986 } },
    { key = "skinning", ids = { 1240952, 1240963, 1240974, 1240987 } },
    { key = "fishing", ids = { 1240948, 1240959, 1240970, 1240983 } },
    { key = "findHerbs", spell = 2383, option = "professionsTracking", cat = "tracking" },    -- 182
    { key = "findMinerals", spell = 2580, option = "professionsTracking", cat = "tracking" }, -- 186
}

local function settings() return CK.db.settings.wheel end

local function spellName(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return type(name) == "string" and name ~= "" and name or nil
end

-- A spell of the book (not passive, not another spec's, not one still to
-- learn), else nil
local function bookSpell(index, bank)
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, bank)
    if not (ok and type(info) == "table" and info.spellID) or info.isPassive or info.isOffSpec then return nil end
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    if spellType then
        if info.itemType ~= spellType then return nil end
    elseif C_SpellBook.IsSpellKnown then
        -- (no item types to tell a spell still to learn: the game asked)
        local okKnown, known = pcall(C_SpellBook.IsSpellKnown, info.spellID)
        if okKnown and known == false then return nil end
    end
    return info.spellID
end

-- The book's places worth reading, in order: each profession's own
-- spells (the game's list of the character's professions, by skill line:
-- where a profession window lists them), then every line of the spell
-- book (the General one holds them in the old way)
local function bookIndexes()
    local indexes, order = {}, {}
    local function add(first, count)
        if type(first) ~= "number" or type(count) ~= "number" then return end
        for i = first + 1, first + count do
            if not indexes[i] then
                indexes[i] = true
                order[#order + 1] = i
            end
        end
    end
    if GetProfessions and GetProfessionInfo then
        -- (up to six, with holes: not a list)
        local got = { pcall(GetProfessions) }
        if got[1] then
            for i = 2, table.maxn(got) do
                if got[i] then
                    local ok, _, _, _, _, numSpells, offset = pcall(GetProfessionInfo, got[i])
                    if ok then add(offset, numSpells) end
                end
            end
        end
    end
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines() or 0 do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info then add(info.itemIndexOffset, info.numSpellBookItems) end
    end
    return order
end

-- The book read again only when its spells change (ConsumableWheel.lua's
-- events: SPELLS_CHANGED, LEARNED_SPELL_IN_SKILL_LINE), not at each
-- filling of the wheels (each loot)
function P:Invalidate()
    self.known = nil
end

-- Each kind this character has: { [kind's index] = spell ID }, the
-- options aside
function P:Known()
    if self.known then return self.known end
    local byName, byId = {}, {}
    for i, kind in ipairs(P.KINDS) do
        if kind.ids then
            for _, id in ipairs(kind.ids) do byId[id] = i end
        else
            local name = spellName(kind.spell)
            if name then byName[name] = i end
        end
    end
    local found = {}
    if not (C_SpellBook and C_SpellBook.GetSpellBookItemInfo) then return found end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    -- (two ranks in the book: the later one, the higher)
    for _, index in ipairs(bookIndexes()) do
        local id = bookSpell(index, bank)
        local kind = id and (byId[id] or byName[spellName(id) or ""])
        if kind then found[kind] = id end
    end
    -- Not found there: the game's own search (a book laid out otherwise),
    -- by name, or by each rank's ID
    if C_SpellBook.FindSpellBookSlotForSpell then
        local function search(what, i, accept)
            if found[i] then return end
            local ok, index, inBank = pcall(C_SpellBook.FindSpellBookSlotForSpell, what)
            local id = ok and index and bookSpell(index, inBank or bank)
            if id and accept(id) then found[i] = id end
        end
        for name, i in pairs(byName) do
            search(name, i, function(id) return spellName(id) == name end)
        end
        for id, i in pairs(byId) do
            search(id, i, function(got) return byId[got] == i end)
        end
    end
    self.known = found
    return found
end

-- What the wheel holds with the options as they are, the wheel on or off
-- (Wheels › Professions lists it): { kind = "spell", id, cat, prof, byId }
-- (byId: cast by its ID, ConsumableWheel.lua's store)
function P:Find()
    local s, known, list = settings(), self:Known(), {}
    for i, kind in ipairs(P.KINDS) do
        if known[i] and (not kind.option or s[kind.option]) then
            list[#list + 1] = { kind = "spell", id = known[i], cat = kind.cat or "profession", prof = kind.key,
                byId = kind.ids ~= nil }
        end
    end
    return list
end

-- What the wheel shows (turned off: nothing, its key opens nothing)
function P:Scan()
    if settings().professionsEnabled == false then return {} end
    return self:Find()
end

-- For /ec wheel: what it holds, and the professions the game lists
function P:Diagnose(wheel)
    local s = settings()
    CK:Print(L.PROF_DIAG, wheel and wheel:GetAttribute("ck-t-total") or 0, tostring(s.professionsEnabled ~= false),
        tostring(s.professionsTracking))
    -- (the book read now, not as it was last kept)
    self:Invalidate()
    for _, e in ipairs(self:Find()) do
        DEFAULT_CHAT_FRAME:AddMessage(format("  |cff40ff40+|r %s (%d, %s%s)", CK.Mapping.SpellName(e.id) or "?", e.id,
            e.prof, e.byId and ", by ID" or ""))
    end
    local lines = {}
    local got = GetProfessions and { pcall(GetProfessions) } or {}
    if got[1] then
        for i = 2, table.maxn(got) do
            if got[i] then
                local ok, name, _, rank, _, numSpells, offset, line = pcall(GetProfessionInfo, got[i])
                if ok and name then
                    lines[#lines + 1] = format("%s %s (%s, %s+%s)", tostring(name), tostring(rank), tostring(line),
                        tostring(offset), tostring(numSpells))
                end
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  |cff9d9a8c" .. format(L.PROF_DIAG_LINES, #lines > 0 and table.concat(lines, ", ") or "-")
        .. "|r")
end
