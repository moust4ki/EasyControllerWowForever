local _, CK = ...

-- Pad buttons. Each input method has its own table (CK.Methods[x].buttons);
-- these ones are common. A sends through the secure macro button. B empties
-- the message while there is one; with an empty message it is left to the
-- game's gamepad UI, which closes the chat (the addon must never do it).
-- X, Y, Start and Select always belong to the game.
local COMMON_ACTIONS = {
    PADDLEFT = "NavPrev",
    PADDRIGHT = "NavNext",
    PADDUP = "FocusSuggestions",
    PADDDOWN = "FocusChannels",
    PADRSTICK = "RowSelect",
}

-- Once a mouse click closed the chat, the game's chat UI is gone: A sends
-- through the secure macro button and B closes the keyboard.
local STANDALONE_ACTIONS = { PAD2 = "Close" }

-- Right stick directions -> slot (1 left, 2 up, 3 right, 4 down)
local SLOT_BY_SECTOR = { [0] = 2, [1] = 3, [2] = 4, [3] = 1 }
-- Right stick navigation (when the method does not use the flick itself)
local NEUTRAL_FLICK = { "NavPrev", "RowSelect", "NavNext", "Backspace" }

-- Actions repeated while the button (or stick) is held
local REPEATABLE = { Backspace = true, NavPrev = true, NavNext = true }
local REPEAT_DELAY, REPEAT_RATE = 0.45, 0.08

local RIGHT_AIM, RIGHT_FIRE, RIGHT_RESET = 0.3, 0.75, 0.4

local function sector(x, y, count)
    local fromNorth = (90 - math.deg(math.atan2(y, x))) % 360
    local size = 360 / count
    return math.floor((fromNorth + size / 2) / size) % count
end

function CK:SetLeftStick(x, y)
    if self.db.settings.invertY then y = -y end
    self:GetMethod():OnLeftStick(x, y)
end

function CK:SetRightStick(x, y)
    if self.db.settings.invertY then y = -y end
    -- A method that uses the right stick as a cursor (split keyboard) gets it raw
    local method = self:GetMethod()
    if method.OnRightStick then
        method:OnRightStick(x, y)
        return
    end
    local state = self.state
    local len = math.sqrt(x * x + y * y)

    local aim
    if len >= RIGHT_AIM then
        aim = SLOT_BY_SECTOR[sector(x, y, 4)]
    end
    if aim ~= state.aim then
        state.aim = aim
        self:UpdateMethod()
    end

    if self.rightFired then
        if len < RIGHT_RESET then
            self.rightFired = false
            if self.repeatButton == "RIGHTSTICK" then self.repeatFn = nil end
        end
    elseif aim and len >= RIGHT_FIRE then
        self.rightFired = true
        if not (method.OnFlick and method:OnFlick(aim)) then
            self:RunAction(NEUTRAL_FLICK[aim], "RIGHTSTICK")
        end
    end
end

function CK:RunAction(action, button)
    self[action](self)
    if REPEATABLE[action] then
        self.repeatFn = action
        self.repeatButton = button
        self.repeatAt = GetTime() + REPEAT_DELAY
    end
end

function CK:ButtonAction(button)
    -- A method that takes the face buttons itself (ConsolePort.lua)
    local method = self:GetMethod()
    if method.ownButtons then return method.buttons[button] end
    if button == "PAD2" then
        return self.standalone and STANDALONE_ACTIONS.PAD2 or "CancelMessage"
    end
    return self:GetMethod().buttons[button] or COMMON_ACTIONS[button]
end

function CK:OnPadButton(button)
    if self.db.settings.debug then
        self:Print("button %s", tostring(button))
    end
    self.padDown = self.padDown or {}
    self.padDown[button] = true
    local action = self:ButtonAction(button)
    if action then
        self:RunAction(action, button)
    end
end

function CK:OnPadButtonUp(button)
    if self.padDown then self.padDown[button] = nil end
    if button == self.repeatButton then
        self.repeatFn = nil
    end
    -- B released after emptying the message: now leave it to the game
    if button == "PAD2" then self:UpdateCancelBinding() end
end

function CK:OnUpdate()
    local now = GetTime()

    -- Safety net: the chat lost the focus without any event we hooked
    if not self.standalone and not (self.editBox and self.editBox:HasFocus()) then
        if self:IsClickingWheel() then
            self:EnterStandalone()
        else
            self:Close("focus lost (OnUpdate)")
            return
        end
    end

    -- A field of the game (Fields.lua): closed when the focus goes to
    -- another field, or the field goes away (a mouse click on the keyboard
    -- takes the focus: typing goes on); typed on a physical keyboard, or cut
    -- by the field (its length, numbers only): the keyboard follows it
    local field = self.field
    if field then
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focus ~= field then
            if focus == nil and (self.fieldMouse or self:IsClickingWheel()) then
                self.fieldMouse = true
            else
                self:Close("field lost")
                return
            end
        end
        if not field:IsVisible() then
            self:Close("field lost")
            return
        end
        local text = field:GetText() or ""
        if text ~= (self.buffer or "") then
            self.buffer = text
            self:Refresh()
        end
    end

    -- Fallback when OnGamePadStick never fires: poll the device state
    if not self.stickEvents and C_GamePad and C_GamePad.GetDeviceMappedState then
        local id = C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
        local st = id and C_GamePad.GetDeviceMappedState(id)
        local sticks = st and st.sticks
        if sticks then
            if sticks[1] then self:SetLeftStick(sticks[1].x or 0, sticks[1].y or 0) end
            if sticks[2] then self:SetRightStick(sticks[2].x or 0, sticks[2].y or 0) end
        end
    end

    self:CheckBindings(now)

    if self.repeatFn and now >= self.repeatAt then
        self[self.repeatFn](self)
        self.repeatAt = now + REPEAT_RATE
    end
end

-- The keyboard's keys kept while it is open (reported: A did nothing, or
-- opened the game's chat menu). The game binds its chat's own footer on the
-- same keys (A send, X channels, Y tab settings) whenever its gamepad focus
-- is refreshed, and the latest override binding on a key wins: ours, set
-- once at opening, could end up under the game's. Looked at five times a
-- second; ours set again when another took one, never more than a few times
-- in a row (no endless back and forth with whoever wants the key).
local CHECK_EVERY, RESTORE_WINDOW, MAX_RESTORES = 0.2, 3, 5

function CK:CheckBindings(now)
    if not (self.bindingsActive and self.keyboardBinds) or InCombatLockdown() or not GetBindingAction then return end
    if now < (self.nextBindCheck or 0) then return end
    self.nextBindCheck = now + CHECK_EVERY
    for key, action in pairs(self.keyboardBinds) do
        local current = GetBindingAction(key, true)
        if current ~= action then
            local restores = self.bindRestores or {}
            while restores[1] and restores[1] < now - RESTORE_WINDOW do table.remove(restores, 1) end
            self.bindRestores = restores
            self.lastTaken = { key = key, by = current, time = now }
            if #restores >= MAX_RESTORES then return end
            restores[#restores + 1] = now
            if self.db.settings.debug then
                self:Print("%s taken by %s: the keyboard's set again", key, tostring(current))
            end
            self:EnableButtons()
            return
        end
    end
end

---------------------------------------------------------------------------
-- Frames
--
-- WoW Forever's gamepad smart navigation hooks the global CreateFrame and
-- refreshes its button groups from the caller's (tainted) context. Creating
-- frames without a parent and calling SetParent afterwards is not watched.
---------------------------------------------------------------------------
function CK.NewFrame(frameType, name, parent, template)
    local f = CreateFrame(frameType, name, nil, template)
    if parent then f:SetParent(parent) end
    return f
end

---------------------------------------------------------------------------
-- Buttons
--
-- While the keyboard is open, each pad button is bound (override binding)
-- to "click" a hidden button. Pad buttons keep working while the chat edit
-- box has the focus, and A clicks a secure macro button that sends the text
-- with "/s ...", "/p ..." etc.: the game itself sends the message.
-- In combat bindings and attributes are locked: they stay as set on open.
---------------------------------------------------------------------------
local function bindingButtonName(key)
    return "ControllerKeyboardPad" .. key
end

-- A trigger held may add a modifier to the keys (the gamepad UI's LT / RT
-- act as Shift, Ctrl or Alt): LT then RT typed quickly is still RT
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local function bind(f, key, button)
    for _, prefix in ipairs(PREFIXES) do SetOverrideBindingClick(f, true, prefix .. key, button) end
    -- What the key must run while the keyboard is open (see CK:CheckBindings)
    if CK.keyboardBinds then CK.keyboardBinds[key] = "CLICK " .. button .. ":LeftButton" end
end

local SEND_BUTTON = "ControllerKeyboardSendButton"
-- A in a prompt (a name for one of ours): confirms, nothing is sent
local PROMPT_BUTTON = "ControllerKeyboardPromptButton"

function CK:CreateButtons()
    -- One hidden button per pad button any method may use, plus B
    local keys, seen = {}, {}
    local function add(key)
        if not seen[key] then seen[key] = true; keys[#keys + 1] = key end
    end
    for key in pairs(COMMON_ACTIONS) do add(key) end
    for _, method in pairs(CK.Methods) do
        for key in pairs(method.buttons) do add(key) end
    end
    add("PAD2")
    for _, key in ipairs(keys) do
        local b = CK.NewFrame("Button", bindingButtonName(key))
        b:SetSize(1, 1)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetScript("OnClick", function(_, _, down)
            if down == false then
                CK:OnPadButtonUp(key)
            else
                CK:OnPadButton(key)
            end
        end)
    end

    local ok = CK.NewFrame("Button", PROMPT_BUTTON)
    ok:SetSize(1, 1)
    ok:RegisterForClicks("AnyDown")
    ok:SetScript("OnClick", function() CK:FinishPrompt(true) end)

    -- Secure macro button laid over the "Send" button for the mouse
    -- (the pad sends with A through the game's own chat UI)
    local s = CK.NewFrame("Button", SEND_BUTTON, nil, "SecureActionButtonTemplate")
    s:SetAttribute("type", "macro")
    s:SetAttribute("macrotext", "")
    s:RegisterForClicks("AnyDown", "AnyUp")
    s:SetFrameStrata("FULLSCREEN_DIALOG")
    -- The overlay takes the mouse: light up the visible "Send" button below
    local function hover(on)
        local send = CK.frame and CK.frame.actions.Send
        if send then
            send.hover = on
            send:Render()
        end
    end
    s:SetScript("OnEnter", function() hover(true) end)
    s:SetScript("OnLeave", function() hover(false) end)
    s:SetScript("PreClick", function(_, _, down) CK:PrepareSend(down) end)
    s:SetScript("PostClick", function(_, _, down) CK:FinishSend(down) end)
    s:Hide()
    self.sendButton = s
end

-- Runs before the secure click: put the current message in the macro
-- (a method with its own Enter decides itself: ConsolePort.lua)
function CK:PrepareSend(down)
    self.justSent = false
    if InCombatLockdown() then return end
    local method = self:GetMethod()
    if method.SendPress and method:SendPress(down) then return end
    self.sendButton:SetAttribute("macrotext", self:BuildMacroText() or "")
    self:SendWhisper()
end

-- Whispers go straight through SendChatMessage with the full name: a macro
-- "/w Fraicheur Hunt hi" would whisper "Fraicheur". Whispers need no hardware
-- event and the game's chat box is not touched.
function CK:SendWhisper()
    local target = self:GetChatAttr("tellTarget")
    local chatType = self:GetChatAttr("chatType")
    if (chatType ~= "WHISPER" and chatType ~= "BN_WHISPER") or self:GetChatAttr("reply")
        or not target or target == "" then
        return
    end
    local text = self:GetText():gsub("[\r\n]", " ")
    if text:match("^[ \t\r\n]*$") then return end
    -- A command (/g, /dance...): the macro runs it, nothing is whispered
    if text:sub(1, 1) == "/" then return end
    -- PreClick runs on both press and release: send once
    local now = GetTime()
    if self.lastWhisper == text and now - (self.lastWhisperTime or 0) < 0.5 then return end
    self.lastWhisper, self.lastWhisperTime = text, now
    if chatType == "BN_WHISPER" then
        -- A Battle.net friend, as the game's chat box sends it
        local account = BNet_GetBNetIDAccount and BNet_GetBNetIDAccount(target)
        local send = C_BattleNet and C_BattleNet.SendWhisper or BNSendWhisper
        if not (account and send) then return end
        send(account, text)
        self.justSent = true
        CK.Predict:LearnMessage(text)
        return
    end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    send(text, "WHISPER", nil, target)
end

-- Runs after the secure click: once the game sent the message, clear it
-- (the chat stays open for the next message; B closes it)
function CK:FinishSend(down)
    local method = self:GetMethod()
    if method.SendDone and method:SendDone(down) then return end
    local text = self:GetText()
    -- /w without a recipient yet: A confirms the typed name (a command typed
    -- there is run, not taken for a name)
    if self:WhisperNameMode() and text:sub(1, 1) ~= "/" and not text:find("|H", 1, true) then
        if down ~= true then self:ConfirmWhisperTarget(text) end
        return
    end
    local slashCommand = text:sub(1, 1) == "/" and down ~= true
    if self.justSent or slashCommand then
        self.justSent = false
        if not InCombatLockdown() then
            self.sendButton:SetAttribute("macrotext", "")
        end
        if slashCommand then CK.Predict:LearnCommand(text) end
        local box = self.editBox and self.editBox:GetText()
        self.sentBoxText = (box and box ~= "") and box or nil
        self:SetText("")
        if self.standalone then self:Close("sent") end
    end
end

-- The secure "Send" button is placed over the visible one with screen
-- coordinates, never anchored to it: a frame a protected frame is anchored to
-- becomes protected too, and the keyboard could no longer be shown in combat.
function CK:PositionSendButton()
    local s, send = self.sendButton, self.frame and self.frame.actions.Send
    if not (s and send) or InCombatLockdown() or not send:GetLeft() then return end
    s:SetScale(send:GetEffectiveScale())
    s:ClearAllPoints()
    s:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", send:GetLeft(), send:GetBottom())
    s:SetSize(send:GetWidth(), send:GetHeight())
    s:EnableMouse(self.db.settings.showActions and not self:GetMethod().noMouseRow)
end

-- Override bindings can't change in combat: the keyboard (and its bindings)
-- is closed just before combat starts, when PLAYER_REGEN_DISABLED still allows it.
function CK:EnableButtons()
    local f = self.frame
    if InCombatLockdown() then return end
    ClearOverrideBindings(f)
    self.cancelBound = false
    self.keyboardBinds = {}
    -- A method that binds its own keys (ConsolePort.lua: A, B, X, Y...)
    local method = self:GetMethod()
    if method.ownButtons then
        self.bindingsActive = true
        method:Bind(f, bind, bindingButtonName, SEND_BUTTON)
        if not self.prompt then
            self:PositionSendButton()
            self.sendButton:Show()
        end
        return
    end
    for key in pairs(COMMON_ACTIONS) do bind(f, key, bindingButtonName(key)) end
    for key in pairs(self:GetMethod().buttons) do bind(f, key, bindingButtonName(key)) end
    if self.standalone then bind(f, "PAD2", bindingButtonName("PAD2")) end
    self.bindingsActive = true
    -- A prompt: A confirms, nothing goes to the chat
    if self.prompt then
        bind(f, "PAD1", PROMPT_BUTTON)
        return
    end
    -- A sends the keyboard's buffer (the chat edit box stays empty)
    bind(f, "PAD1", SEND_BUTTON)
    self:UpdateCancelBinding()
    self:PositionSendButton()
    self.sendButton:Show()
end

-- B is bound only while the message holds text: B then empties it, and the
-- next B (empty message) goes to the game, which closes the chat. Changed on
-- release so the game never sees the second half of the same press.
function CK:UpdateCancelBinding()
    if not self.bindingsActive or self.standalone or InCombatLockdown() then return end
    if self:GetMethod().ownButtons then return end
    if self.padDown and self.padDown.PAD2 then return end
    local want = self:GetText() ~= "" or self:InQuestList()
    if want == self.cancelBound then return end
    if want then
        bind(self.frame, "PAD2", bindingButtonName("PAD2"))
    else
        for _, prefix in ipairs(PREFIXES) do SetOverrideBinding(self.frame, true, prefix .. "PAD2", nil) end
        if self.keyboardBinds then self.keyboardBinds.PAD2 = nil end
    end
    self.cancelBound = want
end

function CK:DisableButtons()
    self.padDown = nil
    self.keyboardBinds = nil
    if not self.bindingsActive or InCombatLockdown() then return end
    ClearOverrideBindings(self.frame)
    self.cancelBound = false
    self.sendButton:Hide()
    self.sendButton:SetAttribute("macrotext", "")
    self.bindingsActive = false
end

function CK:OnCombatStarting()
    self.reopenAfterCombat = self:IsOpen() and self.editBox or nil
    self:Close("combat")
    self:DisableButtons()
end

-- Back after combat if the chat is still being typed in
function CK:OnCombatEnded()
    local eb = self.reopenAfterCombat
    self.reopenAfterCombat = nil
    if not eb and self:WantsKeyboard() then
        local active = CK.ActiveChatWindow()
        if active and active:HasFocus() then eb = active end
    end
    if eb and eb:HasFocus() and not self:IsOpen() then
        self:Open(eb)
    end
end

---------------------------------------------------------------------------
-- Sticks
---------------------------------------------------------------------------
local LEFT_STICKS = { Left = true, Movement = true }
local RIGHT_STICKS = { Right = true, Camera = true }

function CK:SetupInput(f)
    self:CreateButtons()
    if f.EnableGamePadStick then
        f:EnableGamePadStick(true)
        f:SetScript("OnGamePadStick", function(_, stick, x, y)
            if CK.db.settings.debug then
                CK.seenSticks = CK.seenSticks or {}
                if not CK.seenSticks[stick] then
                    CK.seenSticks[stick] = true
                    CK:Print("stick %s", tostring(stick))
                end
            end
            if LEFT_STICKS[stick] then
                CK.stickEvents = true
                CK:SetLeftStick(x or 0, y or 0)
            elseif RIGHT_STICKS[stick] then
                CK.stickEvents = true
                CK:SetRightStick(x or 0, y or 0)
            end
        end)
    end
    f:SetScript("OnUpdate", function() CK:OnUpdate() end)
end
