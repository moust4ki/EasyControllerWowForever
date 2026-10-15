local _, CK = ...

-- Gamepad button glyphs: the game's own atlases when this client has them,
-- otherwise the Claude Design textures shipped with the addon.
local TEX = "Interface\\AddOns\\EasyController\\textures\\"

local FALLBACK = {
    A = "ck_g_a", B = "ck_g_b", X = "ck_g_x", Y = "ck_g_y",
    LB = "ck_g_lb", RB = "ck_g_rb", LT = "ck_g_lt", RT = "ck_g_rt",
    LS = "ck_g_ls", RS = "ck_g_rs",
    DPAD = "ck_g_dpad", DPAD_LR = "ck_g_dpad_lr", DPAD_UP = "ck_g_dpad_up",
    DPAD_LEFT = "ck_g_dpad_lr", DPAD_RIGHT = "ck_g_dpad_lr", DPAD_DOWN = "ck_g_dpad",
}

-- Atlas names tried first, per glyph style. /ec glyphs lists the gamepad
-- atlases this client really has, to complete these lists.
local ATLAS = {
    xbox = {
        A = { "Gamepad_Ltr_A_64", "Gamepad_Ltr_A_32" },
        B = { "Gamepad_Ltr_B_64", "Gamepad_Ltr_B_32" },
        X = { "Gamepad_Ltr_X_64", "Gamepad_Ltr_X_32" },
        Y = { "Gamepad_Ltr_Y_64", "Gamepad_Ltr_Y_32" },
        LB = { "Gamepad_Ltr_LShoulder_64", "Gamepad_Gen_LShoulder_64" },
        RB = { "Gamepad_Ltr_RShoulder_64", "Gamepad_Gen_RShoulder_64" },
        LT = { "Gamepad_Ltr_LTrigger_64", "Gamepad_Gen_LTrigger_64" },
        RT = { "Gamepad_Ltr_RTrigger_64", "Gamepad_Gen_RTrigger_64" },
        LS = { "Gamepad_Gen_LStickIn_64", "Gamepad_Ltr_LStickIn_64" },
        RS = { "Gamepad_Gen_RStickIn_64", "Gamepad_Ltr_RStickIn_64" },
        DPAD_UP = { "Gamepad_Gen_Up_64", "Gamepad_Ltr_Up_64" },
        DPAD_LEFT = { "Gamepad_Gen_Left_64", "Gamepad_Ltr_Left_64" },
        DPAD_RIGHT = { "Gamepad_Gen_Right_64", "Gamepad_Ltr_Right_64" },
        DPAD_DOWN = { "Gamepad_Gen_Down_64", "Gamepad_Ltr_Down_64" },
    },
    switch = {
        A = { "gamepad-switch-128x-face-b-normal" },
        B = { "gamepad-switch-128x-face-a-normal" },
        X = { "gamepad-switch-128x-face-y-normal" },
        Y = { "gamepad-switch-128x-face-x-normal" },
        LB = { "gamepad-switch-128x-shoulder-l-normal" },
        RB = { "gamepad-switch-128x-shoulder-r-normal" },
        LT = { "gamepad-switch-128x-zl-normal" },
        RT = { "gamepad-switch-128x-zr-normal" },
        LS = { "gamepad-switch-128x-stick-l3-normal", "gamepad-switch-128x-stick-l-normal" },
        RS = { "gamepad-switch-128x-stick-r3-normal", "gamepad-switch-128x-stick-r-normal" },
        DPAD = { "gamepad-switch-128x-dpad-all-normal" },
        DPAD_LR = { "gamepad-switch-128x-dpad-leftright-normal" },
        DPAD_UP = { "gamepad-switch-128x-dpad-up-normal" },
        DPAD_LEFT = { "gamepad-switch-128x-dpad-left-normal" },
        DPAD_RIGHT = { "gamepad-switch-128x-dpad-right-normal" },
        DPAD_DOWN = { "gamepad-switch-128x-dpad-down-normal" },
    },
    playstation = {
        A = { "Gamepad_Shp_Cross_64", "Gamepad_Shp_Cross_32" },
        B = { "Gamepad_Shp_Circle_64", "Gamepad_Shp_Circle_32" },
        X = { "Gamepad_Shp_Square_64", "Gamepad_Shp_Square_32" },
        Y = { "Gamepad_Shp_Triangle_64", "Gamepad_Shp_Triangle_32" },
        LB = { "Gamepad_Shp_LShoulder_64", "Gamepad_Gen_LShoulder_64" },
        RB = { "Gamepad_Shp_RShoulder_64", "Gamepad_Gen_RShoulder_64" },
        LT = { "Gamepad_Shp_LTrigger_64", "Gamepad_Gen_LTrigger_64" },
        RT = { "Gamepad_Shp_RTrigger_64", "Gamepad_Gen_RTrigger_64" },
        LS = { "Gamepad_Gen_LStickIn_64", "Gamepad_Shp_LStickIn_64" },
        RS = { "Gamepad_Gen_RStickIn_64", "Gamepad_Shp_RStickIn_64" },
        DPAD_UP = { "Gamepad_Gen_Up_64", "Gamepad_Shp_Up_64" },
        DPAD_LEFT = { "Gamepad_Gen_Left_64", "Gamepad_Shp_Left_64" },
        DPAD_RIGHT = { "Gamepad_Gen_Right_64", "Gamepad_Shp_Right_64" },
        DPAD_DOWN = { "Gamepad_Gen_Down_64", "Gamepad_Shp_Down_64" },
    },
}

-- Without the game's icons, Switch shows our letters where Nintendo puts them
local SWITCH_FALLBACK = { A = "ck_g_b", B = "ck_g_a", X = "ck_g_y", Y = "ck_g_x" }
local function fallback(style, key)
    return (style == "switch" and SWITCH_FALLBACK[key]) or FALLBACK[key] or "ck_g_a"
end

local function atlasExists(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

---------------------------------------------------------------------------
-- The style in use: the one picked, or Auto: the controller's, as the game
-- labels it (its config's label style: Letters, Shapes, Reverse)
---------------------------------------------------------------------------
local LABEL_OF = { xbox = "Letters", playstation = "Shapes", switch = "Reverse" }
local STYLE_OF = { Letters = "xbox", Shapes = "playstation", Reverse = "switch" }
CK.GLYPH_LABEL_OF = LABEL_OF

local GP = C_GamePad

local function activeState()
    local id = GP and GP.GetActiveDeviceID and GP.GetActiveDeviceID()
    local state = id and GP.GetDeviceMappedState and GP.GetDeviceMappedState(id)
    return id, type(state) == "table" and state or nil
end

-- The label style the game gives the controller in use now (nil: none)
function CK:GameLabelStyle()
    local _, state = activeState()
    local label = state and state.labelStyle
    return type(label) == "string" and label or nil
end

-- (read again when the game's controllers or configs change)
function CK:GlyphStyle(style)
    style = style or (self.db and self.db.settings.glyphStyle) or "xbox"
    if style ~= "auto" then return style end
    if self.labelCache == nil then self.labelCache = self:GameLabelStyle() or false end
    return STYLE_OF[self.labelCache or ""] or "xbox"
end

-- style: another one than the one chosen (the guide's choices show theirs)
function CK:SetGlyph(tex, key, style)
    style = self:GlyphStyle(style)
    if self.db.settings.gameGlyphs then
        for _, name in ipairs((ATLAS[style] or ATLAS.xbox)[key] or {}) do
            if atlasExists(name) then
                tex:SetAtlas(name)
                return
            end
        end
    end
    tex:SetTexture(TEX .. fallback(style, key))
    tex:SetTexCoord(0, 1, 0, 1)
end

-- The same glyph inline in a text ("|A...|a" or "|T...|t")
function CK:GlyphMarkup(key, size)
    size = size or 16
    local style = self:GlyphStyle()
    if self.db.settings.gameGlyphs then
        for _, name in ipairs((ATLAS[style] or ATLAS.xbox)[key] or {}) do
            if atlasExists(name) then return format("|A:%s:%d:%d|a", name, size, size) end
        end
    end
    return format("|T%s%s:%d:%d|t", TEX, fallback(style, key), size, size)
end

---------------------------------------------------------------------------
-- The game's own icons (asked): its interface (the NPCs' interact icon, the
-- quest log, the gamepad bar...) shows those of its controller config's
-- label style. Forever lets an addon set it (C_GamePad.SetConfig, then
-- ApplyConfigs: tried in game, the whole interface follows, after a /reload
-- if it doesn't at once). A style picked here (the panel, the guide) sets
-- it too; Auto puts the game's back. The config: the controller's own (its
-- vendor and product, when the game gives them), else the one every
-- controller without its own uses (Steam Input, XInput: no identity given).
-- What was there kept to be put back (CK.db.gameGlyphs); nothing touched
-- before a style is picked.
---------------------------------------------------------------------------
local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end

local function configOf(id)
    local ok, c = pcall(GP.GetConfig, id)
    return ok and type(c) == "table" and c or nil
end

-- The config the controller in use reads
local function configID()
    local id = GP.GetActiveDeviceID and GP.GetActiveDeviceID()
    local raw = id and GP.GetDeviceRawState and GP.GetDeviceRawState(id)
    if type(raw) == "table" and type(raw.vendorID) == "number" and type(raw.productID) == "number" then
        return { vendorID = raw.vendorID, productID = raw.productID }
    end
    return {}
end

local function apply(config)
    return pcall(GP.SetConfig, config) and pcall(GP.ApplyConfigs)
end

-- What the game had, back (Auto, or a broken controller)
local function restore(saved)
    if saved.created then
        pcall(GP.DeleteConfig, saved.id)
        pcall(GP.ApplyConfigs)
    else
        local c = configOf(saved.id)
        if c then
            c.labelStyle = saved.original
            apply(c)
        end
    end
end

-- The game's icons to the style picked (nil, "auto": the game's own).
-- Returns false when the game can't take it (said why: L.GLYPHS_GAME_*)
function CK:SetGameGlyphs(style)
    if not (GP and GP.GetConfig and GP.SetConfig and GP.ApplyConfigs) then return false, "unsupported" end
    if InCombatLockdown() then return false, "combat" end
    local db = self.db
    local saved = db.gameGlyphs
    local want = LABEL_OF[style or ""]
    if not want then
        if saved then
            restore(saved)
            self.glyphsExpect = saved.original
        end
        db.gameGlyphs = nil
        self.labelCache = nil
        return true
    end
    local id = saved and saved.id or configID()
    local c = configOf(id)
    local created = false
    if not c then
        -- None of its own: one made from the one every controller reads
        -- (its mappings empty: the game's own)
        c = copy(configOf({}) or { rawButtonMappings = {}, rawAxisMappings = {}, axisConfigs = {}, stickConfigs = {} })
        c.configID = copy(id)
        created = true
    end
    if not saved then saved = { id = copy(id), original = c.labelStyle, created = created } end
    if c.labelStyle == want and db.gameGlyphs then return true end
    c.labelStyle = want
    if not apply(c) then
        restore(saved)
        return false, "refused"
    end
    -- The controller still read (its buttons): else everything put back
    local _, state = activeState()
    if state and (tonumber(state.buttonCount) or 0) == 0 then
        restore(saved)
        db.gameGlyphs = nil
        self.labelCache = nil
        self.glyphsExpect = saved.original
        return false, "broken"
    end
    saved.forced = want
    db.gameGlyphs = saved
    self.labelCache = nil
    self.glyphsExpect = want
    return true
end

-- The game's interface showing the style its config now says (else after
-- a /reload: it reads its icons when it loads). Read only, never called
function CK:GameGlyphsShown()
    local manager = InputDeviceIconSetManager
    local shown = type(manager) == "table" and rawget(manager, "activeInputDeviceIconSet")
    -- (the keyboard and mouse in use: "Generic", nothing to compare)
    if type(shown) ~= "string" or shown == "Generic" then return true end
    local expect = self.glyphsExpect or self:GameLabelStyle()
    return expect == nil or shown == expect
end

-- A style picked (the panel, the guide): ours and the game's
function CK:PickGlyphStyle(style)
    self.db.settings.glyphStyle = style
    local ok, why = self:SetGameGlyphs(style)
    self:UpdateGlyphs()
    if not ok and why ~= "unsupported" then
        self:Print(CK.L["GLYPHS_GAME_" .. why:upper()] or CK.L.GLYPHS_GAME_REFUSED)
    end
    return ok, why
end

-- At login: the game's config as it was left (a game update may have put
-- it back): set again when it differs; a style left on Auto with ours
-- still there: put back
function CK:CheckGameGlyphs()
    local saved = self.db.gameGlyphs
    if not saved then return end
    if InCombatLockdown() then
        self.glyphsCheckPending = true
        return
    end
    local style = self.db.settings.glyphStyle
    if not LABEL_OF[style or ""] then
        self:SetGameGlyphs(nil)
    elseif self:GameLabelStyle() ~= LABEL_OF[style] then
        self:SetGameGlyphs(style)
    end
end

do
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED",
        "GAME_PAD_CONFIGS_CHANGED", "PLAYER_REGEN_ENABLED" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if CK.glyphsCheckPending then
                CK.glyphsCheckPending = nil
                CK:CheckGameGlyphs()
            end
            return
        end
        -- Auto: the controller's glyphs, whichever it is now
        CK.labelCache = nil
        if CK.db and CK.db.settings.glyphStyle == "auto" and CK.UpdateGlyphs then CK:UpdateGlyphs() end
    end)
end

-- /ec glyphs: print the gamepad atlases found in this client
function CK:ListGlyphAtlases()
    local prefixes = { "Gamepad_Ltr_", "Gamepad_Shp_", "Gamepad_Gen_", "Gamepad_Rev_" }
    local names = {
        "A", "B", "X", "Y", "Cross", "Circle", "Square", "Triangle",
        "LShoulder", "RShoulder", "LTrigger", "RTrigger", "LStickIn", "RStickIn",
        "LStick", "RStick", "Up", "Down", "Left", "Right", "Menu", "View",
        "Share", "Options", "System", "Paddle1", "Paddle2",
    }
    local sizes = { "_64", "_32", "_16", "" }
    local found = {}
    for _, p in ipairs(prefixes) do
        for _, n in ipairs(names) do
            for _, s in ipairs(sizes) do
                local name = p .. n .. s
                if atlasExists(name) then
                    found[#found + 1] = name
                    break
                end
            end
        end
    end
    if #found == 0 then
        self:Print(CK.L.GLYPHS_NONE)
    else
        self:Print(CK.L.GLYPHS_FOUND, #found)
        for i = 1, #found, 4 do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. table.concat(found, "  ", i, math.min(i + 3, #found)))
        end
    end
end
