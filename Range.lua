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

-- The game's bar buttons: each bar's, and the stance bar's in their place
local function gameButtons()
    local P, list = CK.Paddles, {}
    for _, bar in ipairs(P.BARS) do
        for _, b in ipairs(P.BUTTONS) do
            local action = "bar:" .. bar.key .. ":" .. b.key
            list[#list + 1] = P:NativeButton(action)
            list[#list + 1] = P:StanceButton(action)
        end
    end
    return list
end

-- Where the game draws the icon: inside its round or square mask, else the
-- icon itself
local function region(r)
    return type(r) == "table" and r.IsShown and r or nil
end

local function iconArea(button)
    local circle, square = region(button.CircleMask), region(button.SquareMask)
    if circle and circle:IsShown() then return circle end
    if square and square:IsShown() then return square end
    return region(button.icon)
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

-- Laid over the button's icon, in its shape, above its cooldown. Out of
-- combat only: in combat the veils stay where they are.
local function place(v)
    local button = v.button
    local area = iconArea(button)
    if not area then return end
    v:SetFrameStrata(button:GetFrameStrata())
    v:SetFrameLevel(button:GetFrameLevel() + 3)
    if v.area == area then return end
    v.area = area
    v:ClearAllPoints()
    v:SetAllPoints(area)
    local shape = area ~= button.icon and area or nil
    local atlas = shape and shape.GetAtlas and shape:GetAtlas()
    local file = shape and shape.GetTexture and shape:GetTexture()
    if atlas then
        v.mask:SetAtlas(atlas)
    elseif file then
        v.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
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
    for _, button in ipairs(gameButtons()) do
        seen[button] = true
        local v = veils[button] or (free and veilFor(button))
        if v then
            if free then place(v) end
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
