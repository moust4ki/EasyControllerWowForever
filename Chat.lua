local ADDON, CK = ...
local L = CK.L

---------------------------------------------------------------------------
-- Chat integration
--
-- The ChatEdit_* globals are only deprecated aliases (loaded with the
-- loadDeprecationFallbacks CVar): the game itself calls ChatFrameUtil.
---------------------------------------------------------------------------
function CK.ActiveChatWindow()
    local get = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
    return get and get()
end

local function openChat(text)
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    open(text)
end

function CK:IsGamepadActive()
    if self.gamepadActive ~= nil then return self.gamepadActive end
    return C_GamePad ~= nil and C_GamePad.GetActiveDeviceID ~= nil
        and C_GamePad.GetActiveDeviceID() ~= nil
        and GetCVar("GamePadEnable") == "1"
end

function CK:WantsKeyboard(forced)
    local s = self.db.settings
    if not s.modules.keyboard then return false end
    return forced or (s.autoOpen and (not s.onlyWithGamepad or self:IsGamepadActive())) or false
end

-- With the "IM" chat style the edit box stays visible and is "activated"
-- without being typed in: only open when it really has the keyboard focus.
function CK:OnChatActivated(eb)
    local forced = self.forceOpen
    C_Timer.After(0, function()
        if not eb:HasFocus() then return end
        if CK:IsOpen() and CK.editBox == eb then return end
        if not CK:WantsKeyboard(forced) then return end
        if CK:BlockedByCombat() then return end
        CK:Open(eb)
    end)
end

function CK:OnChatDeactivated(eb)
    if eb ~= self.editBox then return end
    -- The game closes the chat on mouse clicks: keep typing in the wheel
    if self:IsClickingWheel() then
        self:EnterStandalone()
    else
        self:Close("chat deactivated")
    end
end

function CK:HookChat()
    -- Learn slash commands: remember the last text typed in each edit box
    -- (a command is already run and cleared when the text is sent)
    local lastTyped = {}
    local function onSend(eb)
        local text = lastTyped[eb]
        lastTyped[eb] = nil
        -- Sent with Enter on a physical keyboard: the keyboard's copy is sent too
        local boxText = eb.GetText and eb:GetText()
        if eb == CK.editBox and CK:IsOpen() and boxText and boxText:find("[^ \t\r\n]") then
            CK:SetText("")
        end
        if text and text:sub(1, 1) == "/" then CK.Predict:LearnCommand(text) end
    end
    -- The edit box's SendText announces itself (listening taints nothing)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", function(_, eb) onSend(eb) end, CK)
    elseif ChatEdit_SendText then
        hooksecurefunc("ChatEdit_SendText", onSend)
    end

    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb:HookScript("OnTextChanged", function(box, userInput)
                local text = box:GetText()
                if text and text ~= "" then lastTyped[box] = text end
                CK:OnChatTextChanged(box, userInput)
            end)
            eb:HookScript("OnEditFocusGained", function(box) CK:OnChatActivated(box) end)
            eb:HookScript("OnEditFocusLost", function(box)
                lastTyped[box] = nil
                CK:OnChatDeactivated(box)
            end)
            eb:HookScript("OnHide", function(box) CK:OnChatDeactivated(box) end)
        end
    end

    -- Learn from every message the player sends (keyboard or controller)
    local function learn(msg)
        CK.justSent = true
        CK.Predict:LearnMessage(msg)
    end
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        hooksecurefunc(C_ChatInfo, "SendChatMessage", learn)
    elseif SendChatMessage then
        hooksecurefunc("SendChatMessage", learn)
    end
end

-- Key binding / slash command: open the chat with the keyboard, or close it
function ControllerKeyboard_Toggle()
    if not CK.db.settings.modules.keyboard then
        CK:Print(CK.L.KEYBOARD_OFF)
        return
    end
    if CK:IsOpen() then
        CK:Close("toggle")
        return
    end
    -- Opening the chat from addon code in combat taints the gamepad UI
    if CK:BlockedByCombat() then return end
    CK.forceOpen = true
    local active = CK.ActiveChatWindow()
    if active and active:HasFocus() then
        CK:Open(active)
    else
        openChat("")
    end
    CK.forceOpen = false
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function onOff(v) return v and L.ON or L.OFF end

local function slash(msg)
    local s = CK.db.settings
    local cmd, arg = (msg or ""):lower():match("^[ \t\r\n]*([^ \t\r\n]*)[ \t\r\n]*(.-)[ \t\r\n]*$")

    if cmd == "" then
        if not s.modules.keyboard then
            CK:Print(L.KEYBOARD_OFF)
            return
        end
        -- The chat edit box is still sending this command: open once it is closed
        C_Timer.After(0, function()
            if CK:IsOpen() or CK:BlockedByCombat() then return end
            CK.forceOpen = true
            local active = CK.ActiveChatWindow()
            if active and active:HasFocus() then
                CK:Open(active)
            else
                openChat("")
            end
            CK.forceOpen = false
        end)
    elseif cmd == "auto" then
        s.autoOpen = not s.autoOpen
        CK:Print("auto: %s", onOff(s.autoOpen))
    elseif cmd == "pad" then
        s.onlyWithGamepad = not s.onlyWithGamepad
        CK:Print("pad: %s", onOff(s.onlyWithGamepad))
    elseif cmd == "learn" then
        s.learn = not s.learn
        CK:Print("learn: %s", onOff(s.learn))
    elseif cmd == "lang" then
        local key = arg == "both" and "fren" or arg
        for _, lang in ipairs(CK.LANGUAGES) do
            if lang.key == key then CK:SetLanguage(key) end
        end
        CK:Print(L.LANG_SET, CK:GetLanguage().name)
    elseif cmd == "scale" then
        local v = tonumber(arg)
        if v and v >= 0.4 and v <= 2 then
            s.scale = v
            if CK.frame then
                CK.frame:SetScale(v)
                CK:PositionSendButton()
            end
        end
        CK:Print("scale: %.2f", s.scale)
    elseif cmd == "invert" then
        s.invertY = not s.invertY
        CK:Print("invert: %s", onOff(s.invertY))
    elseif cmd == "mode" then
        local key = ({ wheel = "wheel", roue = "wheel", stick = "stick", clavier = "stick" })[arg]
        if key then CK:SetInputMethod(key) end
        local m = CK.db.settings.inputMethod
        CK:Print(L.MODE_SET, m == "stick" and L.METHOD_STICK or L.METHOD_WHEEL)
    elseif cmd == "layout" then
        local key = ({ azerty = "azerty", qwerty = "qwerty", qwertz = "qwertz",
            es = "qwerty_es", it = "qwerty_it" })[arg]
        if key then
            s.kbLayout = key
            CK:UpdateMethod()
        end
        CK:Print(L.LAYOUT_SET, s.kbLayout)
    elseif cmd == "lock" then
        s.locked = not s.locked
        CK:UpdateLock()
        CK:Print(L.LOCKED, onOff(s.locked))
        if not s.locked then
            -- Show the keyboard to place it, once the chat that sent this is closed
            C_Timer.After(0, function() CK:OpenStandalone() end)
        end
    elseif cmd == "reset" then
        CK.db.pos = nil
        s.scale = 1
        if CK.frame then CK:RestorePosition() end
    elseif cmd == "stats" then
        CK:Print(L.STATS, CK.Predict:NumLearned(), CK.Predict:NumEntries())
    elseif cmd == "forget" then
        if arg == "confirm" then
            CK.Predict:Forget()
            CK:Print(L.FORGOT)
        else
            CK:Print(L.FORGET_CONFIRM)
        end
    elseif cmd == "map" or cmd == "config" or cmd == "options" then
        -- The chat edit box is still sending this command: open once it is closed
        CK.Config:OpenWhenFree(cmd == "map" and "gamepad" or nil)
    elseif cmd == "keys" then
        CK:DetectKeys()
    elseif cmd == "glyphs" then
        CK:ListGlyphAtlases()
    elseif cmd == "vibe" then
        CK.Vibration:Diagnose(arg)
    elseif cmd == "wheel" then
        CK.ConsumableWheel:Diagnose()
    elseif cmd == "fish" then
        CK.Vibration:TraceFishing()
    elseif cmd == "binds" then
        CK.Mapping:Diagnose()
    elseif cmd == "debug" then
        s.debug = not s.debug
        CK.seenSticks = nil
        CK:Print("debug: %s", onOff(s.debug))
    else
        -- Lines with %s show, in order, the current value of these settings
        local values = { s.autoOpen, s.onlyWithGamepad, s.learn, s.locked }
        local v = 0
        for _, line in ipairs(L.HELP) do
            if line:find("%s", 1, true) then
                v = v + 1
                line = format(line, onOff(values[v]))
            end
            DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
        end
    end
end

SLASH_CONTROLLERKEYBOARD1 = "/ec"
SLASH_CONTROLLERKEYBOARD2 = "/easycontroller"
-- The names it had before 1.1
SLASH_CONTROLLERKEYBOARD3 = "/ck"
SLASH_CONTROLLERKEYBOARD4 = "/controllerkeyboard"
SlashCmdList.CONTROLLERKEYBOARD = slash

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
pcall(events.RegisterEvent, events, "GAME_PAD_ACTIVE_CHANGED")

events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        CK:InitDB()
    elseif event == "PLAYER_LOGIN" then
        local function safe(fn) xpcall(fn, geterrorhandler()) end
        -- This character's profile first: the modules read its settings
        safe(function() CK.Profiles:Init() end)
        safe(function() CK.Predict:Load() end)
        safe(function() CK:HookChat() end)
        safe(function() CK:HookLinks() end)
        safe(function() CK.QuestItems:Init() end)
        safe(function() CK.Mapping:Init() end)
        safe(function() CK.Paddles:Init() end)
        safe(function() CK.Config:Init() end)
        safe(function() CK.Vibration:Init() end)
        safe(function() CK.Supplies:Init() end)
        safe(function() CK.MyWheels:Init() end)
        safe(function() CK.ConsumableWheel:Init() end)
        safe(function() CK.Upgrades:Init() end)
        safe(function() CK.Automation:Init() end)
        safe(function() CK.Reticle:Init() end)
        safe(function() CK.Range:Init() end)
        safe(function() CK.Toggle:Init() end)
        safe(function() CK.Fields:Init() end)
        -- Build the frames now, never while the chat is open (see Input.lua)
        if InCombatLockdown() then CK.buildPending = true else safe(function() CK:BuildUI() end) end
        safe(function() CK:RegisterOptions() end)
        local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version")
        CK:Print(L.LOADED, version or "?")
        safe(function() CK.Mapping:ReportSystemRemoved() end)
        -- The folder was ControllerKeyboard before 1.1: an old copy left
        -- there loads too, with a keyboard of its own
        local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
        if ADDON ~= "ControllerKeyboard" and isLoaded and isLoaded("ControllerKeyboard") then
            CK:Print(L.OLD_FOLDER)
        end
    elseif event == "PLAYER_LOGOUT" then
        -- The account's values back before the game saves, first and
        -- whatever else fails: never saved with a character's in their place
        xpcall(function() CK.Profiles:Store() end, geterrorhandler())
        xpcall(function() CK.Predict:Prune() end, geterrorhandler())
    elseif event == "GAME_PAD_ACTIVE_CHANGED" then
        CK.gamepadActive = arg1
    elseif event == "PLAYER_REGEN_DISABLED" then
        CK:OnCombatStarting()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if CK.buildPending then
            CK.buildPending = false
            CK:BuildUI()
        end
        CK:OnCombatEnded()
    elseif (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") and arg1 == ADDON then
        -- Release the pad at once so the game's popup can be answered safely
        CK:Close(event)
        CK:Print("|cffff4040%s|r: %s", event, tostring(arg2))
    end
end)
