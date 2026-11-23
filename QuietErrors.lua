local _, CK = ...

-- Quiet errors (asked; two options, off by default): at each press of a key
-- that can't act ("Not enough energy", "Ability is not ready yet", "Out of
-- range"...), the game's red message at the top of the screen hidden, its
-- voice silenced, or both (asked: "the text and the voice apart"). Kept
-- whole: the ones that say something to do (bags full, quest log full, pet
-- dead, not enough money, the auction house, the mail, a trade, loot, pick
-- pocketing). The yellow ones (quest progress) are not touched.
--
-- The game's frame for them (UIErrorsFrame) shows the message and plays its
-- voice in one go, on the UI_ERROR_MESSAGE event: that event taken from it
-- while an option is on. A message kept, or with both its text and voice
-- wanted: handed back to it as it came. Its text alone: shown as the game
-- shows it (its own rules: a message shown again flashes), no voice. Its
-- voice alone: played as the game plays it (the message's voice, else its
-- sound), once while the same message would still be on screen.
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
-- The game's message on screen: 2 s, then 0.5 s fading (UIErrorsFrame.xml)
local VOICE_AGAIN = 2.5

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

local function features()
    local db = CK.db and CK.db.settings
    return db and db.features
end

-- The red text hidden / the voice silenced
function QE:HideText()
    local f = features()
    return f ~= nil and f.hideErrorText == true
end

function QE:MuteVoice()
    local f = features()
    return f ~= nil and f.muteErrorVoice == true
end

function QE:On() return self:HideText() or self:MuteVoice() end

-- The game's name for a message ("ERR_OUT_OF_ENERGY"), its sound, its voice
local function info(messageType)
    if type(messageType) ~= "number" or not GetGameMessageInfo then return nil end
    local ok, name, sound, voice = pcall(GetGameMessageInfo, messageType)
    if not ok or secret(name) then return nil end
    return type(name) == "string" and name or nil, sound, voice
end

-- Whether a red message is kept (shown, its voice heard)
function QE.Keep(messageType, message)
    -- Hidden values: nothing to tell, the game's as it came
    if secret(messageType) or secret(message) then return true end
    local name = info(messageType)
    if name then
        if KEEP[name] then return true end
        for _, prefix in ipairs(KEEP_PREFIX) do
            if name:sub(1, #prefix) == prefix then return true end
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

-- Its text only, as the game shows it (not a message the game leaves out,
-- one shown again flashing instead)
local function showText(frame, messageType, message)
    if frame.GetMessagesSuppressed and frame:GetMessagesSuppressed() then return end
    if frame.ShouldDisplayMessageType and not frame:ShouldDisplayMessageType(messageType, message) then return end
    local r, g, b = 1, 0.1, 0.1
    if RED_FONT_COLOR and RED_FONT_COLOR.GetRGB then r, g, b = RED_FONT_COLOR:GetRGB() end
    frame:AddMessage(message, r, g, b, 1.0, messageType)
end

-- Its voice only, as the game plays it (not for a message the game leaves
-- out); the same message again while it would still be on screen: silent
local lastVoice = {}
local function playVoice(messageType)
    local left = BLACK_LISTED_MESSAGE_TYPES
    if type(left) == "table" and left[messageType] then return end
    local now = GetTime()
    if lastVoice[messageType] and now - lastVoice[messageType] < VOICE_AGAIN then return end
    lastVoice[messageType] = now
    local _, sound, voice = info(messageType)
    if voice and C_Sound and C_Sound.PlayVocalErrorSound then
        pcall(C_Sound.PlayVocalErrorSound, voice)
    elseif sound and PlaySound then
        pcall(PlaySound, sound)
    end
end

function QE:OnError(messageType, message)
    local frame = UIErrorsFrame
    if not frame then return end
    local text, voice = not self:HideText(), not self:MuteVoice()
    if (text and voice) or QE.Keep(messageType, message) then
        local handler = frame:GetScript("OnEvent")
        if handler then handler(frame, "UI_ERROR_MESSAGE", messageType, message) end
        return
    end
    if text then showText(frame, messageType, message) end
    if voice then playVoice(messageType) end
end

-- The options on or off: the event taken from the game's frame, or given back
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
    -- 1.24.0's single option (text and voice together): both
    local f = features()
    if f and f.quietErrors ~= nil then
        if f.quietErrors == true then f.hideErrorText, f.muteErrorVoice = true, true end
        f.quietErrors = nil
    end
    local frame = CreateFrame("Frame")
    self.events = frame
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "UI_ERROR_MESSAGE" then QE:OnError(...) end
    end)
    self:Apply()
end
