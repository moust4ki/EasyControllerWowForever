local _, CK = ...
local L = CK.L

-- Common core of the keyboard: the message, prediction, chat channels,
-- sending, opening and closing. The input methods (Wheel.lua: daisywheel,
-- StickKeyboard.lua: split keyboard) only turn the pad into characters.
CK.state = {
    layer = "letters",
    shift = false,
    caps = false,
    suggestions = {},
    selected = 1,
    lastShift = 0,
}

---------------------------------------------------------------------------
-- Text and channel source
--
-- The message lives in the keyboard's own buffer and is sent with the secure
-- macro button. The addon never writes to the chat edit box: text set by an
-- addon is tainted, and when WoW Forever's gamepad UI reads it back
-- (ChatFrame1EditBox:GetText()) its own code gets tainted, which is blocked
-- in combat again and again until the client freezes. The edit box is only
-- read: its channel, and what is typed on a physical keyboard.
-- "standalone": a mouse click made the game close the chat, the keyboard
-- stays open on its own.
---------------------------------------------------------------------------
function CK:GetText()
    return self.buffer or ""
end

-- Channel: the chat's own while it is open, a snapshot once it is closed
function CK:GetChatAttr(key)
    if self.chatAttrs then return self.chatAttrs[key] end
    return self.editBox and self.editBox:GetAttribute(key)
end

local function snapshotAttrs(eb)
    if not eb then return { chatType = "SAY" } end
    return {
        chatType = eb:GetAttribute("chatType") or "SAY",
        tellTarget = eb:GetAttribute("tellTarget"),
        channelTarget = eb:GetAttribute("channelTarget"),
    }
end

function CK:SetChatAttr(key, value)
    self.chatAttrs = self.chatAttrs or snapshotAttrs(self.editBox)
    self.chatAttrs[key] = value
end

-- Text typed on a physical keyboard (links inserted by the game are caught
-- by the Shift+click hook instead, see QuestLinks.lua)
function CK:OnChatTextChanged(eb, userInput)
    if eb ~= self.editBox then return end
    local text = eb:GetText() or ""
    local sent = self.sentBoxText
    if sent and text:sub(1, #sent) ~= sent then self.sentBoxText, sent = nil, nil end
    if not userInput then return end
    if sent then text = text:sub(#sent + 1):gsub("^ +", "") end
    self.buffer = text
    self:Refresh()
end

-- True while a mouse button is held over the keyboard (not just hovering:
-- sending with A while the cursor rests on the wheel must still close it)
function CK:IsClickingWheel()
    return self.frame and self.frame:IsMouseOver()
        and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
end

-- Keyboard without the chat (after /ec lock, to place it): A sends with the
-- secure macro button, B closes
function CK:OpenStandalone()
    if not self.db.settings.modules.keyboard then return end
    if self:BlockedByCombat() then return end
    if not self.frame then self:BuildUI() end
    if self:IsOpen() then return end
    self.standalone = true
    self.buffer = ""
    self.chatAttrs = { chatType = "SAY" }
    self.editBox = nil
    local state = self.state
    state.layer, state.shift, state.caps, state.aim = "letters", false, false, nil
    state.activeRow = "suggestions"
    self:GetMethod():Reset()
    self.frame:Show()
    self:EnableButtons()
    self:UpdateMethod()
    self:Refresh()
end

function CK:EnterStandalone()
    if self.standalone then return end
    self.standalone = true
    self.chatAttrs = self.chatAttrs or snapshotAttrs(self.editBox)
    self.editBox = nil
    if self.db.settings.debug then self:Print("standalone mode") end
    self:EnableButtons()
    self:Refresh()
end

function CK:GetChannelLabel()
    if self.prompt then return "|cffffd100" .. self.prompt.title .. " :|r " end
    local chatType = self:GetChatAttr("chatType") or "SAY"
    local label
    if self:GetChatAttr("reply") then
        label = format(CK.L.REPLY_TO, self:GetChatAttr("tellTarget") or "?")
    elseif self:WhisperNameMode() then
        label = CK.L.WHISPER_NAME
    elseif chatType == "WHISPER" or chatType == "BN_WHISPER" then
        label = format(CHAT_WHISPER_SEND or "To %s: ", self:GetChatAttr("tellTarget") or "?")
    elseif chatType == "CHANNEL" then
        local target = self:GetChatAttr("channelTarget")
        local _, name = GetChannelName(target or 0)
        label = (name or tostring(target or "")) .. ": "
    else
        label = _G["CHAT_" .. chatType .. "_SEND"] or (chatType .. ": ")
    end
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if info then
        label = format("|cff%02x%02x%02x%s|r", info.r * 255, info.g * 255, info.b * 255, label)
    end
    return label
end

-- Keep the end of long messages visible
local MAX_PREVIEW = 80
local function previewTail(text)
    text = CK.DisplayText(text)
    if #text <= MAX_PREVIEW then return text end
    local start = #text - MAX_PREVIEW + 1
    -- Never start inside a colored [link]: move back to its color code
    local from = 1
    while true do
        local s, e = text:find("|c%x%x%x%x%x%x%x%x.-|r", from)
        if not s or s > start then break end
        if e >= start then start = s break end
        from = e + 1
    end
    while start <= #text do
        local b = text:byte(start)
        if b < 128 or b >= 192 then break end
        start = start + 1
    end
    return "..." .. text:sub(start)
end

local WORD_TAIL = "(" .. CK.WORD_CHARS .. "*)$"

-- The word being typed, without a leading Spanish ¿ or ¡ (they stay in the text)
local function wordTail(text)
    if text:find("|r$") then return "" end
    return ((text:match(WORD_TAIL) or ""):gsub("^\194[\161\191]", ""))
end

function CK:Refresh()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    if not (self.standalone or self.editBox) then return end

    local text = self:GetText()
    self.previewBody = self:GetChannelLabel() .. previewTail(text)
    self:UpdatePreview()
    -- A prompt's own field follows what is typed
    if self.prompt and self.prompt.box and self.prompt.box:GetText() ~= text then
        self.prompt.box:SetText(text)
    end

    -- "/re" -> /reload, "/ec l" -> /ec lock: command and at most one argument
    local n = self.db.settings.numSuggestions
    local _, spaces = text:gsub(" ", "")
    self.state.commandMode = text:sub(1, 1) == "/" and spaces <= 1
    if self:InQuestList() then
        -- Quest links: the suggestions row lists the quests in progress
        self.state.suggestions = self:QuestListSuggestions(n)
    elseif self.state.commandMode then
        self.state.suggestions = CK.Predict:QueryCommands(text, n)
    elseif self:WhisperNameMode() then
        -- Typing the name of a /w (names may hold a space): suggest people
        self.state.suggestions = self:QueryNames(text, n)
    else
        local prefix = wordTail(text)
        local ctx = CK.Predict:Context(text:sub(1, #text - #prefix))
        self.state.suggestions = CK.Predict:Query(prefix, ctx, n)
    end
    if not self:InQuestList() then self.state.selected = 1 end
    self:UpdateSuggestions()
    self:UpdateChannels()
    self:UpdateRows()
    self:UpdateCancelBinding()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
function CK:SetText(text)
    self.buffer = text
    self:Refresh()
end

function CK:InsertText(text)
    self:SetText(self:GetText() .. text)
end

-- Type one character of the active input method (shift applies once)
function CK:TypeChar(ch)
    if not ch then return end
    self:InsertText(self:DisplayChar(ch))
    if self.state.shift and not self.state.caps then
        self.state.shift = false
        self:UpdateMethod()
    end
end

function CK:Space()
    self:InsertText(" ")
end

function CK:Backspace()
    local text = self:GetText()
    -- Nothing left to delete in a /w message: back to choosing the name
    if text == "" and self:GetChatAttr("chatType") == "WHISPER" and not self:GetChatAttr("reply")
        and self:GetChatAttr("tellTarget") then
        self.whisperTarget = nil
        self:SetChatAttr("tellTarget", nil)
        self:Refresh()
        return
    end
    local link = CK.TrailingLink(text)
    if link then
        self:SetText(text:sub(1, #text - #link))
        return
    end
    self:SetText(CK.DropLastChar(text))
end

-- B with a message: empty it. With an empty message B belongs to the game,
-- which closes the chat (see CK:UpdateCancelBinding)
function CK:CancelMessage()
    if self:InQuestList() then
        self:CloseQuestList()
        return
    end
    self:SetText("")
end

function CK:DeleteWord()
    local text = self:GetText():gsub("[ \t\r\n]+$", "")
    text = text:gsub("[^ \t\r\n]+$", "")
    self:SetText(text)
end

function CK:AcceptSuggestion(index)
    if self:InQuestList() then
        -- index is a position in the visible window
        local first = self.state.questIndex - self.state.selected + 1
        self:InsertQuestLink(index and (first + index - 1))
        return true
    end
    local word = self.state.suggestions[index or self.state.selected]
    if not word then return false end
    if self.state.commandMode then
        self:SetText(word .. " ")
        return true
    end
    if self:WhisperNameMode() then
        self:ConfirmWhisperTarget(word)
        return true
    end
    local text = self:GetText()
    local prefix = wordTail(text)
    -- No space after an elision: "j'" + "ai"
    local sep = word:sub(-1) == "'" and "" or " "
    -- A link just before: a space between
    local lead = (prefix == "" and text:find("|r$")) and " " or ""
    self:SetText(text:sub(1, #text - #prefix) .. lead .. word .. sep)
    return true
end

function CK:SelectSuggestion(delta)
    local n = #self.state.suggestions
    if n == 0 then return end
    self.state.selected = (self.state.selected - 1 + delta) % n + 1
    self:UpdateSuggestions()
end

function CK:NextSuggestion() self:SelectSuggestion(1) end
function CK:PrevSuggestion() self:SelectSuggestion(-1) end

-- Tap: one capital letter. Double tap: caps lock. Tap again: off.
function CK:ToggleShift()
    local state = self.state
    local now = GetTime()
    if state.caps then
        state.caps, state.shift = false, false
    elseif state.shift and now - state.lastShift < 0.4 then
        state.caps = true
    else
        state.shift = not state.shift
    end
    state.lastShift = now
    self:UpdateMethod()
end

function CK:ToggleSymbols()
    self.state.layer = self.state.layer == "letters" and "symbols" or "letters"
    self:UpdateMethod()
end

-- Channel row: the keyboard keeps its own channel (the game's chat box is
-- never touched) and A sends with the matching command
local function lastTellTarget()
    local get = ChatFrameUtil and ChatFrameUtil.GetLastTellTarget or ChatEdit_GetLastTellTarget
    return get and (get()) or nil
end

local function lastToldTarget()
    local get = ChatFrameUtil and ChatFrameUtil.GetLastToldTarget or ChatEdit_GetLastToldTarget
    return get and (get()) or nil
end

local function nonEmpty(v)
    return v ~= nil and v ~= ""
end

local function inGroup()
    if IsInGroup then return IsInGroup() end
    return (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
end

local function inRaid()
    if IsInRaid then return IsInRaid() end
    return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
end

CK.CHANNEL_LIST = {
    { key = "s", label = "/s", color = "SAY",
      available = function() return true end,
      attrs = function() return { chatType = "SAY" } end },
    { key = "y", label = "/y", color = "YELL",
      available = function() return true end,
      attrs = function() return { chatType = "YELL" } end },
    { key = "p", label = "/p", color = "PARTY",
      available = inGroup,
      attrs = function() return { chatType = "PARTY" } end },
    { key = "ra", label = "/ra", color = "RAID",
      available = inRaid,
      attrs = function() return { chatType = "RAID" } end },
    { key = "g", label = "/g", color = "GUILD",
      available = function() return IsInGuild() end,
      attrs = function() return { chatType = "GUILD" } end },
    { key = "1", label = "/1", color = "CHANNEL1",
      available = function() return (GetChannelName(1) or 0) ~= 0 end,
      attrs = function() return { chatType = "CHANNEL", channelTarget = 1 } end },
    -- /w: the person the chat was opened for, else the last one you whispered
    -- /w: the person the chat was opened for, else type "Name message"
    { key = "w", label = "/w", color = "WHISPER",
      available = function() return true end,
      attrs = function(ck)
          if nonEmpty(ck.whisperTarget) then
              return { chatType = "WHISPER", tellTarget = ck.whisperTarget }
          end
          return { chatType = "WHISPER" }
      end },
    -- /r: reply to the last person who whispered you
    { key = "r", label = "/r", color = "WHISPER",
      available = function() return nonEmpty(lastTellTarget()) end,
      attrs = function() return { chatType = "WHISPER", tellTarget = lastTellTarget(), reply = true } end },
}

-- /w without a known target: the message starts with the name
function CK:WhisperNameMode()
    local target = self:GetChatAttr("tellTarget")
    return self:GetChatAttr("chatType") == "WHISPER" and not self:GetChatAttr("reply")
        and not (target and target ~= "")
end

-- People to whisper: recent correspondents, group, online friends and guild
function CK:KnownNames()
    local list, seen = {}, {}
    local me = UnitName and UnitName("player")
    local function add(name)
        if nonEmpty(name) and name ~= me and not seen[name] then
            seen[name] = true
            list[#list + 1] = name
        end
    end
    add(lastTellTarget())
    add(lastToldTarget())
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    local unit = inRaid() and "raid" or "party"
    for i = 1, count do
        add(UnitName and UnitName(unit .. i))
    end
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then add(info.name) end
        end
    end
    if IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        for i = 1, GetNumGuildMembers() or 0 do
            local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if online and name then add(Ambiguate and Ambiguate(name, "guild") or name) end
        end
    end
    return list
end

-- Matching known names; what was typed is offered last so any name can be used
function CK:QueryNames(prefix, n)
    local typed = prefix:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", "")
    local norm = CK.Normalize(typed)
    local out, exact = {}, false
    for _, name in ipairs(self:KnownNames()) do
        if #out >= n - 1 then break end
        local nn = CK.Normalize(name)
        if nn:sub(1, #norm) == norm then
            out[#out + 1] = name
            if nn == norm then exact = true end
        end
    end
    if typed ~= "" and not exact then out[#out + 1] = typed end
    return out
end

-- Pick the /w recipient; the buffer then holds the message
function CK:ConfirmWhisperTarget(name)
    name = (name or ""):gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", "")
    if name == "" or name:find("|", 1, true) then return end
    self.whisperTarget = name
    self:SetChatAttr("tellTarget", name)
    self:ApplyStickyChannel()
    self:SetText("")
end

function CK:ChannelAvailable(i)
    local ch = CK.CHANNEL_LIST[i]
    return ch and ch.available(self) and true or false
end

local KEY_BY_CHATTYPE = { SAY = "s", YELL = "y", PARTY = "p", RAID = "ra", GUILD = "g", WHISPER = "w" }

-- Index of the current channel in CHANNEL_LIST (nil for other channels)
function CK:CurrentChannelIndex()
    local chatType = self:GetChatAttr("chatType") or "SAY"
    local key
    if self:GetChatAttr("reply") then
        key = "r"
    elseif chatType == "CHANNEL" then
        key = tostring(self:GetChatAttr("channelTarget"))
    else
        key = KEY_BY_CHATTYPE[chatType]
    end
    for i, ch in ipairs(CK.CHANNEL_LIST) do
        if ch.key == key then return i end
    end
end

function CK:SetChannel(i)
    if not (self.standalone or self.editBox) or not self:ChannelAvailable(i) then return end
    -- Remember who the chat was opened for before switching away from them
    if not self.chatAttrs and self.editBox and self.editBox:GetAttribute("chatType") == "WHISPER" then
        self.whisperTarget = self.editBox:GetAttribute("tellTarget")
    end
    self.chatAttrs = CK.CHANNEL_LIST[i].attrs(self)
    self.state.questChip = false
    self:ApplyStickyChannel()
    self:Refresh()
end

-- Remember channels in addon state only. Native chat attributes are also read
-- by the macro executor; writing them can taint subsequent macro commands.
-- Compare the game's own sticky channel so a later native choice takes priority.
local function gameSticky(eb)
    if not eb then return "" end
    return tostring(eb:GetAttribute("stickyType") or "SAY") .. "|" .. tostring((eb:GetAttribute("channelTarget")))
        .. "|" .. tostring((eb:GetAttribute("tellTarget")))
end

function CK:ApplyStickyChannel()
    if not self.db.settings.stickyChannel then return end
    local attrs = self.chatAttrs
    if not (attrs and attrs.chatType) then return end
    if attrs.chatType == "WHISPER" and not (attrs.tellTarget and attrs.tellTarget ~= "") then return end
    self.sticky = { chatType = attrs.chatType, tellTarget = attrs.tellTarget, channelTarget = attrs.channelTarget }
    self.stickyBase = gameSticky(self.editBox or self.lastEditBox or ChatFrame1EditBox)
end

-- Explicit whispers and commands keep the channel the game opened for them.
function CK:StickyFor(eb)
    local sticky = self.sticky
    if not (sticky and eb and self.db.settings.stickyChannel) then return nil end
    local chatType = eb:GetAttribute("chatType") or "SAY"
    if chatType ~= (eb:GetAttribute("stickyType") or "SAY") or chatType == "WHISPER" or chatType == "BN_WHISPER" then
        return nil
    end
    if (eb:GetText() or ""):sub(1, 1) == "/" then return nil end
    if gameSticky(eb) ~= self.stickyBase then
        self.sticky = nil
        return nil
    end
    local attrs = {}
    for k, v in pairs(sticky) do attrs[k] = v end
    return attrs
end

-- delta: 1 = next available channel, -1 = previous
function CK:CycleChannel(delta)
    delta = delta or 1
    local n = #CK.CHANNEL_LIST
    -- With the quest links module, the "Quests" chip is one more stop
    local chip = self.db.settings.modules.questLinks
    local count = chip and n + 1 or n
    local index = (chip and self.state.questChip) and n + 1
        or self:CurrentChannelIndex() or (delta > 0 and 0 or count + 1)
    for step = 1, count do
        local i = (index - 1 + step * delta) % count + 1
        if i == n + 1 then
            -- The Quests chip only inserts links: the channel the row was
            -- entered with comes back (passing /w on the way changes nothing)
            self:RestoreChannelsFrom()
            self.state.questChip = true
            self:Refresh()
            return
        elseif self:ChannelAvailable(i) then
            self:SetChannel(i)
            return
        end
    end
end

function CK:NextChannel() self:CycleChannel(1) end
function CK:PrevChannel() self:CycleChannel(-1) end

-- D-pad down / up picks the active row (channels under the wheel, or the
-- suggestions above it); left /
-- right, and the right stick with no petal picked, move inside it
function CK:SetActiveRow(row)
    self.state.activeRow = row
    self:UpdateRows()
end

-- The channel row: the channel in use is noted, for the Quests chip
function CK:NoteChannelsFrom()
    local attrs = self.chatAttrs or snapshotAttrs(self.editBox)
    local from = {}
    for k, v in pairs(attrs) do from[k] = v end
    self.channelsFrom = from
end

function CK:RestoreChannelsFrom()
    local from = self.channelsFrom
    if not from then return end
    local attrs = {}
    for k, v in pairs(from) do attrs[k] = v end
    self.chatAttrs = attrs
    self:ApplyStickyChannel()
end

function CK:FocusChannels()
    if self.state.activeRow ~= "channels" then self:NoteChannelsFrom() end
    self:SetActiveRow("channels")
end
function CK:FocusSuggestions() self:SetActiveRow("suggestions") end

-- Right stick click (or flick up): on the channel row, confirm the channel
-- (already applied while moving) and go back to the suggestions, without
-- inserting anything; on the suggestions row, insert the selected one
function CK:RowSelect()
    if self.state.activeRow == "channels" then
        if self.state.questChip then
            self:OpenQuestList()
        else
            self:SetActiveRow("suggestions")
        end
    else
        self:AcceptSuggestion()
    end
end

function CK:NavPrev()
    if self.state.activeRow == "channels" then
        self:PrevChannel()
    elseif self:InQuestList() then
        self:MoveInQuestList(-1)
    else
        self:PrevSuggestion()
    end
end

function CK:NavNext()
    if self.state.activeRow == "channels" then
        self:NextChannel()
    elseif self:InQuestList() then
        self:MoveInQuestList(1)
    else
        self:NextSuggestion()
    end
end

-- The message is sent by the secure macro button (see Input.lua): calling the
-- chat functions from addon code gets blocked by WoW Forever's gamepad UI.
local SLASH = {
    SAY = "/s", YELL = "/y", PARTY = "/p", RAID = "/ra", GUILD = "/g",
    OFFICER = "/o", INSTANCE_CHAT = "/i", RAID_WARNING = "/rw", EMOTE = "/e",
}

function CK:BuildMacroText()
    if not (self.standalone or self.editBox) then return end
    local text = self:GetText():gsub("[\r\n]", " ")
    if text:match("^[ \t\r\n]*$") then return end
    if text:sub(1, 1) == "/" then return text end

    local chatType = self:GetChatAttr("chatType") or "SAY"
    if self:GetChatAttr("reply") then
        return "/r " .. text
    elseif chatType == "WHISPER" then
        -- Sent directly by CK:SendWhisper (names may hold a space)
        return nil
    elseif chatType == "CHANNEL" then
        local target = self:GetChatAttr("channelTarget")
        return target and ("/" .. target .. " " .. text)
    end
    local cmd = SLASH[chatType]
    return cmd and (cmd .. " " .. text)
end

-- Only reached when the secure button doesn't take the mouse (the mouse
-- buttons row's option): A sends. A prompt: confirmed.
function CK:Send()
    if self.prompt then return self:FinishPrompt(true) end
    self:Print(L.SEND_COMBAT)
end

-- A name typed for one of the addon's own things (a wheel): the keyboard on
-- its own, nothing sent to the chat. A confirms (onDone(text)), B or its
-- close button cancel (onDone(nil)); `box`, a field of ours, follows it.
function CK:OpenPrompt(title, text, onDone, box)
    if not self.db.settings.modules.keyboard or self:BlockedByCombat() then return false end
    if not self.frame then self:BuildUI() end
    if self:IsOpen() then self:Close("prompt") end
    self.prompt = { title = title, onDone = onDone, box = box }
    self.standalone = true
    self.buffer = text or ""
    self.chatAttrs = { chatType = "SAY" }
    self.editBox = nil
    local state = self.state
    state.layer, state.shift, state.caps, state.aim = "letters", false, false, nil
    state.activeRow = "suggestions"
    self:GetMethod():Reset()
    self.frame:Show()
    self.frame:Raise()
    self:EnableButtons()
    self:UpdateMethod()
    self:Refresh()
    return true
end

function CK:FinishPrompt(confirmed)
    local prompt = self.prompt
    if not prompt then return end
    local text = self:GetText()
    self.prompt = nil
    self:Close("prompt")
    prompt.onDone(confirmed and text or nil)
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------
-- The keyboard is not available in combat: sending from the chat while in
-- combat got blocked by the game. It reopens after combat if the chat is open.
function CK:BlockedByCombat()
    if not InCombatLockdown() then return false end
    -- Red message in the middle of the screen, like the game's own errors
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(CK.L.COMBAT_UNAVAILABLE, 1, 0.1, 0.1, 1)
    else
        self:Print(CK.L.COMBAT_UNAVAILABLE)
    end
    return true
end

-- A message left when the game closed the chat (a panel opened, combat...)
-- is kept as a draft, like on a phone, and comes back with the chat: type
-- "LFM", open the quest log, "Share in chat", and the keyboard holds
-- "LFM [quest]". B empties it as usual.
local DRAFT_TIME = 600
local KEEP_DRAFT = {
    ["chat deactivated"] = true, ["focus lost (OnUpdate)"] = true, combat = true, toggle = true,
}

-- attrs is the remembered channel this keyboard opens on, if any.
function CK:TakeDraft(chatText, eb, attrs)
    local draft = self.draft
    if not draft then return chatText end
    local chatType = attrs and attrs.chatType or (eb and eb:GetAttribute("chatType"))
    local target = attrs and attrs.tellTarget or (eb and eb:GetAttribute("tellTarget"))
    local toWhisper = chatType == "WHISPER" or chatType == "BN_WHISPER"
    local wasWhisper = draft.chatType == "WHISPER" or draft.chatType == "BN_WHISPER"
    if (toWhisper or wasWhisper)
        and not (draft.chatType == chatType and draft.target == target) then
        return chatText
    end
    self.draft = nil
    if GetTime() - draft.time > DRAFT_TIME then return chatText end
    -- The chat opened on a command (/w, reply...), or already holds the text
    if chatText:sub(1, 1) == "/" or chatText:sub(1, #draft.text) == draft.text then return chatText end
    if chatText == "" then return draft.text end
    local sep = draft.text:match("[ \t]$") and "" or " "
    return draft.text .. sep .. chatText
end

function CK:Open(eb)
    if not self.db.settings.modules.keyboard then return end
    if self:BlockedByCombat() then return end
    if not self.frame then self:BuildUI() end
    if self.prompt then self:FinishPrompt(false) end
    -- Keep a message typed with the mouse when the chat is reopened;
    -- otherwise start from the draft and what the chat holds (physical
    -- keyboard, a link the game opened the chat with)
    local keep = self.standalone and self.buffer and self.buffer ~= ""
    if keep then
        local before = self.chatAttrs or {}
        local chatType = eb:GetAttribute("chatType")
        local whisper = function(t) return t == "WHISPER" or t == "BN_WHISPER" end
        if (whisper(chatType) or whisper(before.chatType))
            and not (before.chatType == chatType and before.tellTarget == eb:GetAttribute("tellTarget")) then
            self.draft = { text = self.buffer, time = GetTime(), chatType = before.chatType, target = before.tellTarget }
            keep = false
        end
    end
    local sticky = not keep and self:StickyFor(eb) or nil
    if not keep then
        self.buffer = self:TakeDraft(eb:GetText() or "", eb, sticky)
    end
    self.standalone = false
    self.chatAttrs = nil
    self.channelsFrom = nil
    self.whisperTarget = nil
    self.editBox = eb
    self.lastEditBox = eb
    if sticky then
        self.chatAttrs = sticky
        -- A remembered group/channel may no longer be available.
        local i = self:CurrentChannelIndex()
        if i and not self:ChannelAvailable(i) then self.chatAttrs = nil end
    end
    local state = self.state
    state.layer, state.shift, state.caps, state.aim = "letters", false, false, nil
    state.activeRow = "suggestions"
    self:GetMethod():Reset()
    self.frame:Show()
    self:EnableButtons()
    self:UpdateMethod()
    self:Refresh()
end

function CK:Close(reason)
    if self.db.settings.debug and self:IsOpen() then
        self:Print("close: %s", tostring(reason or "button"))
    end
    -- A prompt closed (B, its button, combat): cancelled
    local prompt = self.prompt
    self.prompt = nil
    self.closing = true
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        self:DisableButtons()
    end
    self.closing = false
    if not prompt and KEEP_DRAFT[reason] and self.db.settings.features.drafts
        and self.buffer and self.buffer:find("[^ \t\r\n]") then
        self.draft = { text = self.buffer, time = GetTime(),
            chatType = self:GetChatAttr("chatType"), target = self:GetChatAttr("tellTarget") }
    end
    self.standalone = false
    self.buffer = nil
    self.chatAttrs = nil
    self.channelsFrom = nil
    self.editBox = nil
    self.state.aim = nil
    self.state.questList = nil
    self.state.questChip = false
    self:GetMethod():Reset()
    self.repeatFn = nil
    if prompt then prompt.onDone(nil) end
end

function CK:IsOpen()
    return self.frame and self.frame:IsShown()
end
