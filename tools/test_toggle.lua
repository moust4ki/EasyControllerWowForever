-- Run from the addon directory: lua tools/test_toggle.lua (Lua 5.1).
-- Exercise the real icon lookup and draw code at the WoW texture API boundary.
local CK = { L = {}, db = { settings = {
    modules = { mapping = true }, features = { triggerToggle = true }, replaced = {},
} } }
local atlasAvailable = true
local env = setmetatable({
    C_Texture = { GetAtlasInfo = function(name)
        return atlasAvailable and name ~= "missing" and {} or nil
    end },
    C_Spell = { GetSpellTexture = function() return 12345 end },
    GetCVarBool = function() return true end,
    GamepadMainActionBarFrame = { PageUnit = { actionBars = { leftBar = {} } } },
}, { __index = _G })
env._G = env
local function loadAddon(path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk("EasyController", CK)
end
loadAddon("Mapping.lua")
loadAddon("Paddles.lua")
loadAddon("Toggle.lua")

local function texture()
    return {
        SetTexture = function(self, value)
            assert(value == nil or type(value) == "string" or type(value) == "number",
                "Texture:SetTexture expects a texture path or file ID, not an icon descriptor")
            self.texture, self.atlas = value, nil
        end,
        SetAtlas = function(self, value)
            self.atlas, self.coords = value, { 0.2, 0.4, 0.6, 0.8 }
            self.atlasWrites = (self.atlasWrites or 0) + 1
        end,
        SetTexCoord = function(self, ...) self.coords = { ... } end,
        ClearAllPoints = function(self) self.anchorClears = (self.anchorClears or 0) + 1 end,
        SetAllPoints = function(self, target) self.anchorSets = (self.anchorSets or 0) + 1; self.target = target end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetShown = function(self, shown) self.shown = shown end,
    }
end
function CK:SetGlyph(tex, glyph) tex:SetAtlas("glyph-" .. glyph) end
local nativeCoords = { 0.08, 0.08, 0.08, 0.92, 0.92, 0.08, 0.92, 0.92 }
local normalAtlas = "slot-ring"
local normal = { GetAtlas = function() return normalAtlas end }
local native = {
    GetNormalTexture = function() return normal end,
    IsVisible = function() return true end,
    icon = { GetTexCoord = function() return unpack(nativeCoords) end },
}
function CK.Paddles:NativeButton() return native end
local slot = {
    icon = texture(), frame = texture(),
    count = { SetText = function(self, text) self.text = text end },
    cooldown = { Clear = function() end },
    ClearAllPoints = function(self) self.anchorClears = (self.anchorClears or 0) + 1 end,
    SetAllPoints = function(self, target) self.anchorSets = (self.anchorSets or 0) + 1; self.target = target end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
}
CK.Toggle.header = { GetAttribute = function(_, key) return key == "ck-layer" and "LT" or nil end }
CK.Toggle.view = { slots = { a = slot } }
local function draw(action)
    CK.db.settings.replaced["A:LT"] = action
    CK.Toggle:Draw()
end
local function sameCoords(actual, expected)
    assert(#actual == #expected, "texture coordinates changed length")
    for i, value in ipairs(expected) do
        assert(actual[i] == value, "incorrect texture coordinate " .. i)
    end
end

-- Atlas commands are valid entries in the mapping catalog.
draw("cmd:TOGGLEAUTORUN")
assert(slot.icon.atlas == "Ping_Marker_Icon_OnMyWay" and slot.icon.shown)
sameCoords(slot.icon.coords, { 0.2, 0.4, 0.6, 0.8 })
-- A missing atlas must retain the existing glyph fallback.
atlasAvailable = false
draw("cmd:TOGGLEAUTORUN")
assert(slot.icon.atlas == "glyph-LS" and slot.icon.shown)
sameCoords(slot.icon.coords, { 0.2, 0.4, 0.6, 0.8 })
atlasAvailable = true
-- The fixed gamepad functions also return descriptors, including textures.
draw("bar:top:x")
assert(slot.icon.texture == "Interface\\Cursor\\Interact" and slot.icon.shown)
sameCoords(slot.icon.coords, { 0, 1, 0, 1 })
-- Ordinary spell icons still use the game's eight-coordinate crop.
draw("spell:133")
assert(slot.icon.texture == 12345 and slot.icon.shown)
sameCoords(slot.icon.coords, nativeCoords)
-- The normal crop remains available if the game cannot supply its own.
native.icon.GetTexCoord = nil
draw("spell:133")
sameCoords(slot.icon.coords, { 0.08, 0.92, 0.08, 0.92 })
-- An unavailable icon must not redisplay a stale texture.
local actionIcon = CK.Mapping.ActionIcon
CK.Mapping.ActionIcon = function() return { atlas = "missing" } end
draw("spell:133")
assert(not slot.icon.shown, "unsupported descriptors should stay hidden")
CK.Mapping.ActionIcon = function() return nil end
draw("spell:133")
assert(not slot.icon.shown, "missing icons should stay hidden")
CK.Mapping.ActionIcon = actionIcon
print("PASS: toggle icons (atlas, glyph, texture, spell crop, missing icon)")
-- Unchanged native regions already carry their overlays when they move.
draw("spell:133")
local overlayClears, overlaySets = slot.anchorClears, slot.anchorSets
local ringClears, ringSets, ringWrites = slot.frame.anchorClears, slot.frame.anchorSets, slot.frame.atlasWrites
for i = 1, 20 do draw("spell:133") end
assert(slot.anchorClears == overlayClears and slot.anchorSets == overlaySets,
    "unchanged overlay was reanchored on every redraw")
assert(slot.frame.anchorClears == ringClears and slot.frame.anchorSets == ringSets
    and slot.frame.atlasWrites == ringWrites, "unchanged ring geometry/atlas was reapplied")
local mask = { IsShown = function() return true end }
native.CircleMask = mask
draw("spell:133")
assert(slot.target == mask and slot.anchorSets == overlaySets + 1, "a different native mask must reanchor")
normal = { GetAtlas = function() return normalAtlas end }
draw("spell:133")
assert(slot.frame.target == normal and slot.frame.anchorSets == ringSets + 1, "a replaced normal region must reanchor")
normalAtlas = "new-slot-ring"
draw("spell:133")
assert(slot.frame.atlas == normalAtlas and slot.frame.atlasWrites == ringWrites + 1,
    "a changed atlas on the same native region must redraw")
normalAtlas = nil
draw("spell:133")
assert(not slot.frame.shown, "a missing ring atlas must hide")
normalAtlas = "new-slot-ring"
draw("spell:133")
assert(slot.frame.shown, "a restored ring atlas must show")
print("PASS: toggle anchors (unchanged, replaced mask/region, changing ring atlas)")

-- Exercise the actual toggle bindings and secure snippets, with WoW's frame
-- boundary stubbed. The installed Wrapped_Click preserves button/down; a
-- native gamepad action with useOnKeyDown=true acts only on the down edge.
-- This verifies the forwarding path, not the client's taint/security engine.
local frames, actions = {}, {}
local combat = false
local function runSnippet(control, signature, code, ...)
    -- Installed SecureHandlers supplies self/button/down as parameters.
    -- RestrictedExecution exposes control; RestrictedInfrastructure also
    -- initializes the header's managed environment with owner = header.
    -- Both names are native; ordinary addon globals are not available here.
    local chunk = assert(loadstring("return function(" .. signature .. ")\n" .. code .. "\nend"))
    setfenv(chunk, { control = control, owner = control })
    return chunk()(...)
end
local function frame(name, kind)
    local f = { name = name, attributes = {}, wrappers = {}, bindings = {}, overrides = {}, clicksSeen = {} }
    function f:GetName() return self.name end
    function f:IsObjectType(objectType) return objectType == (kind or "Button") end
    function f:SetAttribute(key, value) self.attributes[key] = value end
    function f:GetAttribute(key) return self.attributes[key] end
    function f:RegisterForClicks(...) self.clicks = { ... } end
    function f:Hide() self.shown = false end
    function f:SetShown(shown) self.shown = shown end
    function f:RunAttribute(key, ...) return runSnippet(self, "self,...", self.attributes[key], self, ...) end
    function f:SetBindingClick(_, key, target, button) self.bindings[key] = { target, button or "LeftButton" } end
    function f:SetBinding(_, key, command) self.bindings[key] = { command = command } end
    function f:ClearBinding(key) self.bindings[key] = nil end
    function f:Click(button, down)
        local phase = down and "AnyDown" or "AnyUp"
        local accepts = false
        for _, registered in ipairs(self.clicks or {}) do if registered == phase then accepts = true end end
        if not accepts then return end
        for _, wrapper in ipairs(self.wrappers) do
            local newButton = runSnippet(wrapper.header, "self,button,down", wrapper.code, self, button, down)
            if newButton == false then return end
            if newButton then button = newButton end
        end
        self.clicksSeen[#self.clicksSeen + 1] = { button = button, down = down }
        local useDown = self:GetAttribute("useOnKeyDown")
        if (down and useDown) or (not down and not useDown) then
            local kind = self:GetAttribute("type")
            if kind then
                assert(not self:GetAttribute("macrotext"), "target must not be reached through a relay macro")
                actions[#actions + 1] = { target = self, button = button, down = down, kind = kind }
            end
        end
    end
    frames[#frames + 1] = f
    if name then env[name] = f end
    return f
end
CK.NewFrame = function(kind, name) return frame(name, kind) end
env.InCombatLockdown = function() return combat end
env.SecureHandlerWrapScript = function(target, script, header, code)
    assert(script == "OnClick")
    target.wrappers[#target.wrappers + 1] = { header = header, code = code }
end
env.SecureHandlerExecute = function(target, code) return runSnippet(target, "self", code, target) end
env.SecureHandlerSetFrameRef = function() end
env.SetOverrideBindingClick = function(owner, _, key, target, button) owner.overrides[key] = { target, button } end
env.ClearOverrideBindings = function(owner) owner.bindings, owner.overrides = {}, {} end
env.GetCVar = function(name)
    return ({ GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateAlt = "PADRTRIGGER" })[name] or "none"
end
local bars = {}
for _, bar in ipairs({ "top", "left", "right", "bottom" }) do
    local groups = {}
    bars[bar .. "Bar"] = groups
    for _, group in ipairs({ "Left", "Right" }) do
        groups[group] = {}
        for i = 1, 4 do
            local b = frame("Native_" .. bar .. "_" .. group .. i)
            b:RegisterForClicks("AnyDown", "AnyUp")
            b:SetAttribute("useOnKeyDown", true)
            b:SetAttribute("type", "action")
            b:SetAttribute("action", 70 + i) -- the native slot may hold a macro
            groups[group]["ActionButton" .. i] = b
        end
    end
end
env.GamepadMainActionBarFrame = { PageUnit = { actionBars = bars } }
loadAddon("Paddles.lua") -- restore the real NativeButton lookup after the draw fixture
loadAddon("Toggle.lua")
local T, M = CK.Toggle, CK.Mapping
M.CoreActive = function() return true end
M.bound, M.taken = {}, {}
CK.db.settings.replaced = {}
T.BuildView = function(self) self.view = frame() end
local function trigger(which, down) T.triggers[which]:Click("LeftButton", down) end
local function key(which, down)
    local binding = assert(T.header.bindings[which], "missing secure binding: " .. which)
    assert(not binding.command)
    assert(env[binding[1]], "missing click target"):Click(binding[2], down)
end

T:Apply()
assert(next(T.header.bindings) == nil, "no bar keys should be overridden before a trigger is held/toggled")
trigger("LT", true)
local target = bars.leftBar.Right.ActionButton4
assert(T.header.bindings.PAD1[1] == target:GetName(),
    "native target must receive the hardware click directly, without a relay macro")
assert(T.header.bindings.PAD1[2] == "LeftButton")
key("PAD1", true)
key("PAD1", false)
assert(#actions == 1 and actions[1].target == target and actions[1].down == true,
    "native action must run once on down, never again on release")
assert(#target.clicksSeen == 2 and target.clicksSeen[1].down == true and target.clicksSeen[2].down == false,
    "native press-and-hold/release bookkeeping must retain both hardware edges")
assert(T.header:GetAttribute("ck-used-LT"), "the native down edge must mark the held trigger used")
trigger("LT", false)
assert(T:Layer() == "" and not T.header:GetAttribute("ck-on-LT"), "used trigger must not latch on release")
assert(target:GetAttribute("useOnKeyDown") == true and target:GetAttribute("action") == 74,
    "forwarding must not modify the native action or its click phase")
print("PASS: toggle native forwarding (direct target, hardware down, one action, held-trigger release)")

local mapped = frame("MappedMacroButton")
mapped:RegisterForClicks("AnyDown", "AnyUp")
mapped:SetAttribute("useOnKeyDown", true)
mapped:SetAttribute("type", "macro")
mapped:SetAttribute("macro", "FixtureMacro")
-- Preserve Mapping:BindingOf's exact custom mouse-button argument.
M.bound["ALT-SHIFT-PAD1"] = "CLICK MappedMacroButton:kmSA"
T:Apply()
T:Apply()
assert(#target.wrappers == 1 and #mapped.wrappers == 1, "refresh must not stack target wrappers")
trigger("LT", true)
trigger("RT", true)
assert(T.header.bindings.PAD1[1] == mapped:GetName() and T.header.bindings.PAD1[2] == "kmSA")
key("PAD1", true)
key("PAD1", false)
assert(#actions == 2 and actions[2].target == mapped and actions[2].button == "kmSA"
    and mapped:GetAttribute("macro") == "FixtureMacro", "mapped macro must be invoked directly with its exact button")
assert(T.header:GetAttribute("ck-used-LT") and T.header:GetAttribute("ck-used-RT"))
trigger("RT", false)
trigger("LT", false)
assert(T:Layer() == "", "using both held triggers must not latch either one")
print("PASS: toggle mapped forwarding (macro target, exact button, two triggers, wrapper reuse)")

trigger("LT", true)
trigger("LT", false)
assert(T:Layer() == "LT", "a trigger pressed alone must still latch its bar")
key("PAD1", true)
key("PAD1", false)
assert(#actions == 3 and not T.header:GetAttribute("ck-used-LT"), "latched action must not invent a held trigger")
trigger("LT", true)
trigger("LT", false)
assert(T:Layer() == "", "pressing the latched trigger alone must release its bar")
CK.db.settings.features.triggerToggle = false
T:Apply()
assert(next(T.header.bindings) == nil and next(T.header.overrides) == nil, "disabled toggle must release its bindings")
target:Click("LeftButton", true)
assert(#actions == 4 and not T.header:GetAttribute("ck-used-LT"), "disabled bookkeeping must leave native clicks alone")
combat = true
T:Apply()
assert(T.pending, "combat apply must be deferred")
print("PASS: toggle lifecycle (tap latch, unlatch, disabled native action, deferred combat apply)")

combat = false
CK.db.settings.features.triggerToggle = true
M.bound["SHIFT-PAD1"] = "CLICK LateToggleTarget:RightButton"
M.bound["SHIFT-PADLSHOULDER"] = "TOGGLEAUTORUN"
T:Apply() -- named target has not loaded yet
env.LateToggleTarget = 42
T:Apply() -- a non-frame global must not be treated as a button
local notButton = frame("LateToggleTarget", "Frame")
T:Apply()
assert(#notButton.wrappers == 0 and not T.watched[notButton], "non-button target must remain retryable")
local late = frame("LateToggleTarget")
late:RegisterForClicks("AnyDown", "AnyUp")
late:SetAttribute("type", "action")
late:SetAttribute("useOnKeyDown", true)
T:Apply()
T:Apply()
assert(#late.wrappers == 1, "late-created target must be wrapped exactly once when it becomes available")
trigger("LT", true)
assert(T.header.bindings.PADLSHOULDER.command == "TOGGLEAUTORUN", "ordinary command bindings must remain commands")
key("PAD1", true)
key("PAD1", false)
assert(#actions == 5 and actions[5].target == late and actions[5].button == "RightButton",
    "late-created target must receive its original click button and activate once")
for _, f in ipairs(frames) do
    assert(not (f.name and f.name:find("^ControllerKeyboardToggleRelay")), "unused relay buttons must not be created")
end
print("PASS: toggle target lifecycle (missing/non-button, late creation, exact right click, unchanged command)")
