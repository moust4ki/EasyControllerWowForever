local _, CK = ...

-- Out of range, the whole spell in red (the game only turns its small dot
-- red): the gamepad bar's buttons and our extra buttons. On the game's
-- buttons, their icon itself is coloured, so it keeps the button's own
-- shape (a red veil over the button tinted its ring too: a red cross on the
-- round ones, reported). Nothing hooked: the range is checked five times a
-- second and the red put back every frame the game has repainted it (secure
-- hooks on their RefreshRange and UpdateUsable broke the game's own bar
-- refresh with the taint log on: "attempt to call a nil value",
-- ActionButton.lua:584). Only the icon's colour changes, nothing is written
-- on the game's buttons.
local R = {}
CK.Range = R

R.RED = { 0.9, 0.15, 0.15 }
local CHECK = 0.2

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

-- The game's colour for a slot (usable, not enough mana, unusable), given
-- back once a button is in range again
local function usableColor(icon, slot)
    local isUsable = C_ActionBar and C_ActionBar.IsUsableAction or IsUsableAction
    local usable, noMana = true, false
    if isUsable and slot then usable, noMana = isUsable(slot) end
    if usable then
        icon:SetVertexColor(1, 1, 1)
    elseif noMana then
        icon:SetVertexColor(0.5, 0.5, 1)
    else
        icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

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

local out, tinted = {}, {}
R.out, R.tinted = out, tinted

-- Which of the game's buttons shown are out of range
function R:Check()
    wipe(out)
    if not on() then return end
    for _, button in ipairs(gameButtons()) do
        if type(button.icon) == "table" and button:IsVisible() and inRange(button.action) == false then
            out[button] = true
        end
    end
end

local function isRed(icon)
    local red = R.RED
    local r, g, b = icon:GetVertexColor()
    return r and math.abs(r - red[1]) < 0.01 and math.abs(g - red[2]) < 0.01 and math.abs(b - red[3]) < 0.01
end

-- Every frame: the out of range icons red (again, when the game repainted
-- them), the game's colour back on those in range again
function R:Paint()
    local red = R.RED
    for button in pairs(out) do
        if not isRed(button.icon) then button.icon:SetVertexColor(red[1], red[2], red[3]) end
        tinted[button] = true
    end
    for button in pairs(tinted) do
        if not out[button] then
            tinted[button] = nil
            usableColor(button.icon, button.action)
        end
    end
end

-- The option turned on or off
function R:Apply()
    if not self.holder then return end
    if on() then
        self.holder:Show()
        self:Check()
    else
        self.holder:Hide()
        wipe(out)
    end
    self:Paint()
    if CK.Paddles.Refresh and CK.Paddles.frame then CK.Paddles:Refresh(false) end
end

function R:Init()
    local holder = CK.NewFrame("Frame", nil, UIParent)
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
