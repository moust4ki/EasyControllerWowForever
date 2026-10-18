local _, CK = ...

-- The gamepad UI's dot in the middle of the screen (the game's GamepadReticle,
-- its 4 px StandardIcon), for OLED screens: an always-lit white dot at the
-- same place can burn in. Its colour can be changed, changed by itself every 5
-- minutes (each colour lights other subpixels, never all three at full like
-- white), or the whole reticle hidden. The game's frame is only recoloured
-- and faded, never moved or rebuilt; its own code keeps running.
local R = {}
CK.Reticle = R

-- Colours that spare the OLED subpixels: none at full white, blue (the
-- subpixel that ages fastest) kept low, two colours in a row never lighting
-- the same main subpixel
R.COLORS = {
    { key = "amber", rgb = { 1.00, 0.72, 0.20 } },
    { key = "cyan", rgb = { 0.25, 0.80, 0.80 } },
    { key = "red", rgb = { 0.95, 0.30, 0.30 } },
    { key = "green", rgb = { 0.35, 0.85, 0.35 } },
    { key = "magenta", rgb = { 0.85, 0.35, 0.80 } },
    { key = "blue", rgb = { 0.40, 0.55, 0.95 } },
    -- For the fixed colour only (not in the changing cycle): grey, half lit;
    -- black, its pixels off (the least wear, seen on light ground only)
    { key = "grey", rgb = { 0.50, 0.50, 0.50 }, fixed = true },
    { key = "black", rgb = { 0.00, 0.00, 0.00 }, fixed = true },
}
R.MODES = { "game", "color", "cycle", "hidden" }
local CYCLE_TIME = 300

local function settings() return CK.db.settings.reticle end

local function reticle()
    local f = GamepadReticle
    if not f or (f.IsForbidden and f:IsForbidden()) then return nil end
    return f
end

function R:Apply()
    local f = reticle()
    if not f then return end
    local s = settings()
    f:SetAlpha(s.mode == "hidden" and 0 or 1)
    -- The dot: in the reticle's Icons frame since the game's build 70425 (16
    -- October, with its swing timer; reported: its colour no longer changed),
    -- on the reticle itself before
    local dot = f.StandardIcon or (f.Icons and f.Icons.StandardIcon)
    if not dot then return end
    local color
    if s.mode == "color" then
        color = R.COLORS[s.color] or R.COLORS[1]
    elseif s.mode == "cycle" then
        color = R.COLORS[self.cycleIndex or 1]
    end
    if color then
        dot:SetVertexColor(color.rgb[1], color.rgb[2], color.rgb[3])
    else
        dot:SetVertexColor(1, 1, 1)
    end
end

-- The colour changing by itself: only while that mode is on
function R:UpdateTicker()
    local cycling = settings().mode == "cycle"
    if cycling and not self.ticker then
        self.cycleIndex = self.cycleIndex or 1
        self.ticker = C_Timer.NewTicker(CYCLE_TIME, function()
            repeat
                R.cycleIndex = R.cycleIndex % #R.COLORS + 1
            until not R.COLORS[R.cycleIndex].fixed
            R:Apply()
        end)
    elseif not cycling and self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

function R:SetMode(mode)
    settings().mode = mode
    self:UpdateTicker()
    self:Apply()
end

function R:Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function() R:Apply() end)
    self:UpdateTicker()
    self:Apply()
end
