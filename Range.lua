local _, CK = ...

-- Out of range, the whole spell in red (the game only turns its small dot
-- red): the gamepad bar's buttons and our extra buttons. Over the game's
-- buttons, a red veil of ours multiplied over the icon: the game's buttons
-- are only read, never hooked, called nor changed. (Secure hooks on their
-- RefreshRange and UpdateUsable broke the game's own bar refresh with the
-- taint log on: "attempt to call a nil value", ActionButton.lua:584.)
local R = {}
CK.Range = R

R.RED = { 0.9, 0.15, 0.15 }
-- Range checked five times a second, the veils follow their buttons
-- (shown, faded) every frame
local CHECK = 0.2
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function on()
    return CK.db and CK.db.settings.features.rangeTint == true
end
R.On = on

local function inRange(slot)
    local check = (C_ActionBar and C_ActionBar.IsActionInRange) or IsActionInRange
    if not (check and slot) then return nil end
    return check(slot)
end
R.InRange = inRange

-- The D-pad's buttons are square, the others round (as the game draws them)
local SQUARE = { up = true, down = true, left = true, right = true }

-- The game's bar buttons: each bar's, and the stance bar's in their place,
-- with the shape of their place
local function gameButtons()
    local P, list, shapes = CK.Paddles, {}, {}
    for _, bar in ipairs(P.BARS) do
        for _, b in ipairs(P.BUTTONS) do
            local action = "bar:" .. bar.key .. ":" .. b.key
            for _, button in ipairs({ P:NativeButton(action) or false, P:StanceButton(action) or false }) do
                if button then
                    list[#list + 1] = button
                    shapes[button] = SQUARE[b.key] and "square" or "round"
                end
            end
        end
    end
    return list, shapes
end

local function region(r)
    return type(r) == "table" and r.IsShown and r or nil
end

-- The button's shape: its own (the game's activeButtonShape), else its place's
local function shapeOf(button, fallback)
    local shape = type(button.activeButtonShape) == "string" and button.activeButtonShape:lower() or ""
    if shape:find("circle") then return "round" end
    if shape:find("square") then return "square" end
    return fallback or "round"
end

-- Where the game draws the icon: the region of its mask for that shape,
-- else the icon itself
local function iconArea(button, shape)
    if shape == "round" then return region(button.CircleMask) or region(button.icon) end
    return region(button.SquareMask) or region(button.icon)
end

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local veils = {}
R.veils = veils

local function veilFor(button)
    local v = veils[button]
    if v then return v end
    v = CK.NewFrame("Frame", nil, R.holder)
    v.tex = v:CreateTexture(nil, "OVERLAY")
    v.tex:SetAllPoints()
    v.tex:SetTexture(WHITE)
    v.tex:SetBlendMode("MOD")
    v.mask = v:CreateMaskTexture()
    v.mask:SetAllPoints(v.tex)
    v.tex:AddMaskTexture(v.mask)
    v.button = button
    v.out = false
    v:Hide()
    veils[button] = v
    return v
end

-- Laid over the button's icon, in its shape (our own circle: copying the
-- game's mask left a square, reported), above its cooldown. Out of combat
-- only: in combat the veils stay where they are.
local function place(v, fallback)
    local button = v.button
    local shape = shapeOf(button, fallback)
    local area = iconArea(button, shape)
    if not area then return end
    v:SetFrameStrata(button:GetFrameStrata())
    v:SetFrameLevel(button:GetFrameLevel() + 3)
    if v.area == area and v.shape == shape then return end
    v.area, v.shape = area, shape
    v:ClearAllPoints()
    v:SetAllPoints(area)
    if shape == "round" then
        if hasAtlas("CircleMask") then
            v.mask:SetAtlas("CircleMask")
        else
            v.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
    elseif hasAtlas("SquareMask") then
        v.mask:SetAtlas("SquareMask")
    else
        v.mask:SetTexture(WHITE)
    end
end

-- Which buttons are out of range. Out of combat every button gets its veil
-- ready (placed), so that it can show in combat.
function R:Check()
    if not on() then
        for _, v in pairs(veils) do v.out = false end
        return
    end
    local seen = {}
    local free = not InCombatLockdown()
    local buttons, shapes = gameButtons()
    for _, button in ipairs(buttons) do
        seen[button] = true
        local v = veils[button] or (free and veilFor(button))
        if v then
            if free then place(v, shapes[button]) end
            v.out = v.area ~= nil and button:IsVisible() and inRange(button.action) == false
        end
    end
    for button, v in pairs(veils) do
        if not seen[button] then v.out = false end
    end
end

-- Every frame: a veil shows while its button does, as faded as it is (a
-- multiplied colour has no transparency: white is "no change")
function R:Paint()
    local red = R.RED
    for button, v in pairs(veils) do
        local show = v.out and button:IsVisible()
        if show then
            local a = button:GetEffectiveAlpha() or 1
            if a ~= v.alpha then
                v.alpha = a
                v.tex:SetVertexColor(1 - (1 - red[1]) * a, 1 - (1 - red[2]) * a, 1 - (1 - red[3]) * a)
            end
        end
        if show ~= v:IsShown() then v:SetShown(show) end
    end
end

-- The option turned on or off
function R:Apply()
    if not self.holder then return end
    if on() then
        self.holder:Show()
        self:Check()
        self:Paint()
    else
        self.holder:Hide()
        for _, v in pairs(veils) do
            v.out = false
            v:Hide()
        end
    end
    if CK.Paddles.Refresh and CK.Paddles.frame then CK.Paddles:Refresh(false) end
end

function R:Init()
    local holder = CK.NewFrame("Frame", nil, UIParent)
    holder:SetAllPoints()
    holder:Hide()
    local elapsed = CHECK
    holder:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed >= CHECK then
            elapsed = 0
            R:Check()
        end
        R:Paint()
    end)
    self.holder = holder
    self:Apply()
end
