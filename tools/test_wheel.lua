-- Run from the addon root with Lua 5.1. The wheels' secure snippets
-- (ConsumableWheel.lua) run against simulated handles: the wheel frame, its
-- slots' buttons, the right stick (GetGamePadState) and the restricted
-- environment's few functions. Pressed and held to show, EXIT, empty
-- sections, the wheel's button again, a party spell's 6 sections.
local any = setmetatable({}, { __index = function(t) return t end, __call = function(t) return t end })
local env = setmetatable({}, { __index = function(_, k) local g = _G[k]; if g ~= nil then return g end; return any end })
local CK = { L = setmetatable({}, { __index = function(_, k) return k end }) }
-- The snippets are the file's locals: handed out at its end
local file = assert(io.open("ConsumableWheel.lua")):read("*a")
local chunk = assert(loadstring(file .. "\nCK._snips = { TOGGLE = TOGGLE, USE = USE, LET_GO = LET_GO, DONE = DONE, CLOSE = CLOSE }", "ConsumableWheel.lua"))
setfenv(chunk, env)
chunk("EasyController", CK)
local SN = CK._snips

local function handle(name)
  local h = { attrs = {}, shown = false, name = name, bindings = {} }
  function h:GetAttribute(k) return self.attrs[k:lower()] end
  function h:SetAttribute(k, v) self.attrs[k:lower()] = v end
  function h:IsShown() return self.shown end
  function h:Show() self.shown = true end
  function h:Hide() self.shown = false end
  function h:ClearAllPoints() end
  function h:SetPoint() end
  function h:SetWidth() end
  function h:SetHeight() end
  function h:GetName() return self.name end
  function h:ClearBindings() self.bindings = {} end
  function h:SetBindingClick(_, key, target) self.bindings[key] = target end
  function h:SetBinding(_, key, action) self.bindings[key] = action end
  return h
end
local owner = handle("wheel")
local slots = {}
for i = 1, 8 do slots[i] = handle("slot" .. i) end
local walker = handle("walker")
function owner:GetFrameRef(n)
    if n == "walker" then return walker end
    return slots[tonumber(n:match("%d+"))]
end

local stick = { x = 0, y = 0, len = 0 }
local walkStick = { x = 0, y = 0, len = 0 }
local senv = setmetatable({
  GetGamePadState = function() return { sticks = { walkStick, stick } } end,
  UnitExists = function(u) return u == "player" or u == "party1" end,
  strsub = string.sub, strfind = string.find, gmatch = string.gmatch, format = string.format,
  tostring = tostring, math = math,
}, { __index = function(_, k) error("restricted env: no " .. k) end })
local function run(snip, self, button, down)
  local f = assert(loadstring("local self, button, down, owner = ...\n" .. snip))
  setfenv(f, senv)
  return f(self, button, down, owner)
end

-- the wheel's attributes, as Build and store set them
owner:SetAttribute("ck-prefixes", ",SHIFT-,")
owner:SetAttribute("ck-pstickkeys", "PADRSTICKUP,PADRSTICKDOWN,PADRSTICKLEFT,PADRSTICKRIGHT,")
for key, d in pairs({ PADRSTICKUP = { 0, 1 }, PADRSTICKDOWN = { 0, -1 }, PADRSTICKLEFT = { -1, 0 }, PADRSTICKRIGHT = { 1, 0 } }) do
  owner:SetAttribute("ck-kx-" .. key, d[1]); owner:SetAttribute("ck-ky-" .. key, d[2])
end
for n = 1, 8 do for i = 1, n do
  local a = (i - 1) * 2 * math.pi / n
  owner:SetAttribute("ck-x" .. n .. "-" .. i, math.sin(a)); owner:SetAttribute("ck-y" .. n .. "-" .. i, math.cos(a))
end end
owner:SetAttribute("ck-radius", 128); owner:SetAttribute("ck-pradius", 62); owner:SetAttribute("ck-stick", 2)
owner:SetAttribute("ck-walkstick", 1); owner:SetAttribute("ck-move", "strafe")
-- wheel "1": slots 1 (top) and 3 (right) filled; others empty; one page
owner:SetAttribute("ck-1-1-n", 8); owner:SetAttribute("ck-1-pages", 1); owner:SetAttribute("ck-1-total", 2)
owner:SetAttribute("ck-1-1-1-t", "spell"); owner:SetAttribute("ck-1-1-1", "Heal")
owner:SetAttribute("ck-1-1-3-t", "item"); owner:SetAttribute("ck-1-1-3", "item:1")
-- party wheel: 5 sections, player top, party1 at 72, party2 absent
owner:SetAttribute("ck-p9-1-n", 5); owner:SetAttribute("ck-p9-pages", 1); owner:SetAttribute("ck-p9-total", 5)
for i, u in pairs({ [1] = "player", [2] = "party1", [3] = "party2", [4] = "party3", [5] = "party4" }) do
  owner:SetAttribute("ck-p9-1-" .. i .. "-t", "spell"); owner:SetAttribute("ck-p9-1-" .. i, "Renew"); owner:SetAttribute("ck-p9-1-" .. i .. "-u", u)
end

local toggle = handle("ControllerKeyboardMyWheel1"); toggle:SetAttribute("ck-wheel", "1")
toggle:SetAttribute("ck-keys", ",PADRSHOULDER,")
local ptoggle = handle("ControllerKeyboardPartyWheel9"); ptoggle:SetAttribute("ck-wheel", "p9"); ptoggle:SetAttribute("ck-keys", ",")
local letgo = handle("letgo")

local function setStick(x, y) stick.x, stick.y = x, y; stick.len = math.sqrt(x * x + y * y) end
local function flick(key, x, y)    -- direction key pressed with the stick out, then released at the middle
  setStick(x, y); local r1 = run(SN.LET_GO, letgo, key, true)
  setStick(0, 0); return run(SN.LET_GO, letgo, key, false)
end
local FAILED
local function check(what, cond)
    print((cond and "PASS " or "FAIL ") .. what)
    if not cond then FAILED = true end
end

-- PRESS MODE, a flick let go uses (option)
owner:SetAttribute("ck-hold", nil)
owner:SetAttribute("ck-letgo", true)
run(SN.TOGGLE, toggle, "LeftButton", true)
check("press opens wheel 1", owner:IsShown() and owner:GetAttribute("wheel") == "1")
check("slot 1 & 3 shown, 5 hidden", slots[1].shown and slots[3].shown and not slots[5].shown and not slots[2].shown)
check("opener key RB not taken by the wheel; LB neither (one page)", owner.bindings["PADRSHOULDER"] == nil and owner.bindings["PADLSHOULDER"] == nil)
check("R3 closes", owner.bindings["PADRSTICK"] == "ControllerKeyboardWheelClose" and owner.bindings["SHIFT-PADRSTICK"] ~= nil)
check("A, B and stick keys taken", owner.bindings["PAD1"] and owner.bindings["PAD2"] and owner.bindings["PADRSTICKRIGHT"])
check("strafe: the left stick's direction keys bound to movement (walker)", walker.bindings["PADLSTICKUP"] == "MOVEFORWARD"
    and walker.bindings["SHIFT-PADLSTICKLEFT"] == "STRAFELEFT")
-- closed while walking: the movement bindings stay (their release must reach them)
walkStick.x, walkStick.len = -1, 1
run(SN.TOGGLE, toggle, "LeftButton", true)
check("closed with the left stick out: wheel keys gone, movement kept", not owner:IsShown()
    and owner.bindings["PAD1"] == nil and walker.bindings["PADLSTICKLEFT"] == "STRAFELEFT")
walkStick.x, walkStick.len = 0, 0
run(SN.TOGGLE, toggle, "LeftButton", false)
run(SN.TOGGLE, toggle, "LeftButton", true)
run(SN.TOGGLE, toggle, "LeftButton", true)
check("closed with the left stick let go: movement bindings gone", walker.bindings["PADLSTICKLEFT"] == nil)
run(SN.TOGGLE, toggle, "LeftButton", false)
owner:SetAttribute("ck-move", "still")
run(SN.TOGGLE, toggle, "LeftButton", true)
check("still: no movement bindings", walker.bindings["PADLSTICKUP"] == nil)
run(SN.TOGGLE, toggle, "LeftButton", true)
run(SN.TOGGLE, toggle, "LeftButton", false)
owner:SetAttribute("ck-move", "strafe")
run(SN.TOGGLE, toggle, "LeftButton", true)
run(SN.TOGGLE, toggle, "LeftButton", false)
check("release in press mode: still open", owner:IsShown())
local r = flick("PADRSTICKRIGHT", 1, 0)
check("flick right + release fires slot 3", r == "s3")
-- (the slot's click closes it: DONE)
run(SN.DONE, letgo)
run(SN.TOGGLE, toggle, "LeftButton", true); run(SN.TOGGLE, toggle, "LeftButton", false)
r = flick("PADRSTICKDOWN", 0, -1)
check("flick down (an empty section) closes, nothing fired", r == false and not owner:IsShown())
run(SN.TOGGLE, toggle, "LeftButton", true); run(SN.TOGGLE, toggle, "LeftButton", false)
-- up right, then eased back toward up (RIGHT comes up, the stick still out)
setStick(0.7, 0.7); run(SN.LET_GO, letgo, "PADRSTICKRIGHT", true); run(SN.LET_GO, letgo, "PADRSTICKUP", true)
setStick(0.1, 0.85); r = run(SN.LET_GO, letgo, "PADRSTICKRIGHT", false)
check("easing off a diagonal doesn't fire", r == false and owner:IsShown())
setStick(0, 0); r = run(SN.LET_GO, letgo, "PADRSTICKUP", false)
check("then let go fires the top slot", r == "s1")
run(SN.DONE, letgo)
run(SN.TOGGLE, toggle, "LeftButton", true); run(SN.TOGGLE, toggle, "LeftButton", false)
r = flick("PADRSTICKLEFT", -1, 0)
check("flick to empty section (left) closes", r == false and not owner:IsShown())
run(SN.TOGGLE, toggle, "LeftButton", true); run(SN.TOGGLE, toggle, "LeftButton", false)
run(SN.TOGGLE, toggle, "LeftButton", true)
check("button pressed again closes", not owner:IsShown())
run(SN.TOGGLE, toggle, "LeftButton", false)
run(SN.TOGGLE, toggle, "LeftButton", true); run(SN.TOGGLE, toggle, "LeftButton", false)
setStick(0, 1); r = { run(SN.USE, handle("use"), "LeftButton", true) }
check("A with stick up fires slot 1", r[1] == "s1")
setStick(0, -1); r = { run(SN.USE, handle("use"), "LeftButton", true) }
check("A with the stick on an empty section closes", r[1] == false and not owner:IsShown())

-- PRESS MODE, the stick only lights, A uses (the default)
owner:SetAttribute("ck-letgo", nil)
run(SN.TOGGLE, toggle, "LeftButton", true); run(SN.TOGGLE, toggle, "LeftButton", false)
r = flick("PADRSTICKRIGHT", 1, 0)
check("lights: a flick let go only lights (no fire, still open)", r == false and owner:IsShown() and owner:GetAttribute("ck-aim") == 3)
r = { run(SN.USE, handle("use"), "LeftButton", true) }
check("lights: A uses the lit slot 3 (stick back in the middle)", r[1] == "s3")
run(SN.DONE, letgo)
run(SN.TOGGLE, toggle, "LeftButton", true); run(SN.TOGGLE, toggle, "LeftButton", false)
flick("PADRSTICKDOWN", 0, -1)
check("lights: an empty section lit, still open", owner:IsShown() and owner:GetAttribute("ck-aim") == 5)
r = { run(SN.USE, handle("use"), "LeftButton", true) }
check("lights: A on an empty section closes, nothing used", r[1] == false and not owner:IsShown())
run(SN.TOGGLE, toggle, "LeftButton", true); run(SN.TOGGLE, toggle, "LeftButton", false)
flick("PADRSTICKRIGHT", 1, 0)
run(SN.CLOSE, handle("close"), "LeftButton", true)
check("lights: B closes, nothing used", not owner:IsShown())

-- HOLD MODE
owner:SetAttribute("ck-hold", true)
run(SN.TOGGLE, toggle, "LeftButton", true)
r = flick("PADRSTICKRIGHT", 1, 0)
check("hold: flick only lights (no fire, still open)", r == false and owner:IsShown() and owner:GetAttribute("ck-aim") == 3)
r = run(SN.TOGGLE, toggle, "LeftButton", false)
check("hold: release fires the lit slot 3", r == "s3")
run(SN.DONE, letgo)
run(SN.TOGGLE, toggle, "LeftButton", true)
setStick(0, 0)
r = run(SN.TOGGLE, toggle, "LeftButton", false)
check("hold: release with nothing lit closes", r == false and not owner:IsShown())
run(SN.TOGGLE, toggle, "LeftButton", true)
flick("PADRSTICKRIGHT", 1, 0); flick("PADRSTICKDOWN", 0, -1)
r = run(SN.TOGGLE, toggle, "LeftButton", false)
check("hold: an empty section lit, then release closes", r == false and not owner:IsShown())
run(SN.TOGGLE, toggle, "LeftButton", true)
flick("PADRSTICKRIGHT", 1, 0); setStick(0, 1)
r = run(SN.TOGGLE, toggle, "LeftButton", false)
check("hold: stick still out at release wins (slot 1)", r == "s1")
run(SN.DONE, letgo)
-- router release ("ckup")
run(SN.TOGGLE, toggle, "ck", nil); setStick(0, 0); flick("PADRSTICKRIGHT", 1, 0)
r = run(SN.TOGGLE, toggle, "ckup", nil)
check("hold via router: ckup release fires lit slot 3", r == "s3")
run(SN.DONE, letgo)

-- PARTY (press mode, a flick let go uses)
owner:SetAttribute("ck-hold", nil)
owner:SetAttribute("ck-letgo", true)
run(SN.TOGGLE, ptoggle, "LeftButton", true); run(SN.TOGGLE, ptoggle, "LeftButton", false)
check("party: 5 sections, you + party1 shown, absent hidden", slots[1].shown and slots[2].shown and not slots[3].shown and not slots[5].shown)
local a = math.rad(72)
r = flick("PADRSTICKRIGHT", math.sin(a), math.cos(a))
check("party: flick 72 deg casts on party1 (slot 2)", r == "s2")
run(SN.DONE, letgo)
run(SN.TOGGLE, ptoggle, "LeftButton", true); run(SN.TOGGLE, ptoggle, "LeftButton", false)
r = flick("PADRSTICKDOWN", 0, -1)
check("party: flick down (members not there) closes", r == false and not owner:IsShown())
run(SN.TOGGLE, ptoggle, "LeftButton", true); run(SN.TOGGLE, ptoggle, "LeftButton", false)
a = math.rad(144); r = flick("PADRSTICKRIGHT", math.sin(a), math.cos(a))
check("party: absent member's section closes", r == false and not owner:IsShown())
-- a wheel with pages takes LB / RB
owner:SetAttribute("ck-c-1-n", 8); owner:SetAttribute("ck-c-pages", 2); owner:SetAttribute("ck-c-total", 9)
owner:SetAttribute("ck-c-1-1-t", "item"); owner:SetAttribute("ck-c-1-1", "item:2")
local ctoggle = handle("ControllerKeyboardWheelToggle"); ctoggle:SetAttribute("ck-wheel", "c")
owner:SetAttribute("ck-hold", nil)
run(SN.TOGGLE, ctoggle, "LeftButton", true)
check("paged wheel: LB / RB taken", owner.bindings["PADLSHOULDER"] ~= nil and owner.bindings["PADRSHOULDER"] ~= nil)
assert(not FAILED, "some checks failed")
print("ALL PASSED")
