-- Run from the addon directory: lua tools/test_skin.lua (Lua 5.1).
-- Exercise the real texture selectors and activation paths, with WoW frame
-- methods replaced at the API boundary.
local function noop() end
local methods = {}
local function region()
    return setmetatable({ shown = true, scripts = {}, children = {} }, { __index = methods })
end
function methods:CreateTexture(_, layer, _, sub) local r = region(); r.layer, r.sub = layer, sub or 0; self.children[#self.children + 1] = r; return r end
methods.CreateFontString = methods.CreateTexture
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:HookScript(name, fn)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end; fn(...) end
end
function methods:Fire(name, ...) if self.scripts[name] then self.scripts[name](self, ...) end end
function methods:SetTexture(path) self.texture = path; self.textureWrites = (self.textureWrites or 0) + 1 end
function methods:SetTexCoord(...) self.coords = { ... } end
function methods:SetTextColor(...) self.color = { ... } end
function methods:SetShadowColor(...) self.shadow = { ... } end
function methods:SetVertexColor(...) self.vertex = { ... } end
function methods:SetAlpha(a) self.alpha = a end
function methods:SetText(text) self.text = text end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width or 100 end
function methods:GetHeight() return self.height or 32 end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetVerticalScroll(value) self.verticalScroll = value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:GetStringHeight() return 18 end

function methods:IsEnabled() return self.enabled ~= false end
function methods:IsShown() return self.shown end
function methods:SetShown(shown)
    local old = self.shown; self.shown = not not shown
    if old and not self.shown then self:Fire("OnHide") end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
for _, name in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetFont", "SetJustifyH", "SetJustifyV",
    "SetWordWrap", "SetSpacing", "SetShadowOffset", "SetColorTexture", "SetDrawLayer", "SetHorizTile", "SetVertTile",
    "RegisterEvent", "RegisterForClicks", "SetParent", "SetFrameLevel", "SetFrameStrata", "EnableMouse",
    "EnableMouseWheel", "SetNonSpaceWrap", "SetMaxLines" }) do methods[name] = noop end
local timers = {}
local CK = { L = {}, db = { settings = {} }, NewFrame = function() return region() end,
    GetFontPath = function() return "Fonts\\FRIZQT__.TTF" end }
local env = setmetatable({ format = string.format, CreateFrame = CK.NewFrame,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end } }, { __index = _G })
env._G = env
local function loadAddon(path) local f = assert(loadfile(path)); setfenv(f, env); f("EasyController", CK) end
local function expire() local pending = timers; timers = {}; for _, f in ipairs(pending) do f() end end
local function art(button, name)
    for _, part in ipairs(button.slice.parts) do
        assert(part.texture:match("([^\\]+)$") == name, "expected " .. name .. ", got " .. part.texture)
    end
end
loadAddon("UI.lua")
loadAddon("ConfigKit.lua")
local K = CK.ConfigKit
local b = K.Button(region())
assert(type(b.Pulse) == "function", "configuration buttons need an explicit activation pulse")
art(b, "ck_btn_normal")
b:Fire("OnEnter"); art(b, "ck_btn_hover")
b:SetState({ focus = true }); art(b, "ck_btn_active")
b:Fire("OnMouseDown", "LeftButton"); art(b, "ck_btn_pressed")
b:Fire("OnMouseUp", "LeftButton"); art(b, "ck_btn_active")
b:Pulse(); art(b, "ck_btn_pressed")
b:Pulse(); local first = table.remove(timers, 1); first(); art(b, "ck_btn_pressed")
expire(); art(b, "ck_btn_active")
b:SetState({ active = true }); b:Fire("OnLeave"); art(b, "ck_btn_active")
b:Pulse(); b:SetState({ disabled = true, focus = true }); b:Pulse(); b:Fire("OnMouseDown", "LeftButton")
art(b, "ck_btn_normal"); assert(b.alpha == 0.45)
b:SetState({}); art(b, "ck_btn_normal"); expire()
b:SetState({ armed = true }); b:Pulse(); assert(b.armedBox.hidden == false and not b.slice.parts[1].shown)
expire(); b:SetState({}); b:Pulse(); b:Hide(); b:Show(); art(b, "ck_btn_normal")
local clicks = 0
local u = CK.UIKit.buildButton(region(), "Test", function() clicks = clicks + 1 end)
u:Fire("OnEnter"); art(u, "ck_sk_key_hover")
u:SetActive(true); art(u, "ck_sk_key_active")
u:Fire("OnMouseDown", "LeftButton"); art(u, "ck_sk_key_pressed")
u:Fire("OnMouseUp", "LeftButton"); art(u, "ck_sk_key_active")
u:Fire("OnClick"); assert(clicks == 1); art(u, "ck_sk_key_pressed"); expire(); art(u, "ck_sk_key_active")
CK.frame = { actions = { Space = u }, IsShown = function() return true end }
CK:PulseAction("Space"); art(u, "ck_sk_key_pressed"); expire()
print("PASS: real button static/hover/focus/activation states, timer races, disabled/armed and hidden controls")

local panel = region(); K.Panel(panel)
local found = false
for _, t in ipairs(panel.children) do if t.texture and t.texture:find("ck_reforged_frame", 1, true) then found = true end end
assert(found, "panel must consume the exported frame asset")
local detail = K.Detail(region(), 230)
assert(detail.parchment and detail.parchment.parts[1].texture:find("ck_reforged_parchment", 1, true))
for _, label in ipairs({ detail.title, detail.tag, detail.body, detail.extra }) do
    assert(label.color[1] < 0.4 and label.color[2] < 0.4 and label.color[3] < 0.4, "parchment labels need dark ink")
    assert(label.shadow[4] == 0, "dark parchment labels must not retain a black shadow")
end
detail:Set({ title = "Your binding", tag = "Yours", tagColor = K.C.yours, body = "Description" })
assert(detail.dot.vertex[1] == K.C.yours[1], "ownership marker color must survive parchment")
print("PASS: exported frame/parchment consumers and readable ink preserve ownership markers")

loadAddon("ConfigWindow.lua")
local C = CK.Config; C.Render = noop
local actionCount = 0
local row = { id = "test", kind = "button", func = function() actionCount = actionCount + 1 end }
local page = C.NewRailPage({ key = "home", sections = { { key = "test", rows = noop } } })
page.rowsUI = { { row = row, btn = b } }; page.rows = { row }
b:SetState({ focus = true })
page:Act(row); assert(actionCount == 1); art(b, "ck_btn_pressed"); expire(); art(b, "ck_btn_active")
row.disabled = true; page:Act(row); assert(actionCount == 1); art(b, "ck_btn_active")
row.disabled = nil; row.danger = true
page:Act(row); assert(actionCount == 1 and C:IsArmed("test"), "first danger press must only arm")
page:Act(row); assert(actionCount == 2 and not C:IsArmed("test"), "second danger press must activate once")
print("PASS: controller rail activation pulses exactly once, disabled actions and two-press confirmation preserved")

-- Mapping and wheel-editor controller routes use the same logical actions
-- as their mouse buttons, with no new binding or secure-click behavior.
CK.Mapping = { ReplacedCount = function() return 0 end }
CK.Paddles = {}
env.InCombatLockdown = function() return false end
loadAddon("MapWindow.lua")
local W = CK.MapPage
W.frame = { actions = { b } }; local identified = 0
W.Identify = function() identified = identified + 1 end
b:SetState({ focus = true }); W:Act(1)
assert(identified == 1); art(b, "ck_btn_pressed"); expire()
W:Act(3); art(b, "ck_btn_active")
loadAddon("MyWheels.lua")
local editor = CK.MyWheels.Editor; local renamed = 0
editor.frame = { buttons = { b } }; editor.id = 7
CK.MyWheels.StartRename = function(_, id) assert(id == 7); renamed = renamed + 1 end
editor:Button(1); assert(renamed == 1); art(b, "ck_btn_pressed"); expire()
print("PASS: mapping and custom-wheel logical controller actions trigger existing button feedback")

-- Keyboard input uses real successful actions; an empty Backspace is a
-- no-op, but returning from an empty whisper to recipient entry is not.
loadAddon("Input.lua")
local text, target, actions = "", nil, 0
env.GetTime = function() return 1 end
CK.GetText = function() return text end
CK.GetChatAttr = function(_, key) assert(key == "tellTarget"); return target end
CK.Backspace = function() actions = actions + 1; if text == "" then target = nil else text = text:sub(1, -2) end end
CK.Space = function() actions = actions + 1; text = text .. " " end
CK.ToggleSymbols = function() actions = actions + 1 end
CK.frame = { actions = { Space = u, Backspace = u, ToggleSymbols = u }, IsShown = function() return true end }
CK:RunAction("Backspace", "PADLSHOULDER"); art(u, "ck_sk_key_active")
text = "ab"; CK:RunAction("Backspace", "PADLSHOULDER"); assert(text == "a"); art(u, "ck_sk_key_pressed"); expire()
text, target = "", "Recipient"; CK:RunAction("Backspace", "PADLSHOULDER")
assert(target == nil); art(u, "ck_sk_key_pressed"); expire()
CK:RunAction("Space", "PADRSHOULDER"); assert(text == " "); art(u, "ck_sk_key_pressed"); expire()
CK:RunAction("ToggleSymbols", "PADLSTICK"); art(u, "ck_sk_key_pressed"); expire()
assert(actions == 5, "feedback must not repeat or replace any keyboard action")
print("PASS: keyboard controller activation and empty Backspace/whisper guards preserve action counts")

-- Actual keyboard state selection must keep readable text on the exported
-- burgundy pressed key, rather than inheriting the old gold-key black ink.
loadAddon("StickKeyboard.lua")
local split = CK.Methods.stick
local key = region(); key.char = "a"; key.label = region(); key.pressedUntil = 2
key.base = CK.UIKit.nineSlice(key, "ck_sk_key_normal", 128, 64, 12, 12, "BORDER")
local keyset = region(); keyset.keys = { key }
split.sets = { letters = keyset }; split.over = region()
split.ActiveSet = function() return keyset end
split.PickKey = function(_, _, cursor) return cursor.choice end
split.cursors = { left = { choice = key, dot = region(), cx = 0, cy = 0 },
    right = { dot = region(), cx = 0, cy = 0 } }
CK.state = {}; CK.Accents = function() return {} end
split:Update()
assert(key.file == "ck_sk_key_pressed")
assert(key.label.color[1] > 0.9 and key.label.color[2] > 0.8 and key.label.color[3] > 0.7,
    "split keyboard pressed text must be light on the burgundy asset")
assert(key.label.shadow[4] == 0)
u:Pulse()
assert(u.label.color[1] > 0.9 and u.label.color[2] > 0.8 and u.label.color[3] > 0.7,
    "helper button pressed text must be light on the burgundy asset")
expire(); key.pressedUntil = nil; split:Update(); assert(key.file == "ck_sk_key_target_l")
print("PASS: real split-keyboard and helper-button selectors keep pressed labels readable")

methods.CreateMaskTexture = methods.CreateTexture
methods.GetFrameLevel = function() return 0 end
for _, name in ipairs({ "AddMaskTexture", "SetSwipeTexture", "SetSwipeColor", "SetDrawEdge", "SetDrawBling" }) do methods[name] = noop end
loadAddon("Paddles.lua")
local P = CK.Paddles
local slot = P:CreateSlot(region(), 38)
assert(slot.border.texture:find("ck_reforged_slot_normal", 1, true) and not slot.pressed.shown)
assert(slot.pressed.texture:find("ck_reforged_slot_pressed", 1, true))
P.SetHover(slot, true)
assert(slot.border.texture:find("ck_reforged_slot_hover", 1, true))
local writes = slot.border.textureWrites
for _ = 1, 20 do P.SetHover(slot, true) end
assert(slot.border.textureWrites == writes, "unchanged hover must not rewrite textures")
P.SetPressed(slot, true)
assert(slot.visual.width == 34 and slot.visual.height == 34 and slot.pressed.shown and not slot.border.shown)
P.SetPressed(slot, true); P.SetHover(slot, true)
assert(slot.border.textureWrites == writes)
P.SetPressed(slot, false)
assert(slot.visual.width == 38 and slot.visual.height == 38 and not slot.pressed.shown and slot.border.shown)
assert(slot.border.texture:find("ck_reforged_slot_hover", 1, true), "release must preserve hover state")
P.SetHover(slot, false); assert(slot.border.texture:find("ck_reforged_slot_normal", 1, true))
print("PASS: real HUD slot static/hover/pressed art, shrink/release and unchanged-hover write counts")

local oldSetTab = C.SetTab
C.tab = C.TABS[1]; b.key = C.TABS[2]; C.frame = { tabs = { b } }
C.SetTab = function(self, key) self.tab = key end
C:StepTab(1); assert(C.tab == b.key); art(b, "ck_btn_pressed"); expire()
C.SetTab = oldSetTab
print("PASS: controller tab activation pulses the newly selected tab")

-- Build and drive the actual role-card UI, including the shared parchment
-- Apply control. The fixture supplies only game data and frame primitives.
methods.GetStringWidth = function(self) return #(self.text or "") * 7 end
methods.GetStringHeight = function() return 18 end
methods.SetRotation = noop
methods.EnableMouseWheel = noop
methods.SetPoint = function(self, ...) self.lastPoint = { ... } end
CK.SetGlyph = function(_, tex, key) tex:SetTexture("glyph:" .. key) end
local roleSaved, occupied = {}, false
local known = { { action = "spell:1", name = "Kick" }, { action = "spell:2", name = "Shield" } }
CK.Mapping = { INPUTS = { { id = "LT", layer = true }, { id = "L4" }, { id = "L5" } },
    Catalog = function() return known end, ActionName = function(_, action) return action == "spell:1" and "Kick" or "Shield" end,
    ActionIcon = function() return 132219 end }
CK.Profiles = { ready = true,
    ACTION_ROLES = { { key = "interrupt", name = "Interrupt" }, { key = "defensive", name = "Defensive" },
        { key = "movement", name = "Movement" }, { key = "heal", name = "Heal" } },
    CharacterName = function() return "Test-Realm" end, ActiveName = function() return "General" end,
    RolePosition = function(_, role) return role == "interrupt" and "L4" or "L5", "" end,
    RoleAction = function() return nil end,
    PreviewRole = function(_, role, input, layer, action, replace)
        return action ~= nil and (not occupied or replace), occupied and not replace and "Button already assigned." or "Review this assignment before applying."
    end,
    ApplyRole = function(_, ...) roleSaved[#roleSaved + 1] = { ... }; return true end }
C.Toast = function(self, message, warn) self.message, self.warn = message, warn end
local rolePage = C.NewRailPage({ key = "home", sections = {} }); C.pages.home = rolePage
loadAddon("ProfileOptions.lua")
rolePage:Build(region()); rolePage.section = 2
rolePage:Render()
local cards = rolePage.def.sections[2].view
assert(#cards.frame.cards == 4 and cards.frame.cards[1].width == 388 and cards.frame.cards[1].height == 72)
assert(cards.frame.cards[1].icon.width == 36 and rolePage.detail.height == 420)
assert(rolePage.list.width == 388 and rolePage.detail.width == 232)
assert(cards.frame.cards[1].slice.parts[1].coords[2] == 12 / 512, "role skin must honor its source slice margin")
art(cards.frame.cards[1], "ck_reforged_role_active")
assert(rolePage.railEntries[1].slice, "left navigation must use framed button state textures")
assert(rolePage.detail.actionButton.state.disabled)
for _, card in ipairs(cards.frame.cards) do
    assert(not card.icon.shown and card.spell.text == "Choose a known spell", "unassigned role cards must hide placeholder icons and keep readable guidance")
end
assert(not rolePage.detail.icon.shown and rolePage.detail.title.text == "Choose a spell", "unassigned detail must hide the placeholder icon")
cards.frame.cards[2]:Fire("OnClick")
assert(rolePage.picker:IsOpen() and #roleSaved == 0, "mouse role-card activation must open a draft picker")
rolePage:Press("A")
assert(not rolePage.picker:IsOpen() and #roleSaved == 0, "controller picker acceptance must not apply")
rolePage:Render()
assert(rolePage.detail.title.text == "Kick" and rolePage.detail.tag.text == "Defensive")
assert(cards.frame.cards[2].icon.shown and cards.frame.cards[2].icon.texture == 132219 and rolePage.detail.icon.shown and rolePage.detail.icon.texture == 132219, "selecting a real spell must restore both of its actual icons")
assert(not rolePage.detail.actionButton.state.disabled)
cards:Press(rolePage, "RIGHT"); rolePage:Render()
assert(rolePage.detail.actionButton.state.focus, "controller must reach the explicit Apply button")
cards:Press(rolePage, "A"); assert(#roleSaved == 1 and roleSaved[1][1] == "defensive")
occupied = true; rolePage:Render(); rolePage.detail.actionButton:Fire("OnClick")
assert(#roleSaved == 1 and rolePage.detail.actionButton.state.disabled, "conflicts must disable mouse Apply")
cards:Press(rolePage, "LEFT"); cards:Press(rolePage, "X"); rolePage:Render()
assert(cards.frame.settings[1].shown and not cards.frame.cards[1].shown, "binding editor must replace only the card surface")
cards.setting = 3; cards:Press(rolePage, "A"); cards:Press(rolePage, "B"); rolePage:Render()
rolePage.detail.actionButton:Fire("OnClick")
assert(#roleSaved == 2 and roleSaved[2][5] == true, "explicit replacement must reach the backend")
env.InCombatLockdown = function() return true end
rolePage:Render(); rolePage.detail.actionButton:Fire("OnClick"); assert(#roleSaved == 2)
print("PASS: real four-card geometry, framed rail, mouse/controller picker, parchment Apply, conflict and combat guards")


-- Real daisywheel, shared character entry, and stick fire/re-arm logic. The
-- existing frame/timer fixture substitutes only WoW rendering and game data.
methods.SetAtlas = function(self, name, useSize) self.atlas, self.useAtlasSize = name, useSize end
methods.SetColorTexture = function(self, ...) self.colorTexture = { ... } end
methods.SetAllPoints = function(self, anchor) self.allPoints = anchor end
methods.AddMaskTexture = function(self, mask) self.masks = self.masks or {}; self.masks[#self.masks + 1] = mask end
env.C_Texture = { GetAtlasInfo = function() return {} end }
CK.WORD_CHARS = "%a"
loadAddon("Message.lua")
loadAddon("Wheel.lua")
local daisy = CK.Methods.wheel
local area = region(); area:SetSize(304, 304); daisy.area = area
CK.db.settings.inputMethod, CK.db.settings.petalRings = "wheel", true
local accents = { "é", "è", "ê", "à", "ç", "ù", "â", "ô", "î", "û", "ë", "ï" }
CK.Accents = function() return accents end
CK.Upper = string.upper
CK.Refresh = function() daisy:Update() end
CK.UpdateMethod = function() daisy:Update() end
CK.buffer = ""
daisy:Build(area); daisy:Update()
local directions = { {-1,0}, {0,1}, {1,0}, {0,-1} }
for petal = 1, 8 do
    local angle = (petal - 1) * math.pi / 4
    CK:SetLeftStick(math.sin(angle), math.cos(angle))
    assert(daisy.petal == petal)
    for slot, vector in ipairs(directions) do
        CK:SetRightStick(0, 0)
        local before = CK:GetText()
        CK:SetRightStick(vector[1] * .5, vector[2] * .5)
        assert(CK:GetText() == before, "aim alone must not type")
        CK:SetRightStick(vector[1], vector[2])
        assert(CK:GetText() == before .. CK.LAYOUTS.letters[petal][slot], "flick must type exactly the original mapped character")
        local target = daisy.petals[petal].keys[slot]
        assert(target.press and target.press.shown, "successful daisywheel character entry needs a distinct activation state")
        CK:SetRightStick(vector[1], vector[2])
        assert(CK:GetText() == before .. CK.LAYOUTS.letters[petal][slot], "holding a fired stick must not insert twice")
        expire(); assert(not target.press.shown and target.target.shown, "activation must return to the current aim")
    end
end
print("PASS: all32 daisywheel characters use actual aim/fire/re-arm semantics and return from activation without duplicate inserts")

assert(area.width == 304 and area.height == 304 and daisy.rim.atlas == "UI-HUD-Minimap-Frame-Circle" and daisy.rim.width == 352)
assert(daisy.face.width == 276 and daisy.face.colorTexture[4] == 1 and daisy.bg.alpha == .60)
assert(daisy.bg.width == daisy.rim.width and daisy.section.width == 176, "crown and overlays must share the padded rim scale to hide the old outer border")
assert(daisy.faceMask.atlas == "ui-hud-minimap-frame-generic-mask")
assert(daisy.bg.masks[1] == daisy.faceMask and daisy.section.masks[1] == daisy.faceMask)
assert(not daisy.rim.masks, "native outer bevel must not inherit the wedge mask")
assert(daisy.rim.layer == "ARTWORK" and daisy.rim.sub > daisy.section.sub, "focused wedge must stay beneath the native bevel")
for petal, group in ipairs(daisy.petals) do
    local angle = (petal - 1) * math.pi / 4
    assert(math.abs(group.lastPoint[4] - 95 * math.sin(angle)) < .001 and math.abs(group.lastPoint[5] - 95 * math.cos(angle)) < .001)
    for slot, key in ipairs(group.keys) do
        assert(math.abs(key.width - 25.65) < .001 and math.abs(key.height - 25.65) < .001, "native visuals must not change character hitboxes")
        assert(key.hover.atlas == "gamepad-actionbar-circleslot-border-hover" and key.press.atlas == "gamepad-actionbar-circleslot-border-pressed")
        assert(key.target.atlas == "gamepad-actionbar-circleslot-border-selected")
    end
end
local selected = daisy.petals[8].keys[4]
assert(selected.label.color[1] > .9 and selected.label.color[2] > .8, "transparent target artwork needs light character ink")
CK.db.settings.petalRings = false; daisy:Update()
for _, group in ipairs(daisy.petals) do assert(not group.ring.shown and not group.selectedRing.shown) end
CK.db.settings.petalRings = true
print("PASS: native daisywheel face, mask and state artwork retain304px geometry, character hitboxes and optional petal rings")

CK:SetRightStick(0, 0); daisy:Reset(); CK.buffer = ""
assert(daisy:OnFlick(2) == false and CK:GetText() == "", "no selected petal must preserve common right-stick navigation")
local mouse = daisy.petals[1].keys[1]
mouse:Fire("OnEnter"); mouse:Fire("OnClick")
assert(CK:GetText() == "a" and mouse.press.shown)
mouse:Fire("OnClick"); local oldTimer = table.remove(timers, 1); oldTimer()
assert(CK:GetText() == "aa" and mouse.press.shown, "an older timer must not end a newer activation")
expire(); assert(not mouse.press.shown and mouse.hover.shown)
CK.state.shift = true; mouse:Fire("OnClick")
assert(CK:GetText() == "aaA" and not CK.state.shift, "one-shot Shift must still be consumed by actual TypeChar")
CK.state.caps = true; mouse:Fire("OnClick")
assert(CK:GetText() == "aaAA" and CK.state.caps, "Caps must stay persistent")
CK.state.caps = false; CK.state.layer = "symbols"
local before = CK:GetText(); CK:TypeSlot(4,1)
assert(CK:GetText() == before .. accents[1], "language accents must retain their original positions")
area:Hide(); expire()
assert(not mouse.activated and not mouse.press.shown and daisy.hoverPetal == nil, "hidden/reset wheel must clear transient activation and mouse focus")
area:Show(); daisy:Update(); assert(not mouse.press.shown)
print("PASS: daisywheel mouse activation, timer races, Shift/Caps, accent positions and hidden/reset cleanup preserve typing")

-- The shipped native exports preserve transparent character centers on a
-- client missing an atlas; the old gold pastille needs incompatible dark ink.
env.C_Texture.GetAtlasInfo = function() return nil end
local fallbackArea = region(); fallbackArea:SetSize(304, 304); daisy.area = fallbackArea
daisy:Build(fallbackArea); daisy:Reset()
CK.state.layer, CK.state.aim = "letters", 2; daisy.petal = 1; daisy:Update()
local fallback = daisy.petals[1].keys[2]
assert(fallback.hover.texture:find("ck_reforged_slot_hover", 1, true))
assert(fallback.target.texture:find("ck_reforged_slot_hover", 1, true))
assert(fallback.press.texture:find("ck_reforged_slot_pressed", 1, true))
assert(fallback.target.width == fallback.hover.width, "unpadded fallback must not inherit the native80px glow extent")
assert(fallback.label.color[1] > .9 and fallback.label.color[2] > .8)
local beforeFallback = CK:GetText(); fallback:Fire("OnClick")
assert(CK:GetText() == beforeFallback .. "b" and fallback.press.shown)
expire(); assert(not fallback.press.shown and fallback.target.shown)
print("PASS: missing-atlas character states use shipped transparent native fallbacks with readable light ink")
