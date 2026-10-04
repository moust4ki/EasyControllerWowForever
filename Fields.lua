local _, CK = ...
local L = CK.L

-- The keyboard for the game's other fields (the Auction House search, the
-- bags' search, mail, notes...): when one of them gets the keyboard focus,
-- the keyboard opens on it (Keyboard > Opening, on by default). What is
-- typed goes into the field as it is typed; A is Enter on the field (the
-- Auction House searches), B closes the keyboard and leaves the field, what
-- was typed kept. Built on the prompt (Message.lua): the keyboard on its own,
-- nothing sent to the chat.
--
-- Never: the chat's edit boxes (the chat has its own keyboard, and the addon
-- never writes in them), our own fields, password fields, fields of several
-- lines, the macro window, a frame the game forbids, its confirmation
-- popups, settings and key bindings (the windows most sensitive to an
-- addon's code), nor in combat.
--
-- Which field has the focus is asked to the game ten times a second
-- (GetCurrentKeyBoardFocus: one cheap call, nothing created), and only
-- looked at when it changes. The game's EditBox methods are not hooked:
-- they are shared by every field of its UI.
local F = {}
CK.Fields = F

local POLL = 0.1

-- Windows left alone, by the name of a frame the field is in
local SKIPPED = { "^StaticPopup", "^SettingsPanel", "^KeyBindingFrame", "^CommunitiesFrame", "^ChatFrame",
    "^MacroFrame", "^MacroPopup",
    "^GameMenuFrame", "^StoreFrame", "^ControllerKeyboard" }

local function settings() return CK.db.settings end

-- The option on, and the gamepad in use when the keyboard asks for it
function F:Wanted()
    local s = settings()
    if not (s.modules.keyboard and s.openFields) then return false end
    return not s.onlyWithGamepad or CK:IsGamepadActive()
end

-- A field of the game the keyboard may type in
function F:Accepts(eb)
    if type(eb) ~= "table" or not eb.GetObjectType then return false end
    if eb.IsForbidden and eb:IsForbidden() then return false end
    if eb:GetObjectType() ~= "EditBox" or not eb:IsVisible() then return false end
    if eb.IsPassword and eb:IsPassword() then return false end
    -- A field of several lines (the macro window's text, mail...): the
    -- keyboard types one line, it would join them (reported: macros saved
    -- as one line, "/startattack /cast ..." running nothing but the first)
    if eb.IsMultiLine and eb:IsMultiLine() then return false end
    -- The chat's own, and the chat-like ones
    if eb.chatFrame or eb:GetAttribute("chatType") or eb == CK.ActiveChatWindow() then return false end
    if CK.prompt and CK.prompt.box == eb then return false end
    local f, depth = eb, 0
    while f and depth < 25 do
        if f == CK.frame or (CK.Config and f == CK.Config.frame) then return false end
        local name = f:GetName()
        if name then
            for _, pattern in ipairs(SKIPPED) do
                if name:find(pattern) then return false end
            end
        end
        f, depth = f:GetParent(), depth + 1
    end
    return true
end

-- What the field is for: the hint it shows when empty, else "Text"
local function titleOf(eb)
    local hint = eb.Instructions or eb.instructions
    local text = type(hint) == "table" and hint.GetText and hint:GetText()
    if type(text) == "string" and text ~= "" then return text end
    return L.FIELD_TYPING
end

function F:Open(eb)
    if InCombatLockdown() or CK:IsOpen() then return end
    local ok = CK:OpenPrompt(titleOf(eb), eb:GetText() or "", function(text) F:Done(eb, text) end, eb)
    if not ok then return end
    CK.field, CK.fieldMouse = eb, false
    -- A field for numbers: on the numbers
    if eb.IsNumeric and eb:IsNumeric() then
        CK.state.layer = "symbols"
        CK:UpdateMethod()
        CK:Refresh()
    end
end

-- The keyboard closed: confirmed (A: Enter on the field) or not (B, the
-- field gone). A field that keeps the focus all the same is not opened
-- again until the focus goes elsewhere.
function F:Done(eb, text)
    CK.field, CK.fieldMouse = nil, false
    if text and eb:IsVisible() then
        local enter = eb:GetScript("OnEnterPressed")
        if enter then xpcall(function() enter(eb) end, geterrorhandler()) end
    end
    if eb:HasFocus() then eb:ClearFocus() end
    self.dismissed = eb:HasFocus() and eb or nil
end

function F:Check()
    local eb = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if eb ~= self.dismissed then self.dismissed = nil end
    if eb ~= self.rejected then self.rejected = nil end
    if not eb or eb == self.dismissed or eb == self.rejected then return end
    if not CK.frame or CK:IsOpen() or InCombatLockdown() or not self:Wanted() then return end
    if not self:Accepts(eb) then
        self.rejected = eb
        return
    end
    self:Open(eb)
end

function F:Init()
    local watcher = CK.NewFrame("Frame")
    local elapsed = 0
    watcher:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < POLL then return end
        elapsed = 0
        F:Check()
    end)
    self.watcher = watcher
end
