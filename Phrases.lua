local _, CK = ...
local L = CK.L

-- Quick phrases (a player asked for Controller Forever's "Quick Chat"): a
-- window of ready-made phrases, in rows by theme (social, status, combat,
-- moving, emotes, your own), five a row. A sends the one picked on the
-- channel picked with LB / RB and closes; X rewrites it (any of them, the
-- default ones too) or renames a row, Y opens the keyboard with it to add
-- to it, B closes. A phrase that starts with "/" is a command (/wave,
-- /roll...): run as typed, on no channel.
--
-- Opened by a button of the controller (the Gamepad tab gives it like a
-- wheel: "wheel:phrases") or from the keyboard (the bubble at the end of
-- its suggestions: the keyboard comes back after, with what it held).
-- Out of combat only, like the keyboard: its keys are override bindings,
-- and A clicks a secure macro button (the game sends the phrase; calling
-- the chat functions from addon code gets blocked by the gamepad UI).
--
-- The phrases are the account's (settings.phrases), the same for every
-- character. Until one is changed they are the defaults of the game's
-- language, never saved; the first change saves them all.
local P = {}
CK.Phrases = P

local COLS, MAX_ROWS, MAX_LEN = 5, 8, 240
local LABEL_W, TILE_W, TILE_H, GAP, PAD = 104, 112, 38, 6, 16
local GRID_Y = 86
P.COLS, P.MAX_ROWS, P.MAX_LEN = COLS, MAX_ROWS, MAX_LEN
-- The game's own chat icon (its gamepad shortcuts bar)
P.ICON = "Interface\\Icons\\UI_Chat"
P.CHIP_ICON = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up"

local SEND_BUTTON = "ControllerKeyboardPhrasesSend"
local TOGGLE_BUTTON = "ControllerKeyboardPhrasesToggle"

-- The channels LB / RB go through (the keyboard's CHANNEL_LIST keys), and
-- what a phrase is sent with there
P.CHANNELS = { "s", "p", "ra", "g", "y", "r" }
local SLASH = { s = "/s", p = "/p", ra = "/ra", g = "/g", y = "/y", r = "/r" }

-- Each row's colour, by its place
local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end
local ROW_COLORS = { hex("5FC0D0"), hex("7AA04A"), hex("FF7A5C"), hex("F2C43C"), hex("FF9A40"), hex("B48CE6"),
    hex("9FD8E2"), hex("D8CCB0") }
local COMMAND_COLOR = hex("FF9A40")

---------------------------------------------------------------------------
-- The phrases
---------------------------------------------------------------------------
-- The game's own command for an emote ("WAVE" -> "/wave", "/salut" in
-- French), or the English one
local function emoteCommand(token, fallback)
    for i = 1, 700 do
        if _G["EMOTE" .. i .. "_TOKEN"] == token then
            local cmd = _G["EMOTE" .. i .. "_CMD1"]
            if type(cmd) == "string" and cmd:sub(1, 1) == "/" then return cmd end
            break
        end
    end
    return fallback
end

local DEFAULT_COMMANDS = {
    ["@WAVE"] = function() return emoteCommand("WAVE", "/wave") end,
    ["@THANK"] = function() return emoteCommand("THANK", "/thank") end,
    ["@CHEER"] = function() return emoteCommand("CHEER", "/cheer") end,
    ["@DANCE"] = function() return emoteCommand("DANCE", "/dance") end,
    ["@ROLL"] = function()
        local cmd = _G.SLASH_RANDOM1
        return type(cmd) == "string" and cmd:sub(1, 1) == "/" and cmd or "/roll"
    end,
}

-- The defaults, in the game's language (L.PHRASE_ROWS: { name, { phrases } })
function P:Defaults()
    local rows = {}
    for _, def in ipairs(L.PHRASE_ROWS or {}) do
        local tiles = {}
        for c = 1, COLS do
            local text = def[2] and def[2][c] or ""
            local command = DEFAULT_COMMANDS[text]
            tiles[c] = command and command() or text
        end
        rows[#rows + 1] = { name = def[1], tiles = tiles }
    end
    return { rows = rows }
end

-- A saved grid as it should be (a broken file never stops the addon)
local function valid(grid)
    if type(grid) ~= "table" or type(grid.rows) ~= "table" then return nil end
    local rows = {}
    for _, row in ipairs(grid.rows) do
        if type(row) == "table" and #rows < MAX_ROWS then
            local tiles = {}
            for c = 1, COLS do
                local t = type(row.tiles) == "table" and row.tiles[c]
                tiles[c] = type(t) == "string" and t or ""
            end
            rows[#rows + 1] = { name = type(row.name) == "string" and row.name or "", tiles = tiles }
        end
    end
    grid.rows = rows
    return grid
end

local function settings() return CK.db.settings end

-- The grid shown: the player's, else the defaults
function P:Grid()
    local saved = valid(settings().phrases)
    if saved then return saved end
    settings().phrases = nil
    if not self.defaults then self.defaults = self:Defaults() end
    return self.defaults
end

-- The grid to change: the defaults saved first
function P:Editable()
    local saved = valid(settings().phrases)
    if saved then return saved end
    settings().phrases = self:Defaults()
    self.defaults = nil
    return settings().phrases
end

function P:Reset()
    settings().phrases = nil
    self.defaults = nil
    if self.active then
        self:Clamp()
        self:Render()
    end
end

-- One line, no spaces around, at most MAX_LEN bytes (never in the middle
-- of a character)
function P.Clean(text)
    text = tostring(text or ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > MAX_LEN then
        local cut = MAX_LEN
        while cut > 0 do
            local b = text:byte(cut + 1)
            if not b or b < 128 or b >= 192 then break end
            cut = cut - 1
        end
        text = text:sub(1, cut)
    end
    return text
end

local function isCommand(text)
    return type(text) == "string" and text:sub(1, 1) == "/"
end
P.IsCommand = isCommand

---------------------------------------------------------------------------
-- Channels
---------------------------------------------------------------------------
local function listIndex(key)
    for i, ch in ipairs(CK.CHANNEL_LIST) do
        if ch.key == key then return i end
    end
end

function P:ChannelAvailable(key)
    local i = listIndex(key)
    return i and CK:ChannelAvailable(i) or false
end

function P:ChannelName(key)
    local i = listIndex(key)
    return i and L.CHANNEL_NAMES[i] or key
end

function P:ChannelColor(key)
    local i = listIndex(key)
    local info = i and ChatTypeInfo and ChatTypeInfo[CK.CHANNEL_LIST[i].color]
    if info then return info.r, info.g, info.b end
    return 1, 1, 1
end

-- On opening: the keyboard's when opened from it (one of ours, still
-- there), else the group's: raid, party, else say
function P:StartChannel(from)
    local i = from and from.channelIndex
    local key = i and CK.CHANNEL_LIST[i] and CK.CHANNEL_LIST[i].key
    if key and SLASH[key] and self:ChannelAvailable(key) then return key end
    if self:ChannelAvailable("ra") then return "ra" end
    if self:ChannelAvailable("p") then return "p" end
    return "s"
end

function P:CycleChannel(delta)
    local n = #P.CHANNELS
    local at = 1
    for i, key in ipairs(P.CHANNELS) do
        if key == self.channel then at = i end
    end
    for step = 1, n do
        local key = P.CHANNELS[(at - 1 + step * delta) % n + 1]
        if self:ChannelAvailable(key) then
            self.channel = key
            break
        end
    end
    self:Render()
end

-- What A runs for a phrase: "/p Need heals!", a command as typed
function P:MacroText(text)
    text = P.Clean(text)
    if text == "" then return "" end
    if isCommand(text) then return text end
    return (SLASH[self.channel] or "/s") .. " " .. text
end

---------------------------------------------------------------------------
-- Focus: a row (1 to the rows, then the "add a row" line) and a column
-- (0: the row's name, 1 to 5: its phrases)
---------------------------------------------------------------------------
function P:CanAddRow()
    return #self:Grid().rows < MAX_ROWS
end

function P:Clamp()
    local rows = #self:Grid().rows
    local last = rows + (self:CanAddRow() and 1 or 0)
    self.row = math.max(1, math.min(self.row or 1, math.max(last, 1)))
    self.col = math.max(0, math.min(self.col or 1, COLS))
end

-- What has the focus: "tile", "label" or "add"; the row, its phrase
function P:Focused()
    local grid = self:Grid()
    local row = grid.rows[self.row]
    if not row then return "add" end
    if self.col == 0 then return "label", row end
    return "tile", row, row.tiles[self.col] or ""
end

function P:Move(dx, dy)
    if self.ask then return end
    local rows = #self:Grid().rows
    if dy ~= 0 then
        local last = rows + (self:CanAddRow() and 1 or 0)
        self.row = math.max(1, math.min((self.row or 1) + dy, math.max(last, 1)))
    elseif self.row <= rows then
        self.col = math.max(0, math.min(self.col + dx, COLS))
    end
    self:Render()
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function tileText(text)
    if text == "" then return "|cff9d917a" .. L.PH_ADD .. "|r" end
    return text
end

function P:Size()
    local rows = #self:Grid().rows
    local w = PAD * 2 + LABEL_W + GAP + COLS * TILE_W + (COLS - 1) * GAP
    local y = GRID_Y + rows * (TILE_H + GAP)
    if self:CanAddRow() then y = y + 28 + GAP end
    return w, y + 8 + 32 + 10 + 34 + 8
end

local function hint(parent)
    local K, C = CK.ConfigKit, CK.ConfigKit.C
    local h = CK.NewFrame("Button", nil, parent)
    h:SetHeight(28)
    h.glyphs = K.GlyphRow(h, 28)
    h.glyphs:SetPoint("LEFT")
    h.verb = K.Text(h, 14, C.cream)
    h:SetScript("OnClick", function(self) if self.press then P:Press(self.press) end end)
    function h:Set(entry)
        local w = self.glyphs:Set(entry.keys)
        self.verb:ClearAllPoints()
        self.verb:SetPoint("LEFT", w + 5, 0)
        self.verb:SetText(entry.verb)
        self.press = entry.press
        self:SetWidth(w + 5 + self.verb:GetStringWidth())
        self:Show()
    end
    return h
end

function P:Build()
    if self.frame then return end
    local K, C = CK.ConfigKit, CK.ConfigKit.C
    local f = CK.NewFrame("Frame", "ControllerKeyboardPhrases", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetPoint("CENTER", 0, 60)
    f:Hide()
    K.Panel(f)
    self.frame = f

    f.title = K.Text(f, 17, C.title)
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetJustifyH("CENTER")
    f.title:SetText(L.PHRASES_NAME)

    -- The channels, LB / RB on each side
    f.lb = K.Glyph(f, 26)
    f.rb = K.Glyph(f, 26)
    f.tabs = {}
    for i, key in ipairs(P.CHANNELS) do
        local t = CK.NewFrame("Button", nil, f)
        t:SetSize(84, 26)
        t.box = K.Box(t, 4, 1, "ARTWORK")
        t.box:SetPoints(t)
        t.label = K.Text(t, 13)
        t.label:SetPoint("CENTER")
        t.label:SetJustifyH("CENTER")
        t.key = key
        t:SetScript("OnClick", function()
            if P:ChannelAvailable(key) then
                P.channel = key
                P:Render()
            end
        end)
        f.tabs[i] = t
    end

    -- The rows: a name, then the phrases
    f.labels, f.tiles = {}, {}
    for r = 1, MAX_ROWS do
        local lb = CK.NewFrame("Button", nil, f)
        lb:SetSize(LABEL_W, TILE_H)
        lb.box = K.Box(lb, 4, 1, "ARTWORK")
        lb.box:SetPoints(lb)
        lb.label = K.Text(lb, 14)
        lb.label:SetPoint("RIGHT", -8, 0)
        lb.label:SetPoint("LEFT", 6, 0)
        lb.label:SetJustifyH("RIGHT")
        lb:SetScript("OnEnter", function() P:Hover(r, 0) end)
        lb:SetScript("OnClick", function() P:Hover(r, 0) P:Press("A") end)
        f.labels[r] = lb
        f.tiles[r] = {}
        for c = 1, COLS do
            local t = CK.NewFrame("Button", nil, f)
            t:SetSize(TILE_W, TILE_H)
            t.box = K.Box(t, 4, 1, "ARTWORK")
            t.box:SetPoints(t)
            t.accent = K.Solid(t, C.white, 1, "ARTWORK", 3)
            t.accent:SetPoint("TOPLEFT", 1, -1)
            t.accent:SetPoint("BOTTOMLEFT", 1, 1)
            t.accent:SetWidth(3)
            t.label = K.Text(t, 13)
            t.label:SetPoint("LEFT", 8, 0)
            t.label:SetPoint("RIGHT", -5, 0)
            t.label:SetJustifyH("CENTER")
            t.label:SetWordWrap(true)
            if t.label.SetMaxLines then t.label:SetMaxLines(2) end
            t:SetScript("OnEnter", function() P:Hover(r, c) end)
            f.tiles[r][c] = t
        end
    end
    local add = CK.NewFrame("Button", nil, f)
    add:SetHeight(28)
    add.box = K.Box(add, 4, 1, "ARTWORK")
    add.box:SetPoints(add)
    add.label = K.Text(add, 13, C.grey)
    add.label:SetPoint("CENTER")
    add.label:SetText(L.PH_ADD_ROW)
    add:SetScript("OnEnter", function() P:Hover(#P:Grid().rows + 1, P.col) end)
    add:SetScript("OnClick", function() P:Press("A") end)
    f.add = add

    -- What A sends
    f.preview = CK.NewFrame("Frame", nil, f)
    f.preview:SetHeight(32)
    f.preview.box = K.Box(f.preview, 4, 1, "ARTWORK")
    f.preview.box:SetPoints(f.preview)
    f.preview.box:SetColors(C.boxBg, 0.95, C.line2, 1)
    f.preview.text = K.ChatText(f.preview, 14, C.cream)
    f.preview.text:SetPoint("LEFT", 10, 0)
    f.preview.text:SetPoint("RIGHT", -10, 0)
    f.preview.text:SetWordWrap(false)

    -- A question (deleting a row with its phrases): A yes, B no
    f.ask = CK.NewFrame("Frame", nil, f)
    f.ask:SetFrameLevel(f:GetFrameLevel() + 20)
    f.ask:SetSize(420, 70)
    f.ask:SetPoint("CENTER", 0, 10)
    f.ask:EnableMouse(true)
    f.ask.box = K.Box(f.ask, 4, 2, "ARTWORK")
    f.ask.box:SetPoints(f.ask)
    f.ask.box:SetColors(C.dangerBg, 0.97, C.danger, 1)
    f.ask.text = K.Text(f.ask, 15, C.dangerText)
    f.ask.text:SetPoint("LEFT", 14, 0)
    f.ask.text:SetPoint("RIGHT", -14, 0)
    f.ask.text:SetJustifyH("CENTER")
    f.ask.text:SetWordWrap(true)
    f.ask:Hide()

    f.hints = {}
    for i = 1, 6 do f.hints[i] = hint(f) end

    -- Held D-pad: moves again and again; keys held at opening bound once let go
    f:SetScript("OnUpdate", function() P:OnUpdate() end)
    f:SetScript("OnHide", function() P.repeatName = nil end)
    self:CreateInput()
end

function P:Hover(row, col)
    if self.ask then return end
    if self.row == row and self.col == col then return end
    self.row, self.col = row, col
    self:Render()
end

-- Everything placed again (the number of rows changes the height)
function P:Layout()
    local f = self.frame
    local w, h = self:Size()
    f:SetSize(w, h)
    local tabW = 84
    local tabsW = #f.tabs * tabW + (#f.tabs - 1) * 4
    local x0 = (w - tabsW) / 2
    for i, t in ipairs(f.tabs) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", x0 + (i - 1) * (tabW + 4), -44)
    end
    f.lb:ClearAllPoints()
    f.lb:SetPoint("RIGHT", f.tabs[1], "LEFT", -8, 0)
    f.rb:ClearAllPoints()
    f.rb:SetPoint("LEFT", f.tabs[#f.tabs], "RIGHT", 8, 0)
    local rows = #self:Grid().rows
    for r = 1, MAX_ROWS do
        local y = GRID_Y + (r - 1) * (TILE_H + GAP)
        local lb = f.labels[r]
        lb:ClearAllPoints()
        lb:SetPoint("TOPLEFT", PAD, -y)
        lb:SetShown(r <= rows)
        for c = 1, COLS do
            local t = f.tiles[r][c]
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", PAD + LABEL_W + GAP + (c - 1) * (TILE_W + GAP), -y)
            t:SetShown(r <= rows)
        end
    end
    local y = GRID_Y + rows * (TILE_H + GAP)
    f.add:ClearAllPoints()
    f.add:SetPoint("TOPLEFT", PAD, -y)
    f.add:SetPoint("TOPRIGHT", -PAD, -y)
    f.add:SetShown(self:CanAddRow())
    if self:CanAddRow() then y = y + 28 + GAP end
    f.preview:ClearAllPoints()
    f.preview:SetPoint("TOPLEFT", PAD, -(y + 8))
    f.preview:SetPoint("TOPRIGHT", -PAD, -(y + 8))
end

function P:Hints()
    local kind, _, text = self:Focused()
    local list = {}
    local function add(keys, verb, press) list[#list + 1] = { keys = keys, verb = verb, press = press } end
    if self.ask then
        add({ "A" }, L.PH_V_DELETE, "A")
        add({ "B" }, L.PH_V_CANCEL, "B")
        return list
    end
    if kind == "tile" then
        if text == "" then
            add({ "A" }, L.PH_V_ADD, "A")
        else
            add({ "A" }, L.PH_V_SEND)
            add({ "X" }, L.PH_V_EDIT, "X")
        end
        add({ "Y" }, L.PH_V_TYPE, "Y")
    elseif kind == "label" then
        add({ "A" }, L.PH_V_RENAME, "A")
    else
        add({ "A" }, L.PH_V_ADD_ROW, "A")
    end
    add({ "LB", "RB" }, L.PH_V_CHANNEL, "RB")
    add({ "B" }, L.PH_V_CLOSE, "B")
    return list
end

function P:Render()
    local f = self.frame
    if not (f and self.active) then return end
    local K, C = CK.ConfigKit, CK.ConfigKit.C
    self:Clamp()
    self:Layout()
    local grid = self:Grid()
    if not self:ChannelAvailable(self.channel) then self.channel = self:StartChannel(nil) end

    for _, t in ipairs(f.tabs) do
        local on = t.key == self.channel
        local available = self:ChannelAvailable(t.key)
        local r, g, b = self:ChannelColor(t.key)
        t.label:SetText(self:ChannelName(t.key))
        t.label:SetTextColor(r, g, b)
        t.box:SetColors(on and C.pressed or C.boxBg, on and 1 or 0.85, on and C.focus or C.line2, 1)
        t:SetAlpha(available and 1 or 0.35)
    end
    f.lb:Set("LB")
    f.rb:Set("RB")

    local kind, _, focusedText = self:Focused()
    for r = 1, MAX_ROWS do
        local row = grid.rows[r]
        if row then
            local color = ROW_COLORS[(r - 1) % #ROW_COLORS + 1]
            local lb = f.labels[r]
            local focus = self.row == r and self.col == 0 and not self.ask
            lb.label:SetText(row.name ~= "" and row.name or "?")
            lb.label:SetTextColor(color[1], color[2], color[3])
            lb.box:SetColors(focus and C.pressed or nil, 1, focus and C.focus or nil, 1)
            for c = 1, COLS do
                local t = f.tiles[r][c]
                local text = row.tiles[c] or ""
                local on = self.row == r and self.col == c and not self.ask
                t.label:SetText(tileText(text))
                if isCommand(text) then
                    t.label:SetTextColor(COMMAND_COLOR[1], COMMAND_COLOR[2], COMMAND_COLOR[3])
                else
                    t.label:SetTextColor(unpack(on and C.focusText or C.cream))
                end
                t.accent:SetVertexColor(color[1], color[2], color[3], text == "" and 0.35 or 1)
                t.box:SetColors(on and C.pressed or C.boxBg, on and 1 or 0.9, on and C.focus or C.line1, 1)
            end
        end
    end
    local addOn = kind == "add" and not self.ask
    f.add.box:SetColors(addOn and C.pressed or C.boxBg, addOn and 1 or 0.6, addOn and C.focus or C.line2, 1)
    f.add.label:SetTextColor(unpack(addOn and C.focusText or C.grey))

    -- What A does, written out
    local preview = ""
    if kind == "tile" and focusedText ~= "" then
        if isCommand(focusedText) then
            preview = format("|cffff9a40%s|r  |cff9d917a(%s)|r", focusedText, L.PH_COMMAND)
        else
            local r, g, b = self:ChannelColor(self.channel)
            preview = format("|cff%02x%02x%02x[%s]|r  %s", r * 255, g * 255, b * 255, self:ChannelName(self.channel),
                focusedText)
        end
    end
    f.preview.text:SetText(preview)

    f.ask:SetShown(self.ask ~= nil)
    if self.ask then f.ask.text:SetText(self.ask.text) end

    local list = self:Hints()
    local x = 0
    local widths = {}
    for i, h in ipairs(f.hints) do
        if list[i] then
            h:Set(list[i])
            widths[i] = h:GetWidth()
            x = x + widths[i] + (i > 1 and 18 or 0)
        else
            h:Hide()
        end
    end
    local left = (f:GetWidth() - x) / 2
    for i, h in ipairs(f.hints) do
        if list[i] then
            h:ClearAllPoints()
            h:SetPoint("BOTTOMLEFT", left, 10)
            left = left + widths[i] + 18
        end
    end
    self:PlaceSendButton()
end

---------------------------------------------------------------------------
-- Keys: override bindings while open, A on the secure macro button
---------------------------------------------------------------------------
local NAV = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "LB", PADRSHOULDER = "RB", ESCAPE = "B",
}
local REPEAT = { UP = true, DOWN = true, LEFT = true, RIGHT = true }
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }

local function padButton(key) return "ControllerKeyboardPhrasesPad" .. key end

function P:CreateInput()
    for key, name in pairs(NAV) do
        local b = CK.NewFrame("Button", padButton(key))
        b:SetSize(1, 1)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetScript("OnClick", function(_, _, down)
            -- B acts on its release: the game, which would get the release
            -- alone once the window is closed, never sees half a press
            if name == "B" then
                if down == false then P:Press("B") end
                return
            end
            if down == false then
                if P.repeatName == name then P.repeatName = nil end
                return
            end
            if REPEAT[name] then P.repeatName, P.repeatAt = name, GetTime() + 0.35 end
            P:Press(name)
        end)
    end

    local s = CK.NewFrame("Button", SEND_BUTTON, nil, "SecureActionButtonTemplate")
    s:SetAttribute("type", "macro")
    s:SetAttribute("macrotext", "")
    s:RegisterForClicks("AnyDown", "AnyUp")
    s:SetFrameStrata("FULLSCREEN_DIALOG")
    s:SetScript("PreClick", function() P:PrepareSend() end)
    s:SetScript("PostClick", function(_, _, down) P:AfterSend(down) end)
    s:Hide()
    self.sendButton = s
end

local function bindKey(owner, key, button)
    if key == "ESCAPE" then
        SetOverrideBindingClick(owner, true, key, button)
    else
        for _, prefix in ipairs(PREFIXES) do SetOverrideBindingClick(owner, true, prefix .. key, button) end
    end
end

local function buttonFor(key)
    return key == "PAD1" and SEND_BUTTON or padButton(key)
end

-- A key still held (the one that opened the window) is bound once let go:
-- its release is not a press here
function P:Bind()
    if InCombatLockdown() then return end
    local f = self.frame
    ClearOverrideBindings(f)
    self.held = {}
    local keys = { PAD1 = true }
    for key in pairs(NAV) do keys[key] = true end
    for key in pairs(keys) do
        if key ~= "ESCAPE" and IsKeyDown and IsKeyDown(key) then
            self.held[key] = true
        else
            bindKey(f, key, buttonFor(key))
        end
    end
    self.sendButton:Show()
end

function P:Unbind()
    self.held = nil
    self.repeatName = nil
    if InCombatLockdown() then return end
    if self.frame then ClearOverrideBindings(self.frame) end
    if self.sendButton then
        self.sendButton:SetAttribute("macrotext", "")
        self.sendButton:Hide()
    end
end

function P:OnUpdate()
    if self.held and next(self.held) and not InCombatLockdown() then
        for key in pairs(self.held) do
            if not IsKeyDown(key) then
                self.held[key] = nil
                bindKey(self.frame, key, buttonFor(key))
            end
        end
    end
    if self.repeatName and GetTime() >= (self.repeatAt or 0) then
        self.repeatAt = GetTime() + 0.08
        self:Press(self.repeatName)
    end
end

-- The secure button over the cell with the focus: a mouse click there is A
function P:PlaceSendButton()
    local s, f = self.sendButton, self.frame
    if not s or InCombatLockdown() then return end
    local kind = self:Focused()
    local cell
    if kind == "tile" then
        cell = f.tiles[self.row][self.col]
    elseif kind == "label" then
        cell = f.labels[self.row]
    else
        cell = f.add
    end
    s:EnableMouse(not self.ask and cell ~= nil and cell:GetLeft() ~= nil)
    if not (cell and cell:GetLeft()) then return end
    s:SetScale(cell:GetEffectiveScale())
    s:ClearAllPoints()
    s:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cell:GetLeft(), cell:GetBottom())
    s:SetSize(cell:GetWidth(), cell:GetHeight())
    s:SetAttribute("macrotext", self:SendText())
end

-- The macro A runs now: a phrase only (a question, a name, an empty one:
-- nothing, A does something else after the click)
function P:SendText()
    if self.ask then return "" end
    local kind, _, text = self:Focused()
    if kind ~= "tile" then return "" end
    return self:MacroText(text)
end

function P:PrepareSend()
    if InCombatLockdown() then return end
    self.sendButton:SetAttribute("macrotext", self:SendText())
end

-- After the secure click, on the release (the macro runs on the press or
-- the release, as the game's option says): sent, the window closes;
-- otherwise A does what the focus asks
function P:AfterSend(down)
    if down == true then return end
    if not self.active then return end
    if self:SendText() ~= "" then
        self:Close("sent")
        return
    end
    self:Press("A")
end

---------------------------------------------------------------------------
-- Presses
---------------------------------------------------------------------------
function P:Press(name)
    if not self.active then return end
    if self.ask then
        local ask = self.ask
        if name == "A" then
            self.ask = nil
            ask.yes()
            self:Render()
        elseif name == "B" then
            self.ask = nil
            self:Render()
        end
        return
    end
    if name == "UP" then return self:Move(0, -1) end
    if name == "DOWN" then return self:Move(0, 1) end
    if name == "LEFT" then return self:Move(-1, 0) end
    if name == "RIGHT" then return self:Move(1, 0) end
    if name == "LB" then return self:CycleChannel(-1) end
    if name == "RB" then return self:CycleChannel(1) end
    if name == "B" then return self:Close("back") end
    local kind, _, text = self:Focused()
    if name == "Y" then
        return self:TypeMessage(kind == "tile" and text or "")
    end
    if name == "X" or name == "A" then
        -- A on a phrase is the secure button's (sent): nothing here
        if name == "A" and kind == "tile" and text ~= "" then return end
        if kind == "tile" then return self:EditTile() end
        if kind == "label" then return self:RenameRow() end
        return self:AddRow()
    end
end

---------------------------------------------------------------------------
-- Changes, typed with the keyboard (its prompt): the window waits hidden
---------------------------------------------------------------------------
function P:Prompt(title, text, onDone)
    if not settings().modules.keyboard then
        CK:Print(L.KEYBOARD_OFF)
        return
    end
    self.frame:Hide()
    self:Unbind()
    self.prompting = true
    local opened = CK:OpenPrompt(title, text, function(value)
        self.prompting = false
        if not self.active then return end
        if value ~= nil then onDone(P.Clean(value)) end
        self:Resume()
    end)
    if not opened then
        self.prompting = false
        self:Resume()
    end
end

function P:Resume()
    if not self.active or InCombatLockdown() then return end
    self.frame:Show()
    self:Bind()
    self:Render()
end

function P:EditTile()
    local row, col = self.row, self.col
    local _, current = self:Focused()
    self:Prompt(L.PH_EDIT_TITLE, current and current.tiles[col] or "", function(value)
        local grid = self:Editable()
        if grid.rows[row] then grid.rows[row].tiles[col] = value end
    end)
end

local function countPhrases(row)
    local n = 0
    for c = 1, COLS do
        if (row.tiles[c] or "") ~= "" then n = n + 1 end
    end
    return n
end

-- A row renamed; an empty name deletes it (asked first when it holds phrases)
function P:RenameRow()
    local index = self.row
    local _, row = self:Focused()
    self:Prompt(L.PH_ROW_TITLE, row and row.name or "", function(value)
        local grid = self:Editable()
        local target = grid.rows[index]
        if not target then return end
        if value ~= "" then
            target.name = value
            return
        end
        local n = countPhrases(target)
        local function delete()
            table.remove(self:Editable().rows, index)
            self:Clamp()
        end
        if n == 0 then
            delete()
        else
            self.ask = { text = format(L.PH_ASK_DELETE, target.name, n), yes = delete }
        end
    end)
end

function P:AddRow()
    if not self:CanAddRow() then return end
    self:Prompt(L.PH_NEW_ROW_TITLE, "", function(value)
        if value == "" then return end
        local grid = self:Editable()
        if #grid.rows >= MAX_ROWS then return end
        grid.rows[#grid.rows + 1] = { name = value, tiles = { "", "", "", "", "" } }
        self.row, self.col = #grid.rows, 1
    end)
end

---------------------------------------------------------------------------
-- Opening, closing
---------------------------------------------------------------------------
local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- from: the keyboard it was opened from ({ editBox, standalone, buffer,
-- chatAttrs, channelIndex }), brought back when it closes
function P:Open(from)
    if CK:BlockedByCombat() then return false end
    self:Build()
    self.from = from
    self.active = true
    self.ask = nil
    self.channel = self:StartChannel(from)
    self.row, self.col = self.row or 1, self.col or 1
    self.frame:Show()
    self.frame:Raise()
    self:Bind()
    self:Render()
    -- Its cells placed by the next frame: the mouse's A over the focused one
    C_Timer.After(0, function() if P.active then P:PlaceSendButton() end end)
    return true
end

-- From the keyboard (its bubble): it closes meanwhile, and comes back with
-- what it held. Not from a prompt or a field of the game (no channel there)
function P:OpenFromKeyboard()
    if CK.prompt or CK.field or not CK:IsOpen() then return false end
    if InCombatLockdown() then return CK:BlockedByCombat() and false end
    local from = {
        editBox = CK.editBox, standalone = CK.standalone, buffer = CK:GetText(),
        chatAttrs = copy(CK.chatAttrs), channelIndex = CK:CurrentChannelIndex(),
    }
    CK:Close("phrases")
    return self:Open(from)
end

-- The keyboard brought back: on the chat if it is still open, else on its own
function P:RestoreKeyboard(from, text, attrs)
    if not settings().modules.keyboard then return end
    local eb = from and from.editBox
    if eb then
        if not (eb.HasFocus and eb:HasFocus()) then
            -- The game closed the chat meanwhile: the keyboard on its own
            -- only for a message to type (Y)
            if text == nil then return end
            CK:OpenStandalone()
        else
            CK:Open(eb)
        end
    else
        CK:OpenStandalone()
    end
    if not CK:IsOpen() then return end
    CK.buffer = text or (from and from.buffer) or ""
    CK.chatAttrs = attrs or copy(from and from.chatAttrs)
    CK:Refresh()
end

-- Y: the keyboard with the phrase, on the channel picked here (after what
-- the keyboard already held, when opened from it)
function P:TypeMessage(text)
    if not settings().modules.keyboard then
        CK:Print(L.KEYBOARD_OFF)
        return
    end
    local from = self.from
    local before = from and from.buffer or ""
    local message = text
    if before:find("%S") and text ~= "" then
        message = before .. (before:find("%s$") and "" or " ") .. text
    elseif text == "" then
        message = before
    end
    local i = listIndex(self.channel)
    local attrs = i and CK.CHANNEL_LIST[i].attrs(CK) or { chatType = "SAY" }
    self:Close("type")
    self:RestoreKeyboard(from or {}, message, attrs)
end

function P:Close(reason)
    if not self.active then return end
    self.active = false
    self.ask = nil
    self:Unbind()
    if self.frame then self.frame:Hide() end
    local from = self.from
    self.from = nil
    -- A prompt still open (combat): it closes on its own
    if self.prompting and CK.prompt then CK:Close("phrases closed") end
    self.prompting = false
    if from and reason ~= "combat" and reason ~= "type" then self:RestoreKeyboard(from) end
end

function P:IsOpen()
    return self.active and true or false
end

function P:Toggle()
    if self.active then
        self:Close("toggle")
    elseif CK:IsOpen() and not CK.prompt and not CK.field then
        self:OpenFromKeyboard()
    else
        self:Open(nil)
    end
end

-- What a button of the controller clicks (Mapping.lua, "wheel:phrases"):
-- its press opens or closes the window. Bound to a key it gets the press
-- only (AnyDown); through a paddle's router it is clicked without "down",
-- and a release comes as a "ckup" click (the wheels' hold option): nothing
function P:ToggleButton()
    if self.toggle then return self.toggle end
    local b = CK.NewFrame("Button", TOGGLE_BUTTON, UIParent)
    b:SetSize(1, 1)
    b:RegisterForClicks("AnyDown")
    b:SetScript("OnClick", function(_, button)
        if type(button) == "string" and button:sub(1, 4) == "ckup" then return end
        P:Toggle()
    end)
    self.toggle = b
    return b
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            P:Close("combat")
        else
            -- The binding's button exists from the start (Bindings.xml)
            P:ToggleButton()
        end
    end)
end
