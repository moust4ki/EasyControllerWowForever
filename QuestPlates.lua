local _, CK = ...

-- Quest mobs (asked: "like Polestar does"): beside the health bar of a
-- mob's nameplate, a skull and what is left to do when it counts for a
-- quest of the log: "3/10" (to kill, or an item it drops), "3/10 · 1/8"
-- for two. A single one (1 to kill or to loot): the skull alone. Done: none.
--
-- The game tells it itself: its tooltip data for the unit holds the
-- quest's title and objective lines ("Acidic Scorpid Venom: 3/6", line type
-- QuestObjective), the same it shows on hovering the mob (checked in game).
-- No quest database. Our own code, Polestar's look (GPL: nothing of it
-- copied). Nothing of the game's plates is changed: a frame of ours over
-- each one, kept in our own table.
--
-- Secret values: in combat the game may hand out the tooltip's text as
-- secret. The objectives a mob counts for are then the last ones read for
-- that kind of mob (its NPC ID, out of combat); the counts come from the
-- quest log, so they still move with each kill.
local QP = {}
CK.QuestPlates = QP

local LINE = Enum and Enum.TooltipDataLineType or {}
local QUEST_OBJECTIVE = LINE.QuestObjective or 8
local QUEST_TITLE = LINE.QuestTitle or 17
local QUEST_PLAYER = LINE.QuestPlayer or 18
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local SEP = " \194\183 "     -- "3/10 · 1/8"
local SIZE = 16              -- the skull
local GAP = 3                -- between the skull and the bar
local COUNT_GAP = 2          -- between the count and the skull
local LIFT = 5               -- frame levels over the plate's

local units = {}             -- unit token -> { npc, keys }
local frames = {}            -- unit token -> our frame on its plate
local pool = {}
local known = {}             -- npc ID -> the objective keys last read for it
local logCounts = {}         -- objective key -> { have, need }

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

function QP:On()
    local db = CK.db and CK.db.settings
    return db ~= nil and db.modules.questItems == true and db.features.questPlates ~= false
end

-- "Acidic Scorpid Venom: 3/6" -> "acidic scorpid venom", 3, 6. No-break
-- spaces (French "Venin : 3/6") as plain ones; explicit space classes: %s
-- also matches the 2nd byte of "à" in the game's Lua
local function parse(text)
    local t = text:gsub("\194\160", " "):gsub("\226\128\175", " ")
    local have, need = t:match("(%d+)[ \t]*/[ \t]*(%d+)")
    if not have then return nil end
    local key = t:gsub("%d+[ \t]*/[ \t]*%d+", ""):gsub("^[ \t:]+", ""):gsub("[ \t:]+$", "")
    -- (A to Z only: lower() takes the 1st byte of "à" for a capital)
    key = key:gsub("[A-Z]", string.lower)
    return key, tonumber(have), tonumber(need)
end
QP.Parse = parse

-- The NPC ID of a unit ("Creature-0-...-<npc>-<spawn>"), nil when hidden
local function npcOf(unit)
    local guid = UnitGUID and UnitGUID(unit)
    if type(guid) ~= "string" or secret(guid) then return nil end
    local kind, id = guid:match("^(%a+)%-.-%-.-%-.-%-.-%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- The objective lines of the unit's tooltip: { { key, have, need } }; {}
-- for none; nil when the game hides them (secret, in combat)
local function readTooltip(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or secret(data) then return nil end
    if type(data) ~= "table" or type(data.lines) ~= "table" then return {} end
    local list, others = {}, false
    for _, line in ipairs(data.lines) do
        if secret(line.type) then return nil end
        -- In a party, each member's name, then that member's objectives
        -- (theirs, not the player's): left out until the next quest's title
        if line.type == QUEST_TITLE then
            others = false
        elseif line.type == QUEST_PLAYER then
            others = true
        elseif line.type == QUEST_OBJECTIVE and not others then
            local text = line.leftText
            if secret(text) then return nil end
            local key, have, need
            if type(text) == "string" then key, have, need = parse(text) end
            if key then list[#list + 1] = { key = key, have = have, need = need } end
        end
    end
    return list
end

-- The quest log's objectives, by key: their counts now
function QP:ScanLog()
    wipe(logCounts)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetQuestObjectives) then return end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                local key, have, need
                if type(o.text) == "string" and not secret(o.text) then key, have, need = parse(o.text) end
                if key then
                    have = type(o.numFulfilled) == "number" and not secret(o.numFulfilled) and o.numFulfilled or have
                    need = type(o.numRequired) == "number" and not secret(o.numRequired) and o.numRequired or need
                    logCounts[key] = { have = have, need = need }
                end
            end
        end
    end
end

-- What the plate shows: nil (nothing), "" (the skull alone) or the counts
function QP:Text(keys)
    local open, counts = false, {}
    for _, o in ipairs(keys or {}) do
        local now = logCounts[o.key]
        local have, need = now and now.have or o.have, now and now.need or o.need
        if have < need then
            open = true
            if need > 1 then counts[#counts + 1] = have .. "/" .. need end
        end
    end
    if not open then return nil end
    return table.concat(counts, SEP)
end

---------------------------------------------------------------------------
-- Our frame on a plate
---------------------------------------------------------------------------
local function plateOf(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or type(plate) ~= "table" then return nil end
    if plate.IsForbidden and plate:IsForbidden() then return nil end
    return plate
end

-- The health bar the player sees (the game's plate)
local function barOf(plate)
    local uf = plate.UnitFrame
    if type(uf) ~= "table" then return nil, nil end
    local bars = uf.HealthBarsContainer
    local bar = type(bars) == "table" and bars.healthBar or uf.healthBar
    return uf, type(bar) == "table" and bar or nil
end

local function newFrame()
    local f = CreateFrame("Frame")
    f:SetSize(SIZE, SIZE)
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetAllPoints(f)
    f.icon:SetTexture(SKULL)
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.count:SetPoint("RIGHT", f, "LEFT", -COUNT_GAP, 0)
    return f
end

local function place(f, plate)
    local uf, bar = barOf(plate)
    f:SetParent(plate)
    f:ClearAllPoints()
    if bar then
        f:SetPoint("RIGHT", bar, "LEFT", -GAP, 0)
    else
        f:SetPoint("BOTTOM", plate, "TOP", 0, -2)
    end
    f:SetFrameLevel((uf or plate):GetFrameLevel() + LIFT)
end

local function release(unit)
    local f = frames[unit]
    if not f then return end
    frames[unit] = nil
    f:Hide()
    f:ClearAllPoints()
    f:SetParent(nil)
    pool[#pool + 1] = f
end

function QP:Update(unit)
    local u = units[unit]
    local text = u and self:On() and self:Text(u.keys)
    if not text then return release(unit) end
    local f = frames[unit]
    if not f then
        local plate = plateOf(unit)
        if not plate then return end
        f = table.remove(pool) or newFrame()
        if not pcall(place, f, plate) then
            pool[#pool + 1] = f
            return
        end
        frames[unit] = f
        -- (the game's own plate may be set up after us: placed again)
        C_Timer.After(0, function()
            local now = frames[unit] == f and plateOf(unit)
            if now then pcall(place, f, now) end
        end)
    end
    f.count:SetText(text)
    f:Show()
end

-- A plate's mob read again: its tooltip, else the last read for its kind
function QP:Read(unit)
    local u = units[unit]
    if not u then return end
    local list = readTooltip(unit)
    u.npc = u.npc or npcOf(unit)
    if list then
        u.keys = list
        if u.npc then known[u.npc] = list end
    elseif not u.keys and u.npc then
        u.keys = known[u.npc]
    end
    self:Update(unit)
end

function QP:Refresh()
    self:ScanLog()
    for unit in pairs(units) do self:Read(unit) end
end

-- QUEST_LOG_UPDATE comes in bursts: once a moment later
function QP:Soon()
    if self.pending then return end
    self.pending = true
    C_Timer.After(0.2, function()
        QP.pending = nil
        QP:Refresh()
    end)
end

-- Our frame on a unit's plate (tests, debugging)
function QP:FrameFor(unit) return frames[unit] end

-- On screen (tests, debugging): unit -> the text beside its skull
function QP:Shown()
    local out = {}
    for unit, f in pairs(frames) do
        if f:IsShown() then out[unit] = f.count:GetText() or "" end
    end
    return out
end

function QP:Init()
    local f = CreateFrame("Frame")
    self.events = f
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            if type(unit) ~= "string" or secret(unit) then return end
            units[unit] = {}
            if QP:On() then QP:Read(unit) end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if type(unit) ~= "string" or secret(unit) then return end
            units[unit] = nil
            release(unit)
        elseif QP:On() then
            -- A kill, a loot, a quest taken or turned in; out of combat:
            -- the tooltips readable again
            QP:Soon()
        end
    end)
    self:ScanLog()
end

-- The option turned on or off
function QP:Apply()
    if self:On() then
        self:Refresh()
    else
        for unit in pairs(frames) do release(unit) end
    end
end
