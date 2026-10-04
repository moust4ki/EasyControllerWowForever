-- Run from the addon directory with Lua 5.1. Native edit boxes are read-only
-- spies; all channel, open/close, draft and macro behavior uses Message.lua.
local function noop() end
local function fixture()
    local writes, textWrites, grouped = {}, 0, true
    local box = { attrs = { chatType = "SAY", stickyType = "SAY" }, text = "" }
    function box:GetAttribute(key)
        -- WoW may return no values for an absent attribute.
        if self.attrs[key] ~= nil then return self.attrs[key] end
    end
    function box:SetAttribute(key, value)
        writes[#writes + 1] = { key, value }; self.attrs[key] = value
    end
    function box:GetText() return self.text end
    function box:SetText(value) textWrites = textWrites + 1; self.text = value end
    local frame = { shown = false }
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    local CK = {
        L = {}, WORD_CHARS = "%a", frame = frame,
        db = { settings = { stickyChannel = true, modules = { keyboard = true }, features = { drafts = false } } },
        Refresh = noop, UpdateMethod = noop, EnableButtons = noop, DisableButtons = noop,
        GetMethod = function() return { Reset = noop } end,
    }
    local env = setmetatable({
        ChatFrame1EditBox = box, InCombatLockdown = function() return false end,
        GetTime = function() return 100 end, IsInGroup = function() return grouped end,
        IsInRaid = function() return false end, IsInGuild = function() return false end,
        GetChannelName = function(id) return id, "Channel " .. id end,
    }, { __index = _G })
    local chunk = assert(loadfile("Message.lua")); setfenv(chunk, env); chunk("EasyController", CK)
    CK.Refresh = noop -- UI boundary, not the channel/message behavior under test.
    local function pristine()
        assert(#writes == 0, "native chat attributes were written " .. #writes .. " times")
        assert(textWrites == 0, "native chat text was written")
    end
    return CK, box, pristine, writes, function(value) grouped = value end
end

for _, case in ipairs({ { 1, "SAY", "/s hi" }, { 3, "PARTY", "/p hi" }, { 6, "CHANNEL", "/1 hi" } }) do
    local CK, box, pristine, writes = fixture()
    CK:Open(box); CK:SetChannel(case[1]); CK:SetText("hi")
    assert(CK:GetChatAttr("chatType") == case[2] and CK:BuildMacroText() == case[3])
    if #writes > 0 then print("BASELINE: channel selection wrote " .. #writes .. " native chat attributes") end
    pristine()
    CK:Close("sent"); CK:Open(box)
    assert(CK:GetChatAttr("chatType") == case[2], "chosen channel was not remembered")
    if case[2] == "CHANNEL" then assert(CK:GetChatAttr("channelTarget") == 1) end
    assert(box.attrs.chatType == "SAY" and box.attrs.stickyType == "SAY")
    -- Opening yields a snapshot, never the stored remembered table itself.
    CK:SetChatAttr("channelTarget", 99)
    assert(CK.sticky.channelTarget ~= 99)
    pristine()
end
print("PASS: say/party/numbered channels stay addon-owned, reopen correctly and preserve native text/attributes")

do
    local CK, box, pristine = fixture()
    CK:Open(box); CK:SetChannel(3); CK:SetChannel(7)
    assert(CK:WhisperNameMode() and CK.sticky.chatType == "PARTY", "incomplete whisper must not replace remembered channel")
    CK:ConfirmWhisperTarget("  Alice-Realm  ")
    assert(CK:GetChatAttr("tellTarget") == "Alice-Realm" and CK:GetText() == "")
    CK:Close("sent"); CK:Open(box)
    assert(CK:GetChatAttr("chatType") == "WHISPER" and CK:GetChatAttr("tellTarget") == "Alice-Realm")
    CK:SetText("hello"); assert(CK:BuildMacroText() == nil, "whisper still uses the direct whisper sender")
    pristine()
end
print("PASS: incomplete/confirmed whispers keep recipient boundaries without native writes")

do
    local CK, box, pristine = fixture()
    CK.db.settings.stickyChannel = false
    CK:Open(box); CK:SetChannel(3); CK:SetText("hi")
    assert(CK:BuildMacroText() == "/p hi", "disabled remembering must still permit a current channel choice")
    CK:Close("sent"); CK:Open(box)
    assert(CK:GetChatAttr("chatType") == "SAY")
    CK.db.settings.stickyChannel = true; CK:SetChannel(3); CK:Close("sent")
    CK.db.settings.stickyChannel = false; CK:Open(box)
    assert(CK:GetChatAttr("chatType") == "SAY", "disabled setting must ignore an existing remembered choice")
    pristine()
end
print("PASS: disabling remembered channels leaves current sending and native defaults intact")

do
    local CK, box, pristine = fixture()
    CK:Open(box); CK:SetChannel(3); CK:Close("sent")
    box.attrs.chatType, box.attrs.stickyType, box.attrs.channelTarget = "CHANNEL", "CHANNEL", 2
    CK:Open(box)
    assert(CK:GetChatAttr("chatType") == "CHANNEL" and CK:GetChatAttr("channelTarget") == 2)
    assert(CK.sticky == nil, "a later game channel selection must supersede the remembered choice")
    CK:SetChannel(3); CK:Close("sent")
    box.attrs.channelTarget = 3; CK:Open(box)
    assert(CK:GetChatAttr("channelTarget") == 3 and CK.sticky == nil)
    CK:SetChannel(3); CK:Close("sent")
    box.text = "/guild hello"; CK:Open(box)
    assert(CK.chatAttrs == nil and CK:BuildMacroText() == "/guild hello")
    pristine()
end
print("PASS: native channel/target changes and explicit slash commands override remembered channels")

do
    local CK, box, pristine = fixture()
    CK.db.settings.features.drafts = true
    CK:Open(box); CK:SetChannel(7); CK:ConfirmWhisperTarget("Alice")
    CK:SetText("private draft"); CK:Close("chat deactivated")
    box.attrs.chatType, box.attrs.tellTarget = "WHISPER", "Bob"
    CK:Open(box)
    assert(CK:GetChatAttr("tellTarget") == "Bob" and CK:GetText() == "" and CK.draft.target == "Alice")
    CK:Close("sent")
    -- A temporary native whisper has ended; restore its original sticky basis.
    box.attrs.chatType, box.attrs.tellTarget = "SAY", nil
    CK:Open(box)
    assert(CK:GetChatAttr("tellTarget") == "Alice" and CK:GetText() == "private draft" and CK.draft == nil)
    CK:Close("sent")
    box.attrs.chatType, box.attrs.tellTarget = "BN_WHISPER", "77"
    CK:Open(box)
    assert(CK:GetChatAttr("chatType") == "BN_WHISPER" and CK:GetChatAttr("tellTarget") == "77")
    pristine()
end
print("PASS: explicit whisper/BN targets win and a saved private draft only returns to its remembered recipient")

do
    local CK, box, pristine, _, setGrouped = fixture()
    CK:Open(box); CK:SetChannel(3); CK:NoteChannelsFrom(); CK:SetChannel(2); CK:RestoreChannelsFrom()
    CK:Close("sent"); CK:Open(box)
    assert(CK:GetChatAttr("chatType") == "PARTY", "returning from channel navigation must restore the remembered choice")
    CK:Close("sent"); setGrouped(false); CK:Open(box)
    assert(CK:GetChatAttr("chatType") == "SAY", "unavailable remembered party must fall back to native channel")
    pristine()
end
print("PASS: channel-row restoration and unavailable-group fallback preserve current behavior")
