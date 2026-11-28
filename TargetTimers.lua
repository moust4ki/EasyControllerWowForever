local _, CK = ...

-- Hawk timers (asked; hunters, Comfort › Target timers, off by default): the
-- hawks summoned (Invocation de faucon: the game's totem slots, one or two
-- at once; the game shows them as round icons under the pet's frame, left
-- as they are) shown on the target's nameplate (the bar over the mob), as
-- the player chooses:
--   - icons (by default): the game's own hawk icon copied (its round icon
--     and ring, the countdown under it in its font), at the right of the
--     plate's level box, side by side, as big on the screen as the game's;
--     the turning shade the game puts on it can't be copied (its
--     Cooldown:SetCooldown is protected for addons);
--   - bars: a copy of the plate's cast bar under it (its background, the
--     crafting's blue fill, its spark, the frame its Edit Mode preview
--     shows; its sizes and style the player's plates' own, read live: the
--     icon and the hawk's name in or under the bar, the countdown), the
--     thickness and the gap under the cast bar options.
-- (Effects on the target, DoTs and slows, were tried and taken out: the
-- game never let addons read them in combat in game, seen 2026-11-28.)
--
-- In combat the game hides the totems' values from addons (secret values):
-- never read, compared or counted then. The bars get the game's own timers
-- (duration objects, StatusBar:SetTimerDuration), the icons its textures,
-- the countdowns are written by the game (a duration text binding, its
-- seconds formatter). No nameplate for the target (off the screen,
-- nameplates off): nothing shown.
local T = {}
CK.TargetTimers = T

local GAP = 4               -- between two bars (a bar's frame goes 4 out)
local TEXTURE = "Interface\\Buttons\\WHITE8X8"
local MAX_TOTEMS = 4
-- The plate's cast bar (Blizzard_NamePlateCastingBar, its options: a 16 px
-- bar, a 12 px icon, a 12 px font, a 4 x 12 spark)
local CAST = {
    back = "ui-castingbar-background",
    spark = "ui-castingbar-pip",
    fill = "ui-castingbar-filling-applyingcrafting",    -- blue: the hawks
    -- The frame the plate's cast bar shows in the game's Edit Mode (the
    -- player's model): the important cast's frame with its glowing ends,
    -- the targeted cast's red outline
    important = "ui-hud-nameplates-importantcast",
    targeted = "ui-hud-nameplates-targetedbyenemy",
    height = 16, icon = 12, font = 12, sparkW = 4, sparkH = 12,
}
local PLAIN = { 0, 0, 0, 0.5 }      -- no atlas: the classic cast bar's background
local HAWK = { 0.3, 0.62, 1 }       -- the plain bar's blue
-- The game's hawk icon (TotemButtonTemplate, Blizzard_UnitFrame): a 37 px
-- button, the 22 px icon in a circle, its 30 px ring a little off centre,
-- the countdown 5 px into its bottom
local TOTEM = {
    size = 37, icon = 22, ring = 30, ringX = 1, ringY = -1.5, textY = 5,
    ringAtlas = "UI-HUD-UnitFrame-TotemFrame",
    mask = "CircleMask",
}
local ICON_GAP = 2          -- between the level box and the icons
-- From one icon to the next (asked: closer than the game's 37 px buttons
-- side by side: their 30 px rings 4 px apart)
local ICON_STEP = 34

local function settings() return CK.db.settings.targetTimers end

local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function plain(v)
    if secret(v) then return nil end
    return v
end

-- A call of the game's that may refuse (hidden values, an API missing)
local function call(f, ...)
    if not f then return false end
    return pcall(f, ...)
end

-- An atlas of the game's: its size, when it has it
local function atlasInfo(name)
    local ok, info = call(C_Texture and C_Texture.GetAtlasInfo, name)
    return ok and type(info) == "table" and info or nil
end

function T:On()
    local _, class = UnitClass("player")
    return class == "HUNTER" and CK.db ~= nil and settings().enabled == true
end

-- "icons" (by default) or "bars"
function T:Display()
    return CK.db and settings().display == "bars" and "bars" or "icons"
end

-- The player's plates' cast bar, as the game sets it now (their size
-- option): its height, icon, font, the spell name inside or under it
function T.CastStyle()
    local o = type(NamePlateSetupOptions) == "table" and NamePlateSetupOptions or {}
    local function num(v, default)
        v = plain(v)
        return type(v) == "number" and v > 0 and v or default
    end
    return {
        height = num(o.castBarHeight, CAST.height),
        icon = num(o.castIconHeight, CAST.icon),
        font = num(o.castBarFontHeight, CAST.font),
        inside = plain(o.spellNameInsideCastBar) == true,
    }
end

---------------------------------------------------------------------------
-- The hawks: the totem slots
---------------------------------------------------------------------------
-- Slots the game says hold something with no time and no icon (seen in
-- game out of combat: a full bar, no icon, no countdown, no hawk): never a
-- hawk, in combat either
T.phantom = {}

local function empty(v) return v == nil or v == "" or v == 0 end

-- A hawk in that slot: true, false, or "hidden" (the game hides it, in
-- combat). A slot that returns nothing is empty (the game: "may return
-- nothing"); readable: a hawk has a time and an icon; hidden: its timer
-- says (zero: none), else unknown (a slot seen empty that way: none).
function T.HawkIn(have, duration, length, icon, slot)
    if not secret(have) then
        if have ~= true then return false end
        local timed = secret(length) or (type(length) == "number" and length > 0)
        local pictured = secret(icon) or not empty(icon)
        if timed and pictured then
            if slot then T.phantom[slot] = nil end
            return true
        end
        if slot and not secret(length) and not secret(icon) then T.phantom[slot] = true end
        return false
    end
    if slot and T.phantom[slot] then return false end
    local ok, zero = call(duration and duration.IsZero, duration)
    if ok and not secret(zero) and type(zero) == "boolean" then return not zero end
    return "hidden"
end

-- The hawks now: { slot, shown (true or "hidden"), have, name, start,
-- length, icon, duration }. A hidden one only when the game can show or
-- hide it itself (SetAlphaFromBoolean).
function T.Hawks(canHide)
    local out = {}
    local ok, slots = call(GetNumTotemSlots)
    slots = ok and plain(slots) or 0
    for slot = 1, math.min(type(slots) == "number" and slots or 0, MAX_TOTEMS) do
        local got, have, name, start, length, icon = call(GetTotemInfo, slot)
        local okd, duration = call(GetTotemDuration, slot)
        duration = okd and duration or nil
        local hawk = got and T.HawkIn(have, duration, length, icon, slot)
        if hawk == true or (hawk == "hidden" and canHide) then
            out[#out + 1] = { slot = slot, shown = hawk, have = have, name = name, start = start,
                length = length, icon = icon, duration = duration }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Timers: the game's (duration objects, its countdown), else counted here
---------------------------------------------------------------------------
local DIRECTION = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
local INTERPOLATION = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0

-- "12", "2m": a countdown counted here
function T.Countdown(left)
    if left <= 0 then return "" end
    if left >= 60 then return format("%dm", math.ceil(left / 60)) end
    return format("%d", math.ceil(left))
end

-- The game's seconds formatter (its aura buttons' settings: "12 s", "2 m")
local formatter
local function secondsFormatter()
    if formatter ~= nil then return formatter or nil end
    formatter = false
    local ok, f = call(C_StringUtil and C_StringUtil.CreateSecondsFormatter)
    if ok and f then
        local E = Enum or {}
        if E.SecondsFormatterAbbreviation then pcall(f.SetDefaultAbbreviation, f, E.SecondsFormatterAbbreviation.OneLetter) end
        if E.SecondsFormatterRounding then pcall(f.SetRounding, f, E.SecondsFormatterRounding.Truncate) end
        pcall(f.SetCanRoundUpLastUnit, f, true)
        formatter = f
    end
    return formatter or nil
end

-- A countdown the game writes on that font string (hidden values welcome)
local function newBinding(fontString)
    local ok, binding = call(C_DurationUtil and C_DurationUtil.CreateDurationTextBinding)
    if not (ok and binding) then return nil end
    pcall(binding.SetToDefaults, binding)
    local f = secondsFormatter()
    if f then pcall(binding.SetFormatter, binding, f) end
    pcall(binding.SetZeroDurationText, binding, "")
    pcall(binding.SetExpiredText, binding, "")
    if pcall(binding.SetFontString, binding, fontString) then return binding end
    return nil
end

-- The game's countdown for that timer (none: off)
local function bindText(item, duration)
    local b = item.binding
    if not b then return false end
    if duration and pcall(b.SetDuration, b, duration) then
        pcall(b.SetEnabled, b, true)
        return true
    end
    pcall(b.SetEnabled, b, false)
    return false
end

-- A countdown: the game's; else counted here from readable values
local function setCountdown(item, duration, start, length)
    item.manual = nil
    start, length = plain(start), plain(length)
    if bindText(item, duration) then return end
    if start and length and length > 0 then
        item.manual = { start = start, length = length, textOnly = true }
        item.text:SetText(T.Countdown(length - (GetTime() - start)))
    else
        item.text:SetText("")
    end
end

-- A bar fed the game's timer, its countdown the game's; the game's timer
-- missing or refused: counted here from readable values
local function setTimer(item, duration, start, length)
    local bar = item.bar
    item.manual = nil
    start, length = plain(start), plain(length)
    if duration and bar.SetTimerDuration and pcall(bar.SetTimerDuration, bar, duration, INTERPOLATION, DIRECTION) then
        if not bindText(item, duration) then
            item.text:SetText("")
            if start and length and length > 0 then item.manual = { start = start, length = length, textOnly = true } end
        end
        return
    end
    bindText(item, nil)
    if start and length and length > 0 then
        item.manual = { start = start, length = length }
        local left = length - (GetTime() - start)
        bar:SetMinMaxValues(0, length)
        bar:SetValue(math.max(0, left))
        item.text:SetText(T.Countdown(left))
    else
        item.text:SetText("")
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
    end
end

-- A hidden hawk: the game shows or hides it (its hidden answer); else fully
local function showHawk(item, hawk)
    if hawk.shown == "hidden" then
        if not pcall(item.SetAlphaFromBoolean, item, hawk.have) then item:SetAlpha(0) end
    else
        item:SetAlpha(1)
    end
    item:Show()
end

---------------------------------------------------------------------------
-- The target's nameplate (the bar over the mob): its parts, anchored to,
-- never read (their geometry may be hidden)
---------------------------------------------------------------------------
function T.Plate()
    local ok, plate = call(C_NamePlate and C_NamePlate.GetNamePlateForUnit, "target")
    plate = ok and type(plate) == "table" and plate or nil
    -- (a plate the game keeps from addons: none)
    if plate and plate.IsForbidden then
        local okF, forbidden = call(plate.IsForbidden, plate)
        if okF and forbidden == true then plate = nil end
    end
    local uf = plate and (plate.UnitFrame or plate.unitFrame)
    return type(uf) == "table" and uf or nil
end

function T.HealthBar(uf)
    local bars = uf.HealthBarsContainer
    local health = type(bars) == "table" and bars.healthBar or uf.healthBar or bars
    return type(health) == "table" and health or nil
end

-- The cast bar itself (not its place: that one holds the spell name's line
-- too), placed whether a cast shows or not; else its place
function T.CastBar(uf)
    local casts = uf.CastBarsContainer
    local castBar = type(casts) == "table" and casts.castBar or nil
    if type(castBar) == "table" then return castBar end
    return type(casts) == "table" and casts or nil
end

-- The plate's level box, when shown at the right of the health bar (its
-- anchor read, not its geometry)
function T.LevelBox(uf)
    local box = uf.LevelFrame
    if type(box) ~= "table" then return nil end
    local okS, shown = call(box.IsShown, box)
    if not (okS and shown == true) then return nil end
    local okP, _, _, relPoint = call(box.GetPoint, box, 1)
    relPoint = okP and plain(relPoint)
    if type(relPoint) == "string" and relPoint:find("RIGHT") then return box end
    return nil
end

-- The interface's pixels (the options', the game's icon size) in the
-- plate's own units: the target's plate is scaled up (seen in game: a 20 px
-- gap looked like centimetres). 1 when the game doesn't say.
function T.PlateRatio(parent)
    local okU, ui = call(UIParent and UIParent.GetEffectiveScale, UIParent)
    local okP, scale = call(parent and parent.GetEffectiveScale, parent)
    ui, scale = okU and plain(ui), okP and plain(scale)
    if type(ui) == "number" and type(scale) == "number" and ui > 0 and scale > 0 then return ui / scale end
    return 1
end

-- Our frame (one for each display) in the target's plate; parented anew
-- when the plate changes
local function holder(self, key, uf)
    local f = self[key]
    if not f then
        f = CK.NewFrame("Frame", "ControllerKeyboardTargetTimers" .. key, UIParent)
        f:SetSize(1, 1)
        f:Hide()
        self[key] = f
    end
    if f.plate ~= uf then
        f:SetParent(uf)
        local okS, strata = call(uf.GetFrameStrata, uf)
        if okS and plain(strata) then f:SetFrameStrata(strata) end
        local okL, level = call(uf.GetFrameLevel, uf)
        level = okL and plain(level)
        if type(level) == "number" then f:SetFrameLevel(level + 5) end
        f.plate = uf
        f.anchor = nil
    end
    return f
end

-- Off the plate (gone, or another mob's now): hidden, back on UIParent
function T:Detach()
    for _, key in ipairs({ "Icons", "Bars" }) do
        local f = self[key]
        if f then
            f:Hide()
            if f.plate then
                f:ClearAllPoints()
                f:SetParent(UIParent)
                f.plate, f.anchor = nil, nil
            end
        end
    end
end

---------------------------------------------------------------------------
-- Icons: the game's hawk icon, at the right of the level box
---------------------------------------------------------------------------
function T:Icon(i)
    self.icons = self.icons or {}
    local b = self.icons[i]
    if b then return b end
    b = CK.NewFrame("Frame", nil, self.Icons)
    -- The icon in its circle
    b.icon = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    if atlasInfo(TOTEM.mask) then
        local mask = b:CreateMaskTexture()
        mask:SetAtlas(TOTEM.mask)
        mask:SetAllPoints(b.icon)
        b.icon:AddMaskTexture(mask)
    else
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    -- Its ring
    if atlasInfo(TOTEM.ringAtlas) then
        b.ring = b:CreateTexture(nil, "OVERLAY")
        b.ring:SetAtlas(TOTEM.ringAtlas)
    end
    -- The countdown under it, the game's font for it
    b.text = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
    b.text:SetTextColor(1, 1, 1)
    local okF, _, height = call(b.text.GetFont, b.text)
    b.fontHeight = okF and type(height) == "number" and height > 0 and height or 10
    b.binding = newBinding(b.text)
    self.icons[i] = b
    return b
end

-- An icon at the game's sizes, brought to the plate's units
local function sizeIcon(b, r)
    b:SetSize(TOTEM.size * r, TOTEM.size * r)
    b.icon:SetSize(TOTEM.icon * r, TOTEM.icon * r)
    if b.ring then
        b.ring:ClearAllPoints()
        b.ring:SetSize(TOTEM.ring * r, TOTEM.ring * r)
        b.ring:SetPoint("CENTER", b, "CENTER", TOTEM.ringX * r, TOTEM.ringY * r)
    end
    b.text:ClearAllPoints()
    b.text:SetPoint("TOP", b, "BOTTOM", 0, TOTEM.textY * r)
    -- (its font as big on the screen as the game's: the plate scaled up)
    if b.text.SetTextHeight then pcall(b.text.SetTextHeight, b.text, b.fontHeight * r) end
end

function T:ShowIcons(uf, hawks)
    local f = holder(self, "Icons", uf)
    local r = T.PlateRatio(uf)
    -- At the right of the level box (else of the health bar), centred on it
    local box = T.LevelBox(uf)
    local anchor = box or T.HealthBar(uf)
    if not anchor then
        f:Hide()
        return
    end
    if f.anchor ~= anchor or f.ratio ~= r then
        f:ClearAllPoints()
        f:SetPoint("LEFT", anchor, "RIGHT", ICON_GAP * r, 0)
        f.anchor, f.ratio = anchor, r
    end
    local size, step = TOTEM.size * r, ICON_STEP * r
    f:SetSize(size + math.max(0, #hawks - 1) * step, size)
    for i, hawk in ipairs(hawks) do
        local b = self:Icon(i)
        sizeIcon(b, r)
        b:ClearAllPoints()
        b:SetPoint("LEFT", f, "LEFT", (i - 1) * step, 0)
        b.slot = hawk.slot
        b.icon:SetTexture(hawk.icon)
        setCountdown(b, hawk.duration, hawk.start, hawk.length)
        showHawk(b, hawk)
    end
    for i = #hawks + 1, #(self.icons or {}) do self.icons[i]:Hide() end
    self.items = self.icons
    self.count = #hawks
    f:SetShown(#hawks > 0)
end

---------------------------------------------------------------------------
-- Bars: a copy of the plate's cast bar, under it
---------------------------------------------------------------------------
-- The cast bar's font (its spell name's), else a number one
local function castFont()
    if _G.SystemFont_NamePlateCastBar then return "SystemFont_NamePlateCastBar" end
    return "NumberFontNormalSmall"
end

function T:Row(i)
    self.rows = self.rows or {}
    local row = self.rows[i]
    if row then return row end
    row = CK.NewFrame("Frame", nil, self.Bars)
    local bar = CK.NewFrame("StatusBar", nil, row)
    row.bar = bar
    local gameLook = atlasInfo(CAST.back) and true or false
    row.gameLook = gameLook
    row.back = bar:CreateTexture(nil, "BACKGROUND")
    if gameLook then
        row.back:SetAtlas(CAST.back)
        row.back:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, 0)
        row.back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 0)
    else
        row.back:SetTexture(TEXTURE)
        row.back:SetVertexColor(PLAIN[1], PLAIN[2], PLAIN[3], PLAIN[4])
        row.back:SetAllPoints(bar)
    end
    if atlasInfo(CAST.fill) then
        bar:SetStatusBarTexture(CAST.fill)
        bar:SetStatusBarColor(1, 1, 1, 1)
    else
        bar:SetStatusBarTexture(TEXTURE)
        bar:SetStatusBarColor(HAWK[1], HAWK[2], HAWK[3], 1)
    end
    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = row:CreateFontString(nil, "OVERLAY", castFont())
    row.name:SetJustifyH("LEFT")
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    row.text = row:CreateFontString(nil, "OVERLAY", castFont())
    row.text:SetJustifyH("RIGHT")
    -- The spark, at the fill's end
    if atlasInfo(CAST.spark) then
        row.spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        row.spark:SetAtlas(CAST.spark)
        row.spark:SetBlendMode("ADD")
        local ok, fill = call(bar.GetStatusBarTexture, bar)
        row.spark:SetPoint("CENTER", ok and fill or bar, ok and fill and "RIGHT" or "LEFT", 0, 0)
    end
    -- The frame (OVERLAY, as the cast bar's): the important cast's frame
    -- and glowing ends, the targeted cast's outline 4 out
    if atlasInfo(CAST.important) then
        row.important = bar:CreateTexture(nil, "OVERLAY")
        row.important:SetAtlas(CAST.important)
    end
    if atlasInfo(CAST.targeted) then
        row.targeted = bar:CreateTexture(nil, "OVERLAY")
        row.targeted:SetAtlas(CAST.targeted)
        row.targeted:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
        row.targeted:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
    end
    row.binding = newBinding(row.text)
    self.rows[i] = row
    return row
end

-- The important cast's frame reaches past the bar's ends (the game's:
-- 20 each side for the smallest plates, else 26 left and 25 right)
function T.ImportantReach()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local ok, v = call(get, "nameplateSize")
    v = ok and tonumber(plain(v)) or nil
    if v and v < 2 then return 20, 20 end
    return 26, 25
end

-- The cast bar's sizes brought to this thickness
local function scaled(v, thickness, height) return math.max(1, math.floor(v * thickness / height + 0.5)) end

-- Where the icon, name and countdown go: in the bar (the icon at its left)
-- or under it (the icon at the bottom left, as the plate's cast bar shows
-- its spell name); the row as high as the bar, or the bar and that line
local function layout(row, style, thickness, iconSize)
    local bar = row.bar
    bar:ClearAllPoints()
    row.icon:ClearAllPoints()
    row.name:ClearAllPoints()
    row.text:ClearAllPoints()
    row.icon:SetSize(iconSize, iconSize)
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    bar:SetHeight(thickness)
    if style.inside then
        row.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
        row.text:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        row.size = thickness
    else
        row.icon:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
        row.text:SetPoint("RIGHT", row, "BOTTOMRIGHT", -4, iconSize / 2)
        row.size = thickness + iconSize
    end
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 2, 0)
    row.name:SetPoint("RIGHT", row.text, "LEFT", -2, 0)
    row:SetHeight(row.size)
end

-- A row's look: the plate's cast bar style at this thickness (the icon,
-- font and spark as the cast bar's at that size), the icon and name
-- (hidden values welcome)
local function paint(row, icon, name, thickness, style)
    local h = style.height
    local iconSize = scaled(style.icon, thickness, h)
    layout(row, style, thickness, iconSize)
    row.icon:SetTexture(icon)
    row.name:SetText(name or "")
    local font = math.max(7, scaled(style.font, thickness, h))
    for _, fs in ipairs({ row.text, row.name }) do
        if fs.SetTextHeight then pcall(fs.SetTextHeight, fs, font) end
    end
    if row.spark then row.spark:SetSize(scaled(CAST.sparkW, thickness, CAST.height), scaled(CAST.sparkH, thickness, CAST.height)) end
    if row.important then
        local left, right = T.ImportantReach()
        row.important:ClearAllPoints()
        row.important:SetPoint("TOPLEFT", row.bar, "TOPLEFT", -left, 3)
        row.important:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", right, -3)
    end
end

function T:ShowBars(uf, hawks)
    local f = holder(self, "Bars", uf)
    local r = T.PlateRatio(uf)
    -- Under the cast bar (else the health bar), as wide; the gap chosen in
    -- the interface's pixels (negative: up over the cast bar's place)
    local anchor = T.CastBar(uf) or T.HealthBar(uf)
    if not anchor then
        f:Hide()
        return
    end
    local gap = math.floor(tonumber(settings().spacing) or 2) * r
    if f.anchor ~= anchor or f.gap ~= gap then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
        f:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -gap)
        f.anchor, f.gap = anchor, gap
    end
    -- The plate's cast bar now; the thickness chosen (the interface's
    -- pixels), else (0) its own
    local style = T.CastStyle()
    local chosen = math.floor(tonumber(settings().thickness) or 0)
    local thickness = chosen > 0 and math.max(1, chosen * r) or math.max(1, math.floor(style.height + 0.5))
    local y = 0
    for i, hawk in ipairs(hawks) do
        local row = self:Row(i)
        paint(row, hawk.icon, hawk.name, thickness, style)
        row.slot = hawk.slot
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -y)
        y = y + row.size + GAP
        setTimer(row, hawk.duration, hawk.start, hawk.length)
        showHawk(row, hawk)
    end
    for i = #hawks + 1, #(self.rows or {}) do self.rows[i]:Hide() end
    self.items = self.rows
    self.count = #hawks
    f:SetHeight(math.max(1, y))
    f:SetShown(#hawks > 0)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
function T:Refresh()
    if not CK.db then return end
    local uf = self:On() and UnitExists("target") and T.Plate() or nil
    if not uf then
        self:Detach()
        self.count = 0
        return
    end
    local canHide = UIParent and UIParent.SetAlphaFromBoolean ~= nil
    local hawks = T.Hawks(canHide)
    if self:Display() == "bars" then
        if self.Icons then self.Icons:Hide() end
        self:ShowBars(uf, hawks)
    else
        if self.Bars then self.Bars:Hide() end
        self:ShowIcons(uf, hawks)
    end
end

-- The countdowns counted here (the game's missing): their value. And a look
-- twice a second while there is a target.
local LOOK_EVERY = 0.5
function T:Tick(elapsed)
    self.sinceLook = (self.sinceLook or 0) + elapsed
    if self.sinceLook >= LOOK_EVERY then
        self.sinceLook = 0
        if CK.db and self:On() and UnitExists("target") then self:Refresh() end
    end
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.05 then return end
    self.elapsed = 0
    local now = GetTime()
    for i = 1, self.count or 0 do
        local item = self.items and self.items[i]
        local m = item and item.manual
        if m then
            local left = m.length - (now - m.start)
            if not m.textOnly then item.bar:SetValue(math.max(0, left)) end
            item.text:SetText(T.Countdown(left))
        end
    end
end

-- /ec timers: what the game gives, for a report (hidden values named so)
local function show(v)
    if secret(v) then return "<hidden>" end
    return tostring(v)
end

function T:Diagnose()
    local _, class = UnitClass("player")
    local uf = T.Plate()
    CK:Print("timers: on %s, class %s, display %s, target %s, plate %s", tostring(self:On()), tostring(class),
        self:Display(), tostring(UnitExists("target")), tostring(uf ~= nil))
    local style = T.CastStyle()
    DEFAULT_CHAT_FRAME:AddMessage(format("  plate cast bar: height %s, icon %s, font %s, name %s; thickness %s, gap %s, plate ratio %.2f, level box %s",
        tostring(style.height), tostring(style.icon), tostring(style.font), style.inside and "inside" or "under",
        tostring(settings().thickness), tostring(settings().spacing), uf and T.PlateRatio(uf) or 1,
        tostring(uf and T.LevelBox(uf) ~= nil or false)))
    local ok, slots = call(GetNumTotemSlots)
    DEFAULT_CHAT_FRAME:AddMessage("  totem slots: " .. show(ok and slots or "?"))
    for slot = 1, math.min(type(plain(slots)) == "number" and slots or 0, MAX_TOTEMS) do
        local got, have, name, start, length, icon = call(GetTotemInfo, slot)
        local okd, duration = call(GetTotemDuration, slot)
        local okz, zero = call(okd and duration and duration.IsZero, duration)
        DEFAULT_CHAT_FRAME:AddMessage(format("  slot %d: %s have %s, name %s, start %s, length %s, icon %s, zero %s, phantom %s -> %s",
            slot, got and "" or "(error)", show(have), show(name), show(start), show(length), show(icon),
            okz and show(zero) or "?", tostring(T.phantom[slot] or false),
            tostring(got and T.HawkIn(have, okd and duration or nil, length, icon) or false)))
    end
end

function T:Init()
    if self.events then return end
    local f = CK.NewFrame("Frame")
    self.events = f
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    pcall(f.RegisterEvent, f, "PLAYER_TOTEM_UPDATE")
    -- The target's plate shown or gone (the mob on or off the screen)
    pcall(f.RegisterEvent, f, "NAME_PLATE_UNIT_ADDED")
    pcall(f.RegisterEvent, f, "NAME_PLATE_UNIT_REMOVED")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "NAME_PLATE_UNIT_REMOVED" then
            -- The target's plate going (given to another mob next): let go
            local unit = plain((...))
            local okU, same = call(UnitIsUnit, unit, "target")
            if unit and okU and plain(same) == true then
                T:Detach()
                return
            end
        end
        T:Refresh()
    end)
    f:SetScript("OnUpdate", function(_, elapsed) T:Tick(elapsed) end)
    local s = CK.db and settings()
    if s then
        -- (asked "exactly the same" for the bars: the plate's cast bar's
        -- own thickness, 0, once)
        if not s.thick4 then
            s.thickness = 0
            s.thick4 = true
        end
        -- (the icons by default, asked 2026-11-28: set once for a player
        -- who had the bars before)
        if not s.display2 then
            s.display = "icons"
            s.display2 = true
        end
    end
    -- Its section in the options (hunters only): the class known now
    if CK.Config and CK.Config.AddTargetSection then CK.Config.AddTargetSection() end
    self:Refresh()
end
