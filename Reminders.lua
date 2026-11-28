local _, CK = ...
local L = CK.L

-- Reminders (asked; two options, off by default): a message at the top of
-- the screen, a sound and a vibration when something is forgotten:
--   - tracking: Find Minerals or Find Herbs known (Mining, Herbalism) and no
--     tracking spell on (another one on, Find Treasure, Track Beasts...: the
--     player's choice, nothing said);
--   - poisons (rogues): poisons in the bags and a weapon without one.
-- Not while dead, in combat, on a flight or resting (a city, an inn): said
-- once that is over (leaving the city: the moment to think of it). Again
-- every REPEAT seconds while still forgotten; in the chat the first time.
local R = {}
CK.Reminders = R

-- The professions' tracking spells: Find Minerals, Find Herbs
R.TRACKING = { [2580] = true, [2383] = true }
local REPEAT = 120
local TICK = 5
local GOLD = { 1, 0.82, 0 }

local function settings() return CK.db.settings.reminders end

-- A text the game gives, when it is one (not secret)
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- The gathering trackings known and none on: their names ("Find Minerals")
function R.MissingTracking()
    local C = C_Minimap
    if not (C and C.GetNumTrackingTypes and C.GetTrackingInfo) then return nil end
    local ok, n = pcall(C.GetNumTrackingTypes)
    if not ok or type(plain(n)) ~= "number" then return nil end
    local names = {}
    for i = 1, n do
        local got, info = pcall(C.GetTrackingInfo, i)
        info = got and type(info) == "table" and info or nil
        local spell = info and plain(info.spellID)
        if spell then
            -- Any tracking spell on: the player chose
            if plain(info.active) == true then return nil end
            if R.TRACKING[spell] then names[#names + 1] = plain(info.name) or tostring(spell) end
        end
    end
    if #names == 0 then return nil end
    return format(L.REMIND_TRACKING, table.concat(names, " / "))
end

-- A rogue's poisons carried and a weapon without any: its hands' names
function R.MissingPoisons()
    local P = CK.Poisons
    local _, class = UnitClass("player")
    if class ~= "ROGUE" or not P then return nil end
    local carried = false
    for _, id in ipairs(P.IDS) do
        local n = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0
        if (plain(n) or 0) > 0 then
            carried = true
            break
        end
    end
    if not carried or not GetWeaponEnchantInfo then return nil end
    local ok, hasMain, _, _, _, hasOff = pcall(GetWeaponEnchantInfo)
    if not ok then return nil end
    local hands = {}
    if P.WeaponIn(P.MAIN) and plain(hasMain) ~= true then hands[#hands + 1] = L.POISON_RIGHT end
    if P.WeaponIn(P.OFF) and plain(hasOff) ~= true then hands[#hands + 1] = L.POISON_LEFT end
    if #hands == 0 then return nil end
    return format(L.REMIND_POISONS, table.concat(hands, ", "))
end

-- Nothing said now (said once it is over)
local function busy()
    if InCombatLockdown() then return true end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return true end
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    return IsResting and IsResting() or false
end

local KINDS = {
    { key = "tracking", missing = R.MissingTracking },
    { key = "poisons", missing = R.MissingPoisons },
}

function R:Alert(text, first)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, GOLD[1], GOLD[2], GOLD[3], 1) end
    if first then CK:Print(text) end
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
    if CK.Vibration and CK.Vibration.Fire then CK.Vibration:Fire("reminder") end
end

function R:Check()
    if not CK.db then return end
    local s = settings()
    self.said = self.said or {}
    -- Both off: nothing looked at
    if s.tracking ~= true and s.poisons ~= true then
        self.said = {}
        return
    end
    local now = GetTime()
    local quiet = busy()
    for _, kind in ipairs(KINDS) do
        local text = s[kind.key] == true and kind.missing()
        if not text then
            -- Fine again: the next time is a new forgetting
            self.said[kind.key] = nil
        elseif not quiet then
            local last = self.said[kind.key]
            if not last or now - last >= REPEAT then
                self.said[kind.key] = now
                self:Alert(text, last == nil)
            end
        end
    end
end

function R:Init()
    if self.ticker then return end
    self.ticker = C_Timer.NewTicker(TICK, function() R:Check() end)
end
