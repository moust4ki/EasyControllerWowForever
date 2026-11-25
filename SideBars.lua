local _, CK = ...

---------------------------------------------------------------------------
-- The game's action bars 4 and 5 in its gamepad UI (asked 2026-11-25).
-- The game shows its bars 2 to 8 only with its keyboard and mouse bar
-- (MultiActionBar_Update: MainActionBar:IsShown()), and its gamepad Edit Mode
-- layout has no place for them (EditModeManager hides a system missing from
-- the active layout). Showing its own frames anyway would run its Edit Mode
-- and button code under the addon's name (the "blocked" taint of 1.25.1).
-- So two bars of ours, made of the game's own pieces:
--   * how many chosen in the addon's panel (Home > Gamepad: none, bar 4, bars
--     4 and 5), in the game's gamepad UI only; the game's boxes (Options >
--     Action Bars) stay its own, for its keyboard and mouse UI;
--   * the game's slots for them (25-36, 37-48), kept by the server;
--   * the game's button template with its secure action (ActionButtonTemplate
--     + SecureActionButtonTemplate, the combination its own code allows for):
--     a click is the game's own, on the mouse button's release as on its
--     bars (useOnKeyDown false: else, with its "cast on key down", a click
--     did nothing);
--   * the game's key bindings (Key Bindings > Action Bar 4 / 5): they press
--     its own hidden buttons, on the same slots; ours show the key and the
--     press (a hook after the game's MultiActionButtonDown / Up);
--   * the game's place and size for them (EditModeManager
--     UpdateRightActionBarPositions): the right edge, bar 4 outside, scaled
--     to fit under the minimap;
--   * if asked (a box of its own, off by default), the quest tracker moved
--     left of them as the game moves it for its own (EditModeUtil:
--     GetRightContainerAnchor): its container shifted by the same width
--     right after the game places it.
-- A spell group (flyout) in a slot does nothing here: the game's flyout
-- would be opened from the addon's code (its button.popup, written by the
-- addon, read by the secure click) and refuse its spells.
-- Their empty buttons can be hidden (as the game's "Always Show Buttons"
-- turned off), shown again while an action is carried to them.
-- Off by default (Home > Gamepad): none chosen, nothing of the game's is
-- hooked or moved; the tracker not asked, it is never touched.
---------------------------------------------------------------------------
local SB = {}
CK.SideBars = SB

-- Bar 4 then bar 5, in the game's order (the first one shown on the edge)
SB.BARS = {
    { page = "RIGHT_ACTIONBAR_PAGE", pageDefault = 3, command = "MULTIACTIONBAR3BUTTON" },
    { page = "LEFT_ACTIONBAR_PAGE", pageDefault = 4, command = "MULTIACTIONBAR4BUTTON" },
}
local NUM_BUTTONS = 12
local BUTTON_SIZE = 45          -- ActionButtonTemplate
local PADDING = 2               -- ActionBarMixin.minButtonPadding
SB.HEIGHT = NUM_BUTTONS * BUTTON_SIZE + (NUM_BUTTONS - 1) * PADDING
-- Hidden like the game's own bars when its override bar replaces its main one
SB.VISIBILITY = "[vehicleui][overridebar][petbattle] hide; show"
local CHECK = 0.2               -- range, usable, checked: the game's pace

local bars = {}
SB.bars = bars

local function settings() return CK.db and CK.db.settings end

local function features()
    local s = settings()
    return s and type(s.features) == "table" and s.features or nil
end

-- How many bars chosen (0 none, 1 bar 4, 2 bars 4 and 5)
function SB.Chosen()
    local f = features()
    local n = f and tonumber(f.sideBars) or 0
    return math.max(0, math.min(#SB.BARS, math.floor(n)))
end

-- How many shown: the ones chosen, in the game's gamepad UI
local function shownCount()
    return CK.GamepadUI() and SB.Chosen() or 0
end
SB.Count = shownCount

-- The quest tracker moved left of them (its own box)
local function shiftsTracker()
    local f = features()
    return f ~= nil and f.sideBarsTracker == true
end
SB.ShiftsTracker = shiftsTracker

-- The game's slot of a bar's button: page 3 (bar 4) 25-36, page 4 (bar 5) 37-48
function SB.Slot(index, i)
    local def = SB.BARS[index]
    local page = tonumber(_G[def.page]) or def.pageDefault
    return (page - 1) * NUM_BUTTONS + i
end

-- C_ActionBar's function, else the old global one
local function ab(name, ...)
    local fn = C_ActionBar and C_ActionBar[name] or _G[name]
    if type(fn) ~= "function" then return nil end
    return fn(...)
end

---------------------------------------------------------------------------
-- A button: its picture and state, as the game's own buttons show them
-- (ActionBarActionButtonMixin:Update and the functions it calls)
---------------------------------------------------------------------------
-- The first key bound to the button's command that still runs it (a key
-- the addon's gamepad mapping took over runs something else: not shown)
local function boundKey(command)
    if not GetBindingKey then return nil end
    for _, key in ipairs({ GetBindingKey(command) }) do
        if type(key) == "string" and key ~= "" then
            local runs = GetBindingAction and GetBindingAction(key, true)
            if not runs or runs == "" or runs == command then return key end
        end
    end
    return nil
end
SB.BoundKey = boundKey

local function hotkey(b)
    local text = b.HotKey
    if not text then return end
    local key = boundKey(b.command)
    local shown = key and GetBindingText and GetBindingText(key, 1) or ""
    if shown == "" then
        text:SetText(RANGE_INDICATOR or "")
        text:Hide()
        return
    end
    local width = b:GetSize()
    if IsBindingForGamePad and IsBindingForGamePad(key) then
        text:SetSize(width, 16)
        text:SetPoint("TOPRIGHT", b, "TOPRIGHT", b.hotkeyTextGamepadX or 0, b.hotkeyTextGamepadY or 0)
    else
        text:SetSize(width - 8, 10)
        text:SetPoint("TOPRIGHT", b, "TOPRIGHT", b.hotkeyTextKeyboardX or 0, b.hotkeyTextKeyboardY or 0)
    end
    text:SetText(shown)
    text:Show()
end

local function usable(b)
    local isUsable, noMana = ab("IsUsableAction", b.action)
    if isUsable then
        b.icon:SetVertexColor(1, 1, 1)
    elseif noMana then
        b.icon:SetVertexColor(0.5, 0.5, 1)
    else
        b.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function checked(b)
    local slot = b.action
    local on = (ab("IsCurrentAction", slot) or ab("IsAutoRepeatAction", slot)) and not ab("IsAutoCastPetAction", slot)
    b:SetChecked(on and true or false)
end

-- The red key (or dot) out of range: the game's own function
local function range(b)
    if not b.HotKey then return end
    local inRange = ab("IsActionInRange", b.action)
    local checks = inRange ~= nil
    if ActionButton_UpdateRangeIndicator then
        ActionButton_UpdateRangeIndicator(b, checks, inRange)
    elseif checks and not inRange then
        b.HotKey:SetVertexColor(1, 0.1, 0.1)
    else
        b.HotKey:SetVertexColor(0.6, 0.6, 0.6)
    end
end

-- Auto attack and shots blink, as on the game's bar
local function flashing(b)
    local slot = b.action
    return (ab("IsAttackAction", slot) and ab("IsCurrentAction", slot)) or ab("IsAutoRepeatAction", slot) or false
end

local function clearCooldowns(b)
    if ClearActionButtonCooldowns then
        ClearActionButtonCooldowns(b.cooldown, b.chargeCooldown, b.lossOfControlCooldown)
    elseif b.cooldown then
        b.cooldown:Clear()
    end
end

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

-- The game's own function (normal, charges, loss of control). Its cooldowns
-- can be secret values for addons ("SecretWhenCooldownsRestricted"): a test
-- on one stops it, then the duration object the cooldown frame takes as is
local function fromDuration(cd, getter, slot)
    if not cd then return end
    local get = C_ActionBar and C_ActionBar[getter]
    if not (get and cd.SetCooldownFromDurationObject
        and pcall(function() cd:SetCooldownFromDurationObject(get(slot)) end)) then
        cd:Clear()
    end
end

local function cooldowns(b)
    if ActionButton_UpdateCooldown and pcall(ActionButton_UpdateCooldown, b) then return end
    fromDuration(b.cooldown, "GetActionCooldownDuration", b.action)
    fromDuration(b.chargeCooldown, "GetActionChargeDuration", b.action)
    fromDuration(b.lossOfControlCooldown, "GetActionLossOfControlCooldownDuration", b.action)
end

-- A charge or item count: as the game gives it (a secret one shown as is)
local function count(b)
    if not b.Count then return end
    local n = ab("GetActionDisplayCount", b.action, b.maxDisplayCount)
    if secret(n) then
        pcall(b.Count.SetText, b.Count, n)
    else
        b.Count:SetText((type(n) == "string" or type(n) == "number") and n or "")
    end
end

function SB:UpdateButton(b)
    local slot = b.action
    local icon = b.icon
    local texture = ab("GetActionTexture", slot)
    icon:SetDesaturated(false)
    if ab("HasAction", slot) then
        checked(b)
        usable(b)
        cooldowns(b)
    else
        clearCooldowns(b)
        b:SetChecked(false)
    end
    -- Green border on an item worn
    if b.Border then
        if ab("IsEquippedAction", slot) then
            b.Border:SetVertexColor(0, 1, 0, 0.5)
            b.Border:Show()
        else
            b.Border:Hide()
        end
    end
    -- A macro's name
    if b.Name then
        b.Name:SetText(ab("UsesActionText", slot) and (ab("GetActionText", slot) or "") or "")
    end
    if texture then
        icon:SetTexture(texture)
        icon:Show()
        count(b)
    else
        icon:Hide()
        if b.Count then b.Count:SetText("") end
        clearCooldowns(b)
    end
    hotkey(b)
    range(b)
    if not flashing(b) and b.Flash then b.Flash:Hide() end
    if GameTooltip and GameTooltip:GetOwner() == b then self:ShowTooltip(b) end
end

-- A slot holding a spell group: its button does nothing (see the top)
function SB:UpdateTypes()
    if InCombatLockdown() then
        self.pending = true
        return
    end
    for _, bar in pairs(bars) do
        for _, b in ipairs(bar.buttons) do
            local kind = GetActionInfo and GetActionInfo(b.action)
            local want = kind ~= "flyout" and "action" or nil
            if b:GetAttribute("type") ~= want then b:SetAttribute("type", want) end
        end
    end
end

-- Every button of the bars shown
function SB:UpdateAll()
    for _, bar in pairs(bars) do
        if bar.wanted then
            for _, b in ipairs(bar.buttons) do self:UpdateButton(b) end
        end
    end
end

-- Empty buttons hidden (option, as the game's "Always Show Buttons" turned
-- off), all shown while an action is carried to be dropped (the game's
-- grid). Hiding a secure button waits for the end of a fight.
local function hideEmpty()
    local f = features()
    return f ~= nil and f.sideBarsHideEmpty == true
end
SB.HideEmpty = hideEmpty

function SB:UpdateShown()
    if InCombatLockdown() then
        self.pending = true
        return
    end
    local hide = hideEmpty() and not self.grid
    for _, bar in pairs(bars) do
        for _, b in ipairs(bar.buttons) do
            b:SetShown(not hide or ab("HasAction", b.action) and true or false)
        end
    end
end

function SB:ShowTooltip(b)
    if not GameTooltip then return end
    if not ab("HasAction", b.action) then
        if GameTooltip:GetOwner() == b then GameTooltip:Hide() end
        return
    end
    -- Where the game puts its right bars' (ActionBarActionButtonMixin:SetTooltip)
    local placed = GetCVar and GetCVar("UberTooltips") == "1" and GameTooltip_SetDefaultAnchor
        and pcall(GameTooltip_SetDefaultAnchor, GameTooltip, b)
    if not placed then GameTooltip:SetOwner(b, "ANCHOR_LEFT") end
    GameTooltip:SetAction(b.action)
    GameTooltip:Show()
end

-- Drag and drop, as the game's buttons (its lock in Options > Action Bars,
-- its modifier to take one anyway); out of combat
local function locked()
    local lock = GetCVarBool and GetCVarBool("lockActionBars")
    return lock and not (IsModifiedClick and IsModifiedClick("PICKUPACTION"))
end

function SB:PickUp(b)
    if InCombatLockdown() or locked() or not PickupAction then return end
    PickupAction(b.action)
    self:UpdateButton(b)
end

function SB:Drop(b)
    if InCombatLockdown() or not PlaceAction then return end
    PlaceAction(b.action)
    self:UpdateButton(b)
end

local function newButton(bar, index, i)
    local b = CK.NewFrame("CheckButton", "ControllerKeyboardSideBar" .. index .. "Button" .. i, bar,
        "ActionButtonTemplate, SecureActionButtonTemplate")
    local slot = SB.Slot(index, i)
    b.action = slot
    b.command = SB.BARS[index].command .. i
    -- The game's bar art (UpdateButtonArt; never read by its secure code)
    b.bar = bar
    -- The template runs the game's flyout code on each attribute set: never
    -- from the addon (see the top)
    b:SetScript("OnAttributeChanged", nil)
    -- What the game's own action buttons set (ActionBarActionButtonMixin:OnLoad)
    b:SetAttribute("type", "action")
    b:SetAttribute("action", slot)
    b:SetAttribute("checkselfcast", true)
    b:SetAttribute("checkfocuscast", true)
    b:SetAttribute("checkmouseovercast", true)
    -- On the mouse button's release, whatever "cast on key down" says (the
    -- game's buttons pass isSecureAction for that; an addon's sets this)
    b:SetAttribute("useOnKeyDown", false)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton", "RightButton")
    if b.UpdateButtonArt then pcall(b.UpdateButtonArt, b) end
    if ActionButton_UpdateCooldownNumberHidden then pcall(ActionButton_UpdateCooldownNumberHidden, b) end
    b:SetPoint("TOP", bar, "TOP", 0, -(i - 1) * (BUTTON_SIZE + PADDING))
    b:HookScript("OnDragStart", function(self) SB:PickUp(self) end)
    b:SetScript("OnReceiveDrag", function(self) SB:Drop(self) end)
    b:HookScript("OnEnter", function(self) SB:ShowTooltip(self) end)
    -- A CheckButton checks itself on a click: the game's state at once
    b:HookScript("PostClick", function(self) checked(self) end)
    b:HookScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    return b
end

---------------------------------------------------------------------------
-- The bars: built when first wanted, out of combat
---------------------------------------------------------------------------
function SB:Build(index)
    local bar = CK.NewFrame("Frame", "ControllerKeyboardSideBar" .. index, UIParent, "SecureHandlerStateTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetSize(BUTTON_SIZE, SB.HEIGHT)
    bar:Hide()
    bar.index = index
    bar.buttons = {}
    for i = 1, NUM_BUTTONS do bar.buttons[i] = newButton(bar, index, i) end
    -- Shown or hidden (the game's override bar, the boxes): the tracker follows
    bar:HookScript("OnShow", function()
        SB:UpdateAll()
        SB:ShiftTracker()
    end)
    bar:HookScript("OnHide", function() SB:ShiftTracker() end)
    bars[index] = bar
    return bar
end

-- A frame's top or bottom if the addon may compute with it
local function edge(frame, which)
    if not (frame and frame[which]) then return nil end
    local ok, v = pcall(frame[which], frame)
    return ok and CK.Plain(v) or nil
end

-- The game's room for them: under the minimap (where the game left it),
-- above its micro menu's place (EditModeManagerFrame GetRightActionBarTopLimit
-- / BottomLimit)
function SB:Limits()
    local top
    local mini = MinimapCluster
    local ok, default = pcall(function() return mini and mini.IsInDefaultPosition and mini:IsInDefaultPosition() end)
    if ok and default then
        local bottom = edge(mini, "GetBottom")
        if bottom then top = bottom - 10 end
    end
    top = top or edge(UIParent, "GetTop")
    local micro = edge(MicroButtonAndBagsBar, "GetTop")
    local bottom = micro and micro + 24 or edge(UIParent, "GetBottom")
    return top, bottom
end

-- Placed as the game places its own: right edge, bar 4 outside, the same
-- scale for both, each one 5 left of the next
function SB:Layout()
    local top, bottom = self:Limits()
    local scale = 1
    if top and bottom and top > bottom and SB.HEIGHT > top - bottom then scale = (top - bottom) / SB.HEIGHT end
    local x = tonumber(RIGHT_ACTION_BAR_DEFAULT_OFFSET_X) or -5
    local y = tonumber(RIGHT_ACTION_BAR_DEFAULT_OFFSET_Y) or -77
    local padX = tonumber(RIGHT_ACTION_BAR_DEFAULT_PADDING_X) or 0
    local left
    for index = 1, #SB.BARS do
        local bar = bars[index]
        if bar and bar.wanted then
            bar:SetScale(scale)
            if left then x = x - left:GetWidth() - 5 + padX end
            bar:ClearAllPoints()
            bar:SetPoint("RIGHT", UIParent, "RIGHT", x, y)
            bar.offsetX = x
            left = bar
        end
    end
    self.scale = scale
end

-- Their width as the game counts its own (EditModeUtil GetBarsLayoutSize:
-- the leftmost bar shown, its offset and its width)
function SB:Width()
    -- The tracker not asked to move; the keyboard and mouse UI: the game's
    -- own bars are in that place (ours only wait for the end of a fight to go)
    if not shiftsTracker() or not CK.GamepadUI() then return 0 end
    local width = 0
    for index = 1, #SB.BARS do
        local bar = bars[index]
        if bar and bar.wanted and bar:IsShown() and bar.offsetX then
            width = math.abs(bar.offsetX) + bar:GetWidth()
        end
    end
    return width
end

---------------------------------------------------------------------------
-- The quest tracker. The game anchors its right column (RightManagedFrameContainer:
-- the tracker and what it stacks with it) at -(its bars' width) - 5 from the
-- right edge (FramePositionDelegate, a local: not hookable), then lays it
-- out; its bars are hidden in the gamepad UI, so it counts none. Each time
-- the game anchors it, its anchor is kept (the values it passed, not read
-- back) and the column placed again that much left of ours. Recognised by
-- the call, never by the place: the game's own bars (keyboard and mouse UI)
-- can put it exactly where ours would.
-- A protected frame in that column (in combat): the shift waits for its end.
---------------------------------------------------------------------------
local function container()
    local get = GetRightManagedFrameContainer
    if type(get) == "function" then
        local ok, c = pcall(get)
        if ok and c then return c end
    end
    return RightManagedFrameContainer
end

-- The game placed the column (its SetPoint, hooked)
function SB:GameAnchor(point, rel, relPoint, x, y)
    if self.shifting then return end
    x, y = CK.Plain(x), CK.Plain(y)
    if type(point) == "string" and x and y then
        self.anchor = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
    else
        -- A form not known here: left as the game set it
        self.anchor = nil
    end
    self.shifted = nil
    self:ShiftTracker()
end

-- The column where the game put it, minus our bars' width (their wanted
-- and shown state only change out of combat: a bar still on screen in a
-- fight keeps the tracker beside it)
function SB:ShiftTracker()
    local a = self.anchor
    local c = container()
    if not (a and c) then return end
    local want = a.x - self:Width()
    if want == (self.shifted or a.x) then return end
    if InCombatLockdown() and c:IsProtected() then
        self.pending = true
        return
    end
    -- Anchored by more than one point: not a place of the game's we know
    if c:GetNumPoints() > 1 then return end
    self.shifting = true
    local ok = pcall(function()
        c:ClearAllPoints()
        c:SetPoint(a.point, a.rel, a.relPoint, want, a.y)
    end)
    self.shifting = false
    if ok then self.shifted = want ~= a.x and want or nil end
end

-- A key bound to Action Bar 4 / 5 pressed: the game pushes its own hidden
-- button (MultiActionButtonDown / Up), ours shows it
local GAME_BARS = { MultiBarRight = 1, MultiBarLeft = 2 }
function SB:Press(barName, id, down)
    local bar = bars[GAME_BARS[barName] or 0]
    local b = bar and bar.wanted and bar.buttons[tonumber(id) or 0]
    if not b then return end
    if down then
        if b:GetButtonState() == "NORMAL" then b:SetButtonState("PUSHED") end
    elseif b:GetButtonState() == "PUSHED" then
        b:SetButtonState("NORMAL")
    end
end

-- Once, the first time the tracker is asked to move (as soon as the game
-- has its column): never hooked before
function SB:HookTracker()
    if self.trackerHooked then return end
    local c = container()
    if c and type(c.SetPoint) == "function" and c.GetNumPoints then
        self.trackerHooked = true
        -- Its place now, nothing of ours on it yet (never moved, or put back)
        if c:GetNumPoints() == 1 then self:GameAnchor(c:GetPoint(1)) end
        hooksecurefunc(c, "SetPoint", function(_, ...) SB:GameAnchor(...) end)
    end
end

-- Once, the first time the bars are wanted: nothing of the game's hooked
-- before
function SB:HookGame()
    if self.hooked then return end
    self.hooked = true
    for name, down in pairs({ MultiActionButtonDown = true, MultiActionButtonUp = false }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function(barName, id) SB:Press(barName, id, down) end)
        end
    end
end

---------------------------------------------------------------------------
-- The option, the game's gamepad UI: which bars show
---------------------------------------------------------------------------
function SB:Apply()
    if InCombatLockdown() then
        self.pending = true
        return
    end
    self.pending = nil
    local n = shownCount()
    local any = false
    for index = 1, #SB.BARS do
        local want = index <= n
        local bar = bars[index]
        if want and not bar then bar = self:Build(index) end
        if bar then
            bar.wanted = want
            if want then
                RegisterStateDriver(bar, "visibility", SB.VISIBILITY)
            else
                UnregisterStateDriver(bar, "visibility")
                bar:Hide()
            end
        end
        any = any or want
    end
    if any then
        self:HookGame()
        if shiftsTracker() then self:HookTracker() end
    end
    self:Layout()
    self:UpdateTypes()
    self:UpdateAll()
    self:UpdateShown()
    self:ShiftTracker()
    if self.ticker then self.ticker:SetShown(any) end
end

-- The bars a refresh is for
local function anyWanted()
    for _, bar in pairs(bars) do
        if bar.wanted then return true end
    end
    return false
end

local REFRESH = {
    "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_ICON", "SPELLS_CHANGED", "UPDATE_BINDINGS",
    "PLAYER_TARGET_CHANGED", "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
    "UPDATE_SHAPESHIFT_FORM", "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "PLAYER_ENTER_COMBAT",
    "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "UPDATE_MACROS",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "PLAYER_MOUNT_DISPLAY_CHANGED", "GAME_PAD_ACTIVE_CHANGED",
}
-- The bars to show again, or placed again
local APPLY = {
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "INPUT_DEVICE_INTERFACE_TRANSITION",
    "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
}

function SB:OnEvent(event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if self.pending then self:Apply() end
        return
    end
    for _, e in ipairs(APPLY) do
        if e == event then return self:Apply() end
    end
    if event == "CVAR_UPDATE" then
        local name = ...
        if name == "countdownForCooldowns" and ActionButton_UpdateCooldownNumberHidden then
            for _, bar in pairs(bars) do
                for _, b in ipairs(bar.buttons) do pcall(ActionButton_UpdateCooldownNumberHidden, b) end
            end
        end
        return
    end
    if event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" then
        self.grid = event == "ACTIONBAR_SHOWGRID"
        if anyWanted() and hideEmpty() then self:UpdateShown() end
        return
    end
    if not anyWanted() then return end
    if event == "ACTIONBAR_SLOT_CHANGED" then
        self:UpdateTypes()
        if hideEmpty() then self:UpdateShown() end
        local slot = tonumber((...))
        if slot and slot ~= 0 then
            for _, bar in pairs(bars) do
                for _, b in ipairs(bar.buttons) do
                    if b.action == slot and bar.wanted then self:UpdateButton(b) end
                end
            end
            return
        end
    end
    self:UpdateAll()
end

-- Five times a second while shown: range, usable, checked; the blink
function SB:Tick(dt)
    self.since = (self.since or 0) + dt
    local check = self.since >= CHECK
    if check then self.since = 0 end
    local period = tonumber(ATTACK_BUTTON_FLASH_TIME) or 0.4
    self.flashTime = (self.flashTime or 0) - dt
    local blink = self.flashTime <= 0
    if blink then self.flashTime = period end
    for _, bar in pairs(bars) do
        if bar.wanted and bar:IsVisible() then
            for _, b in ipairs(bar.buttons) do
                if check and ab("HasAction", b.action) then
                    range(b)
                    usable(b)
                    checked(b)
                    if GameTooltip and GameTooltip:GetOwner() == b then self:ShowTooltip(b) end
                end
                if b.Flash then
                    if flashing(b) then
                        if blink then b.Flash:SetShown(not b.Flash:IsShown()) end
                    elseif b.Flash:IsShown() then
                        b.Flash:Hide()
                    end
                end
            end
        end
    end
end

function SB:Init()
    local events = CK.NewFrame("Frame", nil, UIParent)
    for _, list in ipairs({ REFRESH, APPLY, { "CVAR_UPDATE", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID" } }) do
        for _, e in ipairs(list) do pcall(events.RegisterEvent, events, e) end
    end
    events:SetScript("OnEvent", function(_, event, ...) SB:OnEvent(event, ...) end)
    self.events = events
    local ticker = CK.NewFrame("Frame", nil, UIParent)
    ticker:Hide()
    ticker:SetScript("OnUpdate", function(_, dt) SB:Tick(dt or 0) end)
    self.ticker = ticker
    self:Apply()
end
