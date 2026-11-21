local _, CK = ...

-- Quiet errors (asked; an option, off by default): the game's red messages
-- at the top of the screen and their voice, at each press of a key that
-- can't act ("Not enough energy", "Ability is not ready yet", "Out of
-- range"...), neither shown nor heard. Kept: the ones that say something to
-- do (bags full, quest log full, pet dead, not enough money, the auction
-- house, the mail, a trade, loot, pick pocketing). The yellow ones (quest
-- progress) are not touched.
--
-- The game's frame for them (UIErrorsFrame) shows the message and plays its
-- voice in one go, on the UI_ERROR_MESSAGE event: that event taken from it
-- while the option is on, the ones kept handed back to it as they came.
local QE = {}
CK.QuietErrors = QE

-- Kept: by the game's name for the message (GetGameMessageInfo)
local KEEP = {
    ERR_INV_FULL = true, ERR_BAG_FULL = true, ERR_ITEM_MAX_COUNT = true, ERR_QUEST_LOG_FULL = true,
    ERR_PET_SPELL_DEAD = true, ERR_NOT_ENOUGH_MONEY = true, ERR_RAID_GROUP_ONLY = true,
    ERR_ALREADY_PICKPOCKETED = true,
}
local KEEP_PREFIX = { "ERR_AUCTION_", "ERR_MAIL_", "ERR_TRADE_", "ERR_LOOT_" }
-- Kept: by their text (a spell's failure comes under a type shared by all)
local KEEP_TEXT = { "SPELL_FAILED_TARGET_NO_POCKETS", "ERR_ALREADY_PICKPOCKETED" }

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

function QE:On()
    local db = CK.db and CK.db.settings
    return db ~= nil and db.features.quietErrors == true
end

-- Whether a red message is kept (shown, its voice heard)
function QE.Keep(messageType, message)
    -- Hidden values: nothing to tell, the game's as it came
    if secret(messageType) or secret(message) then return true end
    if type(messageType) == "number" and GetGameMessageInfo then
        local ok, name = pcall(GetGameMessageInfo, messageType)
        if ok and type(name) == "string" and not secret(name) then
            if KEEP[name] then return true end
            for _, prefix in ipairs(KEEP_PREFIX) do
                if name:sub(1, #prefix) == prefix then return true end
            end
        end
    end
    if type(message) == "string" then
        for _, key in ipairs(KEEP_TEXT) do
            local text = _G[key]
            if type(text) == "string" and text == message then return true end
        end
    end
    return false
end

-- The option on or off: the event taken from the game's frame, or given back
function QE:Apply()
    local frame = UIErrorsFrame
    if not (self.events and frame and frame.UnregisterEvent) then return end
    local on = self:On()
    if on == (self.taken or false) then return end
    if on then
        if not pcall(frame.UnregisterEvent, frame, "UI_ERROR_MESSAGE") then return end
        self.events:RegisterEvent("UI_ERROR_MESSAGE")
    else
        self.events:UnregisterEvent("UI_ERROR_MESSAGE")
        pcall(frame.RegisterEvent, frame, "UI_ERROR_MESSAGE")
    end
    self.taken = on
end

function QE:Init()
    local f = CreateFrame("Frame")
    self.events = f
    f:SetScript("OnEvent", function(_, event, ...)
        if event ~= "UI_ERROR_MESSAGE" or not QE.Keep(...) then return end
        local frame = UIErrorsFrame
        local handler = frame and frame:GetScript("OnEvent")
        if handler then handler(frame, event, ...) end
    end)
    self:Apply()
end
