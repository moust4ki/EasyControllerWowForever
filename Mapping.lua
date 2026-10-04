local _, CK = ...
local L = CK.L

-- Module "gamepad mapping": WoW Forever's gamepad UI is never changed. This
-- module only adds functions on the inputs the game leaves free: the back
-- paddles, and the buttons and trigger combinations nothing is bound to
-- (L3, R3, LT + Start...). A free input can run a game function (any key
-- binding command: run / walk, game menu, map...), a spell, an item, a macro,
-- or press a button of the gamepad action bar.
--
-- "Free" is checked against the game's own bindings every time ours are set,
-- with ours removed first: an input the game uses is never taken. Our
-- bindings are plain override bindings of our own frame, set out of combat
-- while no gamepad window has the focus; the game's windows bind their keys
-- with priority above them, and ours are set again when they close.
--
-- The game's own buttons can be replaced too (see "The game's buttons,
-- replaced"); the Gamepad tab gives them all back to the game at once.
local M = {}
CK.Mapping = M

M.LAYERS = { "", "LT", "RT", "LTRT" }

-- Every input, where it sits on a controller (x, y in the mapping window)
M.INPUTS = {
    { id = "LT", key = "PADLTRIGGER", x = 60, y = 40, layer = true },
    { id = "LB", key = "PADLSHOULDER", x = 140, y = 40 },
    { id = "RB", key = "PADRSHOULDER", x = 330, y = 40 },
    { id = "RT", key = "PADRTRIGGER", x = 410, y = 40, layer = true },
    { id = "UP", key = "PADDUP", x = 110, y = 126, bar = "up" },
    { id = "LEFT", key = "PADDLEFT", x = 66, y = 170, bar = "left" },
    { id = "RIGHT", key = "PADDRIGHT", x = 154, y = 170, bar = "right" },
    { id = "DOWN", key = "PADDDOWN", x = 110, y = 214, bar = "down" },
    { id = "SELECT", key = "PADBACK", x = 200, y = 150 },
    { id = "START", key = "PADFORWARD", x = 270, y = 150 },
    { id = "Y", key = "PAD4", x = 360, y = 126, bar = "y" },
    { id = "X", key = "PAD3", x = 316, y = 170, bar = "x" },
    { id = "B", key = "PAD2", x = 404, y = 170, bar = "b" },
    { id = "A", key = "PAD1", x = 360, y = 214, bar = "a" },
    { id = "L3", key = "PADLSTICK", x = 170, y = 270 },
    { id = "R3", key = "PADRSTICK", x = 300, y = 270 },
    { id = "L4", paddle = true, x = 80, y = 372 },
    { id = "L5", paddle = true, x = 160, y = 372 },
    { id = "R5", paddle = true, x = 310, y = 372 },
    { id = "R4", paddle = true, x = 390, y = 372 },
    -- Touchpads set as buttons (Steam Deck, Steam Controller, Vader Pro...):
    -- 4 a side (up, right, down, left), each turned on in Gamepad > Display.
    -- They work like the back paddles (a learned key, the four layers).
    { id = "TL1", paddle = true, touch = true }, { id = "TL2", paddle = true, touch = true },
    { id = "TL3", paddle = true, touch = true }, { id = "TL4", paddle = true, touch = true },
    { id = "TR1", paddle = true, touch = true }, { id = "TR2", paddle = true, touch = true },
    { id = "TR3", paddle = true, touch = true }, { id = "TR4", paddle = true, touch = true },
}
M.TOUCH = { "TL1", "TL2", "TL3", "TL4", "TR1", "TR2", "TR3", "TR4" }
M.BY_ID = {}
for _, input in ipairs(M.INPUTS) do M.BY_ID[input.id] = input end

-- Gamepad buttons the client reports for back paddles (Xbox Elite, DualSense
-- Edge...); Steam Input sends keyboard keys instead, learned by pressing
M.PADDLE_KEYS = { L4 = "PADPADDLE2", R4 = "PADPADDLE1", L5 = "PADPADDLE4", R5 = "PADPADDLE3" }

-- The game's gamepad bar for each layer, and its fixed top face buttons
M.LAYER_BAR = { [""] = "top", LT = "left", RT = "right", LTRT = "bottom" }

local function settings() return CK.db.settings end

function M:Enabled()
    return CK.db and settings().modules.mapping
end

-- A touchpad button only once turned on (Gamepad > Display)
function M:InputEnabled(input)
    if not (input and input.touch) then return input ~= nil end
    local on = settings().touchButtons
    return type(on) == "table" and on[input.id] == true
end

function M:AnyTouch()
    for _, id in ipairs(M.TOUCH) do
        if self:InputEnabled(M.BY_ID[id]) then return true end
    end
    return false
end

function M:InputKey(input)
    if input.paddle then
        local cfg = settings().paddles[input.id]
        return cfg and cfg.key or M.PADDLE_KEYS[input.id]
    end
    return input.key
end

---------------------------------------------------------------------------
-- Trigger layers: the triggers act as keyboard modifiers when the client's
-- GamePadEmulateShift / Ctrl / Alt settings name them
---------------------------------------------------------------------------
local EMULATE = { { "ALT", "GamePadEmulateAlt" }, { "CTRL", "GamePadEmulateCtrl" }, { "SHIFT", "GamePadEmulateShift" } }

function M:TriggerModifier(button)
    for _, e in ipairs(EMULATE) do
        if GetCVar(e[2]) == button then return e[1] end
    end
end

-- RT as a modifier too (the game's own gamepad setting, like LT = Shift):
-- with it, RT + a paddle is a key of its own, so the RT and LT + RT layers
-- exist for the extra buttons. Takes a free modifier, Alt then Ctrl.
local FREE = { [""] = true, none = true, NONE = true }

function M:SetTriggerModifier(button, on)
    if InCombatLockdown() then return CK:BlockedByCombat() end
    if on then
        if self:TriggerModifier(button) then return end
        for _, cvar in ipairs({ "GamePadEmulateAlt", "GamePadEmulateCtrl" }) do
            if FREE[GetCVar(cvar) or ""] then
                SetCVar(cvar, button)
                break
            end
        end
    else
        for _, e in ipairs(EMULATE) do
            if GetCVar(e[2]) == button then SetCVar(e[2], "none") end
        end
    end
    self:Apply()
    CK.Paddles:Apply()
end

function M:CanBeModifier(button)
    if self:TriggerModifier(button) then return true end
    return FREE[GetCVar("GamePadEmulateAlt") or ""] or FREE[GetCVar("GamePadEmulateCtrl") or ""] or false
end

-- The modifiers a key comes with while a layer's triggers are held: those
-- of the triggers that are modifiers ("SHIFT-"...)
function M:ArrivalPrefix(layer)
    local held = {}
    for _, t in ipairs({ { "LT", "PADLTRIGGER" }, { "RT", "PADRTRIGGER" } }) do
        local mod = layer:find(t[1], 1, true) and self:TriggerModifier(t[2])
        if mod then held[mod] = true end
    end
    local prefix = ""
    for _, e in ipairs(EMULATE) do
        if held[e[1]] then prefix = prefix .. e[1] .. "-" end
    end
    return prefix
end

-- Key name prefix of a layer, nil when a trigger of the layer is not a
-- modifier (the key is then the same as without it)
function M:LayerPrefix(layer)
    if layer:find("LT", 1, true) and not self:TriggerModifier("PADLTRIGGER") then return nil end
    if layer:find("RT", 1, true) and not self:TriggerModifier("PADRTRIGGER") then return nil end
    return self:ArrivalPrefix(layer)
end

-- The layers whose key is the same as this layer's, the one without the
-- triggers that are no modifier first
function M:SharedLayers(layer)
    local prefix, list = self:ArrivalPrefix(layer), {}
    for _, l in ipairs(M.LAYERS) do
        if self:ArrivalPrefix(l) == prefix then list[#list + 1] = l end
    end
    return list
end

function M:Combo(input, layer)
    local key, prefix = self:InputKey(input), self:LayerPrefix(layer)
    return key and prefix and (prefix .. key)
end

---------------------------------------------------------------------------
-- What the game does with an input (nil: free)
---------------------------------------------------------------------------
M.bound = {}    -- combo -> what we bound there
M.taken = {}    -- combo -> what we bound there over the game (replaced buttons)
M.padRouted = {} -- input id -> its keys go to its router (ApplyPad)

function M:NativeBinding(combo)
    local action = GetBindingAction(combo, true)
    if action == self.bound[combo] or action == self.taken[combo]
        or (action and action:find("^CLICK ControllerKeyboardConfigPad")) then
        action = GetBindingAction(combo, false)
    end
    if action and action ~= "" then return action end
    if C_KeyBindings and C_KeyBindings.GetBindingByKey and Enum and Enum.BindingContext then
        local ok, context = pcall(C_KeyBindings.GetBindingByKey, combo, Enum.BindingContext.GamepadModeInGameCore)
        if ok and type(context) == "string" and context ~= "" then return context end
    end
end

-- The game's gamepad bar button for an input and a layer
function M:NativeBarButton(input, layer)
    if not input.bar then return end
    return CK.Paddles:NativeButton(self:BarAction(input, layer))
end

-- "bar:right:a": the game's bar button of an input in a layer
function M:BarAction(input, layer)
    return input.bar and ("bar:" .. M.LAYER_BAR[layer] .. ":" .. input.bar) or nil
end

-- The one shown now: in a stance (stealth, a form), the stance bar's
function M:LiveBarButton(input, layer)
    if not input.bar then return end
    return CK.Paddles:LiveButton(self:BarAction(input, layer))
end

-- A press on the game's bar button, as a macro: in a stance, the stance
-- bar's button where it takes that bar ([bonusbar]: decided by the game on
-- the press, in combat too), else the bar's own. For a character with no
-- stance or form, nil: its button is clicked as before.
function M:StanceMacro(barAction)
    local P = CK.Paddles
    if not P:HasStances() then return nil end
    local native, stance = P:NativeButton(barAction), P:StanceButton(barAction)
    local nativeName, stanceName = native and native:GetName(), stance and stance:GetName()
    if not (nativeName and stanceName) then return nil end
    return "/click [bonusbar] " .. stanceName .. " LeftButton true; " .. nativeName .. " LeftButton true"
end

function M:BarMacro(barAction)
    local stance = self:StanceMacro(barAction)
    if stance then return stance end
    local native = CK.Paddles:NativeButton(barAction)
    local name = native and native:GetName()
    return name and ("/click " .. name .. " LeftButton true") or nil
end

local FIXED_FACE = { a = "JUMP", x = "INTERACT", b = "BACK", y = "INSPECT" }
-- The game's own pictures for its fixed functions
local FIXED_ICON = {
    JUMP = { atlas = "gamepad-ability-icon-jump" },
    INTERACT = { texture = "Interface\\Cursor\\Interact" },
    BACK = { atlas = "128-redbutton-exit" },
    INSPECT = { atlas = "crosshair_inspect_32" },
}

-- Label and icon of the game's own function, for the mapping page (icons:
-- see CK.Paddles.SetIcon)
function M:NativeInfo(input, layer)
    if input.layer then
        return input.id == "LT" and L.NAT_LAYER_LEFT or L.NAT_LAYER_RIGHT, { glyph = input.id }
    end
    if layer == "" and FIXED_FACE[input.bar] then
        return L["NAT_" .. FIXED_FACE[input.bar]], FIXED_ICON[FIXED_FACE[input.bar]]
    end
    local native = self:LiveBarButton(input, layer)
    if native then
        local slot = native.action
        local name = slot and CK.Paddles.SlotName(slot)
        local icon = slot and CK.Paddles.SlotTexture(slot)
        return name or L.MAP_EMPTY_SLOT, icon, true
    end
    if input.id == "LB" then
        return layer == "" and L.NAT_TARGET_FRIEND or L.MAP_GAME, { atlas = "gamepad-targeting-friendly" }
    end
    if input.id == "RB" then
        return layer == "" and L.NAT_TARGET_ENEMY or L.MAP_GAME, { atlas = "gamepad-targeting-hostile" }
    end
    if layer == "" and input.id == "START" then return self:NativeCommandInfo("OPENRADIAL") end
    if layer == "" and input.id == "SELECT" then return self:NativeCommandInfo("TOGGLEUIFOCUS") end
    local combo = self:Combo(input, layer)
    local action = combo and self:NativeBinding(combo)
    if not action then return nil end
    return self:NativeCommandInfo(action)
end

---------------------------------------------------------------------------
-- The game's gamepad bar slots (D-pad, A / B / X / Y in each layer): what
-- they hold is changed the way the game's own action bar editor does it
-- (picked up and placed in the slot, out of combat). The button itself stays
-- the game's. The fixed face buttons alone (jump, interact...) are no slot.
---------------------------------------------------------------------------
function M:NativeSlot(input, layer)
    if not input.bar or (layer == "" and FIXED_FACE[input.bar]) then return nil end
    local native = self:LiveBarButton(input, layer)
    local slot = native and native.action
    if type(slot) == "number" and slot > 0 then return slot end
end

-- "spell:133" for what a slot holds
function M:SlotAction(slot)
    if not (slot and C_ActionBar.HasAction(slot)) then return nil end
    local kind, id = GetActionInfo(slot)
    if kind == "spell" then return "spell:" .. id end
    if kind == "item" then return "item:" .. id end
    if kind == "macro" then
        local name = GetActionText and GetActionText(slot) or (GetMacroInfo and (GetMacroInfo(id)))
        return name and ("macro:" .. name)
    end
end

-- What the game itself won't take off its gamepad bars (the hunter's aspects,
-- pet actions while the pet has its bar): its own message, else nil
function M:SlotKept(slot)
    local util = GamepadActionBarBindingUtil
    if not (slot and util and util.GetUnbindErrorMessage and C_ActionBar.HasAction(slot)) then return nil end
    local ok, message = pcall(util.GetUnbindErrorMessage, { GetActionInfo(slot) })
    return ok and message or nil
end

local function refuseKept(slot)
    local message = M:SlotKept(slot)
    if message and UIErrorsFrame then UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1) end
    return message ~= nil
end

function M:PlaceInSlot(slot, action)
    if CK:BlockedByCombat() then return false end
    -- What was there would be lost
    if refuseKept(slot) then return false end
    local kind, value = (action or ""):match("^(%a+):(.+)$")
    ClearCursor()
    if kind == "spell" then
        local pickup = C_Spell and C_Spell.PickupSpell or PickupSpell
        pickup(tonumber(value))
    elseif kind == "item" then
        local pickup = C_Item and C_Item.PickupItem or PickupItem
        pickup(tonumber(value))
    elseif kind == "macro" then
        PickupMacro(value)
    end
    if not GetCursorInfo() then return false end
    PlaceAction(slot)
    -- What was there comes back on the cursor: let it go
    ClearCursor()
    return true
end

function M:ClearSlot(slot)
    if CK:BlockedByCombat() or refuseKept(slot) then return end
    ClearCursor()
    PickupAction(slot)
    ClearCursor()
end

-- "free", "native", "slot", "locked" (layer unavailable) for an input
function M:State(input, layer)
    if input.layer then return "native" end
    -- The bars' buttons, and LB / RB (targeting, and the game's class
    -- actions on LT + LB / RT + RB) always belong to the game, in every
    -- layer: the game switches its bars itself, triggers modifiers or not
    if input.bar then return self:NativeSlot(input, layer) and "slot" or "native" end
    if input.id == "LB" or input.id == "RB" then return "native" end
    -- The back paddles have every layer (see "Back paddles" below), but a
    -- game function on a shared key takes it in all its layers
    if input.paddle then
        if not self:InputKey(input) then return "locked" end
        local base = self:SharedLayers(layer)[1]
        local baseAction = layer ~= base and self:Get(input.id, base)
        if baseAction and not M.Routable(baseAction) then return "locked" end
        return "free"
    end
    local combo = self:Combo(input, layer)
    if not combo then return "locked" end
    if self.snapshot and self.snapshot[combo] ~= nil then
        return self.snapshot[combo] and "native" or "free"
    end
    return self:NativeBinding(combo) and "native" or "free"
end

-- Free / native state of every combo, taken before the window binds the pad
function M:TakeSnapshot()
    self:Release()
    self.snapshot = nil
    local snapshot = {}
    for _, input in ipairs(M.INPUTS) do
        for _, layer in ipairs(M.LAYERS) do
            local combo = self:Combo(input, layer)
            if combo then snapshot[combo] = self:NativeBinding(combo) ~= nil end
        end
    end
    self.snapshot = snapshot
end

function M:DropSnapshot()
    self.snapshot = nil
end

---------------------------------------------------------------------------
-- Assignments: settings.mapping["L3:LT"] = "cmd:TOGGLERUN" | "spell:133" |
-- "item:5512" | "macro:Name" | "bar:bottom:a" | "wheel:consumables"
---------------------------------------------------------------------------
function M:Get(inputId, layer)
    return settings().mapping[inputId .. ":" .. layer]
end

function M:Set(inputId, layer, action)
    settings().mapping[inputId .. ":" .. layer] = action
    self:Apply()
    CK.Paddles:Apply()
end

---------------------------------------------------------------------------
-- The game's buttons, replaced: A, B, X, Y, the D-pad, LB / RB, Start,
-- Select... take any function, bound over the game's with priority.
-- settings.replaced["A:"] = action; the Gamepad tab's Restore button empties
-- it. Each layer needs a key of its own, so both triggers are modifiers.
-- The other layers of a replaced button get what the game does there, bound
-- the same way: a key with no binding of its own would fall back to ours
-- (the game takes the key without its modifiers). The game's menus bind
-- their keys over ours; ours are also taken away while one of them has the
-- focus (out of combat). A slot of the game's bar keeps what it holds,
-- under our function's picture, and gets it back when the button does.
---------------------------------------------------------------------------
local TRIGGERS = { "PADLTRIGGER", "PADRTRIGGER" }

function M:ReplaceOn()
    return self:Enabled() or false
end

-- How many of the game's buttons are replaced
function M:ReplacedCount()
    local n = 0
    for _ in pairs(settings().replaced) do n = n + 1 end
    return n
end

-- Every replaced button back to the game's own binding (what the player put
-- in the game's slots, on the free buttons and paddles stays)
function M:RestoreGameButtons()
    wipe(settings().replaced)
    self:Apply()
    CK.Paddles:Apply()
end

-- The game's own: never the triggers (its bars), LB / RB alone only (with
-- a trigger, its class and pet actions read the buttons themselves)
-- LB / RB: alone, and LT + RB / RT + LB, which the game leaves to the
-- targeting (its class actions are LT + LB and RT + RB, read from the keys
-- held: they stay the game's)
local CROSSED = { LB = "RT", RB = "LT" }
M.CROSSED = CROSSED

function M:Replaceable(input, layer)
    if not self:ReplaceOn() or input.layer or input.paddle then return false end
    if (input.id == "LB" or input.id == "RB") and layer ~= "" and layer ~= CROSSED[input.id] then return false end
    local state = self:State(input, layer)
    return state == "native" or state == "slot"
end

-- Every layer has a key of its own: both triggers are modifiers
function M:OwnKeys()
    return self:TriggerModifier("PADLTRIGGER") ~= nil and self:TriggerModifier("PADRTRIGGER") ~= nil
end

-- Enough free modifiers in the game's gamepad settings for that
function M:CanOwnKeys()
    local need, free = 0, 0
    for _, t in ipairs(TRIGGERS) do
        if not self:TriggerModifier(t) then need = need + 1 end
    end
    for _, cvar in ipairs({ "GamePadEmulateAlt", "GamePadEmulateCtrl" }) do
        if FREE[GetCVar(cvar) or ""] then free = free + 1 end
    end
    return free >= need
end

function M:GetReplaced(inputId, layer)
    return self:ReplaceOn() and settings().replaced[inputId .. ":" .. layer] or nil
end

-- Bound now: the option on, the button the game's, a key of its own
function M:ReplacedActive(input, layer)
    return self:GetReplaced(input.id, layer) ~= nil and self:OwnKeys() and self:Replaceable(input, layer)
end

-- What the game itself runs on an input: its bar button, else its binding
function M:NativeAction(input, layer)
    if input.bar then return "bar:" .. M.LAYER_BAR[layer] .. ":" .. input.bar end
    local combo = self:Combo(input, layer)
    local command = combo and self:NativeBinding(combo)
    return command and not command:find("^CLICK ") and ("cmd:" .. command) or nil
end

function M:SetReplaced(inputId, layer, action)
    -- The game's own function chosen: the button given back to it
    local input = M.BY_ID[inputId]
    if action and input and action == self:NativeAction(input, layer) then action = nil end
    settings().replaced[inputId .. ":" .. layer] = action
    if action then
        for _, t in ipairs(TRIGGERS) do
            if not self:TriggerModifier(t) then self:SetTriggerModifier(t, true) end
        end
    end
    self:Apply()
    CK.Paddles:Apply()
end

---------------------------------------------------------------------------
-- Back paddles: four layers, triggers modifiers or not. A trigger that is
-- no keyboard modifier (RT, unless the option makes it one) changes nothing
-- in the key a paddle sends: L4 and RT + L4 are one key, which the layers
-- share. That key then goes to a secure button that picks the layer when it
-- is pressed, from the triggers held (the game lets secure code read the
-- gamepad), and runs that layer's spell, item or macro. A game function is
-- a key binding: it needs the key to itself, all its layers.
---------------------------------------------------------------------------
local ROUTABLE = { spell = true, item = true, macro = true, wheel = true }

function M.Routable(action)
    return type(action) == "string" and ROUTABLE[action:match("^(%a+):") or ""] or false
end

-- What an input runs in a layer: its own action, else (a shared key) the
-- one of the layer the key belongs to
function M:EffectiveAction(input, layer)
    local base = self:SharedLayers(layer)[1]
    local baseAction = self:Get(input.id, base)
    if not input.paddle or (baseAction and not M.Routable(baseAction)) then return baseAction end
    local own = self:Get(input.id, layer)
    -- Each layer its own: a layer with nothing runs nothing
    if layer ~= base and not M.Routable(own) then return nil end
    return own
end

-- A game function left on a layer that now shares its key (RT no longer a
-- modifier): kept, not bound
function M:Inactive(input, layer)
    local action = input.paddle and self:Get(input.id, layer)
    return action and not M.Routable(action) and layer ~= self:SharedLayers(layer)[1] or false
end

-- The lists the mapping window offers for a paddle in a layer
function M:PaddleTabs(input, layer)
    local shared = self:SharedLayers(layer)
    if #shared == 1 then return M.TABS end
    if layer == shared[1] then
        for i = 2, #shared do
            if self:Get(input.id, shared[i]) then return M.SLOT_TABS end
        end
        return M.TABS
    end
    return M.SLOT_TABS
end

---------------------------------------------------------------------------
-- Actions: names, icons
---------------------------------------------------------------------------
local COMMAND_ICONS = {
    CONTROLLERKEYBOARD_TOGGLE = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up",
    CONTROLLERKEYBOARD_MAP = "Interface\\Icons\\INV_Gizmo_02",
    CONTROLLERKEYBOARD_CONFIG = "Interface\\Icons\\INV_Gizmo_02",
    TOGGLEAUTORUN = { atlas = "Ping_Marker_Icon_OnMyWay", glyph = "LS" },
    TOGGLERUN = "Interface\\Icons\\Ability_Tracking",
    JUMP = { atlas = "gamepad-ability-icon-jump", glyph = "A" },
    TOGGLEWORLDMAP = "Interface\\Icons\\INV_Misc_Map02",
    OPENALLBAGS = "Interface\\Icons\\INV_Misc_Bag_08",
    TOGGLEBACKPACK = "Interface\\Icons\\INV_Misc_Bag_08",
    TOGGLECHARACTER0 = "Interface\\Icons\\INV_Chest_Cloth_17",
    TOGGLESPELLBOOK = "Interface\\Icons\\INV_Misc_Book_09",
    TOGGLETALENTS = "Interface\\Icons\\Ability_Marksmanship",
    TOGGLEQUESTLOG = "Interface\\Icons\\INV_Misc_Book_08",
    TOGGLESOCIAL = "Interface\\Icons\\INV_Letter_15",
    TOGGLEGAMEMENU = "Interface\\Icons\\INV_Misc_Gear_01",
    TARGETNEARESTENEMY = "Interface\\Icons\\Ability_Hunter_SniperShot",
    TARGETNEARESTFRIEND = "Interface\\Icons\\Spell_Holy_Heal",
    INTERACTTARGET = "Interface\\Icons\\INV_Misc_Gear_01",
    ASSISTTARGET = "Interface\\Icons\\Ability_Hunter_SniperShot",
    FOLLOWTARGET = "Interface\\Icons\\Ability_Tracking",
    TOGGLESHEATH = "Interface\\Icons\\INV_Sword_04",
    SITORSTAND = "Interface\\Icons\\Spell_Nature_Sleep",
    TOGGLEUI = "Interface\\Icons\\INV_Misc_Spyglass_03",
    SCREENSHOT = "Interface\\Icons\\INV_Misc_Spyglass_03",
}
local COMMAND_ICON = "Interface\\Icons\\INV_Misc_Key_03"

-- The game's own gamepad bindings have no name of their own
local NATIVE_COMMANDS = {
    OPENRADIAL = { "NAT_START", "Interface\\Icons\\INV_Misc_Gear_01" },
    TOGGLEUIFOCUS = { "NAT_SELECT", "Interface\\Icons\\INV_Misc_Spyglass_02" },
    TOGGLEPINGSYSTEM = { "NAT_PING", { atlas = "Ping_Marker_Icon_Assist", glyph = "RS" } },
    TOGGLEPINGLISTENER = { "NAT_PING", { atlas = "Ping_Marker_Icon_Assist", glyph = "RS" } },
    -- Held: the game's targeting (LB / RB)
    GAMEPADLEFTTARGETMODIFIER = { "NAT_TARGET_FRIEND", { atlas = "gamepad-targeting-friendly" }, hold = true },
    GAMEPADRIGHTTARGETMODIFIER = { "NAT_TARGET_ENEMY", { atlas = "gamepad-targeting-hostile" }, hold = true },
}

-- The game's own gamepad functions, for any free input: its four fixed
-- buttons (pressed: their own behaviour, the smart interact...) and its
-- gamepad key bindings. Not its left / right bar modifiers: the game checks
-- which key holds them.
M.PAD_FUNCTIONS = {
    "bar:top:a", "bar:top:b", "bar:top:x", "bar:top:y",
    "cmd:OPENRADIAL", "cmd:TOGGLEUIFOCUS", "cmd:TOGGLEPINGSYSTEM",
    "cmd:GAMEPADLEFTTARGETMODIFIER", "cmd:GAMEPADRIGHTTARGETMODIFIER",
}

-- Name and icon of a binding of the game's (a command, or a click on one
-- of its gamepad buttons)
function M:NativeCommandInfo(action)
    local known = NATIVE_COMMANDS[action] or (action:find("^TOGGLEPING") and NATIVE_COMMANDS.TOGGLEPINGSYSTEM)
    if known then return L[known[1]], known[2] end
    if action:find("^CLICK ") then return L.MAP_GAME end
    local name = CK.Paddles:CommandName(action)
    if name == action then name = L.MAP_GAME end
    return name, COMMAND_ICONS[action]
end

-- Game functions offered first, the most missed on a gamepad
M.COMMON = {
    "TOGGLERUN", "TOGGLEAUTORUN", "TOGGLEGAMEMENU", "TOGGLEWORLDMAP", "OPENALLBAGS",
    "TOGGLECHARACTER0", "TOGGLESPELLBOOK", "TOGGLETALENTS", "TOGGLEQUESTLOG", "TOGGLESOCIAL",
    "CONTROLLERKEYBOARD_TOGGLE", "CONTROLLERKEYBOARD_CONFIG", "TARGETNEARESTENEMY", "ASSISTTARGET", "FOLLOWTARGET",
    "SITORSTAND", "TOGGLESHEATH", "TOGGLEUI", "SCREENSHOT",
}

-- "Name (Rank 3)": the spell book holds each rank of a spell
function M.SpellName(id, rank)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if not name then return nil end
    rank = rank or (C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id))
    if rank and rank ~= "" then name = name .. " |cff9d9a8c(" .. rank .. ")|r" end
    return name
end

-- What a secure button casts for a spell: its name, with its rank when the
-- spell book lists ranks ("Name(Rank 3)", the rank chosen stays the one
-- cast); its ID only while the name is not known. Some spells (Ghost Wolf,
-- shapeshift forms) don't cast by ID, a macro casting them by name did.
function M.SpellCast(id)
    id = tonumber(id)
    local name = id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if not name then return id end
    local sub = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
    if type(sub) == "string" and sub:find("%d") then return name .. "(" .. sub .. ")" end
    return name
end

function M:ActionName(action)
    if not action then return nil end
    local kind, value = action:match("^(%a+):(.+)$")
    local fixed = FIXED_FACE[action:match("^bar:top:(%a)$") or ""]
    if fixed then return L["NAT_" .. fixed] end
    if kind == "cmd" and NATIVE_COMMANDS[value] then
        local native = NATIVE_COMMANDS[value]
        return L[native[1]] .. (native.hold and L.MAP_HOLD or "")
    end
    if kind == "cmd" then
        return CK.Paddles:CommandName(value)
    elseif kind == "spell" then
        return M.SpellName(tonumber(value)) or value
    elseif kind == "item" then
        local id = tonumber(value)
        return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) or value
    elseif kind == "macro" then
        return value
    elseif kind == "bar" then
        return CK.Paddles:ActionLabel(action)
    elseif kind == "wheel" then
        local n = tonumber(value)
        if not n then return L.WHEEL_NAME end
        return CK.MyWheels and CK.MyWheels:Name(n) or L.MYWHEEL_GONE
    end
end

function M:ActionIcon(action)
    if not action then return nil end
    local kind, value = action:match("^(%a+):(.+)$")
    local fixed = FIXED_FACE[action:match("^bar:top:(%a)$") or ""]
    if fixed then return FIXED_ICON[fixed] end
    if kind == "cmd" and NATIVE_COMMANDS[value] then return NATIVE_COMMANDS[value][2] end
    if kind == "cmd" then
        return COMMAND_ICONS[value] or COMMAND_ICON
    elseif kind == "spell" then
        return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(tonumber(value))
    elseif kind == "item" then
        return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(tonumber(value))
    elseif kind == "macro" then
        local _, icon = GetMacroInfo(value)
        return icon
    elseif kind == "bar" then
        return CK.Paddles:ActionIcon(action)
    elseif kind == "wheel" then
        local n = tonumber(value)
        return n and CK.MyWheels and CK.MyWheels:Icon(n) or M.WHEEL_ICON
    end
end

---------------------------------------------------------------------------
-- Catalogue for the mapping window: { header = "..." } or
-- { action = "...", name = "...", icon = ... }
---------------------------------------------------------------------------
M.TABS = { "game", "spells", "items", "macros", "bar" }
-- The game's slots only take spells, items and macros
M.SLOT_TABS = { "spells", "items", "macros" }

local function commandEntry(command)
    return { action = "cmd:" .. command, name = CK.Paddles:CommandName(command),
        icon = COMMAND_ICONS[command] or COMMAND_ICON }
end

M.WHEEL_ICON = "Interface\\Icons\\INV_Potion_54"

-- forSlot: for one of the game's bar slots (spells, items, macros only)
function M:Catalog(tab, forSlot)
    local list = {}
    if tab == "game" then
        local known, cats, byCategory = {}, {}, {}
        for i = 1, GetNumBindings and GetNumBindings() or 0 do
            local command, category = GetBinding(i)
            if command and command ~= "" and category and not command:find("^HEADER_") and not command:find("^CLICK ") then
                known[command] = true
                local cat = byCategory[category]
                if not cat then
                    cat = { name = _G[category] or category, commands = {} }
                    byCategory[category] = cat
                    cats[#cats + 1] = cat
                end
                table.insert(cat.commands, command)
            end
        end
        -- The game's own gamepad functions first
        list[#list + 1] = { header = L.CAT_GAMEPAD }
        for _, action in ipairs(M.PAD_FUNCTIONS) do
            if not action:find("^bar:") or CK.Paddles:NativeButton(action) then
                list[#list + 1] = { action = action, name = M:ActionName(action), icon = M:ActionIcon(action) }
            end
        end
        list[#list + 1] = { header = L.CAT_COMMON }
        for _, command in ipairs(M.COMMON) do
            if known[command] then list[#list + 1] = commandEntry(command) end
        end
        for _, cat in ipairs(cats) do
            list[#list + 1] = { header = cat.name }
            for _, command in ipairs(cat.commands) do list[#list + 1] = commandEntry(command) end
        end
    elseif tab == "spells" and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide then
                local first = true
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
                    if item and item.spellID and not item.isPassive and not item.isOffSpec
                        and (not spellType or item.itemType == spellType) then
                        if first then
                            list[#list + 1] = { header = info.name }
                            first = false
                        end
                        list[#list + 1] = { action = "spell:" .. item.spellID, icon = item.iconID,
                            name = M.SpellName(item.spellID, item.subName) or item.name }
                    end
                end
            end
        end
    elseif tab == "items" and C_Container then
        -- Ours first: the consumables wheel (not for the game's bar slots)
        if not forSlot and CK.ConsumableWheel then
            list[#list + 1] = { header = L.HDR_WHEELS }
            list[#list + 1] = { action = "wheel:consumables", name = L.WHEEL_NAME, icon = M.WHEEL_ICON }
            -- The player's own wheels
            for _, w in ipairs(CK.MyWheels and CK.MyWheels:List() or {}) do
                list[#list + 1] = { action = "wheel:" .. w.id, name = w.name, icon = CK.MyWheels:Icon(w.id) }
            end
            list[#list + 1] = { header = L.MAP_TAB_ITEMS }
        end
        local seen = {}
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local id = C_Container.GetContainerItemID(bag, slot)
                if id and not seen[id] and C_Item.GetItemSpell and C_Item.GetItemSpell(id) then
                    seen[id] = true
                    list[#list + 1] = { action = "item:" .. id,
                        name = C_Item.GetItemNameByID(id) or ("item:" .. id), icon = C_Item.GetItemIconByID(id) }
                end
            end
        end
    elseif tab == "macros" and GetNumMacros then
        local account, character = GetNumMacros()
        local perAccount = MAX_ACCOUNT_MACROS or 120
        for i = 1, account do
            local name, icon = GetMacroInfo(i)
            if name then list[#list + 1] = { action = "macro:" .. name, name = name, icon = icon } end
        end
        for i = perAccount + 1, perAccount + character do
            local name, icon = GetMacroInfo(i)
            if name then list[#list + 1] = { action = "macro:" .. name, name = name, icon = icon } end
        end
    elseif tab == "bar" then
        for _, layer in ipairs(M.LAYERS) do
            list[#list + 1] = { header = CK.Paddles:LayerLabel(layer) }
            for _, input in ipairs(M.INPUTS) do
                if input.bar and not (layer == "" and FIXED_FACE[input.bar]) then
                    local action = "bar:" .. M.LAYER_BAR[layer] .. ":" .. input.bar
                    list[#list + 1] = { action = action, name = CK.Paddles:ActionLabel(action),
                        icon = CK.Paddles:ActionIcon(action) }
                end
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Bindings
---------------------------------------------------------------------------
local owner
local takeOwner         -- the game's buttons replaced: priority bindings

-- Every key set on an owner taken away, then the owner cleared. In case a
-- binding to one of the game's gamepad commands (ping, Start menu...) would
-- outlive ClearOverrideBindings, each key bound to a command this session
-- first goes to one that does nothing, and to a button that does nothing,
-- then to none.
local noop
local commanded = {}    -- owner -> keys it bound to a command, this session
local function unbindAll(o, record, priority)
    noop = noop or CK.NewFrame("Button", "ControllerKeyboardNoopButton")
    local keys = commanded[o] or {}
    for combo in pairs(record) do keys[combo] = true end
    for combo in pairs(keys) do
        SetOverrideBinding(o, priority, combo, "CONTROLLERKEYBOARD_NOOP")
        SetOverrideBindingClick(o, priority, combo, noop:GetName(), "LeftButton")
        SetOverrideBinding(o, priority, combo, nil)
    end
    ClearOverrideBindings(o)
    wipe(record)
end

local function bindCommand(o, priority, combo, command)
    commanded[o] = commanded[o] or {}
    commanded[o][combo] = true
    SetOverrideBinding(o, priority, combo, command)
end
local buttons = {}      -- comboId -> secure button (spells, items, macros)

local function secureButton(comboId)
    local b = buttons[comboId]
    if not b then
        local n = 0
        for _ in pairs(buttons) do n = n + 1 end
        b = CK.NewFrame("Button", "ControllerKeyboardMapButton" .. (n + 1), nil, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetAttribute("useOnKeyDown", true)
        -- The extra button on screen shows the press
        local inputId = comboId:match("^(%w+):")
        b:SetScript("PreClick", function(_, _, down)
            if down ~= false then CK.Paddles:NotifyPress(inputId) end
        end)
        b:Hide()
        buttons[comboId] = b
    end
    return b
end

-- A secure button set to cast a spell, use an item or run a macro
local function actionButton(comboId, action)
    local kind, value = action:match("^(%a+):(.+)$")
    local b = secureButton(comboId)
    b:SetAttribute("type", kind)
    b:SetAttribute("spell", kind == "spell" and M.SpellCast(value) or nil)
    b:SetAttribute("item", kind == "item" and ("item:" .. value) or nil)
    b:SetAttribute("macro", kind == "macro" and value or nil)
    return b
end

-- The game's gamepad ping, held then released, opens its wheel and waits
-- for the same key to be pressed again, a full-screen listener shown until
-- then: a key of ours changed meanwhile left it up for good, every A in a
-- menu landing on it as a ping. Ours is the game's other ping binding: hold
-- (the wheel and the stick), release sends; it never waits.
local BOUND_AS = { TOGGLEPINGSYSTEM = "TOGGLEPINGLISTENER" }

-- replace: over a button of the game (priority, our second owner)
local function bindAction(combo, comboId, action, replace)
    local kind, value = action:match("^(%a+):(.+)$")
    if kind == "cmd" then value = BOUND_AS[value] or value end
    local o, record = owner, M.bound
    if replace then o, record = takeOwner, M.taken end
    local click
    if kind == "cmd" then
        bindCommand(o, replace or false, combo, value)
        record[combo] = value
    elseif kind == "bar" then
        local stance = M:StanceMacro(action)
        local native = CK.Paddles:NativeButton(action)
        click = stance and M.KeyRelay(action, stance):GetName() or (native and native:GetName())
    elseif kind == "wheel" then
        -- Its key opens that wheel
        click = CK.ConsumableWheel:Toggle(value):GetName()
    elseif M.Routable(action) then
        local b = actionButton(comboId, action)
        -- Pressed by its key: acts on the press
        b:SetAttribute("useOnKeyDown", true)
        click = b:GetName()
    end
    if click then
        SetOverrideBindingClick(o, replace or false, combo, click, "LeftButton")
        record[combo] = "CLICK " .. click .. ":LeftButton"
    end
end

-- A paddle's key: one secure button for all its layers, bound to the key
-- with every modifier the triggers can add. When it is pressed it reads the
-- triggers held and clicks the button of that layer's action. A trigger
-- counts as held from the gamepad's state, or from the modifier it adds:
-- in the key's name (the binding's click "button" names them: "kmSA" for
-- ALT-SHIFT-) or held (Shift / Ctrl / Alt). Steam Input sends the paddles as
-- keyboard keys, which can come without the triggers' modifiers: any of
-- these is enough. Its click "button" for the action names the layer
-- ("ckRT"...): it picks the "*clickbutton-ckRT" attribute. The gamepad
-- state lists its buttons from 1, the index the game gives from 0. A layer
-- with nothing does nothing.
local ROUTE = [[
    -- The release: to a wheel of the layer pressed (its hold option), as a
    -- "ckup" click on this release
    if not down then
        local pressed = self:GetAttribute("ck-pressed")
        self:SetAttribute("ck-pressed", nil)
        if pressed and self:GetAttribute("ck-up-" .. pressed) then
            self:SetAttribute("useOnKeyDown", false)
            return "ckup" .. pressed
        end
        return false
    end
    self:SetAttribute("useOnKeyDown", true)
    self:SetAttribute("ck-pressed", nil)
    -- The trigger toggle on (Toggle.lua): its layer, held or toggled; a
    -- trigger held was used
    local toggle = self:GetFrameRef("toggle")
    if toggle then
        if toggle:GetAttribute("ck-held-LT") then toggle:SetAttribute("ck-used-LT", true) end
        if toggle:GetAttribute("ck-held-RT") then toggle:SetAttribute("ck-used-RT", true) end
        local on = toggle:GetAttribute("ck-layer") or ""
        if not self:GetAttribute("ck-has-" .. on) then return false end
        self:SetAttribute("ck-pressed", on)
        return "ck" .. on
    end
    local state = GetGamePadState()
    local pad = state and state.buttons
    local came = button or ""
    local shift = strfind(came, "S", 3, true) or IsShiftKeyDown()
    local ctrl = strfind(came, "C", 3, true) or IsControlKeyDown()
    local alt = strfind(came, "A", 3, true) or IsAltKeyDown()
    local lt, rt = self:GetAttribute("ck-lt"), self:GetAttribute("ck-rt")
    local ltMod, rtMod = self:GetAttribute("ck-lt-mod"), self:GetAttribute("ck-rt-mod")
    local ltDown = (pad and lt and pad[lt]) or (ltMod == "SHIFT" and shift)
        or (ltMod == "CTRL" and ctrl) or (ltMod == "ALT" and alt)
    local rtDown = (pad and rt and pad[rt]) or (rtMod == "SHIFT" and shift)
        or (rtMod == "CTRL" and ctrl) or (rtMod == "ALT" and alt)
    local layer = (ltDown and "LT" or "") .. (rtDown and "RT" or "")
    if not self:GetAttribute("ck-has-" .. layer) then return false end
    self:SetAttribute("ck-pressed", layer)
    return "ck" .. layer
]]

local header
local routers = {}      -- paddle -> its secure button

-- A wheel on a layer gets the key's release too (its hold option)
local function setRelease(r, layer, b, action)
    local wheel = b and type(action) == "string" and action:find("^wheel:") and b
    r:SetAttribute("ck-up-" .. layer, wheel and true or nil)
    r:SetAttribute("*clickbutton-ckup" .. layer, wheel or nil)
end
M.routers = routers

local function router(inputId)
    local r = routers[inputId]
    if not r then
        header = header or CK.NewFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
        local n = 0
        for _ in pairs(routers) do n = n + 1 end
        r = CK.NewFrame("Button", "ControllerKeyboardRouteButton" .. (n + 1), nil, "SecureActionButtonTemplate")
        r:RegisterForClicks("AnyDown", "AnyUp")
        r:SetAttribute("useOnKeyDown", true)
        r:SetAttribute("type", "click")
        r:SetScript("PreClick", function(self, _, down)
            if down ~= false and self.ckInput then CK.Paddles:NotifyPress(self.ckInput) end
        end)
        SecureHandlerWrapScript(r, "OnClick", header, ROUTE)
        r:Hide()
        routers[inputId] = r
    end
    return r
end

local function padIndex(button)
    local index = C_GamePad and C_GamePad.ButtonBindingToIndex and C_GamePad.ButtonBindingToIndex(button)
    return index and index + 1
end

M.padIndex = padIndex

-- What we bound on a key: ("click", button name, mouse button) or ("cmd",
-- command); nothing when the key is not ours
function M:BindingOf(combo)
    local b = self.taken[combo] or self.bound[combo]
    if not b then return nil end
    local name, button = b:match("^CLICK ([^:]+):(.+)$")
    if name then return "click", name, button end
    return "cmd", b
end

-- The binding's click "button" for a key's modifiers: "km", "kmS", "kmSA"...
local function modHint(prefix)
    return "km" .. (prefix:find("SHIFT", 1, true) and "S" or "") .. (prefix:find("ALT", 1, true) and "A" or "")
        .. (prefix:find("CTRL", 1, true) and "C" or "")
end

-- A paddle's spells, items, macros and wheels: its router, bound to the key
-- with each modifier the triggers add, but those a game function takes
local function routeKeys(input, key, taken)
    local r = router(input.id)
    r.ckInput = input.id
    r:SetAttribute("ck-lt", padIndex("PADLTRIGGER"))
    r:SetAttribute("ck-rt", padIndex("PADRTRIGGER"))
    r:SetAttribute("ck-lt-mod", M:TriggerModifier("PADLTRIGGER"))
    r:SetAttribute("ck-rt-mod", M:TriggerModifier("PADRTRIGGER"))
    for _, layer in ipairs(M.LAYERS) do
        r:SetAttribute("ck-has-" .. layer, nil)
        r:SetAttribute("*clickbutton-ck" .. layer, nil)
        local action = M:Get(input.id, layer)
        local b
        if M.Routable(action) and not taken[M:ArrivalPrefix(layer)] then
            b = action:find("^wheel:") and CK.ConsumableWheel:Toggle(action:match("^wheel:(.+)$"))
                or actionButton(input.id .. ":" .. layer, action)
            -- Clicked by the key's button, once per press
            b:SetAttribute("useOnKeyDown", false)
            r:SetAttribute("*clickbutton-ck" .. layer, b)
            r:SetAttribute("ck-has-" .. layer, true)
        end
        setRelease(r, layer, b, action)
    end
    for prefix, isTaken in pairs(taken) do
        if not isTaken then
            local hint = modHint(prefix)
            SetOverrideBindingClick(owner, false, prefix .. key, r:GetName(), hint)
            M.bound[prefix .. key] = "CLICK " .. r:GetName() .. ":" .. hint
        end
    end
end

-- Each key a paddle sends. A game function takes the key of its layer (and
-- of the layers sharing it, a trigger that is no modifier adds nothing to
-- the key); the spells, items, macros and wheels of every layer go to the
-- paddle's router, on all the other keys.
function M:ApplyPaddle(input)
    local key = self:InputKey(input)
    if not key then return end
    local taken, routed = {}, false
    for _, layer in ipairs(M.LAYERS) do
        local prefix = self:ArrivalPrefix(layer)
        if taken[prefix] == nil then
            local action = self:Get(input.id, layer)
            taken[prefix] = type(action) == "string" and not M.Routable(action)
            if taken[prefix] then bindAction(prefix .. key, input.id .. ":" .. layer, action) end
        end
    end
    for _, layer in ipairs(M.LAYERS) do
        if M.Routable(self:Get(input.id, layer)) and not taken[self:ArrivalPrefix(layer)] then routed = true end
    end
    if routed then routeKeys(input, key, taken) end
end

---------------------------------------------------------------------------
-- The pad's own buttons with something of ours on them (a free button's
-- spell, a replaced button's wheel...) go to a router too. Players saw a
-- wheel on D-pad down open with RT held as well, and one on LT + D-pad down
-- never open: the key had come without the trigger's modifier, which the
-- game itself doesn't need (its bars read the triggers held). The router
-- reads the triggers held when the key is pressed, whatever the key came
-- with, and runs that layer's: ours, or the game's bar button of that
-- layer. A layer the game runs with a key binding (a command) can't be
-- clicked: such a button keeps its keys bound as before.
---------------------------------------------------------------------------
local relays = {}
M.relayMacros = {}      -- relay's name -> its macro (the toggle reuses it)

-- The game's bar button "/click"ed down, as its own binding presses it (a
-- macro: the stance bar's in a stance, see StanceMacro). Clicked by a
-- router (once per press), or by a key bound to it (on the press).
local function newRelay(id, macro, onKey)
    local key = (onKey and "key:" or "router:") .. id
    local r = relays[key]
    if not r then
        local n = 0
        for _ in pairs(relays) do n = n + 1 end
        r = CK.NewFrame("Button", "ControllerKeyboardBarRelay" .. (n + 1), nil, "SecureActionButtonTemplate")
        if onKey then r:RegisterForClicks("AnyDown") else r:RegisterForClicks("AnyDown", "AnyUp") end
        r:SetAttribute("useOnKeyDown", onKey and true or false)
        r:SetAttribute("type", "macro")
        r:Hide()
        relays[key] = r
    end
    r:SetAttribute("macrotext", macro)
    M.relayMacros[r:GetName()] = macro
    return r
end

local function relay(barAction)
    return newRelay(barAction, M:BarMacro(barAction), false)
end

function M.KeyRelay(barAction, macro)
    return newRelay(barAction, macro, true)
end

-- What each layer of a pad button runs through its router: { action } or
-- { native = the game's button }, nothing for a layer left empty. Nil when
-- the button has nothing of ours, or a layer only a key binding runs.
-- Second value: a replaced button of the game (bound with priority).
function M:PadTargets(input)
    if input.layer or input.paddle or not self:InputKey(input) then return nil end
    local targets, ours, replaced = {}, false, false
    local replaceOn = self:ReplaceOn() and self:OwnKeys()
    for _, layer in ipairs(M.LAYERS) do
        local combo = self:Combo(input, layer)
        if combo then
            local action, isReplaced
            if self:State(input, layer) == "free" then action = self:Get(input.id, layer) end
            if not action and replaceOn and self:Replaceable(input, layer) then
                action = self:GetReplaced(input.id, layer)
                isReplaced = action ~= nil
            end
            local native = action and action:find("^bar:") and CK.Paddles:NativeButton(action)
            if action and M.Routable(action) then
                targets[layer] = { action = action }
            elseif native then
                targets[layer] = { bar = action }
            elseif action then
                return nil
            else
                native = self:NativeBarButton(input, layer)
                if native then
                    targets[layer] = { bar = self:BarAction(input, layer) }
                elseif self:NativeBinding(combo) or (input.id ~= "L3" and input.id ~= "R3"
                    and self:NativeBinding(self:InputKey(input))) then
                    -- The game's command there (or the key without the
                    -- modifier's, it falls back to): a key binding
                    return nil
                end
            end
            if action then ours, replaced = true, replaced or isReplaced end
        end
    end
    if not ours then return nil end
    -- A trigger that is no modifier: its layer shares the key of the one
    -- without it, and what it runs (as before)
    for _, layer in ipairs(M.LAYERS) do
        if not self:Combo(input, layer) then targets[layer] = targets[self:SharedLayers(layer)[1]] end
    end
    return targets, replaced
end

function M:ApplyPad(input, targets, replaced)
    local key = self:InputKey(input)
    local r = router(input.id)
    r.ckInput = input.id
    r:SetAttribute("ck-lt", padIndex("PADLTRIGGER"))
    r:SetAttribute("ck-rt", padIndex("PADRTRIGGER"))
    r:SetAttribute("ck-lt-mod", M:TriggerModifier("PADLTRIGGER"))
    r:SetAttribute("ck-rt-mod", M:TriggerModifier("PADRTRIGGER"))
    for _, layer in ipairs(M.LAYERS) do
        r:SetAttribute("ck-has-" .. layer, nil)
        r:SetAttribute("*clickbutton-ck" .. layer, nil)
        local t, b = targets[layer], nil
        if t and t.action then
            b = t.action:find("^wheel:") and CK.ConsumableWheel:Toggle(t.action:match("^wheel:(.+)$"))
                or actionButton(input.id .. ":" .. layer, t.action)
            -- Clicked by the key's button, once per press
            b:SetAttribute("useOnKeyDown", false)
        elseif t and t.bar then
            b = relay(t.bar)
        end
        if b then
            r:SetAttribute("*clickbutton-ck" .. layer, b)
            r:SetAttribute("ck-has-" .. layer, true)
        end
        setRelease(r, layer, b, t and t.action)
    end
    local o, record = owner, self.bound
    if replaced then o, record = takeOwner, self.taken end
    local done = {}
    for _, layer in ipairs(M.LAYERS) do
        local combo = self:Combo(input, layer)
        if combo and not done[combo] then
            done[combo] = true
            local hint = modHint(combo:sub(1, #combo - #key))
            SetOverrideBindingClick(o, replaced and true or false, combo, r:GetName(), hint)
            record[combo] = "CLICK " .. r:GetName() .. ":" .. hint
        end
    end
end

-- Ours were replaced (a gamepad window of the game rebinds the pad when it
-- closes): set them again. Only then, so the game's own refreshes don't
-- make us rebind for nothing.
function M:Repair()
    if self.pending then return self:Apply() end
    for combo, want in pairs(self.bound) do
        if GetBindingAction(combo, true) ~= want and not (CK.Toggle and CK.Toggle:Holds(combo)) then
            return self:Apply()
        end
    end
    -- The game's buttons replaced: its binding sets (menus, its own while a
    -- trigger is held) go over ours for a while; checked once none is left
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    local stack = manager and manager.bindingSetStack
    if stack and #stack > 0 then return end
    for combo, want in pairs(self.taken) do
        if GetBindingAction(combo, true) ~= want and not (CK.Toggle and CK.Toggle:Holds(combo)) then
            return self:Apply()
        end
    end
end

-- No gamepad window has the focus (the game's own HUD bindings are active)
function M:CoreActive()
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if manager and manager.GetActiveFrame and manager:GetActiveFrame() then return false end
    -- The chat keyboard or a wheel open: their keys stay theirs
    if CK.IsOpen and CK:IsOpen() then return false end
    if ControllerKeyboardWheel and ControllerKeyboardWheel:IsShown() then return false end
    return not (CK.Config and CK.Config:IsOpen())
end

function M:Apply()
    if InCombatLockdown() or not self:CoreActive() then
        self.pending = true
        -- A menu of the game, or our panel: its buttons back to it
        self:Release()
        if CK.Toggle then CK.Toggle:Apply() end
        return
    end
    self.pending = false
    self.applying = true
    owner = owner or CK.NewFrame("Frame")
    takeOwner = takeOwner or CK.NewFrame("Frame")
    unbindAll(owner, self.bound, false)
    unbindAll(takeOwner, self.taken, true)
    self.padRouted = {}
    if self:Enabled() then
        -- The pad's buttons with something of ours: their routers
        for _, input in ipairs(M.INPUTS) do
            local targets, replaced = self:PadTargets(input)
            if targets then
                self.padRouted[input.id] = true
                self:ApplyPad(input, targets, replaced)
            end
        end
        for comboId, action in pairs(settings().mapping) do
            local inputId, layer = comboId:match("^(%w+):(%a*)$")
            local input = inputId and M.BY_ID[inputId]
            -- Never on an input the game uses
            if input and not input.paddle and not self.padRouted[inputId] and type(action) == "string"
                and self:State(input, layer) == "free" then
                bindAction(self:Combo(input, layer), comboId, action)
            end
        end
        for _, input in ipairs(M.INPUTS) do
            if input.paddle and self:InputEnabled(input) then self:ApplyPaddle(input) end
        end
        self:ApplyReplaced()
        self:BlockFallbacks()
    end
    -- The trigger toggle's keys over ours (it reads what we bound)
    if CK.Toggle then CK.Toggle:Apply() end
    -- The panel's shortcut held: its second button left to the game
    if self.suspended then self:Suspend(self.suspended) end
    self:UpdateMarks()
    self.applying = false
end

-- A key with a trigger modifier and no binding of its own falls back to the
-- key without it: our action on L3 alone ran on LT + L3 too, a wheel opened
-- in every layer. The layers of our keys left free get a binding that does
-- nothing (the game's own bindings, of its gamepad UI too, stay).
local NOOP = "CONTROLLERKEYBOARD_NOOP"
function M:BlockFallbacks()
    for _, input in ipairs(M.INPUTS) do
        local key = not input.layer and self:InputKey(input)
        if key and (self.bound[key] or self.taken[key]) and self.bound[key] ~= NOOP then
            for _, layer in ipairs(M.LAYERS) do
                local prefix = input.paddle and self:ArrivalPrefix(layer) or self:LayerPrefix(layer)
                local combo = prefix and prefix ~= "" and prefix .. key
                if combo and not (self.bound[combo] or self.taken[combo]) and not self:NativeBinding(combo) then
                    SetOverrideBinding(owner, false, combo, NOOP)
                    self.bound[combo] = NOOP
                end
            end
        end
    end
end

-- The panel's shortcut (RB + D-pad down): while its first button is held,
-- out of combat, what we put on the second one is taken off, so the press
-- only opens the panel (a wheel on D-pad down opened with it). Back on
-- release.
function M:Suspend(key)
    if InCombatLockdown() or not (owner and key) then return end
    self.suspended = key
    if self.bound[key] then
        SetOverrideBinding(owner, false, key, nil)
        self.bound[key] = nil
    end
    if self.taken[key] then
        SetOverrideBinding(takeOwner, true, key, nil)
        self.taken[key] = nil
    end
    if CK.Toggle then CK.Toggle:Unbind(key) end
end

function M:Resume()
    if not self.suspended then return end
    self.suspended = nil
    self:Apply()
end

function M:IsOurs(key)
    return key and (self.bound[key] or self.taken[key]) and self.bound[key] ~= NOOP and true or false
end

-- The game's buttons the player replaced, and the other layers of each
function M:ApplyReplaced()
    if not (self:ReplaceOn() and self:OwnKeys()) then return end
    for _, input in ipairs(M.INPUTS) do
        local replaced = {}
        for _, layer in ipairs(M.padRouted[input.id] and {} or M.LAYERS) do
            local action = self:Replaceable(input, layer) and self:GetReplaced(input.id, layer)
            if action then replaced[layer] = action end
        end
        if next(replaced) then
            for _, layer in ipairs(M.LAYERS) do
                local combo = self:Combo(input, layer)
                if combo and replaced[layer] then
                    bindAction(combo, input.id .. ":" .. layer, replaced[layer], true)
                elseif combo and not self.bound[combo] then
                    self:KeepNative(input, layer, combo)
                end
            end
        end
    end
end

-- What the game does on the key of a layer left to it: its bar button, else
-- its binding (the key's own, or the one without modifiers it fell back to)
function M:KeepNative(input, layer, combo)
    local native = self:NativeBarButton(input, layer)
    local stance = native and self:StanceMacro(self:BarAction(input, layer))
    local name = stance and M.KeyRelay(self:BarAction(input, layer), stance):GetName() or (native and native:GetName())
    if name then
        SetOverrideBindingClick(takeOwner, true, combo, name, "LeftButton")
        self.taken[combo] = "CLICK " .. name .. ":LeftButton"
        return
    end
    -- The sticks: while a trigger is held the game binds them itself
    if input.id == "L3" or input.id == "R3" then return end
    local command = self:NativeBinding(combo) or self:NativeBinding(self:InputKey(input))
    if command then
        bindCommand(takeOwner, true, combo, command)
        self.taken[combo] = command
    end
end

-- Our replacements taken away, out of combat: a menu of the game (or our
-- panel) has the focus. Set again when it closes.
function M:Release()
    if InCombatLockdown() or not (takeOwner and next(self.taken)) then return end
    local keys = {}
    for combo in pairs(self.taken) do keys[#keys + 1] = combo end
    self.applying = true
    unbindAll(takeOwner, self.taken, true)
    self.applying = false
    self.pending = true
    -- For /ec binds: what each key runs once ours are away
    local after = {}
    table.sort(keys)
    for _, combo in ipairs(keys) do after[#after + 1] = combo .. " = " .. tostring(GetBindingAction(combo, true)) end
    self.lastRelease = date("%H:%M:%S") .. "  " .. table.concat(after, ", ")
end

-- Our function's picture over the game's bar button it replaces (what the
-- slot holds stays under it)
local marks = {}        -- the game's button -> our picture
function M:UpdateMarks()
    local wanted = {}
    if self:ReplaceOn() and self:OwnKeys() then
        for comboId, action in pairs(settings().replaced) do
            local inputId, layer = comboId:match("^(%w+):(%a*)$")
            local input = inputId and M.BY_ID[inputId]
            local native = input and self:Replaceable(input, layer) and self:NativeBarButton(input, layer)
            if native then wanted[native] = action end
        end
    end
    for native, mark in pairs(marks) do
        if not wanted[native] then mark:Hide() end
    end
    for native, action in pairs(wanted) do
        local mark = marks[native]
        if not mark then
            -- An opaque round hides the game's picture, inside its ring
            mark = CK.NewFrame("Frame", nil, native)
            mark:SetAllPoints(native.icon or native)
            mark.bg = mark:CreateTexture(nil, "ARTWORK")
            mark.bg:SetPoint("TOPLEFT", 3, -3)
            mark.bg:SetPoint("BOTTOMRIGHT", -3, 3)
            mark.bg:SetColorTexture(0.04, 0.04, 0.04, 1)
            mark.icon = mark:CreateTexture(nil, "OVERLAY")
            -- The round the picture shows through
            local round = { mark.bg, CK.NewFrame("Frame", nil, mark) }
            round[2]:SetPoint("TOPLEFT", 6, -6)
            round[2]:SetPoint("BOTTOMRIGHT", -6, 6)
            for i, tex in ipairs({ mark.bg, mark.icon }) do
                local mask = mark:CreateMaskTexture()
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(round[i])
                tex:AddMaskTexture(mask)
            end
            marks[native] = mark
        end
        mark:SetFrameLevel(native:GetFrameLevel() + 3)
        local icon = self:ActionIcon(action)
        -- The game's own pictures (jump, ping...) come with their ring:
        -- larger than the round, it stays outside
        local zoom = type(icon) == "table" and icon.atlas and -2 or 6
        mark.icon:ClearAllPoints()
        mark.icon:SetPoint("TOPLEFT", zoom, -zoom)
        mark.icon:SetPoint("BOTTOMRIGHT", -zoom, zoom)
        CK.Paddles.SetIcon(mark.icon, icon)
        mark:Show()
    end
end

-- /ec binds: the game's buttons replaced, and what each key runs now
function M:Diagnose()
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    local stack = manager and manager.bindingSetStack
    CK:Print(format(L.REPLACE_DIAG, tostring(self:ReplaceOn()), tostring(self:OwnKeys()),
        tostring(InCombatLockdown()), tostring(self:CoreActive()))
        .. format(" | pending %s, game sets %s", tostring(self.pending), stack and #stack or "?"))
    -- What is saved, and whether it can be bound
    for comboId, action in pairs(settings().replaced) do
        local inputId, layer = comboId:match("^(%w+):(%a*)$")
        local input = inputId and M.BY_ID[inputId]
        DEFAULT_CHAT_FRAME:AddMessage(format("  %s = %s: %s, replaceable %s, key %s", comboId, action,
            input and self:State(input, layer) or "?", tostring(input and self:Replaceable(input, layer)),
            tostring(input and self:Combo(input, layer))))
    end
    if self.lastRelease then
        DEFAULT_CHAT_FRAME:AddMessage("  released " .. self.lastRelease)
    end
    -- Each key bound: ours, what runs now, the game's own (its gamepad context)
    local keys = {}
    for combo in pairs(self.taken) do keys[#keys + 1] = combo end
    table.sort(keys)
    for _, combo in ipairs(keys) do
        local now = GetBindingAction(combo, true)
        local game
        if C_KeyBindings and C_KeyBindings.GetBindingByKey and Enum and Enum.BindingContext then
            local ok, value = pcall(C_KeyBindings.GetBindingByKey, combo, Enum.BindingContext.GamepadModeInGameCore)
            game = ok and value or nil
        end
        local color = now == self.taken[combo] and "|cff6fd36f" or "|cffff6060"
        DEFAULT_CHAT_FRAME:AddMessage(format("  %s%s|r: %s | now %s | game %s", color, combo,
            tostring(self.taken[combo]), tostring(now), tostring(game)))
    end
end

-- Labels of keys and pad buttons ("LB", "Start", "L4"...)
local PAD_GLYPHS = {
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
    PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADLSTICK = "LS", PADRSTICK = "RS",
    PADDUP = "DPAD_UP", PADDDOWN = "DPAD_DOWN", PADDLEFT = "DPAD_LEFT", PADDRIGHT = "DPAD_RIGHT",
}
local PAD_NAMES = { PADFORWARD = "START", PADBACK = "SELECT" }

local function keyLabel(key)
    if PAD_GLYPHS[key] then return CK:GlyphMarkup(PAD_GLYPHS[key], 16) end
    if PAD_NAMES[key] then return CK.ConfigKit.ChipText(PAD_NAMES[key]) end
    local paddle = key:match("^PADPADDLE(%d)$")
    if paddle then
        for id, k in pairs(M.PADDLE_KEYS) do
            if k == key then return id end
        end
    end
    for _, id in ipairs(CK.Paddles.ALL) do
        if settings().paddles[id] and settings().paddles[id].key == key then return id end
    end
    return GetBindingText and GetBindingText(key) or key
end

-- "RB + D-pad down": the panel's shortcut, a button held then another
function M:ChordLabel(chord)
    if not chord then return "-" end
    return keyLabel(chord.hold) .. " + " .. keyLabel(chord.press)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function M:Init()
    -- Paddle actions set before 0.5.0 lived with the paddles
    for id, cfg in pairs(settings().paddles) do
        if cfg.action then
            settings().mapping[id .. ":"] = settings().mapping[id .. ":"] or cfg.action
            cfg.action, cfg.cat = nil, nil
        end
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("CVAR_UPDATE")
    -- A gamepad connected: the triggers' indexes the routers read
    pcall(events.RegisterEvent, events, "GAME_PAD_CONNECTED")
    pcall(events.RegisterEvent, events, "GAME_PAD_ACTIVE_CHANGED")
    -- A stance or form learned (the stance bar's presses), a stance taken
    -- (the Gamepad tab shows the stance bar's slots)
    pcall(events.RegisterEvent, events, "UPDATE_SHAPESHIFT_FORMS")
    pcall(events.RegisterEvent, events, "UPDATE_BONUS_ACTIONBAR")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "UPDATE_BONUS_ACTIONBAR" then
            if CK.Config and CK.Config:IsOpen() and not InCombatLockdown() then CK.Config:Render() end
            return
        end
        if event == "UPDATE_SHAPESHIFT_FORMS" then
            local has = CK.Paddles:HasStances()
            if has == M.hadStances then return end
            M.hadStances = has
        end
        if event == "CVAR_UPDATE" and not (name and (tostring(name):find("GamePadEmulate")
            or tostring(name) == "GamepadStanceBarOverride")) then return end
        if event == "GAME_PAD_CONNECTED" or event == "GAME_PAD_ACTIVE_CHANGED" then
            local lt, rt = padIndex("PADLTRIGGER"), padIndex("PADRTRIGGER")
            if lt == M.ltIndex and rt == M.rtIndex then return end
            M.ltIndex, M.rtIndex = lt, rt
        end
        -- Let the game set its own bindings first
        C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 1 or 0, function()
            if event == "PLAYER_REGEN_ENABLED" then M:Repair() else M:Apply() end
        end)
    end)
    -- The game sets its own pad bindings at many moments (its windows, its
    -- targeting...), and an override binding replaces any other on its key:
    -- after a change that isn't ours, check ours a moment later. Never more
    -- than a few times in a row, should the game answer each of ours.
    local recent = {}
    local changed
    function changed()
        if M.applying or M.repairQueued or InCombatLockdown() then return end
        local now = GetTime()
        while recent[1] and recent[1] < now - 3 do table.remove(recent, 1) end
        if #recent >= 6 then
            if not M.repairLater then
                M.repairLater = true
                C_Timer.After(3, function()
                    M.repairLater = false
                    changed()
                end)
            end
            return
        end
        M.repairQueued = true
        C_Timer.After(0.15, function()
            M.repairQueued = false
            if not InCombatLockdown() and M:CoreActive() then
                recent[#recent + 1] = GetTime()
                M:Repair()
            end
        end)
    end
    for _, name in ipairs({ "SetOverrideBinding", "SetOverrideBindingClick", "SetOverrideBindingSpell",
        "SetOverrideBindingItem", "SetOverrideBindingMacro", "ClearOverrideBindings" }) do
        if _G[name] then hooksecurefunc(name, changed) end
    end
    -- The game's gamepad windows rebind the pad when they close
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("Gamepad.RefreshFrameFocus", function()
            C_Timer.After(0, function()
                if InCombatLockdown() then return end
                if M:CoreActive() then M:Repair() else M:Release() end
            end)
        end, M)
    end
end
