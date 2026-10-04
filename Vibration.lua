local _, CK = ...

-- Module "vibrations": the controller rumbles on the game events the player
-- picks. Each event can be turned on or off, with a pattern of its own, and
-- one intensity for all. Only the two standard motors are used (no trigger
-- motors): every controller the game drives feels them.
--
-- No event on the player's health: WoW Forever hides it from addons in
-- combat (a secret value), so low health and big hit could not work. No
-- critical hit either: the combat log is the Blizzard UI's only (an addon
-- registering it, or even unregistering it, is blocked and the game shows
-- its "blocked" popup, in front of the others: invitations...).
local V = {}
CK.Vibration = V

-- Patterns: steps of { low motor, high motor, seconds }; 0, 0 is a pause
V.PATTERNS = {
    { key = "micro", steps = { { 0, 0.35, 0.04 } } },
    { key = "tick", steps = { { 0, 0.7, 0.07 } } },
    { key = "double", steps = { { 0, 0.7, 0.07 }, { 0, 0, 0.09 }, { 0, 0.7, 0.07 } } },
    { key = "pulse", steps = { { 0.8, 0.5, 0.18 } } },
    { key = "long", steps = { { 0.8, 0.4, 0.6 } } },
    { key = "heart", steps = { { 0.9, 0, 0.09 }, { 0, 0, 0.12 }, { 0.6, 0, 0.09 } } },
    { key = "rise", steps = { { 0.3, 0.2, 0.12 }, { 0.6, 0.4, 0.12 }, { 1, 0.6, 0.18 } } },
}
local PATTERN = {}
for i, p in ipairs(V.PATTERNS) do
    p.index = i
    PATTERN[p.key] = p
end

-- The events, by group, with their default state and pattern. "needs": shown
-- once that module of ours exists.
V.GROUPS = { "combat", "social", "progress", "addon" }
V.EVENTS = {
    { key = "death", group = "combat", on = true, pattern = "long" },
    { key = "interrupted", group = "combat", on = true, pattern = "double" },
    { key = "lossOfControl", group = "combat", on = true, pattern = "pulse" },
    { key = "aggro", group = "combat", on = false, pattern = "tick" },
    { key = "aggroLost", group = "combat", on = false, pattern = "double" },
    { key = "combat", group = "combat", on = false, pattern = "tick" },
    { key = "proc", group = "combat", on = false, pattern = "tick" },
    { key = "actionFailed", group = "combat", on = false, pattern = "micro" },
    { key = "whisper", group = "social", on = true, pattern = "double" },
    { key = "invite", group = "social", on = true, pattern = "pulse" },
    { key = "readyCheck", group = "social", on = true, pattern = "pulse" },
    { key = "rezSummon", group = "social", on = true, pattern = "pulse" },
    { key = "tradeDuel", group = "social", on = false, pattern = "tick" },
    { key = "levelUp", group = "progress", on = true, pattern = "rise" },
    { key = "quest", group = "progress", on = true, pattern = "tick" },
    { key = "rareLoot", group = "progress", on = false, pattern = "tick" },
    { key = "bagsFull", group = "progress", on = true, pattern = "double" },
    { key = "durability", group = "progress", on = false, pattern = "tick" },
    { key = "lowStock", group = "addon", on = true, pattern = "pulse", needs = "Supplies" },
    { key = "lowSpace", group = "addon", on = true, pattern = "pulse", needs = "Supplies" },
    { key = "wheelTick", group = "addon", on = true, pattern = "micro", needs = "ConsumableWheel" },
    { key = "keyPress", group = "addon", on = false, pattern = "micro" },
}
local EVENT = {}
for _, e in ipairs(V.EVENTS) do EVENT[e.key] = e end

-- settings.vibration = { enabled, intensity, events = { key = { on, pattern } } }
function V:Settings()
    local s = CK.db.settings.vibration
    -- Events no longer offered (low health, big hit before 1.3.0)
    for key in pairs(s.events) do
        if not EVENT[key] then s.events[key] = nil end
    end
    for _, e in ipairs(V.EVENTS) do
        local cfg = s.events[e.key]
        if type(cfg) ~= "table" then
            cfg = { on = e.on, pattern = e.pattern }
            s.events[e.key] = cfg
        end
        if not PATTERN[cfg.pattern] then cfg.pattern = e.pattern end
    end
    return s
end

-- The events of a group the Vibrations tab lists
function V:GroupEvents(group)
    local list = {}
    for _, e in ipairs(V.EVENTS) do
        if e.group == group and (not e.needs or CK[e.needs]) then list[#list + 1] = e end
    end
    return list
end

function V:NextPattern(key, delta)
    local p = PATTERN[key] or V.PATTERNS[1]
    return V.PATTERNS[(p.index - 1 + delta) % #V.PATTERNS + 1].key
end

---------------------------------------------------------------------------
-- Playing a pattern
---------------------------------------------------------------------------
local timers = {}
local playingPriority

local function motors(low, high)
    C_GamePad.SetVibration("Low", low)
    C_GamePad.SetVibration("High", high)
end

local function later(delay, fn)
    if delay <= 0 then
        fn()
    else
        timers[#timers + 1] = C_Timer.NewTimer(delay, fn)
    end
end

function V:Stop()
    for _, t in ipairs(timers) do t:Cancel() end
    wipe(timers)
    playingPriority = nil
    if C_GamePad and C_GamePad.StopVibration then C_GamePad.StopVibration() end
end

-- Events replace an equal or lower-priority pattern; weaker events are
-- dropped, never queued. A direct call (settings preview or /ec vibe)
-- always replaces playback and lets the player hear the whole pattern.
function V:Play(key, strength, priority)
    if not (C_GamePad and C_GamePad.SetVibration and CK.db) then return end
    if priority and playingPriority and priority < playingPriority then return end
    local pattern = PATTERN[key] or PATTERN.tick
    local gain = math.max(0, math.min(1, self:Settings().intensity * (strength or 1)))
    self:Stop()
    playingPriority = priority or math.huge
    local t = 0
    for _, step in ipairs(pattern.steps) do
        local low, high, length = step[1] * gain, step[2] * gain, step[3]
        -- Sent again every 0.1 s: holds on a client that lets it fade
        local at = 0
        repeat
            later(t + at, function() motors(low, high) end)
            at = at + 0.1
        until at >= length
        t = t + length
    end
    later(t, function()
        wipe(timers)
        playingPriority = nil
        C_GamePad.StopVibration()
    end)
end

-- An event happened: its pattern, if it is on (the same event at most every
-- 0.4 s; aggro lost every 3 s, a mob going back and forth doesn't buzz)
local last = {}
local GAPS = { aggroLost = 3 }
-- Death, urgent warnings, ordinary notifications, then UI feedback.
local PRIORITY = {
    death = 3,
    interrupted = 2, lossOfControl = 2, aggro = 2, aggroLost = 2,
    readyCheck = 2, rezSummon = 2,
    wheelTick = 0, keyPress = 0,
}
function V:Fire(key, strength)
    if not CK.db then return end
    local s = self:Settings()
    local cfg = s.events[key]
    if not (s.enabled and cfg and cfg.on) then return end
    local now = GetTime()
    local gap = (key == "wheelTick" or key == "keyPress") and 0.03 or GAPS[key] or 0.4
    if last[key] and now - last[key] < gap then return end
    last[key] = now
    self:Play(cfg.pattern, strength, PRIORITY[key] or 1)
end

-- Combat values WoW Forever hides from addons
local function secret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

---------------------------------------------------------------------------
-- Game messages
---------------------------------------------------------------------------
-- "You receive loot: %s." -> a pattern that finds the link
local function lootPattern(text)
    if type(text) ~= "string" then return nil end
    -- "%1$s" (some languages) is "%s"
    text = text:gsub("%%%d%$([sd])", "%%%1")
    text = text:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    text = text:gsub("%%s", "(.+)")
    text = text:gsub("%%d", "%%d+")
    return "^" .. text .. "$"
end

-- Built on first use, from the game's own messages
local selfLoot
local function selfLootPatterns()
    if not selfLoot then
        selfLoot = {}
        for _, name in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
            "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
            selfLoot[#selfLoot + 1] = lootPattern(_G[name])
        end
    end
    return selfLoot
end

local function selfLootQuality(text)
    if type(text) ~= "string" or secret(text) then return nil end
    for _, pattern in ipairs(selfLootPatterns()) do
        local link = text:match(pattern)
        if link then
            local item = link:match("|H(item:[^|]+)|h")
            local get = C_Item and C_Item.GetItemInfo or GetItemInfo
            return item and get and select(3, get(item))
        end
    end
end

local questDone
local function questProgress(message)
    if type(message) ~= "string" or secret(message) then return false end
    questDone = questDone or lootPattern(ERR_QUEST_COMPLETE_S) or false
    if questDone and message:match(questDone) then return true end
    -- "Gnoll Paw: 8/8": an objective done
    local have, need = message:match("(%d+)%s*/%s*(%d+)")
    return have ~= nil and have == need and tonumber(need) > 0
end

local function durabilityLow()
    if not GetInventoryItemDurability then return false end
    for slot = 1, 19 do
        local current, max = GetInventoryItemDurability(slot)
        if current and max and max > 0 and current / max <= 0.2 then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local HANDLERS = {
    PLAYER_DEAD = function() V:Fire("death") end,
    UNIT_SPELLCAST_INTERRUPTED = function(unit, _, _, interruptedBy)
        -- Interrupted by someone (moving also cancels a cast: no interrupter)
        if unit == "player" and (secret(interruptedBy) or (interruptedBy ~= nil and interruptedBy ~= "")) then
            V:Fire("interrupted")
        end
    end,
    LOSS_OF_CONTROL_ADDED = function(unit)
        if unit == nil or unit == "player" then V:Fire("lossOfControl") end
    end,
    UNIT_THREAT_SITUATION_UPDATE = function(unit)
        if unit ~= "player" then return end
        local status = UnitThreatSituation("player")
        if secret(status) then return end
        if status and status >= 2 and (V.threat or 0) < 2 then V:Fire("aggro") end
        -- Tanking, then not, still in combat and the target alive: a mob
        -- went for someone else (leaving combat or a kill doesn't count)
        if (V.threat or 0) >= 2 and (status or 0) < 2 and UnitAffectingCombat("player")
            and not (UnitExists("target") and UnitIsDead("target")) then
            V:Fire("aggroLost")
        end
        V.threat = status
    end,
    PLAYER_REGEN_DISABLED = function() V:Fire("combat") end,
    SPELL_ACTIVATION_OVERLAY_SHOW = function() V:Fire("proc") end,
    UI_ERROR_MESSAGE = function(_, message)
        if message == ERR_INV_FULL or message == ERR_BAG_FULL then
            V:Fire("bagsFull")
        else
            V:Fire("actionFailed")
        end
    end,
    CHAT_MSG_WHISPER = function() V:Fire("whisper") end,
    CHAT_MSG_BN_WHISPER = function() V:Fire("whisper") end,
    PARTY_INVITE_REQUEST = function() V:Fire("invite") end,
    READY_CHECK = function(initiator)
        if initiator ~= UnitName("player") then V:Fire("readyCheck") end
    end,
    RESURRECT_REQUEST = function() V:Fire("rezSummon") end,
    CONFIRM_SUMMON = function() V:Fire("rezSummon") end,
    TRADE_REQUEST = function() V:Fire("tradeDuel") end,
    DUEL_REQUESTED = function() V:Fire("tradeDuel") end,
    PLAYER_LEVEL_UP = function() V:Fire("levelUp") end,
    UI_INFO_MESSAGE = function(_, message)
        if questProgress(message) then V:Fire("quest") end
    end,
    CHAT_MSG_LOOT = function(text)
        local quality = selfLootQuality(text)
        if quality and quality >= 3 then V:Fire("rareLoot") end
    end,
    UPDATE_INVENTORY_DURABILITY = function()
        local low = durabilityLow()
        if low and not V.durabilityWasLow then V:Fire("durability") end
        V.durabilityWasLow = low
    end,
}

-- /ec fish: the game's events for a minute, in the chat, to find which one
-- comes when a fish bites (the game has no "bite" event we know of): the
-- chattiest ones left out, the same one in a row shown once
local TRACE_TIME = 60
-- The ones that may come with a bite: the Fishing channel, the bobber as the
-- soft interact target, the loot; never every event (the combat log, the
-- Blizzard UI's only, would be blocked)
local TRACED = {
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP", "PLAYER_SOFT_INTERACT_CHANGED",
    "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_SOFT_FRIEND_CHANGED", "PLAYER_TARGET_CHANGED", "CURSOR_CHANGED",
    "UPDATE_MOUSEOVER_UNIT", "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE",
    "CHAT_MSG_SYSTEM", "SOUNDKIT_FINISHED",
}
function V:TraceFishing()
    local f = self.traceFrame
    if not f then
        f = CreateFrame("Frame")
        f:SetScript("OnEvent", function(_, event, ...)
            if event == f.lastEvent then return end
            f.lastEvent = event
            local args = {}
            for i = 1, math.min(select("#", ...), 4) do
                local v = select(i, ...)
                args[i] = secret(v) and "?" or tostring(v)
            end
            CK:Print("+%.1f s  %s  %s", GetTime() - f.start, event, table.concat(args, ", "))
        end)
        self.traceFrame = f
    end
    f.start, f.lastEvent = GetTime(), nil
    for _, event in ipairs(TRACED) do pcall(f.RegisterEvent, f, event) end
    CK:Print(CK.L.FISH_TRACE_START, TRACE_TIME)
    local token = {}
    f.token = token
    C_Timer.After(TRACE_TIME, function()
        if f.token ~= token then return end
        f:UnregisterAllEvents()
        CK:Print(CK.L.FISH_TRACE_END)
    end)
end

-- /ec vibe [pattern]: what this client allows, then a pattern
function V:Diagnose(key)
    local L = CK.L
    local api = (C_GamePad and C_GamePad.SetVibration ~= nil) or false
    local device = C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
    CK:Print(L.VIB_DIAG, tostring(api), tostring(device), tostring(self:Settings().enabled))
    local names = {}
    for _, p in ipairs(V.PATTERNS) do names[#names + 1] = p.key end
    key = key and key ~= "" and key or "pulse"
    if not PATTERN[key] then
        CK:Print(L.VIB_DIAG_PATTERNS, table.concat(names, ", "))
        return
    end
    self:Play(key)
end

function V:Init()
    self:Settings()
    local f = CreateFrame("Frame")
    for event in pairs(HANDLERS) do pcall(f.RegisterEvent, f, event) end
    f:SetScript("OnEvent", function(_, event, ...) HANDLERS[event](...) end)
    -- The chat keyboard: a key typed
    for _, name in ipairs({ "TypeChar", "Space", "Backspace" }) do
        hooksecurefunc(CK, name, function() V:Fire("keyPress") end)
    end
    self.durabilityWasLow = durabilityLow()
end
