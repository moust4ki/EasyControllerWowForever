local _, CK = ...

-- Out of range, the whole spell in red (the game only turns its small dot
-- red): the gamepad bar's buttons and our extra buttons. The game's buttons
-- are only recoloured, after the game's own colouring (secure hooks on their
-- RefreshRange and UpdateUsable), never called nor changed otherwise.
local R = {}
CK.Range = R

R.RED = { 0.9, 0.15, 0.15 }

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

-- The game's colour for a slot (usable, not enough mana, unusable)
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

local function paint(button)
    local icon = button.icon
    if not icon then return end
    if on() and button.ckOutOfRange then
        icon:SetVertexColor(R.RED[1], R.RED[2], R.RED[3])
    elseif button.ckTinted then
        usableColor(icon, button.action)
    end
    button.ckTinted = on() and button.ckOutOfRange or nil
end

local hooked = {}
local function hook(button)
    if not button or hooked[button] or (button.IsForbidden and button:IsForbidden()) then return end
    if type(button.RefreshRange) ~= "function" or type(button.UpdateUsable) ~= "function" then return end
    hooked[button] = true
    hooksecurefunc(button, "RefreshRange", function(self, checksRange, isInRange)
        self.ckOutOfRange = (checksRange and not isInRange) or nil
        paint(self)
    end)
    hooksecurefunc(button, "UpdateUsable", function(self)
        if self.ckOutOfRange and on() then paint(self) end
    end)
    -- Already out of range when hooked
    local range = inRange(button.action)
    button.ckOutOfRange = (range == false) or nil
    paint(button)
end

-- Every button of the game's gamepad bar (once it is loaded). Only with the
-- option on: off (the default), the game's buttons are never touched.
function R:HookBar()
    if not on() then return end
    local P = CK.Paddles
    for _, bar in ipairs(P.BARS) do
        for _, b in ipairs(P.BUTTONS) do
            hook(P:NativeButton("bar:" .. bar.key .. ":" .. b.key))
            -- In a stance (stealth...), the stance bar's in its place
            hook(P:StanceButton("bar:" .. bar.key .. ":" .. b.key))
        end
    end
end

-- The option turned on or off: every hooked button repainted
function R:Apply()
    self:HookBar()
    for button in pairs(hooked) do
        local range = inRange(button.action)
        button.ckOutOfRange = (range == false) or nil
        paint(button)
    end
    if CK.Paddles.Refresh and CK.Paddles.frame then CK.Paddles:Refresh(false) end
end

function R:Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function() R:HookBar() end)
    self:HookBar()
end
