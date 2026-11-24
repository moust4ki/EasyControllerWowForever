-- The whole addon without the game, as a session runs it: every file as the
-- TOC lists them, the login, the keyboard, the panel's every row and every
-- choice, the guide, the quick phrases, the slash commands. The game is a
-- stand-in: a frame is a plain object that keeps what it is told (its texts,
-- its fonts), the game's functions answer nothing (a few, fixed values). An
-- error in the addon's code fails the run; what the game does not have in
-- the stand-in is not one (it answers nothing).
--
-- Run from the addon root with Lua 5.1. Alone: every client language, then
-- Russian picked on another client:
--     luajit tools/test_load.lua
-- One session (the client's language, the one picked, the addon's folder):
--     luajit tools/test_load.lua ruRU
--     luajit tools/test_load.lua enUS ruRU
local LOCALE, UILANG = arg[1] or "ruRU", arg[2] ~= "-" and arg[2] or nil
local ROOT = arg[3] or "."
if not arg[1] then
    -- Every session in turn, each in a Lua of its own (a loading is a loading)
    local failed = 0
    for _, case in ipairs({ "ruRU", "enUS ruRU", "frFR", "deDE", "esES", "itIT", "enUS" }) do
        if os.execute(string.format('"%s" "%s" %s', arg[-1], arg[0], case)) ~= 0 then failed = failed + 1 end
    end
    print(failed == 0 and "All 7 sessions passed" or failed .. " session(s) failed")
    os.exit(failed == 0 and 0 or 1)
end
local errors, unknown = {}, {}
local STUB = {}
-- (the addon's version, as the game gives it: the TOC's)
local VERSION = assert(io.open(ROOT .. "/EasyController.toc", "rb")):read("*a"):match("^## Version:%s*(%S+)")
-- What the session must show
local RU = UILANG == "ruRU" or (not UILANG and LOCALE == "ruRU")
local SHOWN = UILANG or LOCALE
local SEND = { ruRU = "Отправить", frFR = "Envoyer", deDE = "Senden", esES = "Enviar", itIT = "Invia", enUS = "Send" }
local MODULES = { ruRU = "Модули", frFR = "Modules", deDE = "Module", esES = "Módulos", itIT = "Moduli", enUS = "Modules" }
local FORUM = "Interface\\AddOns\\EasyController\\Fonts\\Forum-Regular.ttf"
local function expect(ok, what)
    if not ok then errors[#errors + 1] = "expected: " .. what end
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local NOW = 0
local timers = {}
local function utf8len(s) return select(2, tostring(s or ""):gsub("[^\128-\191]", "")) end

local Frame = {}
local NOOP = {}
for name in ([[SetPoint ClearAllPoints SetAlpha SetVertexColor SetShadowColor SetShadowOffset SetRotation SetTexCoord
    SetJustifyH SetJustifyV SetWordWrap SetMaxLines SetTextInsets SetAutoFocus SetMaxLetters SetSpacing SetFrameLevel
    SetFrameStrata SetClampedToScreen SetMovable EnableMouse RegisterForClicks EnableGamePadStick SetMotionScriptsWhileDisabled
    SetDesaturated SetBlinkSpeed SetFocusChain SetToplevel SetResizable SetDontSavePosition SetUserPlaced SetID SetScale
    SetMaxResize SetMinResize SetHitRectInsets SetBackdrop SetBackdropColor SetBackdropBorderColor SetNormalTexture
    SetPushedTexture SetHighlightTexture SetDisabledTexture SetCheckedTexture SetFontObject SetTextColor SetTextInsets
    SetGradient SetGradientAlpha SetHorizTile SetVertTile SetSnapToPixelGrid SetIgnoreParentScale SetFlattenedRenderLayers
    SetIsPassword SetMultiLine SetNumeric SetNumber SetEnabled SetDisabled SetShown LockHighlight UnlockHighlight
    RegisterUnitWatch UnregisterUnitWatch RegisterForDrag SetAllPoints FitToFrameInBounds AddMaskTexture RemoveMaskTexture AddFontString SetFontString
    SetScrollChild SetVerticalScroll SetHorizontalScroll SetInventoryItem SetAction SetSpell SetMacroItem SetMacroSpell
    SetPadding HideTooltip ShowTooltip]]):gmatch("%S+") do NOOP[name] = true end

local ALL = {}
local function new(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, shown = false, scripts = {}, hooks = {},
        events = {}, attrs = {} }, Frame)
    ALL[#ALL + 1] = f
    return f
end

Frame.__index = function(self, key)
    if key == "SetText" then return function(s, text, ...) s.text = text; s.args = { ... } end end
    if key == "GetText" then return function(s) return s.text or "" end end
    if key == "SetFont" then
        return function(s, path, size, flags) s.fontPath, s.fontSize, s.flags = path, tonumber(size) or 12, flags end
    end
    if key == "GetStringWidth" then
        return function(s) return utf8len(s.text) * (s.fontSize or 12) * 0.6 end
    end
    if key == "GetStringHeight" then return function(s) return (s.fontSize or 12) * 1.4 end end
    if key == "GetWidth" or key == "GetHeight" then return function(s) return s[key == "GetWidth" and "width" or "height"] or 100 end end
    if key == "SetWidth" then return function(s, w) s.width = tonumber(w) or 100 end end
    if key == "SetHeight" then return function(s, h) s.height = tonumber(h) or 100 end end
    if key == "SetSize" then return function(s, w, h) s.width, s.height = tonumber(w) or 100, tonumber(h) or 100 end end
    if key == "SetPoint" then return function(s, ...) s.point = { ... }; s.points = (s.points or 0) + 1 end end
    if key == "ClearAllPoints" then return function(s) s.points = 0 end end
    if key == "GetPoint" then return function(s, n) if n and n > (s.points or 0) then return nil end return "CENTER", s.parent, "CENTER", 0, 0 end end
    if key == "GetLeft" or key == "GetBottom" or key == "GetRight" or key == "GetTop" then return function() return 100 end end
    if key == "GetCenter" then return function() return 150, 150 end end
    if key == "GetEffectiveScale" or key == "GetScale" then return function() return 1 end end
    if key == "GetFrameLevel" then return function() return 1 end end
    if key == "GetFrameStrata" then return function() return "DIALOG" end end
    if key == "GetAlpha" then return function(s) return s.alpha or 1 end end
    if key == "Show" then return function(s) s.shown = true end end
    if key == "Hide" then return function(s) s.shown = false end end
    if key == "IsShown" or key == "IsVisible" then return function(s) return s.shown and true or false end end
    if key == "CreateTexture" or key == "CreateMaskTexture" then return function(s, ...) return new("Texture", nil, s) end end
    if key == "CreateAnimationGroup" then return function(s) return new("AnimationGroup", nil, s) end end
    if key == "CreateAnimation" then return function(s) return new("Animation", nil, s) end end
    if key == "CreateFontString" then return function(s, ...) return new("FontString", nil, s) end end
    if key == "CreateLine" then return function(s, ...) return new("Line", nil, s) end end
    if key == "SetTexture" then return function(s, file, ...) s.file = file; return 1 end end
    if key == "GetTexture" then return function(s) return s.file end end
    if key == "GetObjectType" then return function(s) return s.kind or "Frame" end end
    if key == "GetName" then return function(s) return s.name end end
    if key == "GetParent" then return function(s) return s.parent end end
    if key == "SetParent" then return function(s, p) s.parent = p end end
    if key == "SetScript" then return function(s, name, fn) s.scripts[name] = fn end end
    if key == "GetScript" then return function(s, name) return s.scripts[name] end end
    if key == "HookScript" then
        return function(s, name, fn) s.hooks[name] = s.hooks[name] or {}; table.insert(s.hooks[name], fn) end
    end
    if key == "RegisterEvent" then return function(s, e) s.events[e] = true; STUB.watch(e, s) end end
    if key == "UnregisterEvent" then return function(s, e) s.events[e] = nil end end
    if key == "UnregisterAllEvents" then return function(s) for e in pairs(s.events) do s.events[e] = nil end end end
    if key == "IsEventRegistered" then return function(s, e) return s.events[e] and true or false end end
    if key == "SetAttribute" then return function(s, name, value) s.attrs[name] = value end end
    if key == "GetAttribute" then return function(s, name) return s.attrs[name] end end
    if key == "HasFocus" then return function(s) return s.focused and true or false end end
    if key == "SetFocus" then return function(s) s.focused = true; STUB.focus = s end end
    if key == "ClearFocus" then return function(s) s.focused = false; if STUB.focus == s then STUB.focus = nil end end end
    if key == "Click" then return function(s, button) if s.scripts.OnClick then s.scripts.OnClick(s, button or "LeftButton", true) end end end
    if key == "GetCursorPosition" then return function() return 0, 0 end end
    if key == "GetRect" then return function() return 0, 0, 100, 100 end end
    if key == "GetRegions" then return function() return end end
    if key == "GetChildren" then return function() return end end
    if key == "GetNumChildren" then return function() return 0 end end
    if key == "GetHitRectInsets" then return function() return 0, 0, 0, 0 end end
    if key == "IsForbidden" or key == "IsPassword" or key == "IsNumeric" or key == "IsMultiLine" then return function() return false end end
    if key == "IsMouseOver" then return function() return false end end
    if key == "IsMouseEnabled" then return function() return true end end
    if key == "AddMessage" then return function(s, text, ...) s.messages = s.messages or {}; s.messages[#s.messages + 1] = tostring(text) end end
    if key == "AddLine" or key == "AddDoubleLine" then
        return function(s, text, right, ...) s.lines = s.lines or {}; s.lines[#s.lines + 1] = { tostring(text), right and tostring(right) or nil } end
    end
    if key == "ClearLines" then return function(s) s.lines = {} end end
    if key == "NumLines" then return function(s) return s.lines and #s.lines or 0 end end
    if key == "SetOwner" then return function(s, owner) s.owner = owner end end
    if key == "SetHyperlink" then return function() end end
    if key == "GetWidth" then return function() return 100 end end
    local head = key:match("^(%u%l+)[%u]")
    if NOOP[key] or head == "Set" or head == "Enable" or head == "Disable" or head == "Register" or head == "Unregister"
        or head == "Clear" or head == "Start" or head == "Stop" or head == "Hook" or head == "Play" or head == "Pause"
        or head == "Feed" or key == "Raise" or key == "Lower" or key == "Collapse" or key == "Expand"
        or key == "Cancel" or key == "Play" or key == "Pause" or key == "Finish" or key == "SetToFinalAlpha"
        or key == "Stop" or key == "IsPlaying" or key == "IsDone" then
        return function() end
    end
    if head == "Is" or head == "Has" or head == "Can" then return function() return false end end
    if head == "Get" or head == "Num" or head == "Enum" or head == "Get" then return function() return nil end end
    return nil
end

local watch = {}
function STUB.watch(event, frame)
    watch[event] = watch[event] or {}
    for _, f in ipairs(watch[event]) do if f == frame then return end end
    table.insert(watch[event], frame)
end
local function fire(event, ...)
    local count, args = select("#", ...), { ... }
    for _, f in ipairs(watch[event] or {}) do
        local script = f.scripts.OnEvent
        if script and f.events[event] then
            -- (a closure: Lua 5.1's xpcall gives a function no arguments, LuaJIT's does)
            local ok, err = xpcall(function() return script(f, event, unpack(args, 1, count)) end,
                function(e) return debug.traceback(tostring(e), 2) end)
            if not ok then errors[#errors + 1] = "event " .. event .. ": " .. tostring(err) end
        end
    end
end
local function flush()
    local n = 0
    while #timers > 0 and n < 200 do
        local t = table.remove(timers, 1)
        n = n + 1
        local ok, err = xpcall(t.fn, function(e) return debug.traceback(tostring(e), 2) end)
        if not ok then errors[#errors + 1] = "timer: " .. tostring(err) end
    end
end

---------------------------------------------------------------------------
-- The game's functions
---------------------------------------------------------------------------
local editBoxes = {}
function STUB.GetLocale() return LOCALE end
function STUB.GetTime() NOW = NOW + 0.017; return NOW end
function STUB.GetCVar() return "1" end
function STUB.GetCVarBool() return false end
function STUB.GetBuildInfo() return "1.60.1", "60100", "Forever", 16001 end
function STUB.UnitName(unit) if unit == "player" then return "Тест" end return "Моб" end
function STUB.UnitGUID() return "Player-6942-000689C3" end
function STUB.UnitLevel() return 60 end
function STUB.GetRealmName() return "Тестовый realm" end
function STUB.GetNormalizedRealmName() return "TestRealm" end
function STUB.InCombatLockdown() return false end
function STUB.IsInGroup() return false end
function STUB.IsInRaid() return false end
function STUB.IsInGuild() return false end
function STUB.GetNumGroupMembers() return 0 end
function STUB.GetNumGuildMembers() return 0 end
function STUB.GetChannelName() return 0 end
function STUB.GetCurrentKeyBoardFocus() return STUB.focus end
function STUB.IsMouseButtonDown() return false end
function STUB.IsKeyDown() return false end
function STUB.GetBindingAction() return nil end
function STUB.GetBindingText(key) return key end
function STUB.strcmputf8i(a, b) return a < b and -1 or (a > b and 1 or 0) end
function STUB.strlenutf8(s) return utf8len(s) end
function STUB.issecretvalue() return false end
function STUB.issecurevalue() return true, "test" end
function STUB.debugstack() return "stack" end
function STUB.GetAddOnMetadata() return VERSION end
function STUB.GetMouseFoci() return {} end
function STUB.GetMouseFocus() return nil end
function STUB.BreakUpLargeNumbers(n) return tostring(n) end
function STUB.GetSpellInfo(id) return "Заклинание" .. tostring(id), nil, nil, 1 end
function STUB.GetItemInfo() return nil end
function STUB.GetItemInfoInstant() return nil end
function STUB.GetNumBuybackItems() return 0 end
function STUB.GetNumQuestLogEntries() return 0 end
function STUB.GetRealZoneText() return "" end
STUB.wipe = function(t) for k in pairs(t) do t[k] = nil end end
STUB.format = string.format
STUB.gsub = string.gsub
STUB.strsplit = function(sep, text)
    local out = {}
    for piece in (text .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
    return unpack(out)
end
STUB.CreateFrame = function(kind, name, parent, template)
    local f = new(kind, name, parent)
    if name then rawset(STUB, name, f) end
    if kind == "EditBox" then editBoxes[#editBoxes + 1] = f end
    return f
end
STUB.UIParent = new("Frame", "UIParent")
STUB.GameTooltip = new("GameTooltip", "GameTooltip")
STUB.ItemRefTooltip = new("GameTooltip", "ItemRefTooltip")
STUB.ChatFontNormal = new("FontString", "ChatFontNormal")
STUB.GameFontNormal, STUB.GameFontDisable, STUB.GameFontNormalLarge, STUB.GameFontHighlight, STUB.GameFontHighlightSmall =
    new("Font"), new("Font"), new("Font"), new("Font"), new("Font")
STUB.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__" .. (LOCALE == "ruRU" and "_CYR" or "") .. ".TTF"
STUB.NUM_CHAT_WINDOWS = 10
for i = 1, 10 do
    local eb = new("EditBox", "ChatFrame" .. i .. "EditBox")
    eb.attrs.chatType = "SAY"
    rawset(STUB, "ChatFrame" .. i .. "EditBox", eb)
    rawset(STUB, "ChatFrame" .. i, new("Frame", "ChatFrame" .. i))
end
STUB.DEFAULT_CHAT_FRAME = rawget(STUB, "ChatFrame1")
STUB.ChatTypeInfo = { SAY = { r = 1, g = 1, b = 1 }, YELL = { r = 1, g = 0.3, b = 0.3 }, PARTY = { r = 0.7, g = 0.7, b = 1 },
    RAID = { r = 1, g = 0.5, b = 0 }, GUILD = { r = 0.3, g = 1, b = 0.3 }, CHANNEL1 = { r = 0.8, g = 0.7, b = 0.7 },
    WHISPER = { r = 1, g = 0.6, b = 1 } }
STUB.SlashCmdList = {}
STUB.hooksecurefunc = function() end
STUB.C_Timer = {
    After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end,
    NewTimer = function() return new("Timer") end,
    NewTicker = function() return new("Ticker") end,
}
local namespaces = {}
local function ns(name)
    if namespaces[name] then return namespaces[name] end
    local t = setmetatable({}, { __index = function(_, fn)
        if fn == "GetItemNameByID" then return function(id) return "Предмет " .. id end end
        if fn == "GetSpellName" then return function(id) return "Заклинание " .. id end end
        if fn == "GetSpellInfo" then return function(id) return "Заклинание " .. id end end
        if fn == "GetItemCount" then return function() return 0 end end
        if fn == "GetContainerNumSlots" then return function() return 0 end end
        if fn == "GetContainerItemID" then return nil end
        if fn == "GetContainerNumFreeSlots" then return function() return 0, 0 end end
        if fn == "GetContainerItemInfo" then return nil end
        if fn == "GetContainerItemQuestInfo" then return nil end
        if fn == "GetContainerItemLink" then return nil end
        if fn == "GetNumQuestLogEntries" then return function() return 0 end end
        if fn == "GetQuestObjectives" then return function() return {} end end
        if fn == "GetInfo" then return nil end
        if fn == "GetActiveDeviceID" then return function() return nil end end
        if fn == "GetDeviceMappedState" then return nil end
        if fn == "GetDeviceRawState" then return nil end
        if fn == "GetAtlasInfo" then return nil end
        if fn == "GetFriendInfoByIndex" then return nil end
        if fn == "GetNumFriends" then return function() return 0 end end
        if fn == "GetGuildRosterInfo" then return nil end
        if fn == "GetNumGuildMembers" then return function() return 0 end end
        if fn == "GetAddOnMetadata" then return function() return VERSION end end
        if fn == "IsAddOnLoaded" then return function() return false end end
        if fn == "GetItemSpell" then return nil end
        if fn == "IsEquippableItem" then return function() return false end end
        if fn == "GetItemIconByID" then return nil end
        if fn == "GetNumFreeBagSlots" then return function() return 0 end end
        return function() return nil end
    end })
    namespaces[name] = t
    return t
end
STUB.C_Item = ns("C_Item")
STUB.C_Spell = ns("C_Spell")
STUB.C_Container = ns("C_Container")
STUB.C_QuestLog = ns("C_QuestLog")
STUB.C_GamePad = ns("C_GamePad")
STUB.C_Texture = ns("C_Texture")
STUB.C_FriendList = ns("C_FriendList")
STUB.C_TooltipInfo = ns("C_TooltipInfo")
STUB.C_ChatInfo = { SendChatMessage = function() end }
STUB.C_AddOns = { GetAddOnMetadata = function() return VERSION end, IsAddOnLoaded = function() return false end }
STUB.C_CVar = { GetCVar = function() return "1" end, SetCVar = function() end, GetCVarBool = function() return false end }
STUB.C_UI = { Reload = function() errors[#errors + 1] = "Reload called" end }
STUB.C_BattleNet = {}
STUB.Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return nil end }) end })
STUB.SmartNavigation = nil
STUB.Settings = { RegisterCanvasLayoutCategory = function(panel, name) return { name = name } end,
    RegisterAddOnCategory = function() end }
STUB.EventRegistry = { RegisterCallback = function(_, event, fn, owner) STUB.callbacks = STUB.callbacks or {}; STUB.callbacks[event] = STUB.callbacks[event] or {}
    table.insert(STUB.callbacks[event], fn) end }

-- The game's frames and tables the addon looks for, none open in the session
local NILS = {}
for name in ([[GamepadMainActionBarFrame GamepadStanceBarFrame GamepadStanceBarOverride PlayerSpellsFrame SpellBookFrame
    ChatFrameUtil TooltipDataProcessor TooltipDataSink EditModeManagerEditModeFrameSettingsContainerEditModeFrameSettingsBase
    GamepadMode InputUtil SmartNavigation UIErrorsFrame RaidClassColors ClassColor HUD_EDIT_MODE_MENU EventUtil
    ContainerFrameCombinedBags GameMenuFrame SettingsPanel KeyBindingFrame StaticPopup1 GameTooltip ShoppingTooltip1
    ItemRefTooltip WorldFrame SpellButton PendingGlueParent ModelSceneAddonCamera ]]):gmatch("%S+") do NILS[name] = true end
NILS.GameTooltip, NILS.ItemRefTooltip, NILS.UIErrorsFrame = nil, nil, nil
local API = {}
for name in ([[Ambiguate BNet_GetBNetIDAccount BreakUpLargeNumbers CanDualWield CanGuildBankRepair CanMerchantRepair ClearCursor ClearOverrideBindings CreateCatmullRomSpline CreateColor GetActionBarPage GetActionInfo GetActionText GetActionTexture GetBinding GetBindingAction GetBindingName GetBindingText GetBonusBarOffset GetBuybackItemLink GetCVar GetCVarBool GetChannelName GetCurrentKeyBoardFocus GetCursorInfo GetCursorPosition GetFlyoutInfo GetGamePadState GetGuildBankMoney GetGuildBankWithdrawMoney GetGuildRosterInfo GetInventoryItemCount GetInventoryItemDurability GetInventoryItemID GetInventoryItemLink GetInventoryItemTexture GetItemCount GetItemInfo GetItemInfoInstant GetLocale GetMacroIndexByName GetMacroInfo GetMacroItem GetMacroSpell GetModifiedClick GetMoney GetMoneyString GetMouseFoci GetMouseFocus GetNumBindings GetNumBuybackItems GetNumGroupMembers GetNumGuildMembers GetNumMacros GetNumPartyMembers GetNumQuestLogEntries GetNumRaidMembers GetNumShapeshiftForms GetNumTalentTabs GetQuestLink GetQuestLogTitle GetRepairAllCost GetServerTime GetSpellInfo GetSpellTexture GetTalentTabInfo GetTime GetTimePrecise HasAction InCombatLockdown InterfaceOptions_AddCategory IsAltKeyDown IsControlKeyDown IsInGroup IsInGuild IsInRaid IsKeyDown IsModifiedClick IsMouseButtonDown IsPlayerSpell IsShiftKeyDown IsSpellKnown PickupAction PickupMacro PlaceAction PlayerCanAssist PlayerCanAttack RepairAllItems SecureHandlerExecute SecureHandlerSetFrameRef SecureHandlerWrapScript SetCVar SetOverrideBinding SetOverrideBindingClick SetPortraitTexture UIFrameFadeIn UnitAffectingCombat UnitChannelInfo UnitClass UnitExists UnitFactionGroup UnitGUID UnitHealth UnitHealthMax UnitHealthPercent UnitInRange UnitIsConnected UnitIsDead UnitIsDeadOrGhost UnitLevel UnitName UnitThreatSituation date debugstack hooksecurefunc issecretvalue issecurevariable strcmputf8i strlenutf8i strfind strsplit strsub wipe format gsub geterrorhandler min find]]):gmatch("%S+") do API[name] = true end
NILS.C_SpellBook = true
function STUB.UnitClass() return "Воин", "WARRIOR" end
function STUB.UnitFactionGroup() return "Alliance" end
function STUB.UnitHealth() return 100 end
function STUB.UnitHealthMax() return 100 end
function STUB.UnitHealthPercent() return 100 end
function STUB.UnitInRange() return true end
function STUB.UnitIsDead() return false end
function STUB.UnitIsDeadOrGhost() return false end
function STUB.UnitIsConnected() return true end
function STUB.UnitExists() return true end
function STUB.UnitAffectingCombat() return false end
function STUB.GetMoney() return 123456 end
function STUB.GetMoneyString(money) return tostring(money) end
function STUB.GetServerTime() return NOW end
function STUB.GetTimePrecise() return NOW end
function STUB.GetNumTalentTabs() return 3 end
function STUB.GetNumShapeshiftForms() return 0 end
function STUB.GetNumMacros() return 0 end
function STUB.GetNumBindings() return 0 end
function STUB.date(fmt) return os.date(fmt or "!%Y-%m-%d %H:%M:%S") end
function STUB.min(a, b) return math.min(tonumber(a) or 0, tonumber(b) or 0) end
function STUB.CreateColor(r, g, b, a)
    return { r = tonumber(r) or 0, g = tonumber(g) or 0, b = tonumber(b) or 0, a = tonumber(a) or 1,
        GetRGB = function(c) return c.r, c.g, c.b end, GenerateHexColorMarkup = function() return "|cffffffff" end }
end
function STUB.GetModifiedClick() return "SHIFT" end
function STUB.IsModifiedClick() return false end
function STUB.hooksecurefunc() end

local env = setmetatable({}, {
    __index = function(_, key)
        local value = STUB[key]
        if value ~= nil then return value end
        if _G[key] ~= nil then return _G[key] end
        if key:match("^C_[%u_]") and not NILS[key] then return ns(key) end
        if API[key] then
            unknown[key] = (unknown[key] or 0) + 1
            return function() return nil end
        end
        return nil
    end,
    __newindex = function(t, key, value) rawset(t, key, value) end,
})
env._G = env
env.GetLocale = STUB.GetLocale
env.geterrorhandler = function() return function(err) errors[#errors + 1] = tostring(err) end end
env.strsplit = STUB.strsplit

---------------------------------------------------------------------------
-- The files, the session
---------------------------------------------------------------------------
local CK = {}
local order = {}
for line in io.open(ROOT .. "/EasyController.toc"):lines() do
    if line:match("%.lua$") then order[#order + 1] = line:gsub("\\", "/") end
end
-- (Paddles.lua has an escape the game's Lua 5.1 takes and LuaJIT refuses:
-- a backslash before a letter, read as the letter alone by 5.1)
local function load1(file)
    local chunk, err = loadfile(ROOT .. "/" .. file)
    if chunk then return chunk end
    if not tostring(err):find("invalid escape") then return nil, err end
    local text = io.open(ROOT .. "/" .. file):read("a")
    local out, i = {}, 1
    while i <= #text do
        local c = text:sub(i, i)
        if c == "\\" then
            local n = text:sub(i + 1, i + 1)
            if n == "" or n:match("[%d\\ntr\"']") then out[#out + 1] = text:sub(i, i + 1); i = i + 2
            else out[#out + 1] = "\\\\" .. n; i = i + 2 end
        else out[#out + 1] = c; i = i + 1 end
    end
    chunk, err = loadstring(table.concat(out), "@" .. file)
    print("  (loaded " .. file .. " with its stray backslashes doubled)")
    return chunk, err
end
local function loadAll()
    for _, file in ipairs(order) do
        local chunk, err = load1(file)
        if not chunk then errors[#errors + 1] = "LOAD " .. file .. ": " .. tostring(err) break end
        local ok, e = pcall(setfenv(chunk, env), "EasyController", CK)
        if not ok then errors[#errors + 1] = "RUN " .. file .. ": " .. tostring(e) end
    end
end
local function step(name, fn, ...)
    -- (a closure: Lua 5.1's xpcall gives a function no arguments, LuaJIT's does)
    local count, args = select("#", ...), { ... }
    local ok, err = xpcall(function() return fn(unpack(args, 1, count)) end,
        function(e) return debug.traceback(tostring(e), 2) end)
    if not ok then errors[#errors + 1] = name .. ": " .. tostring(err) end
    flush()
end

loadAll()
step("ADDON_LOADED", fire, "ADDON_LOADED", "EasyController")
if UILANG then step("uiLang", function() CK:SetUILanguage(UILANG); CK:ApplyLocale(CK:UILocale()); CK.DefinePages() end) end
step("PLAYER_LOGIN", fire, "PLAYER_LOGIN")
step("PLAYER_ENTERING_WORLD", fire, "PLAYER_ENTERING_WORLD")

local function early()
    print(string.format("== after loading and login: %d errors", #errors))
    for _, e in ipairs(errors) do print("ERROR " .. e) end
end
local function dump()
earlyCount = #errors
    early()
    local L = CK.L
    print(string.format("== %s%s: locale in use %s, language %s, layout %s, font %s, Cyrillic %s", LOCALE, UILANG and " + " .. UILANG or "",
        tostring(CK.locale), tostring(CK.db.settings.lang), tostring(CK.db.settings.kbLayout), tostring(CK:GetFontPath()),
        tostring(CK:Cyrillic())))
    print("texts: SEND=" .. L.SEND .. " | TAB_HOME=" .. L.TAB_HOME .. " | METHOD_STICK=" .. L.METHOD_STICK)
    local pages = CK.Config and CK.Config.pages or {}
    for key, page in pairs(pages) do
        local titles = {}
        if page.def then for _, sec in ipairs(page.def.sections) do titles[#titles + 1] = tostring(sec.label) end end
        print("page " .. key .. ": " .. table.concat(titles, " › "))
    end
    print("loaded message: " .. tostring((rawget(STUB, "ChatFrame1").messages or {})[1]))
    expect(L.SEND == SEND[SHOWN], "the texts in " .. SHOWN .. " (SEND is " .. tostring(L.SEND) .. ")")
    expect(CK.locale == SHOWN, "the locale in use " .. SHOWN)
    local home = CK.Config.pages.home
    expect(home and home.def.sections[1].label == MODULES[SHOWN], "the panel's pages titled in " .. SHOWN)
    expect(CK.db.settings.lang == (RU and "ru" or ({ frFR = "fr", deDE = "de", esES = "es", itIT = "it" })[SHOWN] or "en"),
        "the suggestions' language")
    expect(CK.db.settings.kbLayout == (RU and "russian" or ({ frFR = "azerty", deDE = "qwertz", esES = "qwerty_es",
        itIT = "qwerty_it" })[SHOWN] or "qwerty"), "the keyboard layout")
    expect(CK:Cyrillic() == RU, "Russian on screen")
    -- The font: the game's own on a Russian client, the addon's elsewhere,
    -- the game's Latin files otherwise
    local font = CK:GetFontPath()
    if RU then
        expect(font == (LOCALE == "ruRU" and STUB.STANDARD_TEXT_FONT or FORUM), "the font with Russian letters (" .. font .. ")")
    else
        expect(font == "Fonts\\FRIZQT__.TTF", "the game's font (" .. tostring(font) .. ")")
    end
end
dump()

-- The keyboard
local function withKeyboard(method, lang, fn)
    step("keyboard " .. method, function()
        CK:SetInputMethod(method)
        local eb = rawget(STUB, "ChatFrame1EditBox")
        eb.focused = true
        CK:Open(eb)
        CK.state.layer = "letters"
        fn(CK)
        CK:Close("test")
    end)
    flush()
end

local function typeText(ck, text)
    for ch in text:gmatch("[^\128-\191][\128-\191]*") do ck:TypeChar(ch) end
end

for _, method in ipairs({ "wheel", "stick" }) do
    withKeyboard(method, nil, function(ck)
        typeText(ck, "прив")
        print(string.format("  [%s] typed «прив»: suggestions = %s", method, table.concat(ck.state.suggestions, " | ")))
        ck:AcceptSuggestion(1)
        print(string.format("  [%s] after the suggestion: «%s» (buffer %d bytes)", method, ck:GetText(), #ck:GetText()))
        typeText(ck, "мир")
        print(string.format("  [%s] «%s»", method, ck:GetText()))
        -- 123: punctuation, back
        ck:ToggleSymbols()
        if method == "wheel" then ck:TypeSlot(4, 2) else ck:TypeChar(".") end
        ck:ToggleSymbols()
        print(string.format("  [%s] with a dot: «%s»", method, ck:GetText()))
        print(string.format("  [%s] macro: %s", method, tostring(ck:BuildMacroText())))
        expect(ck:GetText() == (RU and "привет мир." or ck:GetText()), "«привет мир.» typed on the " .. method)
        if RU then
            expect(ck.state.suggestions[1] == "привет", "«привет» offered first for «прив» (" ..
                tostring(ck.state.suggestions[1]) .. ")")
        end
        expect(ck:BuildMacroText() == "/s " .. ck:GetText(), "the message goes to /s")
        -- The Latin letters
        ck:ToggleSymbols(); ck:ToggleSymbols()
        local latin = method == "wheel" and ck:TypeSlot(1, 1) or function() end
        if method == "wheel" then latin() end
        print(string.format("  [%s] latin=%s letters label=%s, text «%s»", method, tostring(ck.state.latin), ck:LettersLabel(), ck:GetText()))
        expect((ck.state.latin and true or false) == RU, "a quick second press on 123: the Latin letters with Russian, nothing otherwise")
        expect(ck:LettersLabel() == "abc", "the label of the letters a press gives back")
        ck:ToggleSymbols(); ck:ToggleSymbols()
    end)
end

-- The panel: every tab, section, row
local function choices(page, id, times)
    -- A choice row stepped through all its values (back to the one in use)
    page:Rebuild()
    local row
    for _, r in ipairs(page.rows) do if r.id == id then row = r end end
    if not row then return "(no row " .. id .. ")" end
    local names = {}
    for _ = 1, times do
        page:Act(row, 1)
        names[#names + 1] = tostring(row.text())
        page:Render()
        page:Help()
        page:Detail()
    end
    for _ = 1, times do page:Act(row, -1) end
    return table.concat(names, " › ")
end

step("panel", function()
    local C = CK.Config
    C:Build()
    C.frame.shown = true
    for _, tab in ipairs(C.TABS) do
        C:SetTab(tab)
        local page = C:Page()
        if page.def then
            for i, sec in ipairs(page.def.sections) do
                page:SetSection(i, "list")
                page:Render()
                page:Rebuild()
                for row = 1, #page.rows do
                    local r = page.rows[row]
                    if r.kind ~= "header" then
                        page.zone = "list"
                        page:SetFocus(row)
                        page:Render()
                        page:Help()
                        page:Detail()
                        page:Crumb()
                    end
                end
            end
            local seen = {}
            for i in ipairs(page.def.sections) do
                page:SetSection(i, "list")
                page:Rebuild()
                for _, r in ipairs(page.rows) do
                    if r.kind == "choice" and not seen[r.id] then
                        seen[r.id] = true
                        local n = 0
                        local copy = page.rows
                        -- (as many steps as the row has values: until it comes back)
                        local first = tostring(r.text())
                        local names = {}
                        for _ = 1, 12 do
                            page:Act(r, 1)
                            local name = tostring(r.text())
                            if name == first then break end
                            names[#names + 1] = name
                        end
                        for _ = 1, #names + 1 do page:Act(r, -1) end
                        print(string.format("  %s › %s (%s): %s", tab, r.id, first, table.concat(names, " › ")))
                        n = n + 1
                    end
                end
            end
            page.zone = "rail"
            page:Render()
            page:Help()
        end
    end
end)
flush()

-- The language row: a language picked, then the row offering a reload
step("language row", function()
    local C = CK.Config
    C:SetTab("home")
    local page = C:Page()
    page:SetSection(3, "list")
    print("  languages: " .. choices(page, "lang", 6))
    page:Rebuild()
    local hasReload = function()
        for _, r in ipairs(page.rows) do if r.id == "lang_reload" then return true end end
        return false
    end
    print("  reload row before any change: " .. tostring(hasReload()))
    page:Rebuild()
    local row
    for _, r in ipairs(page.rows) do if r.id == "lang" then row = r end end
    page:Act(row, 1)
    print("  reload row after a language picked: " .. tostring(hasReload()) .. " (asked " .. tostring(CK:UILocale()) ..
        ", on screen " .. tostring(CK.locale) .. ")")
    page:Act(row, -1)
    print("  reload row back to the client's: " .. tostring(hasReload()))
    expect(hasReload() == (CK:UILocale() ~= CK.locale),
        "a reload offered when the language asked for is not the one on screen")
    expect(CK:UILocale() == (UILANG or LOCALE), "the language asked for")
end)

-- The guide
step("guide", function()
    local G = CK.Guide
    G:Open(1)
    for _ = 1, 12 do
        G:Render()
        G:RenderHelp()
        G:Press("RB")
        flush()
    end
    if G.Close then G:Close() end
end)

-- The phrases
step("phrases", function()
    local P = CK.Phrases
    P:Open(nil)
    P:Render()
    for _, row in ipairs(P:Grid().rows) do
        print("  phrases: " .. tostring(row.name) .. ": " .. table.concat(row.tiles, " | "))
    end
    P:Close("test")
end)

-- The slash commands
step("commands", function()
    local slash = env.SlashCmdList.CONTROLLERKEYBOARD
    for _, cmd in ipairs({ "lang ru", "layout ru", "ui ru", "layout qwerty", "lang en", "ui auto", "ui", "layout",
        "lang", "ЯЗЫК ru" }) do
        step("command /ec " .. cmd, slash, cmd)
    end
    local messages = rawget(STUB, "ChatFrame1").messages or {}
    local last = {}
    for i = math.max(1, #messages - 6), #messages do last[#last + 1] = tostring(messages[i]):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
    print("  last messages: " .. table.concat(last, "\n    "))
end)

-- What was drawn with: the fonts, and no text without a font
do
    local fonts, noFont = {}, 0
    for _, f in ipairs(ALL) do
        if f.kind == "FontString" or f.kind == "EditBox" then
            if f.fontPath then fonts[f.fontPath] = (fonts[f.fontPath] or 0) + 1
            elseif f.text then noFont = noFont + 1 end
        end
    end
    local list = {}
    for path, n in pairs(fonts) do list[#list + 1] = path .. " x" .. n end
    table.sort(list)
    print("fonts drawn with: " .. table.concat(list, "; ") .. " | texts without a font: " .. noFont)
    local cyr = 0
    for _, f in ipairs(ALL) do
        if type(f.text) == "string" and f.text:find("[\208\209]") then cyr = cyr + 1 end
    end
    print("texts drawn with Russian letters: " .. cyr)
end
print(string.format("== errors: %d", #errors))
for i = earlyCount + 1, #errors do print("ERROR " .. errors[i]) end
local names = {}
for name in pairs(unknown) do names[#names + 1] = name end
table.sort(names)
print("unknown game functions called: " .. table.concat(names, ", "))
if #errors > 0 then os.exit(1) end
