local _, CK = ...
local L = CK.L

---------------------------------------------------------------------------
-- Fonts (Blizzard fonts shipped with the game)
---------------------------------------------------------------------------
CK.FONTS = {
    { key = "friz", name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { key = "skurri", name = "Skurri", path = "Fonts\\SKURRI.TTF" },
    { key = "arialn", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "chat", name = L.FONT_CHAT },
}

function CK:GetFontPath()
    local key = self.db and self.db.settings.font
    for _, font in ipairs(CK.FONTS) do
        if font.key == key then
            if font.key == "chat" then
                return (ChatFontNormal and ChatFontNormal:GetFont()) or STANDARD_TEXT_FONT
            end
            return font.path
        end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local Config = CK.Config

local GLYPH_STYLES = {
    { key = "xbox", name = "Xbox" },
    { key = "playstation", name = "PlayStation" },
    { key = "switch", name = "Nintendo Switch" },
}

local function indexOf(list, key)
    for i, item in ipairs(list) do
        if item.key == key then return i end
    end
    return 1
end

-- A choice among { key, name } items kept in settings[field]
local function pick(items, s, field, after)
    return function() return items[indexOf(items, s[field])].name end, function(d)
        local i = (indexOf(items, s[field]) - 1 + d) % #items + 1
        s[field] = items[i].key
        if after then after() end
    end
end

local function percent(v) return format("%d %%", v * 100 + 0.5) end

local function settings() return CK.db.settings end

---------------------------------------------------------------------------
-- Home: every module and its state (Y: its settings), the panel's
-- shortcut, the look
---------------------------------------------------------------------------
local function moduleRows(b)
    local s = settings()
    local mods, f = s.modules, s.features
    local method = s.inputMethod == "stick" and L.METHOD_STICK or L.METHOD_WHEEL
    b.header(L.SEC_MODULES)
    b.check({ id = "m_kb", label = L.LBL_CHAT_KEYBOARD, status = method, tip = L.OPT_SUBTITLE,
        get = function() return mods.keyboard end,
        set = function(v)
            mods.keyboard = v
            if not v then CK:Close("keyboard module off") end
        end,
        onY = function() Config:SetTab("keyboard", 1) end, yVerb = L.V_SETTINGS })
    b.check({ id = "m_ql", label = L.LBL_QUEST_LINKS, indent = true, disabled = not mods.keyboard, tip = L.MOD_QUEST_LINKS,
        get = function() return mods.questLinks end,
        set = function(v)
            mods.questLinks = v
            CK:Layout()
        end,
        onY = function() Config:SetTab("keyboard", 1) end, yVerb = L.V_SETTINGS })
    b.check({ id = "m_qi", label = L.SEC_QUESTITEMS, tip = L.MOD_QUEST_ITEMS,
        get = function() return mods.questItems end,
        set = function(v)
            mods.questItems = v
            if v then
                CK.QuestItems:ScanBags()
                CK.QuestItems:ScanQuests()
            end
            CK.QuestItems:RefreshBorders()
        end,
        onY = function() Config:SetTab("alerts", 3) end, yVerb = L.V_SETTINGS })
    b.check({ id = "m_up", label = L.LBL_UPGRADES, status = function() return CK.Upgrades:ByStats() and L.STATUS_CLASS_STATS or L.STATUS_ITEM_LEVEL end, tip = L.TIP_UPGRADES,
        extra = function() return CK.Upgrades:ScaleText() end,
        get = function() return mods.upgrades end,
        set = function(v)
            mods.upgrades = v
            CK.Upgrades:Refresh()
        end,
        onY = function() Config:SetTab("alerts", 4) end, yVerb = L.V_SETTINGS })
    local tracked = 0
    for _, r in ipairs(CK.Supplies:Resources()) do
        if r.cfg.on then tracked = tracked + 1 end
    end
    b.check({ id = "m_sup", label = L.LBL_SUPPLY_BUTTONS, status = format(L.STATUS_TRACKED, tracked), tip = L.SUP_INFO,
        get = function() return s.supplies.enabled end,
        set = function(v)
            s.supplies.enabled = v
            CK.Supplies:Refresh()
        end,
        onY = function() Config:SetTab("alerts", 2) end, yVerb = L.V_SETTINGS })
    b.check({ id = "m_cw", label = L.WHEEL_NAME, tip = L.WHEEL_INFO,
        get = function() return s.wheel.enabled end,
        set = function(v)
            s.wheel.enabled = v
            CK.ConsumableWheel:Fill()
        end,
        onY = function() Config:SetTab("wheels", 2) end, yVerb = L.V_SETTINGS })
    local V = CK.Vibration
    local vib = V:Settings()
    local events = 0
    for _, e in ipairs(V.EVENTS) do
        if vib.events[e.key] and vib.events[e.key].on then events = events + 1 end
    end
    b.check({ id = "m_vib", label = L.SEC_VIBRATIONS, status = format(L.STATUS_EVENTS, events), tip = L.TIP_MOD_VIBRATIONS,
        get = function() return vib.enabled end,
        set = function(v)
            vib.enabled = v
            if v then V:Play("pulse") else V:Stop() end
        end,
        onY = function() Config:SetTab("alerts", 1) end, yVerb = L.V_SETTINGS })
end

local function shortcutRows(b)
    local s = settings()
    local f, M = s.features, CK.Mapping
    b.header(L.SEC_SHORTCUT)
    b.check({ id = "sc_on", label = L.LBL_PANEL_SHORTCUT, tip = L.FEAT_SHORTCUT,
        get = function() return f.configShortcut end,
        set = function(v) f.configShortcut = v end })
    if not f.configShortcut then return end
    -- A, then hold a button and press a second one
    b.value({ id = "sc_combo", label = L.LBL_COMBINATION, indent = true, verb = L.V_CHANGE, tip = L.TIP_COMBINATION,
        text = function()
            return Config:IsCapturingChord() and L.LBL_HOLD_PRESS or M:ChordLabel(s.shortcut)
        end,
        onA = function()
            Config:CaptureChord(function(chord)
                if chord then
                    s.shortcut = chord
                    Config:Toast(format(L.TOAST_SHORTCUT, M:ChordLabel(chord)))
                end
                Config:Render()
            end)
        end })
    local default = CK.DEFAULT_SHORTCUT
    if s.shortcut.hold ~= default.hold or s.shortcut.press ~= default.press then
        b.button({ id = "sc_reset", label = format(L.LBL_BACK_TO, M:ChordLabel(default)), indent = true,
            tip = L.TIP_SHORTCUT_RESET,
            func = function() s.shortcut = { hold = default.hold, press = default.press } end })
    end
end

local function lookRows(b)
    local s = settings()
    b.header(L.SEC_LOOK)
    local text, step = pick(GLYPH_STYLES, s, "glyphStyle", function() CK:UpdateGlyphs() end)
    b.choice({ id = "glyph", label = L.LBL_GLYPHS, text = text, step = step, tip = L.TIP_GLYPHS })
    b.check({ id = "gicons", label = L.LBL_GAME_ICONS, tip = L.OPT_GAME_GLYPHS,
        get = function() return s.gameGlyphs end,
        set = function(v)
            s.gameGlyphs = v
            CK:UpdateGlyphs()
        end })
    text, step = pick(CK.FONTS, s, "font", function()
        CK:ApplyFont()
        CK:UpdateMethod()
    end)
    b.choice({ id = "font", label = L.OPT_FONT, text = text, step = step, tip = L.TIP_FONT })
    -- The gamepad UI's centre dot (OLED screens)
    local r = s.reticle
    local modes = {
        { key = "game", name = L.RET_GAME }, { key = "color", name = L.RET_COLOR },
        { key = "cycle", name = L.RET_CYCLE }, { key = "hidden", name = L.RET_HIDDEN },
    }
    b.choice({ id = "ret_mode", label = L.LBL_RETICLE, tip = L.TIP_RETICLE,
        text = function() return modes[indexOf(modes, r.mode)].name end,
        step = function(d)
            local i = (indexOf(modes, r.mode) - 1 + d) % #modes + 1
            CK.Reticle:SetMode(modes[i].key)
        end })
    b.choice({ id = "ret_color", label = L.LBL_RETICLE_COLOR, indent = true, disabled = r.mode ~= "color",
        tip = L.TIP_RETICLE_COLOR,
        text = function()
            local c = CK.Reticle.COLORS[r.color] or CK.Reticle.COLORS[1]
            return format("|cff%02x%02x%02x%s|r", c.rgb[1] * 255, c.rgb[2] * 255, c.rgb[3] * 255,
                L["RET_C_" .. c.key:upper()])
        end,
        step = function(d)
            r.color = ((r.color or 1) - 1 + d) % #CK.Reticle.COLORS + 1
            CK.Reticle:Apply()
        end })
end

-- At merchants (Automation.lua)
local function automationRows(b)
    local s = settings()
    local mods = s.modules
    b.header(L.SEC_AUTOMATION)
    b.check({ id = "a_junk", label = L.LBL_SELL_JUNK, tip = L.TIP_SELL_JUNK,
        get = function() return mods.sellJunk end, set = function(v) mods.sellJunk = v end })
    b.check({ id = "a_repair", label = L.LBL_AUTO_REPAIR, tip = L.TIP_AUTO_REPAIR,
        get = function() return mods.autoRepair end, set = function(v) mods.autoRepair = v end })
    if not mods.autoRepair then return end
    b.check({ id = "a_guild", label = L.LBL_GUILD_REPAIR, indent = true, tip = L.TIP_GUILD_REPAIR,
        get = function() return s.automation.guildRepair end, set = function(v) s.automation.guildRepair = v end })
end

Config.pages.home = Config.NewRailPage({
    key = "home",
    sections = {
        { key = "modules", label = L.SEC_MODULES, tip = L.TIP_SEC_MODULES, rows = moduleRows },
        { key = "shortcut", label = L.SEC_SHORTCUT, tip = L.TIP_SEC_SHORTCUT, rows = shortcutRows },
        { key = "look", label = L.SEC_LOOK, tip = L.TIP_SEC_LOOK, rows = lookRows },
        { key = "gamepad", label = L.TAB_GAMEPAD, tip = L.TIP_SEC_DISPLAY, rows = function(b) CK.MapPage.DisplayRows(b) end },
        { key = "automation", label = L.SEC_AUTOMATION, tip = L.TIP_SEC_AUTOMATION, rows = automationRows },
    },
})

---------------------------------------------------------------------------
-- Keyboard: opening, input, sticks, prediction, position. Module off:
-- each section only offers to turn it on.
---------------------------------------------------------------------------
local SIZES = {
    { scale = 0.8, name = L.SIZE_SMALL }, { scale = 1, name = L.SIZE_NORMAL },
    { scale = 1.25, name = L.SIZE_LARGE }, { scale = 1.5, name = L.SIZE_XL },
}
local LAYOUTS = {
    { key = "azerty", name = "AZERTY" }, { key = "qwerty", name = "QWERTY" },
    { key = "qwertz", name = "QWERTZ" }, { key = "qwerty_es", name = "QWERTY (español)" },
    { key = "qwerty_it", name = "QWERTY (italiano)" },
}
local CURVES = {
    { key = "linear", name = L.CURVE_LINEAR }, { key = "gentle", name = L.CURVE_GENTLE },
    { key = "fast", name = L.CURVE_FAST },
}
local MAGNETS = {
    { key = "none", name = L.MAGNET_NONE }, { key = "weak", name = L.MAGNET_WEAK },
    { key = "medium", name = L.MAGNET_MEDIUM }, { key = "strong", name = L.MAGNET_STRONG },
}
local METHODS = { { key = "wheel", name = L.METHOD_WHEEL }, { key = "stick", name = L.METHOD_STICK } }

-- The module off: only its box
local function keyboardOff(b)
    local mods = settings().modules
    if mods.keyboard then return false end
    b.header(L.LBL_CHAT_KEYBOARD)
    b.check({ id = "k_module", label = L.LBL_CHAT_KEYBOARD, tip = L.TIP_KEYBOARD_OFF,
        get = function() return mods.keyboard end,
        set = function(v) mods.keyboard = v end })
    return true
end

local function openingRows(b)
    if keyboardOff(b) then return end
    local s = settings()
    local f, mods = s.features, s.modules
    b.header(L.SEC_OPENING)
    b.check({ id = "k_auto", label = L.LBL_OPEN_WITH_CHAT, tip = L.OPT_AUTO,
        get = function() return s.autoOpen end, set = function(v) s.autoOpen = v end })
    b.check({ id = "k_pad", label = L.LBL_ONLY_GAMEPAD, indent = true, disabled = not s.autoOpen, tip = L.OPT_PAD_ONLY,
        get = function() return s.onlyWithGamepad end, set = function(v) s.onlyWithGamepad = v end })
    b.check({ id = "k_fields", label = L.LBL_OPEN_FIELDS, tip = L.OPT_FIELDS,
        get = function() return s.openFields end, set = function(v) s.openFields = v end })
    b.header(L.HDR_MESSAGES)
    b.check({ id = "k_sticky", label = L.LBL_CHANNEL_STICKS, tip = L.OPT_STICKY,
        get = function() return s.stickyChannel end, set = function(v) s.stickyChannel = v end })
    b.check({ id = "k_drafts", label = L.LBL_KEEP_DRAFTS, tip = L.FEAT_DRAFTS,
        get = function() return f.drafts end, set = function(v) f.drafts = v end })
    b.check({ id = "k_links", label = L.LBL_SHIFT_LINKS, tip = L.FEAT_LINKS,
        get = function() return f.linkCapture end, set = function(v) f.linkCapture = v end })
    b.check({ id = "k_ql", label = L.LBL_QUEST_LINKS, tip = L.MOD_QUEST_LINKS,
        get = function() return mods.questLinks end,
        set = function(v)
            mods.questLinks = v
            CK:Layout()
        end })
end

local function inputRows(b)
    if keyboardOff(b) then return end
    local s = settings()
    b.header(L.SEC_INPUT)
    b.choice({ id = "k_method", label = L.OPT_METHOD, tip = L.TIP_METHOD,
        text = function() return METHODS[indexOf(METHODS, s.inputMethod)].name end,
        step = function(d)
            local i = (indexOf(METHODS, s.inputMethod) - 1 + d) % #METHODS + 1
            CK:SetInputMethod(METHODS[i].key)
        end })
    local text, step = pick(LAYOUTS, s, "kbLayout", function() CK:UpdateMethod() end)
    b.choice({ id = "k_layout", label = L.LBL_LAYOUT, indent = true, disabled = s.inputMethod ~= "stick",
        tip = L.TIP_LAYOUT, text = text, step = step })
    -- The daisywheel's look: each group of 4 in a ring, or the characters alone
    b.choice({ id = "k_dwlook", label = L.LBL_DW_LOOK, indent = true, disabled = s.inputMethod ~= "wheel",
        tip = L.TIP_DW_LOOK,
        text = function() return s.petalRings and L.DW_LOOK_RINGS or L.DW_LOOK_PLAIN end,
        step = function()
            s.petalRings = not s.petalRings
            CK:UpdateMethod()
        end })
    -- 4 preset sizes (/ec scale still sets any value)
    local function sizeIndex()
        local best, bestD = 2, math.huge
        for i, size in ipairs(SIZES) do
            local d = math.abs(size.scale - s.scale)
            if d < bestD then best, bestD = i, d end
        end
        return best, bestD < 0.01
    end
    b.choice({ id = "k_size", label = L.OPT_SCALE, tip = L.TIP_SIZE,
        text = function()
            local i, exact = sizeIndex()
            if exact then return format("%s (%d %%)", SIZES[i].name, SIZES[i].scale * 100 + 0.5) end
            return percent(s.scale)
        end,
        step = function(d)
            local i, exact = sizeIndex()
            if exact then
                i = math.min(#SIZES, math.max(1, i + d))
            else
                -- From a custom value: the next preset that way (none: as it is)
                i = nil
                for n = 1, #SIZES do
                    local preset = SIZES[d > 0 and n or (#SIZES + 1 - n)].scale
                    if (d > 0 and preset > s.scale) or (d < 0 and preset < s.scale) then
                        i = d > 0 and n or (#SIZES + 1 - n)
                        break
                    end
                end
            end
            if not i then return end
            s.scale = SIZES[i].scale
            if CK.frame then
                CK.frame:SetScale(s.scale)
                CK:PositionSendButton()
            end
        end })
end

local function sticksRows(b)
    if keyboardOff(b) then return end
    local s = settings()
    b.header(L.SEC_STICKS)
    b.slider({ id = "k_dead", label = L.LBL_DEADZONE, tip = L.OPT_DEADZONE, min = 0.05, max = 0.40, stepSize = 0.05,
        fmt = percent, get = function() return s.deadzone end,
        set = function(v) s.deadzone = math.floor(v * 100 + 0.5) / 100 end })
    local text, step = pick(CURVES, s, "stickCurve")
    b.choice({ id = "k_curve", label = L.LBL_RESPONSE, tip = L.TIP_CURVE, text = text, step = step })
    text, step = pick(MAGNETS, s, "magnet")
    b.choice({ id = "k_magnet", label = L.LBL_MAGNET, tip = L.TIP_MAGNET, text = text, step = step })
    b.check({ id = "k_inv", label = L.LBL_INVERT, tip = L.OPT_INVERT,
        get = function() return s.invertY end, set = function(v) s.invertY = v end })
    b.check({ id = "k_line", label = L.LBL_CURSOR_LINE, tip = L.OPT_LINE,
        get = function() return s.showLine end,
        set = function(v)
            s.showLine = v
            CK:UpdateMethod()
        end })
end

local function predictionRows(b)
    if keyboardOff(b) then return end
    local s = settings()
    b.header(L.SEC_PREDICTION)
    b.choice({ id = "k_lang", label = L.LBL_SUGGESTIONS, tip = L.OPT_LANG,
        text = function() return CK:GetLanguage().name end,
        step = function(d)
            local i = (indexOf(CK.LANGUAGES, CK:GetLanguage().key) - 1 + d) % #CK.LANGUAGES + 1
            CK:SetLanguage(CK.LANGUAGES[i].key)
        end })
    b.check({ id = "k_learn", label = L.OPT_LEARN, tip = L.TIP_LEARN,
        get = function() return s.learn end, set = function(v) s.learn = v end })
    local learned = CK.Predict:NumLearned()
    b.stat({ label = L.LBL_LEARNED_WORDS, text = BreakUpLargeNumbers and BreakUpLargeNumbers(learned) or tostring(learned) })
    -- Two presses to forget (no confirmation popup)
    b.button({ id = "k_forget", label = L.OPT_FORGET, danger = true, armedLabel = L.LBL_FORGET_ARMED,
        disabled = learned == 0, tip = format(L.TIP_FORGET, learned),
        func = function()
            CK.Predict:Forget()
            Config:Toast(L.FORGOT)
        end })
end

local function keyboardPositionRows(b)
    if keyboardOff(b) then return end
    local s = settings()
    b.header(L.SEC_POSITION)
    b.check({ id = "k_lock", label = L.OPT_LOCK, tip = L.TIP_KB_LOCK,
        get = function() return s.locked end,
        set = function(v)
            s.locked = v
            CK:UpdateLock()
        end })
    b.check({ id = "k_mouse", label = L.LBL_MOUSE_BUTTONS, tip = L.OPT_ACTIONS,
        get = function() return s.showActions end,
        set = function(v)
            s.showActions = v
            CK:ApplyLayout()
        end })
    b.button({ id = "k_reset", label = L.OPT_RESET_POS, tip = L.OPT_RESET_POS,
        func = function()
            CK.db.pos = nil
            if CK.frame then CK:RestorePosition() end
            Config:Toast(L.TOAST_KB_RESET)
        end })
end

Config.pages.keyboard = Config.NewRailPage({
    key = "keyboard",
    sections = {
        { key = "opening", label = L.SEC_OPENING, tip = L.TIP_SEC_OPENING, rows = openingRows },
        { key = "input", label = L.SEC_INPUT, tip = L.TIP_SEC_INPUT, rows = inputRows },
        { key = "sticks", label = L.SEC_STICKS, tip = L.TIP_SEC_STICKS, rows = sticksRows },
        { key = "prediction", label = L.SEC_PREDICTION, tip = L.TIP_SEC_PREDICTION, rows = predictionRows },
        { key = "position", label = L.SEC_POSITION, tip = L.TIP_SEC_KBPOS, rows = keyboardPositionRows },
    },
})

---------------------------------------------------------------------------
-- Alerts: vibrations, supplies, quest items
---------------------------------------------------------------------------
local function vibrationRows(b)
    local V = CK.Vibration
    local s = V:Settings()
    b.header(L.SEC_VIBRATIONS)
    b.check({ id = "v_on", label = L.VIB_ENABLE, tip = s.enabled and L.TIP_MOD_VIBRATIONS or L.VIB_OFF_INFO,
        get = function() return s.enabled end,
        set = function(v)
            s.enabled = v
            if v then V:Play("pulse") else V:Stop() end
        end })
    if not s.enabled then return end
    b.slider({ id = "v_int", label = L.LBL_INTENSITY, indent = true, tip = L.VIB_INTENSITY, min = 0.2, max = 1,
        stepSize = 0.1, fmt = percent, get = function() return s.intensity end,
        set = function(v)
            s.intensity = math.floor(v * 10 + 0.5) / 10
            V:Play("pulse")
        end })
    for _, group in ipairs(V.GROUPS) do
        local events = V:GroupEvents(group)
        if #events > 0 then
            b.header(L["VIB_H_" .. group:upper()])
            for _, e in ipairs(events) do
                local cfg = s.events[e.key]
                b.event({ id = "v_" .. e.key, label = L["VIBS_" .. e.key:upper()], tip = L["VIB_E_" .. e.key:upper()],
                    on = function() return cfg.on end,
                    toggle = function()
                        cfg.on = not cfg.on
                        if cfg.on then V:Play(cfg.pattern) end
                    end,
                    pattern = function() return cfg.on and L["VIB_P_" .. cfg.pattern:upper()] or L.VIB_OFF end,
                    -- A pattern picked turns the event on
                    step = function(d)
                        cfg.pattern = V:NextPattern(cfg.pattern, d)
                        cfg.on = true
                        V:Play(cfg.pattern)
                    end,
                    onY = function()
                        V:Play(cfg.pattern)
                        Config:Toast(format(L.TOAST_VIB_TEST, L["VIB_P_" .. cfg.pattern:upper()]))
                    end, yVerb = L.V_TEST })
            end
        end
    end
end

local DIR_NAMES = { right = "SUP_DIR_RIGHT", left = "SUP_DIR_LEFT", down = "SUP_DIR_DOWN", up = "SUP_DIR_UP" }

local function suppliesRows(b, page)
    local S = CK.Supplies
    local s = settings().supplies
    b.header(L.SEC_SUPPLIES)
    b.check({ id = "s_on", label = L.LBL_SUPPLY_BUTTONS, tip = L.SUP_ENABLE,
        get = function() return s.enabled end,
        set = function(v)
            s.enabled = v
            S:Refresh()
        end })
    if not s.enabled then return end
    b.header(L.SUP_H_TRACKED)
    for _, r in ipairs(S:Resources()) do
        local cfg = r.cfg
        b.check({ id = "s_" .. r.key, label = r.name, status = tostring(r.count),
            tip = format(L.TIP_RESOURCE, r.count, cfg.low, cfg.critical),
            get = function() return cfg.on end,
            set = function(v)
                cfg.on = v
                S:Refresh()
            end })
        if cfg.on then
            local step = S.Step(r.kind)
            b.choice({ id = "s_low_" .. r.key, label = L.SUP_LOW, indent = true, tip = L.TIP_LOW,
                text = function() return tostring(cfg.low) end,
                step = function(d) S:SetThreshold(cfg, "low", cfg.low + d * step) end })
            b.choice({ id = "s_crit_" .. r.key, label = L.SUP_CRITICAL, indent = true, tip = L.TIP_CRITICAL,
                text = function() return tostring(cfg.critical) end,
                step = function(d) S:SetThreshold(cfg, "critical", cfg.critical + d * step) end })
        end
        if r.custom then
            b.button({ id = "s_rm_" .. r.key, label = L.SUP_REMOVE, indent = true, tip = L.TIP_REMOVE,
                func = function()
                    S:RemoveItem(r.id)
                    Config:Toast(format(L.TOAST_REMOVED, r.name))
                end })
        end
    end
    -- The picker, one list: the bags
    b.button({ id = "s_add", label = L.LBL_ADD_BAGS, tip = L.SUP_ADD_SHOW, verb = L.V_OPEN,
        func = function()
            page:OpenPicker({
                kicker = L.SEC_SUPPLIES, title = L.LBL_ADD_BAGS, rows = 9,
                lists = { { label = L.LIST_BAGS, entries = function()
                    local entries = { { header = L.HDR_YOUR_BAGS } }
                    for _, item in ipairs(S:BagItems()) do
                        entries[#entries + 1] = { action = item.id, name = item.name, icon = item.icon, sub = tostring(item.count) }
                    end
                    if #entries == 1 then entries = {} end
                    return entries
                end } },
                onChoose = function(e)
                    S:AddItem(e.action)
                    page.picker:Close()
                    Config:Toast(format(L.TOAST_TRACKED, e.name))
                end,
            })
        end })
    b.header(L.HDR_BUTTONS)
    b.choice({ id = "s_dir", label = L.LBL_DIRECTION, tip = L.TIP_DIRECTION,
        text = function() return L[DIR_NAMES[s.layout] or "SUP_DIR_RIGHT"] end,
        step = function(d)
            local i = (indexOf(S.DIRECTIONS, s.layout) - 1 + d) % #S.DIRECTIONS + 1
            s.layout = S.DIRECTIONS[i].key
            S:Refresh()
        end })
    local sizes = { L.SIZE_SMALL, L.SIZE_NORMAL, L.SIZE_LARGE }
    b.choice({ id = "s_size", label = L.SUP_SIZE, tip = L.TIP_SUP_SIZE,
        text = function() return sizes[s.size] or sizes[2] end,
        step = function(d)
            s.size = ((s.size or 2) - 1 + d) % #sizes + 1
            S:Refresh()
        end })
    b.check({ id = "s_lock", label = L.OPT_LOCK, tip = L.SUP_LOCK,
        get = function() return s.locked end, set = function(v) s.locked = v end })
    b.button({ id = "s_move", label = L.SUP_MOVE, tip = L.TIP_SUP_MOVE,
        func = function()
            Config:BeginPlacement(S)
            S:StartPlacement()
        end })
    b.button({ id = "s_reset", label = L.SUP_RESET, tip = L.SUP_RESET,
        func = function()
            S:ResetPosition()
            Config:Toast(L.TOAST_SUP_RESET)
        end })
end

local function questRows(b)
    local s = settings()
    local mods, f = s.modules, s.features
    b.header(L.SEC_QUESTITEMS)
    b.check({ id = "q_on", label = L.SEC_QUESTITEMS, tip = L.MOD_QUEST_ITEMS,
        get = function() return mods.questItems end,
        set = function(v)
            mods.questItems = v
            if v then
                CK.QuestItems:ScanBags()
                CK.QuestItems:ScanQuests()
            end
            CK.QuestItems:RefreshBorders()
        end })
    if not mods.questItems then return end
    b.check({ id = "q_tip", label = L.LBL_QI_TOOLTIP, indent = true, tip = L.FEAT_QUEST_TOOLTIP,
        get = function() return f.questTooltip end, set = function(v) f.questTooltip = v end })
    b.check({ id = "q_glow", label = L.LBL_QI_GLOW, indent = true, tip = L.FEAT_QUEST_GLOW,
        get = function() return f.questGlow end,
        set = function(v)
            f.questGlow = v
            CK.QuestItems:RefreshBorders()
        end })
    b.check({ id = "q_sell", label = L.LBL_QI_SELL, indent = true, tip = L.FEAT_QUEST_SELL,
        get = function() return f.questSellAlert end, set = function(v) f.questSellAlert = v end })
    b.check({ id = "q_hover", label = L.LBL_QI_HOVER, indent = true, tip = L.FEAT_QUEST_HOVER,
        get = function() return f.questHoverAlert end, set = function(v) f.questHoverAlert = v end })
end

-- Marks in the bags (Upgrades.lua)
local function inventoryRows(b)
    local mods = settings().modules
    b.header(L.SEC_INVENTORY)
    b.check({ id = "i_up", label = L.LBL_UPGRADES, status = function() return CK.Upgrades:ByStats() and L.STATUS_CLASS_STATS or L.STATUS_ITEM_LEVEL end, tip = L.TIP_UPGRADES,
        extra = function() return CK.Upgrades:ScaleText() end,
        get = function() return mods.upgrades end,
        set = function(v)
            mods.upgrades = v
            CK.Upgrades:Refresh()
        end })
end

Config.pages.alerts = Config.NewRailPage({
    key = "alerts",
    sections = {
        { key = "vibrations", label = L.SEC_VIBRATIONS, tip = L.TIP_SEC_VIBRATIONS, rows = vibrationRows },
        { key = "supplies", label = L.SEC_SUPPLIES, tip = L.SUP_INFO, rows = suppliesRows },
        { key = "quest", label = L.SEC_QUESTITEMS, tip = L.TIP_SEC_QUESTITEMS, rows = questRows },
        { key = "inventory", label = L.SEC_INVENTORY, tip = L.TIP_SEC_INVENTORY, rows = inventoryRows },
    },
})

---------------------------------------------------------------------------
-- Wheels: the player's own (a grid of cards, MyWheels.lua, each opening its
-- editor), the consumables wheel, where every wheel opens
---------------------------------------------------------------------------
local function consumableRows(b)
    local W = CK.ConsumableWheel
    local s = settings().wheel
    b.header(L.WHEEL_NAME)
    b.check({ id = "cw_on", label = L.LBL_USE_WHEEL, tip = L.WHEEL_INFO,
        get = function() return s.enabled end,
        set = function(v)
            s.enabled = v
            W:Fill()
        end })
    b.check({ id = "cw_var", label = L.LBL_ALL_VARIANTS, indent = true, disabled = not s.enabled, tip = L.WHEEL_VARIANTS,
        get = function() return s.variants end,
        set = function(v)
            s.variants = v
            W:Fill()
        end })
    b.check({ id = "cw_seated", label = L.LBL_STAY_SEATED, tip = L.TIP_STAY_SEATED,
        get = function() return s.staySeated end,
        set = function(v)
            s.staySeated = v
            if not v and W.seated then W.seated:Hide() end
        end })
    b.check({ id = "cw_bandage", label = L.LBL_STILL_BANDAGING, tip = L.TIP_STILL_BANDAGING,
        get = function() return s.stillBandaging end,
        set = function(v)
            s.stillBandaging = v
            if not v and W.seated then W.seated:Hide() end
        end })
    b.header(L.WHEEL_H_CATEGORIES)
    for _, cat in ipairs(W.CATEGORIES) do
        b.check({ id = "cat_" .. cat, label = L["WHEEL_CAT_" .. cat:upper()], disabled = not s.enabled,
            tip = L.TIP_WHEEL_CAT,
            get = function() return s.categories[cat] end,
            set = function(v)
                s.categories[cat] = v
                W:Fill()
            end })
    end
end

-- How every wheel opens: pressed (open, A uses, press again closes) or held
local function wheelOpenRows(b)
    local s = settings().wheel
    b.header(L.SEC_WHEEL_OPEN)
    b.check({ id = "w_hold", label = L.LBL_WHEEL_HOLD, tip = L.TIP_WHEEL_HOLD,
        get = function() return s.hold end,
        set = function(v)
            s.hold = v
            CK.ConsumableWheel:Fill()
        end })
end

local function wheelPositionRows(b)
    local W = CK.ConsumableWheel
    local s = settings().wheel
    b.header(L.SEC_POSITION)
    b.check({ id = "w_lock", label = L.OPT_LOCK, tip = L.TIP_WHEEL_LOCK,
        get = function() return s.locked end, set = function(v) s.locked = v end })
    b.button({ id = "w_move", label = L.SUP_MOVE, tip = L.WHEEL_MOVE,
        func = function()
            Config:BeginPlacement(W)
            W:StartPlacement()
        end })
    b.button({ id = "w_reset", label = L.LBL_BACK_TO_CENTER, tip = L.WHEEL_RESET,
        func = function()
            W:ResetPosition()
            Config:Toast(L.TOAST_WHEEL_RESET)
        end })
end

Config.pages.wheels = CK.MyWheels:TabPage(Config.NewRailPage({
    key = "wheels",
    sections = {
        { key = "mine", label = L.MYWHEEL_H, tip = L.MYWHEEL_INFO, view = CK.MyWheels.Grid },
        { key = "consumables", label = L.SEC_CONSUMABLES, tip = L.WHEEL_INFO2, rows = consumableRows },
        { key = "open", label = L.SEC_WHEEL_OPEN, tip = L.TIP_SEC_WHEEL_OPEN, rows = wheelOpenRows },
        { key = "position", label = L.SEC_POSITION, tip = L.TIP_SEC_WHEELPOS, rows = wheelPositionRows },
    },
}))

---------------------------------------------------------------------------
-- The game's settings panel (Escape > Options > AddOns > Controller
-- Keyboard) only points to the addon's own panel. Plain buttons: no
-- dropdowns or StaticPopups, which go through WoW Forever's gamepad UI.
---------------------------------------------------------------------------
function CK:RegisterOptions()
    if self.optionsPanel then return end
    local panel = CK.NewFrame("Frame")
    panel.name = "Easy Controller - Forever"
    panel:Hide()
    self.optionsPanel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Easy Controller - Forever")
    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 16, -40)
    sub:SetText(L.OPT_SUBTITLE)
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", 16, -70)
    hint:SetWidth(560)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.CFG_SETTINGS_HINT)
    local open = CK.NewFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(240, 26)
    open:SetPoint("TOPLEFT", 16, -120)
    open:SetText(L.CFG_OPEN)
    open:SetScript("OnClick", function() CK.Config:OpenWhenFree() end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
