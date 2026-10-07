local _, CK = ...

---------------------------------------------------------------------------
-- Input method "ConsolePort" (asked: ConsolePort's keyboard, its layout and
-- its prediction, as a third method next to the daisywheel and the split
-- keyboard). Ported from ConsolePort 3.3.9: ConsolePort_Keyboard (layout,
-- charsets, word suggester, scoring, UTF-8 helpers) and the pieces of
-- ConsolePort it uses (radial maths, spline line, the pie menu's needle).
--
-- ConsolePort: Copyright (c) 2022 Sebastian Lindfors, The Artistic License
-- 2.0, https://github.com/seblindfors/ConsolePort. This is a Modified
-- Version; LICENSE-ConsolePort.md holds the license and lists what differs
-- from the Standard Version:
-- * the text: the keyboard's own buffer (Message.lua), never the chat's
--   edit box (an addon writing there gets WoW Forever's chat tainted). B
--   (Enter) and Y (Escape) go through secure macro buttons: the game sends
--   the message, the game's own B closes its chat
-- * the buttons: the addon's override bindings while the keyboard is open
--   (Input.lua), not OnGamePadButtonDown
-- * the dictionary: the addon's (Predict.lua: its languages, what the
--   player sends), ranked with ConsolePort's scoring, compared without
--   accents ("tres" finds "très")
-- * the accents of the language on the Alt layer (RT), empty in ConsolePort
-- * the keyboard opens where it was left; with no group chosen the right
--   stick moves it (ConsolePort moves the mouse cursor, the keyboard follows)
-- * a channel line above the text (asked): D-pad left / right change the
--   channel (the addon's list), LB + left / right move the cursor; a whisper
--   to no one yet: the known names suggested, RB picks one
-- * the addon's prediction first (asked): the next word from the context
--   when nothing is typed, the word's completions in its context, a
--   command's; ConsolePort's matches (typos forgiven) after them
-- * frames built in Lua (no XML templates); the layout is not editable
---------------------------------------------------------------------------
CK.Methods = CK.Methods or {}
local M = { key = "consoleport", floating = true, ownButtons = true, width = 160, areaWidth = 160, height = 160 }
CK.Methods.consoleport = M

local TEX = "Interface\\AddOns\\EasyController\\textures\\consoleport\\"
local ESCAPE_BUTTON = "ControllerKeyboardEscapeButton"

local Clamp = Clamp or function(v, lo, hi) return math.min(math.max(v, lo), hi) end
local Lerp = Lerp or function(a, b, t) return a + (b - a) * t end
local function InCubic(p) return p * p * p end
local function InQuadratic(p) return p * p end
local function ClampedPercentageBetween(value, startValue, endValue)
    if startValue == endValue then return 0 end
    return Clamp((value - startValue) / (endValue - startValue), 0, 1)
end

---------------------------------------------------------------------------
-- Default data (ConsolePort_Keyboard/Database.lua)
---------------------------------------------------------------------------
local function _(t) return ([[|TInterface\%s:0|t]]):format(t) end

-- 8 sets around the ring (top first, clockwise), 4 keys each (top, right,
-- bottom, left: Y, B, A, X), one character per state: none, Shift, Ctrl,
-- Shift+Ctrl (then Alt and its combinations). "||" is the pipe, escaped for
-- the chat.
local DefaultLayout = {
    {
        { "a", "A", "1", "/s " },
        { "b", "B", "2", "/p " },
        { "c", "C", "3", "/i " },
        { "d", "D", "4", "/g " },
    },
    {
        { "e", "E", "5", "/y " },
        { "f", "F", "6", "/w " },
        { "g", "G", "7", "/e " },
        { "h", "H", "8", "/r " },
    },
    {
        { "i", "I", "9", "/raid " },
        { "j", "J", "<", "/readycheck " },
        { "k", "K", "0", "/rw " },
        { "l", "L", ">", "%T " },
    },
    {
        { "m", "M", "@", "^" },
        { "n", "N", "&", "#" },
        { "o", "O", "$", "€" },
        { "p", "P", "%", "£" },
    },
    {
        { "q", "Q", "/", "½" },
        { "r", "R", "(", "[" },
        { "s", "S", "\\", "||" },
        { "t", "T", ")", "]" },
    },
    {
        { "u", "U", "+", "§" },
        { "v", "V", "*", "{" },
        { "w", "W", "=", "¿" },
        { "x", "X", "/", "}" },
    },
    {
        { "y", "Y", "{rt1}", "{rt1}" },
        { "z", "Z", "{rt2}", "{rt2}" },
        { "\"", "'", "{rt3}", "{rt3}" },
        { "-", "_", "{rt4}", "{rt4}" },
    },
    {
        { "!", "!", "{rt5}", "{rt5}" },
        { ".", ":", "{rt6}", "{rt6}" },
        { ",", ";", "{rt7}", "{rt7}" },
        { "?", "?", "{rt8}", "{rt8}" },
    },
}

local Cmd = {
    Space = "{cmd1}",
    Enter = "{cmd2}",
    Erase = "{cmd3}",
    Escape = "{cmd4}",
}

-- Each key set draws four characters as a diamond, top first and clockwise,
-- matching the face buttons; the button pressed decides which one is typed.
local StrokeButtons = { "PAD4", "PAD2", "PAD1", "PAD3" }
local StrokeIndex = {}
for i, button in ipairs(StrokeButtons) do StrokeIndex[button] = i end

local Markers = {
    ["{rt1}"] = _ [[TARGETINGFRAME\UI-RaidTargetingIcon_1]],
    ["{rt2}"] = _ [[TARGETINGFRAME\UI-RaidTargetingIcon_2]],
    ["{rt3}"] = _ [[TARGETINGFRAME\UI-RaidTargetingIcon_3]],
    ["{rt4}"] = _ [[TARGETINGFRAME\UI-RaidTargetingIcon_4]],
    ["{rt5}"] = _ [[TARGETINGFRAME\UI-RaidTargetingIcon_5]],
    ["{rt6}"] = _ [[TARGETINGFRAME\UI-RaidTargetingIcon_6]],
    ["{rt7}"] = _ [[TARGETINGFRAME\UI-RaidTargetingIcon_7]],
    ["{rt8}"] = _ [[TARGETINGFRAME\UI-RaidTargetingIcon_8]],

    [Cmd.Space] = _ [[AddOns\EasyController\textures\consoleport\IconSpace]],
    [Cmd.Erase] = _ [[AddOns\EasyController\textures\consoleport\IconEraser]],
    [Cmd.Enter] = _ [[RAIDFRAME\ReadyCheck-Ready]],
    [Cmd.Escape] = _ [[RAIDFRAME\ReadyCheck-NotReady]],

    ["/rw "] = _ [[DialogFrame\UI-Dialog-Icon-AlertNew]],
    ["/raid "] = _ [[Scenarios\ScenarioIcon-Boss]],
    ["/readycheck "] = _ [[RAIDFRAME\ReadyCheck-Waiting]],
    ["/attacktarget "] = _ [[CURSOR\Attack]],

    ["%T "] = _ [[MINIMAP\TRACKING\Target]],
    ["%T"] = _ [[MINIMAP\TRACKING\Target]],
    ["%F "] = _ [[MINIMAP\TRACKING\Focus]],
    ["%F"] = _ [[MINIMAP\TRACKING\Focus]],

    ["/s "] = "/s",
    ["/p "] = "/p",
    ["/i "] = "/i",
    ["/g "] = "/g",
    ["/y "] = "/y",
    ["/w "] = "/w",
    ["/e "] = "/e",
    ["/r "] = "/r",
}

local NUM_STATES = 8

-- The layout with the language's 12 accents on the Alt layer (Alt: sets 1
-- to 3, Shift+Alt: the same in capitals)
local layouts = {}
local function GetLayout()
    local accents = CK:Accents()
    if layouts[accents] then return layouts[accents] end
    local layout = {}
    for i, set in ipairs(DefaultLayout) do
        layout[i] = {}
        for j, keys in ipairs(set) do
            layout[i][j] = {}
            for k = 1, NUM_STATES do
                layout[i][j][k] = keys[k] or ""
            end
        end
    end
    for n, ch in ipairs(accents) do
        local set, key = math.floor((n - 1) / 4) + 1, (n - 1) % 4 + 1
        layout[set][key][5] = ch
        layout[set][key][6] = CK.Upper(ch)
    end
    layouts[accents] = layout
    return layout
end

local function GetText(text)
    return Markers[text] or text
end

---------------------------------------------------------------------------
-- UTF-8 (ConsolePort_Keyboard/Core/UTF8.lua; words hold accented letters)
---------------------------------------------------------------------------
local utf8 = {}

function utf8.len(s)
    if strlenutf8 then return strlenutf8(s) end
    return select(2, s:gsub("[^\128-\191]", ""))
end

function utf8.size(char)
    return not char and 0 or
        char > 240 and 4 or
        char > 225 and 3 or
        char > 192 and 2 or 1
end

function utf8.sub(str, startChar, numChars)
    local startIndex = 1
    while startChar > 1 do
        local char = string.byte(str, startIndex)
        startIndex = startIndex + utf8.size(char)
        startChar = startChar - 1
    end

    local currentIndex = startIndex

    while numChars > 0 and currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        currentIndex = currentIndex + utf8.size(char)
        numChars = numChars - 1
    end
    return str:sub(startIndex, currentIndex - 1)
end

function utf8.pos(text, position)
    local startIndex = 1
    local curIndex = 0
    while curIndex < position do
        local char = string.byte(text, startIndex)
        startIndex = startIndex + utf8.size(char)
        curIndex = curIndex + 1
    end
    return startIndex - 1
end

-- The word around a position (in characters): the word, its first and last byte
function utf8.getword(text, position)
    position = utf8.pos(text, position)
    local altText = text:sub(1, position) .. ("\t") .. text:sub(position + 1)
    local startPos, endPos = altText:find("[%a'\128-\255]*\t[%a'\128-\255]*")
    return (altText:sub(startPos, endPos):gsub("\t", "")), startPos, endPos - 1
end
M.utf8 = utf8

---------------------------------------------------------------------------
-- Radial maths (ConsolePort/Controller/Radial.lua, its default settings)
---------------------------------------------------------------------------
local ANGLE_IDX_ONE, COS_DELTA, VALID_VEC_LEN = 90, -1, 0.5

local function GetAngleForIndex(index, size)
    local step = 360 / size
    return ((ANGLE_IDX_ONE + ((index - 1) * step)) % 360)
end

local function GetPointForIndex(index, size, radius)
    local angle = math.rad(GetAngleForIndex(index, size))
    return COS_DELTA * (radius * math.cos(angle)), (radius * math.sin(angle))
end

local function GetNormalizedAngle(x, y)
    local angle = math.deg(math.atan2(x, y)) + ANGLE_IDX_ONE
    return ((angle % 360) + 360) % 360
end

local function GetAngleDistance(a1, a2)
    return (180 - math.abs(math.abs(a1 - a2) - 180))
end

local function GetIndexForPos(x, y, len, size)
    local angle = GetNormalizedAngle(x, y)
    local offset, index = math.huge, nil
    for i = 1, size do
        local distance = GetAngleDistance(angle, GetAngleForIndex(i, size))
        if distance < offset then
            offset, index = distance, i
        end
    end
    return len and len >= VALID_VEC_LEN and index or nil, index
end
M.GetIndexForPos = GetIndexForPos

---------------------------------------------------------------------------
-- Colors (ConsolePort/Utils/Color.lua, Widget/Helpers.lua)
---------------------------------------------------------------------------
local function GetReverseMixColorGradient(dir, r, g, b, a, base, multi)
    local add = base or 0.3
    local mul = multi or 1.1
    local alp = a or 1
    return dir,
        1 - (r - add) * mul, 1 - (g - add) * mul, 1 - (b - add) * mul, alp,
        0 + (r + add) * mul, 0 + (g + add) * mul, 0 + (b + add) * mul, alp
end

local function SetGradient(texture, dir, r1, g1, b1, a1, r2, g2, b2, a2)
    if not (CreateColor and texture.SetGradient) then return end
    pcall(texture.SetGradient, texture, dir, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
end

local function ClassColor()
    local _, class = UnitClass and UnitClass("player")
    local color = class and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
    if color and color.GetRGB then
        local r, g, b = color:GetRGB()
        return { r, g, b }
    end
    color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return { color.r, color.g, color.b } end
    return { 1, 1, 1 }
end

---------------------------------------------------------------------------
-- Spline line (ConsolePort/Utils/Spline.lua)
---------------------------------------------------------------------------
local SplineLine = {
    lineSegments = 50,
    lineBaseCoord = {
        LEFT = { 0, 1, 1, 0 },
        RIGHT = { 0, 1, 0, 1 },
    },
}

function SplineLine:OnLoad()
    self.spline = CreateCatmullRomSpline and CreateCatmullRomSpline(2)
    self.spbits, self.spfree = {}, {}
end

function SplineLine:SetLineOrigin(point, relTo)
    self.lineRelTo = relTo or self
    self.linePoint = point
end

function SplineLine:SetLineOwner(owner) self.lineOwner = owner end

function SplineLine:SetLineDrawLayer(drawLayer, subLayer)
    self.lineDrawLayer = drawLayer
    self.lineSubLayer = tonumber(subLayer) or 0
end

function SplineLine:SetLineSegments(segments) self.lineSegments = segments end

function SplineLine:GetLineCoord()
    local startX, endX = self:CalculatePoint(0), self:CalculatePoint(1)
    return self.lineBaseCoord[startX > endX and "LEFT" or "RIGHT"]
end

function SplineLine:AddLinePoint(x, y)
    if self.spline then self.spline:AddPoint(x, y) end
end

function SplineLine:ClearLinePoints()
    if self.spline then self.spline:ClearPoints() end
    self:ReleaseLine()
end

function SplineLine:CalculatePoint(t)
    return self.spline:CalculatePointOnGlobalCurve(t)
end

function SplineLine:ReleaseLine()
    for _, bit in ipairs(self.spbits) do
        bit:Hide()
        self.spfree[#self.spfree + 1] = bit
    end
    wipe(self.spbits)
    self.lineIsDrawn = false
end

-- A line of the CPSplineLine template (thickness 8, Pie_Line1)
function SplineLine:AcquireBit()
    local bit = table.remove(self.spfree)
    if not bit then
        bit = self.lineOwner:CreateLine(nil, self.lineDrawLayer, nil, self.lineSubLayer)
        bit:SetTexture(TEX .. "Pie_Line1")
        bit:SetThickness(8)
    end
    self.spbits[#self.spbits + 1] = bit
    return bit
end

function SplineLine:DrawLine(postProcess)
    postProcess = postProcess or function() end
    local numSegments = self.lineSegments
    self:ReleaseLine()
    local spline = self.spline
    if not spline or spline:GetNumPoints() < 2 then
        return false
    end
    local l, r, t, b = unpack(self:GetLineCoord())
    for i = 1, numSegments do
        local section = i / numSegments
        local bit = self:AcquireBit()
        bit:SetDrawLayer(self.lineDrawLayer, self.lineSubLayer)
        bit:SetTexCoord(l, r, t, b)
        bit:SetStartPoint(self.linePoint, self.lineRelTo, spline:CalculatePointOnGlobalCurve(section - (2 / numSegments)))
        bit:SetEndPoint(self.linePoint, self.lineRelTo, spline:CalculatePointOnGlobalCurve(section))
        bit:Show()
        postProcess(bit, section, i, numSegments)
    end
    self.lineIsDrawn = true
    return true
end

---------------------------------------------------------------------------
-- The text: the keyboard's buffer, seen as ConsolePort sees an edit box
-- (a cursor in characters; SetText puts it at the end)
---------------------------------------------------------------------------
local Box = {}
M.Box = Box

local function vibrate()
    if CK.Vibration and CK.Vibration.Fire then CK.Vibration:Fire("keyPress") end
end

function Box:GetText()
    return CK:GetText()
end

function Box:GetUTF8CursorPosition()
    local n = utf8.len(CK:GetText())
    local pos = M.cursor
    if not pos or pos > n then pos = n end
    return pos
end

-- In bytes, as the game's EditBox:SetCursorPosition
function Box:SetCursorPosition(bytes)
    local text = CK:GetText()
    bytes = Clamp(bytes or #text, 0, #text)
    M.cursor = utf8.len(text:sub(1, bytes))
end

function Box:SetText(text)
    M.knownText = text
    M.cursor = utf8.len(text)
    CK:SetText(text)
end

function Box:Insert(s)
    local text = CK:GetText()
    local pos = self:GetUTF8CursorPosition()
    local at = utf8.pos(text, pos)
    local newText = text:sub(1, at) .. s .. text:sub(at + 1)
    M.knownText = newText
    M.cursor = pos + utf8.len(s)
    CK:SetText(newText)
    vibrate()
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local function tex(parent, file, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if file then t:SetTexture(TEX .. file) end
    return t
end

-- A client without mask textures: the shapes drawn unmasked
local NO_MASK = setmetatable({}, { __index = function() return function() end end })

local function mask(parent, file, region)
    local m = parent.CreateMaskTexture and parent:CreateMaskTexture()
    if not m then return NO_MASK end
    m:SetTexture(TEX .. file, "CLAMPTOWHITE", "CLAMPTOWHITE")
    if region and region.AddMaskTexture then region:AddMaskTexture(m) end
    return m
end

---------------------------------------------------------------------------
-- Individual flyout keys (Components/Charset.lua)
---------------------------------------------------------------------------
local Key = {}

-- CPKeyboardChar (View/Keyboard.xml)
local function NewKey(parent)
    local k = CK.NewFrame("Frame", nil, parent)
    k:SetSize(24, 24)
    k.Background = tex(k, "Char", "BACKGROUND")
    k.Background:SetPoint("TOPLEFT", -4, 4)
    k.Background:SetPoint("BOTTOMRIGHT", 4, -4)
    k.Text = k:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    k.Text:SetJustifyH("CENTER")
    k.Text:SetAllPoints()
    k.Ring = tex(k, "Char", "ARTWORK")
    k.Ring:SetAlpha(0.75)
    k.Ring:SetPoint("TOPLEFT", -4, 4)
    k.Ring:SetPoint("BOTTOMRIGHT", 4, -4)
    k.Ring:Hide()
    k.RingMask = mask(k, "CharMask", k.Ring)
    k.RingMask:SetPoint("TOPLEFT", k.Ring, "TOPLEFT", 1, -1)
    k.RingMask:SetPoint("BOTTOMRIGHT", k.Ring, "BOTTOMRIGHT", -1, 1)
    for name, fn in pairs(Key) do k[name] = fn end
    k:OnLoad()
    return k
end

function Key:OnLoad()
    self.Background:SetVertexColor(0, 0, 0, 0.75)
end

function Key:SetData(data)
    self.data = data
end

function Key:GetText()
    return self.content
end

function Key:SetState(state)
    self.content = self.data[state]
    self.Text:SetText(GetText(self.content))
end

function Key:SetFocus(factor, cancelFlash)
    if cancelFlash then
        self:SetScript("OnUpdate", nil)
    end
    self.Background:SetVertexColor(0, factor or 0, 0, 0.75)
    self:SetScale(1 + (factor or 0) * 0.05)
end

function Key:Flash()
    local factor, focus = 1, 1
    self:SetScript("OnUpdate", function(self, elapsed)
        factor = Clamp(factor - elapsed, 0, 1)
        focus = InCubic(factor)
        self:SetFocus(focus, false)
        if focus <= 0 then
            self:SetFocus(false, true)
        end
    end)
end

---------------------------------------------------------------------------
-- Sets of keys (Components/Charset.lua)
---------------------------------------------------------------------------
local Set = {}

-- CPKeyboardSet: 90 x 90, its keys around its centre
local function NewSet(parent)
    local s = CK.NewFrame("Frame", nil, parent)
    s:SetSize(90, 90)
    s.Registry = {}
    for name, fn in pairs(Set) do s[name] = fn end
    return s
end

function Set:SetData(data)
    self.numSets = #data
    for i, set in ipairs(data) do
        local widget = self.Registry[i]
        if not widget then
            widget = NewKey(self)
            self.Registry[i] = widget
        end
        local x, y = GetPointForIndex(i, self.numSets, 24)
        local angle = GetNormalizedAngle(x, y)
        local rot = -math.rad(angle - 45) -- offset the texture 45 degrees.
        widget:SetData(set)
        widget:ClearAllPoints()
        widget:SetPoint("CENTER", x, y)
        widget.Background:SetRotation(rot)
        widget.Ring:SetRotation(rot)
        if widget.RingMask.SetRotation then widget.RingMask:SetRotation(rot) end
        widget:Show()
    end
end

function Set:OnStickChanged(x, y, len, valid)
    local oldFocusKey = self.focusKey
    self.focusKey = valid and self.Registry[GetIndexForPos(x, y, .5, self.numSets)]
    if oldFocusKey and oldFocusKey ~= self.focusKey then
        oldFocusKey:SetFocus(false, true)
    end
    if self.focusKey then
        self.focusKey:SetFocus(len, true)
    end
end

function Set:SetState(state)
    for _, widget in ipairs(self.Registry) do
        widget:SetState(state)
    end
end

function Set:SetHighlight(enabled)
    for _, widget in ipairs(self.Registry) do
        widget.Ring:SetShown(enabled)
    end
end

function Set:GetKeyByIndex(index)
    return self.Registry[index]
end

---------------------------------------------------------------------------
-- Word suggester (Components/Suggester.lua)
---------------------------------------------------------------------------
local MAX_DISPLAY_ENTRIES, WIDGET_HEIGHT = 8, 20
local Suggester
local widgets, suggestions = {}, {}

local function AcquireWidget()
    for _, widget in ipairs(widgets) do
        if not widget.active then
            widget.active = true
            return widget, false
        end
    end
    -- CPKeyboardWordButton
    local widget = CK.NewFrame("Frame", nil, Suggester)
    widget:SetSize(140, 20)
    widget.Hilite = widget:CreateTexture(nil, "BACKGROUND")
    widget.Hilite:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    widget.Hilite:SetBlendMode("ADD")
    widget.Hilite:SetAllPoints()
    widget.Text = widget:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    widget.Text:SetJustifyH("CENTER")
    widget.Text:SetAllPoints()
    widget.active = true
    widgets[#widgets + 1] = widget
    return widget, true
end

local function ReleaseAllWidgets()
    for _, widget in ipairs(widgets) do
        widget.active = false
        widget:Hide()
        widget:ClearAllPoints()
    end
end

local function OnSuggestionsUpdatedCallback(result, iterator)
    local self = Suggester

    wipe(suggestions)
    local i = 1
    for word in iterator(result) do
        local widget, newObj = AcquireWidget()
        if newObj and widget.Hilite.AddMaskTexture then
            widget.Hilite:AddMaskTexture(self.Background.FillMask)
        end
        widget.Text:SetText(word)
        widget:Show()
        suggestions[i], i = widget, i + 1
        if i > MAX_DISPLAY_ENTRIES then
            break
        end
    end

    local mimeHeight = self.Mime:GetHeight() + self.Channel:GetHeight()
    self:SetHeight(Clamp((#suggestions + 1) * WIDGET_HEIGHT + mimeHeight, 100, 200 + self.Channel:GetHeight()))
    local prev = self.Mime
    for row, widget in ipairs(suggestions) do
        widget:SetPoint("TOP", prev, "BOTTOM", 0, row == 1 and -8 or 0)
        prev = widget
    end

    self:OnSuggestionsChanged()
end

local SuggesterMixin = {}
local OnSearchDone -- below

-- ours: the addon's predictions for this word, shown first
function SuggesterMixin:OnWordChanged(word, ours)
    ReleaseAllWidgets()
    self.ours = ours
    M:GetAutoCorrectSuggestions(word, OnSearchDone, MAX_DISPLAY_ENTRIES)
end

local function IterateWords(list)
    local i = 0
    return function()
        i = i + 1
        return list[i]
    end
end

-- Words given as they are (the names to whisper, the commands), in their order
function SuggesterMixin:ShowWords(list)
    ReleaseAllWidgets()
    M.Scheduler:Hide()
    OnSuggestionsUpdatedCallback(list, IterateWords)
end

-- ConsolePort's matches found: the addon's predictions first (asked), then
-- theirs, each word once
function OnSearchDone(result, iterator)
    local merged, seen = {}, {}
    local function add(word)
        local key = CK.Lower(word)
        if #merged < MAX_DISPLAY_ENTRIES and not seen[key] then
            seen[key] = true
            merged[#merged + 1] = word
        end
    end
    for _, word in ipairs(Suggester.ours or {}) do add(word) end
    for word in iterator(result) do add(word) end
    OnSuggestionsUpdatedCallback(merged, IterateWords)
end

function SuggesterMixin:OnSuggestionsChanged()
    self.curIndex, self.maxIndex = 1, #suggestions
    self:SetIndex(self.curIndex)
end

function SuggesterMixin:SetDelta(delta)
    if self.curIndex and self.maxIndex then
        local newIndex = self.curIndex + delta
        if newIndex < 1 then return self:SetIndex(self.maxIndex) end
        if newIndex > self.maxIndex then return self:SetIndex(1) end
        self:SetIndex(Clamp(newIndex, 1, self.maxIndex))
    end
end

function SuggesterMixin:SetIndex(index)
    self.selectedWord, self.curIndex = nil, index
    for _, widget in ipairs(suggestions) do
        widget.Hilite:Hide()
    end
    local widget = suggestions[index]
    if widget then
        widget.Hilite:Show()
        self.selectedWord = widget.Text:GetText()
    end
end

function SuggesterMixin:GetSuggestion()
    return self.selectedWord
end

function SuggesterMixin:Clear()
    ReleaseAllWidgets()
    wipe(suggestions)
    self.curIndex, self.maxIndex, self.selectedWord = nil, nil, nil
end

-- The suggestions and their order, for the tests
function M:Suggestions()
    local out = {}
    for i, widget in ipairs(suggestions) do out[i] = widget.Text:GetText() end
    return out, Suggester and Suggester.selectedWord
end

---------------------------------------------------------------------------
-- Mime: the text and its caret above the suggestions. ConsolePort copies
-- the edit box's own text and cursor; here the keyboard's buffer, the
-- caret at the Mime's centre, the text moved under it.
---------------------------------------------------------------------------
local MimeMixin = {}

function MimeMixin:Refresh()
    local text = CK:GetText()
    local pos = utf8.pos(text, Box:GetUTF8CursorPosition())
    self.Text:SetText(text)
    self.Measure:SetText(text:sub(1, pos))
    local dx = pos > 0 and self.Measure:GetStringWidth() or 0
    self.Text:ClearAllPoints()
    self.Text:SetPoint("LEFT", self.Cursor, "CENTER", -dx, 0)
end

function MimeMixin:OnUpdate(elapsed)
    self.throttle = (self.throttle or 0) + elapsed
    if self.throttle < 0.05 then return end
    self.throttle = 0
    self:Refresh()
end

---------------------------------------------------------------------------
-- Autocorrect (Core/Autocorrect.lua): every word of the dictionary scored
-- against the one typed, a few at a time over the frames
---------------------------------------------------------------------------
local MinEditDistance = CalculateStringEditDistance or function(str1, str2)
    -- Wagner–Fischer algorithm
    local len1, len2, min, byte = #str1, #str2, math.min, string.byte
    local matrix = {}
    for i = 0, len1 do
        matrix[i] = { [0] = i }
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (byte(str1, i) == byte(str2, j)) and 0 or 1
            matrix[i][j] = min(
                matrix[i - 1][j] + 1,
                matrix[i][j - 1] + 1,
                matrix[i - 1][j - 1] + cost
            )
        end
    end
    return matrix[len1][len2]
end

local function ScoreStrings(searchText, otherString, weight, len)
    -- lower is better

    local subStringStartIndex = otherString:find(searchText, 1, true)
    local hasSubString = not not subStringStartIndex

    local editDistance = MinEditDistance(searchText, otherString)
    if not hasSubString and editDistance == math.max(len, #otherString) then
        return 100 -- not even close
    end

    local subStringScore = hasSubString and -len * 10 or 0
    local startOfMatchScore = hasSubString
        and ClampedPercentageBetween(subStringStartIndex, 15, 1) * -2 * len or 0

    return editDistance + subStringScore + startOfMatchScore - weight
end

local function BinaryInsert(t, value)
    local startIndex = 1
    local endIndex = #t
    local midIndex = 1
    local preInsert = true

    while startIndex <= endIndex do
        midIndex = math.floor((startIndex + endIndex) / 2)

        if value.score < t[midIndex].score then
            endIndex = midIndex - 1
            preInsert = true
        else
            startIndex = midIndex + 1
            preInsert = false
        end
    end

    table.insert(t, midIndex + (preInsert and 0 or 1), value)
end

-- The dictionary: the addon's words (its languages, the WoW words, what the
-- player sends) and their weight, each with its form without accents (the
-- one scored: "tres" finds "très"); built again when it grows or the
-- keyboard opens (what was learned meanwhile)
local dictionary, dictionaryKey
local function GetDictionary()
    local P = CK.Predict
    local key = P:NumEntries() .. ":" .. tostring(CK.db.settings.lang) .. ":" .. (M.dictionaryStamp or 0)
    if dictionary and dictionaryKey == key then return dictionary end
    dictionary = {}
    P:EachWord(function(word, weight)
        dictionary[#dictionary + 1] = { word = word, weight = weight, norm = CK.Normalize(word) }
    end)
    dictionaryKey = key
    return dictionary
end
M.GetDictionary = GetDictionary

local TIME_PER_FRAME_SEC = 0.015
local WEIGHT_DEF_GRAVITY = 0.005
local GetTimePrecise = GetTimePreciseSec or GetTime

local SchedulerMixin = {}

function SchedulerMixin:ResumeWork()
    self.workEndTime = GetTimePrecise() + TIME_PER_FRAME_SEC
    local ok, err = coroutine.resume(self.workingCoroutine)
    if not ok then geterrorhandler()(err) end
end

function SchedulerMixin:CheckYield()
    if self.workEndTime and GetTimePrecise() > self.workEndTime then
        return coroutine.yield()
    end
end

function SchedulerMixin:CancelSearch()
    self.workingCoroutine = nil
end

function SchedulerMixin:StartSearch()
    self.workingCoroutine = coroutine.create(function()
        local text = self.searchTerm
        self:StepAutoCompleteSearchCoroutine(text)
    end)
    self.bestResults = {}
end

function SchedulerMixin:StepAutoCompleteSearchCoroutine(searchText)
    local dict = GetDictionary()

    local lowerSearchText = CK.Normalize(searchText)
    local len = #lowerSearchText
    local gravity = len > 0 and WEIGHT_DEF_GRAVITY or 0.1

    local candidates = {}
    for _, entry in ipairs(dict) do
        self:CheckYield()
        table.insert(candidates, {
            word = entry.word,
            score = ScoreStrings(lowerSearchText, entry.norm, entry.weight * gravity, len),
        })
    end

    local criteria = len / 2
    for _, candidate in ipairs(candidates) do
        self:CheckYield()

        if candidate.score < criteria then
            BinaryInsert(self.bestResults, candidate)
            if #self.bestResults > self.maxResults then
                self.bestResults[#self.bestResults] = nil
            end
        end
    end
end

function SchedulerMixin:MarkDirty()
    self.dirty = true
end

function SchedulerMixin:OnUpdate()
    if not self.dirty and not self.workingCoroutine then
        return self:DisplayResults()
    end

    if self.dirty and self.workingCoroutine then
        self:CancelSearch()
    end

    if self.workingCoroutine then
        self:ResumeWork()
        if self.workingCoroutine and coroutine.status(self.workingCoroutine) == "dead" then
            self.workingCoroutine = nil
        end
    else
        self:StartSearch()
    end
    self.dirty = false
end

local function IterateResults(results)
    local i = 0
    return function()
        i = i + 1
        if results[i] then
            return results[i].word, results[i].score
        end
    end
end

function SchedulerMixin:DisplayResults()
    self.callback(self.bestResults or {}, IterateResults)
    self:Hide()
end

function SchedulerMixin:Init(word, callback, maxResults)
    self.searchTerm = word
    self.callback = callback
    self.maxResults = maxResults
    self:MarkDirty()
    self:Show()
end

function M:GetAutoCorrectSuggestions(word, callback, maxResults)
    word = CK.Lower(word)
    self.Scheduler:Init(word, callback, maxResults)
end

---------------------------------------------------------------------------
-- The keyboard (View/Keyboard.lua)
---------------------------------------------------------------------------
local Keyboard = {}
local VALID_DSP_LEN = 0.15
-- The right stick moving the keyboard (no group chosen): px per second at full tilt
local MOVE_SPEED, MOVE_DEADZONE = 700, 0.2

function Keyboard:Left(x, y, len)
    self:ReflectStickPosition(x, y, len, len > VALID_VEC_LEN)

    local oldFocusSet = self.focusSet
    self.focusSet = len > VALID_VEC_LEN and
        self.Registry[GetIndexForPos(x, y, len, self.numSets)]

    local isNewFocusSet = oldFocusSet ~= self.focusSet
    local hasFocusset = not not self.focusSet

    if oldFocusSet and isNewFocusSet then
        oldFocusSet:OnStickChanged(0, 0, 0, false)
        oldFocusSet:SetHighlight(false)
    end
    if isNewFocusSet and hasFocusset then
        self.focusSet:SetHighlight(true)
        self.moveX, self.moveY = 0, 0
    end
    self.Controls:SetHighlight(not hasFocusset)
end

function Keyboard:Right(x, y, len)
    if self.focusSet then
        self.focusSet:OnStickChanged(x, y, len, len > VALID_DSP_LEN)
        self.moveX, self.moveY = 0, 0
    else
        -- No group chosen: the stick moves the keyboard (OnUpdate)
        self.moveX, self.moveY = x, y
    end
    if not self.inputLock and len > VALID_VEC_LEN then
        self.inputLock = true
        self:Insert()
    elseif len <= VALID_VEC_LEN then
        self.inputLock = false
    end
end

function Keyboard:SetState(state)
    if self.state == state then return end
    self.state = state
    for _, widget in ipairs(self.Registry) do
        widget:SetState(state)
    end
end

function Keyboard:ReflectStickPosition(x, y, len, isValid)
    local color = isValid and self.VertexColor or self.VertexValid
    self.Arrow:SetVertexColor(color[1], color[2], color[3], 1)

    local r, g, b = unpack(self.VertexColor)
    SetGradient(self.BG, GetReverseMixColorGradient("VERTICAL", r * len, g * len, b * len, len))
    self.Arrow:SetAlpha(Clamp(len + len / 1.5, 0, 1))

    local rotation = -math.atan2(x, y)
    self.BG:SetRotation(rotation)
    self.Arrow:SetRotation(rotation)
end

---------------------------------------------------------------------------
-- Input scripts
---------------------------------------------------------------------------
function Keyboard:GetFocusKey(index)
    if not self.focusSet then return end
    return self.focusSet:GetKeyByIndex(index)
end

-- A face button with a group chosen: its character
function Keyboard:Stroke(button)
    local index = StrokeIndex[button]
    if not index then return false end
    local key = self:GetFocusKey(index)
    if not key then
        self.Controls:GetKeyByIndex(index):Flash()
        return false
    end
    key:Flash()
    self:Insert(key)
    return true
end

function Keyboard:Insert(key)
    key = key or self.focusSet and self.focusSet.focusKey
    if key then
        local text = key:GetText()
        if text and text ~= "" then Box:Insert(text) end
    end
end

function Keyboard:Space(button)
    if self:Stroke(button) then return end
    Box:Insert(" ")
end

function Keyboard:Erase(button)
    if self:Stroke(button) then return end
    -- Nothing left in a whisper: back to its name (CK:Backspace)
    if CK:GetText() == "" and CK:GetChatAttr("chatType") == "WHISPER" and not CK:GetChatAttr("reply")
        and CK:GetChatAttr("tellTarget") then
        return CK:Backspace()
    end
    if IsControlKeyDown() then
        vibrate()
        return Box:SetText("")
    end
    local pos = Box:GetUTF8CursorPosition()
    if pos ~= 0 then
        local text, offset = (Box:GetText())
        -- TODO: handle markers

        local newText =
            utf8.sub(text, 0, offset and pos - offset or pos - 1) .. -- prefix
            utf8.sub(text, pos + 1, utf8.len(text) - pos)              -- suffix
        Box:SetText(newText)
        Box:SetCursorPosition(utf8.pos(newText, offset and pos - offset or pos - 1))
        vibrate()
    end
end

function Keyboard:MoveLeft()
    local text, pos = Box:GetText(), Box:GetUTF8CursorPosition()
    local marker = text:sub(pos - 4, pos):find("{rt%d}")
    Box:SetCursorPosition(utf8.pos(text, marker and pos - 5 or pos - 1))
end

function Keyboard:MoveRight()
    local text, pos = Box:GetText(), Box:GetUTF8CursorPosition()
    local marker = text:sub(pos, pos + 5):find("{rt%d}")
    Box:SetCursorPosition(utf8.pos(text, marker and pos + 5 or pos + 1))
end

function Keyboard:PrevWord()
    Suggester:SetDelta(-1)
end

function Keyboard:NextWord()
    Suggester:SetDelta(1)
end

function Keyboard:AutoCorrect()
    local word = Suggester:GetSuggestion()
    -- A whisper to no one yet: the name picked
    if word and CK:WhisperNameMode() then
        return CK:ConfirmWhisperTarget(word)
    end
    -- A command: the whole of it, ready for its argument
    if word and Suggester.commandMode then
        return Box:SetText(word .. " ")
    end
    if word then
        local text = Box:GetText()
        local _, startPos, endPos = utf8.getword(text, Box:GetUTF8CursorPosition())
        if text and word and startPos and endPos then
            Box:SetText(text:sub(0, startPos - 1) .. word .. text:sub(endPos + 1))
        end
    end
end

---------------------------------------------------------------------------
-- Position: where it was left (saved); the suggestions on the side with room
---------------------------------------------------------------------------
function Keyboard:SavePosition()
    local point, _, relPoint, x, y = self:GetPoint()
    if point then CK.db.cpPos = { point, relPoint, x, y } end
end

function Keyboard:StopMoving()
    self:StopMovingOrSizing()
    self:SavePosition()
    self:OnMoveComplete()
end

function Keyboard:OnMoveComplete()
    -- Move the WordSuggester to the side of the keyboard based
    -- on whether the keyboard is to the left or right of UIParent
    local x = self:GetCenter()
    local scale = self:GetEffectiveScale() / (UIParent:GetEffectiveScale() or 1)
    self.WordSuggester:ClearAllPoints()
    if x and x * scale < UIParent:GetWidth() * 0.5 then
        self.WordSuggester:SetPoint("LEFT", self, "RIGHT", 40, 0)
    else
        self.WordSuggester:SetPoint("RIGHT", self, "LEFT", -40, 0)
    end
    self:UpdateSpline()
end

-- The right stick, no group chosen: the keyboard moves with it
function Keyboard:Move(elapsed)
    local x, y = self.moveX or 0, self.moveY or 0
    local len = math.sqrt(x * x + y * y)
    if self.focusSet or len < MOVE_DEADZONE then
        if self.moving then
            self.moving = false
            self:SavePosition()
        end
        return
    end
    local cx, cy = self:GetCenter()
    if not cx then return end
    local step = MOVE_SPEED * elapsed * len / (self:GetEffectiveScale() / (UIParent:GetEffectiveScale() or 1))
    self.moving = true
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx + x / len * step, cy + y / len * step)
    self:OnMoveComplete()
end

---------------------------------------------------------------------------
-- Spline line effects: from the keyboard to the field it types in
---------------------------------------------------------------------------
function Keyboard:UpdateSpline()
    self:ClearLinePoints()
    local focus = self.focusFrame
    if not (focus and focus.GetCenter and self.spline) then return end

    local kX, kY = self:GetCenter()
    local tX, tY = focus:GetCenter()
    if not (kX and tX) then return end
    -- The field's coordinates in the keyboard's scale
    local ratio = (focus:GetEffectiveScale() or 1) / (self:GetEffectiveScale() or 1)
    tX, tY = tX * ratio, tY * ratio
    local midY = Lerp(kY, tY, 0.5)
    self:AddLinePoint(kX, kY)
    self:AddLinePoint(Lerp(kX, tX, 1 / 3), midY)
    self:AddLinePoint(Lerp(kX, tX, 2 / 3), midY)
    self:AddLinePoint(tX, tY)
    self:DrawLine(function(bit, _, i, numSegments)
        local t = (i - 1) / (numSegments - 1)
        local alpha = InQuadratic(0 + 0.5 * math.sin(math.pi * t))
        bit:SetAlpha(alpha)
    end)
end

-- The field the keyboard types in: the chat's edit box, a prompt's field,
-- a field of the game (none once the chat closed: standalone)
function M:FocusFrame()
    if CK.prompt then return CK.prompt.box end
    return CK.editBox
end

---------------------------------------------------------------------------
-- Data handling (and ConsolePort's Observer: the modifiers held, the text
-- and its cursor, looked at every frame)
---------------------------------------------------------------------------
function Keyboard:OnTextChanged(text, pos)
    local S, P = self.WordSuggester, CK.Predict
    S.commandMode = false
    if CK:WhisperNameMode() then
        -- A whisper to no one yet: the text is the name, the known ones offered
        S:ShowWords(CK:QueryNames(text, MAX_DISPLAY_ENTRIES))
    elseif text:match("^/[^ \t\r\n]*$") then
        -- A command being typed: the addon's completion ("/re": /reload)
        S.commandMode = true
        S:ShowWords(P:QueryCommands(text, MAX_DISPLAY_ENTRIES))
    else
        -- The addon's prediction (asked): the word's completions in its
        -- context, or the next word when nothing is typed; ConsolePort's after
        local word, startPos = utf8.getword(text, pos)
        local ctx = P:Context(text:sub(1, (startPos or 1) - 1))
        S:OnWordChanged(word, P:Query(word, ctx, MAX_DISPLAY_ENTRIES))
    end
    S.Mime:Refresh()
end

---------------------------------------------------------------------------
-- The channel line: the chat's channel (colored) and the D-pad left / right
-- that change it; a prompt's title (nothing to change there)
---------------------------------------------------------------------------
function M:ChannelLabel()
    local label
    if CK:WhisperNameMode() and not CK.prompt then
        local info = ChatTypeInfo and ChatTypeInfo.WHISPER
        label = CK.L.CP_WHISPER_NAME
        if info then label = format("|cff%02x%02x%02x%s|r", info.r * 255, info.g * 255, info.b * 255, label) end
    else
        label = CK:GetChannelLabel()
    end
    -- "Say: " -> "Say"
    label = label:gsub("[ \t]+$", "")
    return (label:gsub("[ :]+|r$", "|r"):gsub("[ :]+$", ""))
end

-- The channel can be changed: the chat (not a prompt, a field of the game)
function M:CanChangeChannel()
    return not CK.prompt and (CK.standalone or CK.editBox) and true or false
end

function Keyboard:UpdateChannel(label)
    local channel = self.WordSuggester.Channel
    channel.Text:SetText(label)
    local canChange = M:CanChangeChannel()
    channel.Glyph:SetShown(canChange)
    if canChange and CK.SetGlyph then CK:SetGlyph(channel.Glyph, "DPAD_LR") end
    channel.Text:ClearAllPoints()
    channel.Text:SetPoint("CENTER", canChange and 9 or 0, 0)
end

-- The next channel available (the addon's list, as on its channel row)
function M:CycleChannel(delta)
    local list = CK.CHANNEL_LIST
    local n = #list
    local index = CK:CurrentChannelIndex() or (delta > 0 and 0 or n + 1)
    for step = 1, n do
        local i = (index - 1 + step * delta) % n + 1
        if CK:ChannelAvailable(i) then
            CK:SetChannel(i)
            return
        end
    end
end

function Keyboard:Observe(elapsed)
    self:SetState(1 + (IsShiftKeyDown() and 1 or 0) + (IsControlKeyDown() and 2 or 0)
        + (IsAltKeyDown() and 4 or 0))
    -- Changed elsewhere (sent, a link, a physical keyboard): the cursor at the end
    local text = CK:GetText()
    if text ~= M.knownText then
        M.knownText = text
        M.cursor = utf8.len(text)
    end
    local pos = Box:GetUTF8CursorPosition()
    if text ~= self.focusText or pos ~= self.focusPos then
        self.focusText, self.focusPos = text, pos
        self:OnTextChanged(text, pos)
    end
    local focus = M:FocusFrame()
    if focus ~= self.focusFrame then
        self.focusFrame = focus
        self:UpdateSpline()
    end
    -- The channel changed (here, a whisper's name picked, the chat's own):
    -- its line, and the suggestions (words or names)
    local label = M:ChannelLabel()
    if label ~= self.channelLabel then
        local wasNames = self.channelNames
        self.channelLabel, self.channelNames = label, CK:WhisperNameMode()
        self:UpdateChannel(label)
        if wasNames ~= self.channelNames then self:OnTextChanged(text, pos) end
    end
    self:Move(elapsed or 0)
end

function Keyboard:OnShow()
    self.focusText, self.focusPos, self.focusFrame = nil, nil, M:FocusFrame()
    self.Controls:SetHighlight(true)
    self:OnMoveComplete()
end

function Keyboard:OnLayoutChanged()
    local layout = GetLayout()
    if self.layout == layout then return end
    self.layout = layout
    self.numSets = #layout
    for i, set in ipairs(layout) do
        local widget = self.Registry[i]
        if not widget then
            widget = NewSet(self)
            widget:SetFrameStrata(self:GetFrameStrata())
            self.Registry[i] = widget
        end
        local x, y = GetPointForIndex(i, self.numSets, (self:GetWidth() or 160) * 0.62)
        widget:ClearAllPoints()
        widget:SetPoint("CENTER", x, y)
        widget:SetData(set)
        widget:Show()
    end
    self.state = nil
    self:SetState(1)
end

---------------------------------------------------------------------------
-- Construction (View/Keyboard.xml)
---------------------------------------------------------------------------
local function BuildSuggester(K)
    local S = CK.NewFrame("Frame", nil, K)
    S:SetFrameLevel(1)
    S:SetSize(150, 200)
    S:SetPoint("LEFT", K, "RIGHT", 40, 0)
    S.Fill = tex(S, "Char", "BACKGROUND")
    S.Fill:SetAllPoints()
    if S.Fill.SetTextureSliceMargins then pcall(S.Fill.SetTextureSliceMargins, S.Fill, 32, 32, 32, 32) end
    if S.Fill.SetScale then pcall(S.Fill.SetScale, S.Fill, 0.5) end
    S.Fill:SetRotation(math.pi)
    S.FillMask = mask(S, "PaletteMask", S.Fill)
    S.FillMask:SetPoint("TOPLEFT", K, "TOPLEFT", -70, 70)
    S.FillMask:SetPoint("BOTTOMRIGHT", K, "BOTTOMRIGHT", 70, -70)

    -- The channel (asked): D-pad left / right change it
    local channel = CK.NewFrame("Frame", nil, S)
    channel:SetHeight(18)
    channel:SetPoint("TOPLEFT", 16, -6)
    channel:SetPoint("TOPRIGHT", -16, -6)
    channel.Text = channel:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    channel.Text:SetPoint("CENTER", 9, 0)
    channel.Text:SetWordWrap(false)
    channel.Glyph = channel:CreateTexture(nil, "ARTWORK")
    channel.Glyph:SetSize(16, 16)
    channel.Glyph:SetPoint("RIGHT", channel.Text, "LEFT", -3, 0)
    S.Channel = channel

    local mime = CK.NewFrame("Frame", nil, S)
    mime:SetHeight(20)
    mime:SetPoint("TOPLEFT", channel, "BOTTOMLEFT", 0, -2)
    mime:SetPoint("TOPRIGHT", channel, "BOTTOMRIGHT", 0, -2)
    if mime.SetClipsChildren then mime:SetClipsChildren(true) end
    mime.Cursor = mime:CreateTexture(nil, "ARTWORK")
    mime.Cursor:SetPoint("CENTER")
    mime.Cursor:SetSize(1, 10)
    mime.Cursor:SetColorTexture(1, 1, 1, 1)
    local anim = mime.Cursor.CreateAnimationGroup and mime.Cursor:CreateAnimationGroup()
    if anim then
        if anim.SetLooping then anim:SetLooping("REPEAT") end
        if anim.SetToFinalAlpha then anim:SetToFinalAlpha(true) end
        local fadeIn = anim:CreateAnimation("Alpha")
        if fadeIn and fadeIn.SetFromAlpha then
            fadeIn:SetDuration(0.25) fadeIn:SetFromAlpha(0) fadeIn:SetToAlpha(1) fadeIn:SetOrder(1)
            local fadeOut = anim:CreateAnimation("Alpha")
            fadeOut:SetDuration(0.25) fadeOut:SetFromAlpha(1) fadeOut:SetToAlpha(0) fadeOut:SetOrder(2)
        end
        mime.FlashAnim = anim
        if anim.Play then anim:Play() end
    end
    mime.Text = mime:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    mime.Measure = mime:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    mime.Measure:SetAlpha(0)
    for name, fn in pairs(MimeMixin) do mime[name] = fn end
    -- The caret as high as the text
    local _, size = mime.Text:GetFont()
    mime:SetHeight(Clamp((size or 14) + 4, 20, 40))
    mime.Cursor:SetHeight(Clamp((size or 14), 10, 30))
    mime:SetScript("OnUpdate", mime.OnUpdate)
    S.Mime = mime

    local bg = CK.NewFrame("Frame", nil, S)
    if bg.SetUseParentLevel then bg:SetUseParentLevel(true) end
    bg:SetPoint("TOPLEFT", channel, "TOPLEFT", -12, 2)
    bg:SetPoint("BOTTOMRIGHT", mime, "BOTTOMRIGHT", 12, -2)
    bg.Box = bg:CreateTexture(nil, "BACKGROUND")
    local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("glues-gamemode-bg")
    if atlas then
        bg.Box:SetAtlas("glues-gamemode-bg")
    else
        bg.Box:SetColorTexture(0, 0, 0, 0.6)
    end
    if bg.Box.SetScale then pcall(bg.Box.SetScale, bg.Box, 0.8) end
    bg.Box:SetPoint("TOPLEFT", 0, 0)
    bg.Box:SetPoint("BOTTOMRIGHT", 0, 0)
    bg.FillMask = mask(bg, "PaletteMask", bg.Box)
    bg.FillMask:SetPoint("TOPLEFT", K, "TOPLEFT", -80, 80)
    bg.FillMask:SetPoint("BOTTOMRIGHT", K, "BOTTOMRIGHT", 80, -80)
    S.Background = bg

    for name, fn in pairs(SuggesterMixin) do S[name] = fn end
    S.Fill:SetVertexColor(0.12, 0.12, 0.12, .75)
    return S
end

-- Built with the panel (UI.lua) for every method: should this one fail, it
-- is left out (the others keep working) and the error reported
function M:Build(area)
    local ok, err = pcall(self.BuildKeyboard, self, area)
    if not ok then
        self.broken = true
        local report = geterrorhandler and geterrorhandler() or print
        report(err)
    end
end

function M:BuildKeyboard(area)
    local K = CK.NewFrame("Frame", "ControllerKeyboardConsolePort", area)
    K:SetSize(160, 160)
    K:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
    K:SetClampedToScreen(true)
    K:SetClampRectInsets(-70, 70, 70, -70)
    K:SetMovable(true)
    K:EnableMouse(true)
    K:RegisterForDrag("LeftButton")
    K:SetScript("OnDragStart", function(k)
        if not CK.db.settings.locked then k:StartMoving() end
    end)
    K:SetScript("OnDragStop", function(k) k:StopMoving() end)
    K.Registry = {}
    for name, fn in pairs(SplineLine) do K[name] = fn end
    for name, fn in pairs(Keyboard) do K[name] = fn end
    self.frame = K
    self.Keyboard = K

    -- The ring (Palette, its masks)
    K.Fill = tex(K, "Palette", "BACKGROUND", 1)
    K.Fill:SetAlpha(0.5)
    K.Fill:SetPoint("TOPLEFT", -64, 64)
    K.Fill:SetPoint("BOTTOMRIGHT", 64, -64)
    K.FillMask = mask(K, "PaletteMask", K.Fill)
    K.FillMask:SetPoint("TOPLEFT", 30, -30)
    K.FillMask:SetPoint("BOTTOMRIGHT", -30, 30)
    K.Edge = tex(K, "Palette", "BACKGROUND", 2)
    K.Edge:SetAlpha(0.5)
    K.Edge:SetPoint("TOPLEFT", -64, 64)
    K.Edge:SetPoint("BOTTOMRIGHT", 64, -64)
    K.EdgeMask = mask(K, "PaletteMask", K.Edge)
    K.EdgeMask:SetPoint("TOPLEFT", K.Edge, "TOPLEFT", 1, -1)
    K.EdgeMask:SetPoint("BOTTOMRIGHT", K.Edge, "BOTTOMRIGHT", -1, 1)
    K.Donut = tex(K, "Palette", "BACKGROUND", 2)
    K.Donut:SetAlpha(0.5)
    K.Donut:SetPoint("TOPLEFT", 30, -30)
    K.Donut:SetPoint("BOTTOMRIGHT", -30, 30)
    K.DonutMask = mask(K, "PaletteMask", K.Donut)
    K.DonutMask:SetPoint("TOPLEFT", K.Donut, "TOPLEFT", 1, -1)
    K.DonutMask:SetPoint("BOTTOMRIGHT", K.Donut, "BOTTOMRIGHT", -1, 1)
    K.Fill:SetVertexColor(0.12, 0.12, 0.12, .75)
    K.Edge:SetVertexColor(0.35, 0.35, 0.35, .75)
    K.Donut:SetVertexColor(0.35, 0.35, 0.35, .75)

    -- The pie menu's needle and band (PieMenu.xml), following the left stick
    K.Arrow = tex(K, "Pie_Arrow", "BORDER")
    K.Arrow:SetAlpha(0)
    K.Arrow:SetPoint("CENTER")
    K.Arrow:SetSize(160 * 0.1, 160 * 0.8)
    K.BG = tex(K, "Pie_Band", "ARTWORK")
    K.BG:SetAlpha(0)
    local inset = 160 - (422 / 500) * 160
    K.BG:SetPoint("TOPLEFT", inset, -inset)
    K.BG:SetPoint("BOTTOMRIGHT", -inset, inset)
    K.VertexColor = ClassColor()
    K.VertexValid = { 1, .81, 0 }

    K.WordSuggester = BuildSuggester(K)
    Suggester = K.WordSuggester

    -- The commands in the middle, the face buttons' places
    K.Controls = NewSet(K)
    K.Controls:SetFrameLevel(1)
    K.Controls:SetPoint("CENTER")
    local controls = { { "" }, { "" }, { "" }, { "" } }
    for button, cmd in pairs({ PAD3 = Cmd.Erase, PAD4 = Cmd.Escape, PAD1 = Cmd.Space, PAD2 = Cmd.Enter }) do
        controls[StrokeIndex[button]] = { cmd }
    end
    K.Controls:SetData(controls)
    K.Controls:SetState(1)

    -- The search, a few words per frame (Core/Autocorrect.lua's Scheduler)
    local scheduler = CK.NewFrame("Frame", nil, K)
    for name, fn in pairs(SchedulerMixin) do scheduler[name] = fn end
    scheduler:Hide()
    scheduler:SetScript("OnUpdate", scheduler.OnUpdate)
    self.Scheduler = scheduler

    K:OnLoad()
    K:SetLineOrigin("BOTTOMLEFT", UIParent)
    K:SetLineDrawLayer("BACKGROUND", 0)
    K:SetLineSegments(100)
    K:SetLineOwner(K)

    K:OnLayoutChanged()
    K:SetScript("OnShow", K.OnShow)
    K:SetScript("OnUpdate", K.Observe)

    -- Y in the chat: Escape, the game's own B closing its chat (secure)
    local esc = CK.NewFrame("Button", ESCAPE_BUTTON, nil, "SecureActionButtonTemplate")
    esc:SetSize(1, 1)
    esc:SetAttribute("type", "macro")
    esc:SetAttribute("macrotext", "")
    esc:RegisterForClicks("AnyDown", "AnyUp")
    esc:SetScript("PreClick", function(_, _, down) M:EscapePress(down) end)
    self.escapeButton = esc
end

-- Saved where it was left; else where ConsolePort puts it first
function M:RestorePosition()
    local K = self.frame
    if not K then return end
    K:ClearAllPoints()
    local pos = CK.db.cpPos
    if pos then
        K:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        K:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
    end
    if K:IsVisible() then K:OnMoveComplete() end
end

---------------------------------------------------------------------------
-- The method (UI.lua, Input.lua)
---------------------------------------------------------------------------
-- Every pad button the keyboard takes while open: A space, B enter, X erase,
-- Y escape (with a group chosen: its characters), the D-pad the channel
-- (LB + left / right the cursor) and the suggestions, RB the suggestion. LB / LT / RT stay the game's
-- modifiers (Ctrl, Shift, Alt): the layers.
M.buttons = {
    PAD1 = "CPSpace", PAD2 = "CPEnter", PAD3 = "CPErase", PAD4 = "CPEscape",
    PADDLEFT = "CPMoveLeft", PADDRIGHT = "CPMoveRight", PADDUP = "CPPrevWord", PADDDOWN = "CPNextWord",
    PADRSHOULDER = "CPAutoCorrect",
}

function M:Help()
    return {}
end

function M:Reset()
    local K = self.frame
    self.cursor, self.knownText = nil, nil
    self.sendLatch, self.escapeLatch = nil, nil
    self.dictionaryStamp = (self.dictionaryStamp or 0) + 1
    if not K then return end
    if K.focusSet then
        K.focusSet:OnStickChanged(0, 0, 0, false)
        K.focusSet:SetHighlight(false)
    end
    K.focusSet, K.inputLock, K.moveX, K.moveY, K.moving = nil, false, 0, 0, false
    K.focusText, K.focusPos, K.channelLabel, K.channelNames = nil, nil, nil, nil
    K:ReflectStickPosition(0, 0, 0, false)
    K.Controls:SetHighlight(true)
    K:OnLayoutChanged()
    Suggester:Clear()
end

-- The ring follows the text and the modifiers itself (Observe)
function M:Update()
    if self.frame then self.frame:OnLayoutChanged() end
end

function M:OnLeftStick(x, y)
    self.frame:Left(x, y, math.sqrt(x * x + y * y))
end

function M:OnRightStick(x, y)
    self.frame:Right(x, y, math.sqrt(x * x + y * y))
end

-- The game's B while its chat is open (its gamepad UI's own button), read
-- before ours go over it (see Phrases.lua)
local function gameBack()
    local action = GetBindingAction and GetBindingAction("PAD2", true)
    local name = type(action) == "string" and action:match("^CLICK (InputFunctionBindingButton_[^:]+):")
    return name and _G[name] and name or nil
end

local function closeLine()
    local eb = CK.editBox
    if M.gameBack and eb and eb.HasFocus and eb:HasFocus() then
        return "/click " .. M.gameBack .. " LeftButton 1"
    end
    return ""
end

-- Input.lua: our bindings cleared, the method's keys bound. In the chat B
-- and Y are secure (the game sends, the game closes its chat); in a prompt
-- B confirms and Y cancels; once the chat closed (standalone) Y closes the
-- keyboard.
function M:Bind(f, bind, padButton, sendButton)
    self.gameBack = gameBack()
    for key in pairs(self.buttons) do bind(f, key, padButton(key)) end
    if CK.prompt then return end
    bind(f, "PAD2", sendButton)
    if not CK.standalone then bind(f, "PAD4", ESCAPE_BUTTON) end
end

-- B in the chat, the secure send button's PreClick (on the press and the
-- release): a character with a group chosen; else Enter: the message sent,
-- then the chat closed as Enter does (an empty line: just closed). Decided
-- on the press, kept for the release (the macro runs on one of them).
function M:SendPress(down)
    if down ~= false then
        if self.frame:Stroke("PAD2") then
            self.sendLatch = { macro = "" }
        else
            self.sendLatch = self:EnterMacro()
        end
    end
    local latch = self.sendLatch
    CK.sendButton:SetAttribute("macrotext", latch and latch.macro or "")
    return true
end

function M:EnterMacro()
    local latch = { macro = closeLine() }
    local text = CK:GetText()
    if text:match("^[ \t\r\n]*$") then return latch end
    -- /w with no one yet: the name typed (the addon's whisper flow)
    if CK:WhisperNameMode() and text:sub(1, 1) ~= "/" and not text:find("|H", 1, true) then
        CK:ConfirmWhisperTarget(text)
        return { macro = "" }
    end
    local body = CK:BuildMacroText()
    -- A whisper goes straight out (names may hold a space)
    CK:SendWhisper()
    if text:sub(1, 1) == "/" then CK.Predict:LearnCommand(text) end
    -- Sent: nothing left for a draft
    Box:SetText("")
    if CK.standalone then latch.closeKeyboard = true end
    if body and body ~= "" then
        latch.macro = latch.macro ~= "" and (body .. "\n" .. latch.macro) or body
    end
    return latch
end

-- The secure send button's PostClick: on the release, a keyboard left
-- alone (the chat closed by the mouse) closes once sent
function M:SendDone(down)
    if down ~= true then
        local latch = self.sendLatch
        self.sendLatch = nil
        if latch and latch.closeKeyboard then CK:Close("sent") end
    end
    return true
end

-- Y in the chat: a character with a group chosen; else Escape: the text
-- dropped (no draft), the game's B closes the chat
function M:EscapePress(down)
    if InCombatLockdown() then return end
    if down ~= false then
        if self.frame:Stroke("PAD4") then
            self.escapeLatch = "stroke"
        else
            self.escapeLatch = "close"
            Box:SetText("")
        end
    end
    local latch = self.escapeLatch
    if down == false then self.escapeLatch = nil end
    self.escapeButton:SetAttribute("macrotext", latch == "close" and closeLine() or "")
end

---------------------------------------------------------------------------
-- The pad buttons' actions (Input.lua: CK.Methods[x].buttons)
---------------------------------------------------------------------------
function CK:CPSpace() M.frame:Space("PAD1") end
function CK:CPErase() M.frame:Erase("PAD3") end
-- D-pad left / right: the channel (asked); with LB held, or where there is
-- no channel (a prompt), the cursor as in ConsolePort
function CK:CPMoveLeft()
    if M:CanChangeChannel() and not IsControlKeyDown() then return M:CycleChannel(-1) end
    M.frame:MoveLeft()
end

function CK:CPMoveRight()
    if M:CanChangeChannel() and not IsControlKeyDown() then return M:CycleChannel(1) end
    M.frame:MoveRight()
end
function CK:CPPrevWord() M.frame:PrevWord() end
function CK:CPNextWord() M.frame:NextWord() end
function CK:CPAutoCorrect() M.frame:AutoCorrect() end

-- B and Y where they aren't secure: a prompt (B confirms, Y cancels), the
-- keyboard alone (Y closes it)
function CK:CPEnter()
    if M.frame:Stroke("PAD2") then return end
    if self.prompt then return self:FinishPrompt(true) end
end

function CK:CPEscape()
    if M.frame:Stroke("PAD4") then return end
    if self.prompt then return self:FinishPrompt(false) end
    self:Close("escape")
end
