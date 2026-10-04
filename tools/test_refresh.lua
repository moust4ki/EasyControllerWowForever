-- Run from the addon directory: lua tools/test_refresh.lua (Lua 5.1).
local failures, passed = {}, 0
local function check(name, run)
    local ok, message = pcall(run)
    if ok then passed = passed + 1; print("PASS: " .. name)
    else failures[#failures + 1] = name .. ": " .. tostring(message); print("FAIL: " .. failures[#failures]) end
end
local function fixture(CK, globals)
    local env = setmetatable(globals or {}, { __index = _G })
    env._G = env
    return function(path)
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk("EasyController", CK)
    end
end
local function noop() end

check("mapping keeps shared-layer behavior without building all layers", function()
    local cv, calls = {}, 0
    local CK = { L = {}, db = { settings = { mapping = {} } } }
    fixture(CK, { GetCVar = function(name) calls = calls + 1; return cv[name] end })("Mapping.lua")
    local M, worst, checks = CK.Mapping, 0, 0
    local values = { "none", "PADLTRIGGER", "PADRTRIGGER" }
    local assignments = {
        { [""] = "spell:1", LT = "spell:2", RT = "spell:3", LTRT = "spell:4" },
        { [""] = "cmd:JUMP", LT = "spell:2", LTRT = "cmd:TOGGLERUN" },
        { RT = "spell:3" },
    }
    for _, alt in ipairs(values) do
        for _, ctrl in ipairs(values) do
            for _, shift in ipairs(values) do
                cv.GamePadEmulateAlt, cv.GamePadEmulateCtrl, cv.GamePadEmulateShift = alt, ctrl, shift
                for _, actions in ipairs(assignments) do
                    for _, id in ipairs({ "L4", "L3" }) do
                        for _, layer in ipairs(M.LAYERS) do CK.db.settings.mapping[id .. ":" .. layer] = actions[layer] end
                        local input = M.BY_ID[id]
                        for _, layer in ipairs(M.LAYERS) do
                            -- The existing complete shared-layer query defines the behavior.
                            local base = M:SharedLayers(layer)[1]
                            local expected = actions[base]
                            if input.paddle and not (expected and not M.Routable(expected)) then
                                expected = actions[layer]
                                if layer ~= base and not M.Routable(expected) then expected = nil end
                            end
                            calls = 0
                            assert(M:EffectiveAction(input, layer) == expected, "changed action in layer " .. layer)
                            worst = math.max(worst, calls)
                            checks = checks + 1
                        end
                    end
                end
            end
        end
    end
    print("Mapping: " .. checks .. " action comparisons; worst GetCVar reads per lookup=" .. worst)
    assert(worst <= 6, "an action lookup should inspect at most the two trigger modifiers")
end)

check("paddle event bursts refresh once on the next frame", function()
    local CK = { L = {} }
    local refreshes, presses = {}, 0
    local function region()
        return { SetPoint = noop, SetTexture = noop, SetVertexColor = noop, Hide = noop }
    end
    local f = { scripts = {}, SetSize = noop, SetPoint = noop, SetFrameStrata = noop,
        RegisterEvent = noop, Hide = noop }
    function f:SetScript(name, callback) self.scripts[name] = callback end
    CK.NewFrame = function() return f end
    fixture(CK)("Paddles.lua")
    local P = CK.Paddles
    function P:CreateSlot()
        return { over = { CreateTexture = region }, EnableMouse = noop, SetScript = noop }
    end
    P.AddBadge, P.Layout, P.AttachToBar = noop, noop, noop
    function P:UpdatePressed() presses = presses + 1 end
    function P:Refresh(cooldown) refreshes[#refreshes + 1] = { cooldown = cooldown } end
    P:BuildFrame()
    for _, event in ipairs({ "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN" }) do
        f.scripts.OnEvent(f, event)
    end
    assert(#refreshes == 0, "event burst redrew immediately " .. #refreshes .. " times")
    f.scripts.OnUpdate(f, 0.01)
    assert(#refreshes == 1 and refreshes[1].cooldown, "cooldowns must refresh on the next frame")
    assert(presses == 1, "pressed feedback must still update every frame")
    f.scripts.OnUpdate(f, 0.01)
    assert(#refreshes == 1 and presses == 2, "no extra redraw between periodic ticks")
    f.scripts.OnUpdate(f, 0.1)
    assert(#refreshes == 2 and not refreshes[2].cooldown, "periodic range/count refresh must continue")
    f.scripts.OnEvent(f, "ACTIONBAR_SLOT_CHANGED")
    f.scripts.OnUpdate(f, 0.1)
    assert(#refreshes == 3 and refreshes[3].cooldown, "a dirty periodic tick should only refresh once")
    f.scripts.OnEvent(f, "SPELL_UPDATE_COOLDOWN")
    f.scripts.OnShow(f)
    f.scripts.OnUpdate(f, 0.001)
    assert(#refreshes == 4 and refreshes[4].cooldown, "show must consume any pending refresh")
    assert(presses == 5, "event coalescing must not throttle input feedback")
end)

check("supplies skip unchanged geometry but keep live counts, glows and combat deferral", function()
    local settings = { enabled = true, size = 2, layout = "right" }
    local CK = { L = {}, db = { settings = { supplies = settings } }, Paddles = {} }
    local geometry, combat, vibrations = 0, false, 0
    CK.Paddles.SetIcon = function(tex, icon) tex.value = icon end
    CK.Vibration = { Fire = function() vibrations = vibrations + 1 end }
    fixture(CK, { InCombatLockdown = function() return combat end })("Supplies.lua")
    local S = CK.Supplies
    local function region(track)
        return {
            shown = true,
            ClearAllPoints = function() if track then geometry = geometry + 1 end end,
            SetPoint = function(self, ...) if track then geometry = geometry + 1 end; self.point = { ... } end,
            SetSize = function(self, w, h) if track then geometry = geometry + 1 end; self.width, self.height = w, h end,
            Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
            SetShown = function(self, value) self.shown = value end,
            IsShown = function(self) return self.shown end,
            GetLeft = function() return nil end,
        }
    end
    local resources = {
        { key = "item:1", kind = "item", icon = 1, count = 10, cfg = { on = true, low = 4, critical = 1 } },
        { key = "item:2", kind = "item", icon = 2, count = 8, cfg = { on = true, low = 4, critical = 1 } },
    }
    S.bar = region(true); S.bar.buttons = {}
    S.BuildBar = noop
    function S:Resources() return resources end
    function S:Button(i)
        if self.bar.buttons[i] then return self.bar.buttons[i] end
        local b = region(true)
        b.click, b.visual, b.icon = region(true), region(true), {}
        b.count = { SetText = function(self, text) self.text = text end, SetTextColor = noop }
        local glow = region(false)
        glow.SetVertexColor = noop
        glow.pulse = { Stop = noop, IsPlaying = function() return false end, Play = noop }
        glow.alpha = { SetFromAlpha = noop, SetToAlpha = noop, SetDuration = noop }
        S.glows[b] = glow
        self.bar.buttons[i] = b
        return b
    end
    S:Refresh()
    local b1, b2 = S.bar.buttons[1], S.bar.buttons[2]
    assert(b1.size == 40 and b2:IsShown(), "initial geometry was not built")
    geometry = 0
    resources[1].count = 1
    S:Refresh()
    assert(b1.count.text == 1 and S.glows[b1].shown and vibrations == 1, "live values stopped updating")
    assert(geometry == 0, "unchanged layout performed " .. geometry .. " geometry calls")
    settings.size = 1
    S:Refresh()
    assert(geometry > 0 and b1.size == 32 and b1.click.width == 32, "size changes must update display and clicks")
    geometry = 0
    settings.layout = "down"
    S:Refresh()
    assert(geometry > 0 and b2.point[1] == "TOP" and b2.point[5] < 0, "direction changes must relayout")
    resources[2].cfg.on = false
    S:Refresh()
    assert(not b2.shown and not b2.click.shown, "removed resources must hide both frames")
    geometry, combat = 0, true
    resources[2].cfg.on = true
    resources[1].count = 9
    S:Refresh()
    assert(geometry == 0 and S.pendingLayout and not b2.shown, "combat must defer secure geometry")
    assert(b1.count.text == 9 and not S.glows[b1].shown, "combat must still update counts and glows")
    combat = false
    S:Refresh()
    assert(geometry > 0 and b2.shown and b2.click.shown and not S.pendingLayout, "deferred layout must apply after combat")
    settings.enabled = false
    S:Refresh()
    assert(not S.bar.shown, "disabled supplies should hide")
    settings.enabled = true
    S:Refresh()
    assert(S.bar.shown and b1.shown, "re-enabled supplies should show")
end)

check("mapping dispatches profile bindings and applies effective shared entries", function()
    local settings = { modules = { mapping = true }, mapping = {}, replaced = {}, paddles = {} }
    local calls, bindings = {}, {}
    local CK = { L = {}, db = { settings = settings }, Paddles = { Apply = noop } }
    local function wipe(t) for key in pairs(t) do t[key] = nil end; return t end
    local loadAddon = fixture(CK, {
        wipe = wipe, InCombatLockdown = function() return false end,
        GetBindingAction = function() return "" end,
        ClearOverrideBindings = noop, hooksecurefunc = noop,
        CreateFrame = function() return { RegisterEvent = noop, SetScript = noop } end,
        SetOverrideBinding = function(_, _, key, action) bindings[key] = action end,
        SetOverrideBindingClick = noop,
    })
    CK.NewFrame = function(_, name) return { GetName = function() return name end } end
    loadAddon("Mapping.lua")
    local M = CK.Mapping
    local apply = M.Apply
    M.Apply = noop
    M:Set("L3", "", "cmd:JUMP")
    assert(settings.mapping["L3:"] == "cmd:JUMP", "legacy mapping writes must still work")
    CK.Profiles = {
        ready = false,
        SetBinding = function(_, kind, key, action)
            calls[#calls + 1] = { kind, key, action }
            settings[kind][key] = action
        end,
        BindingPairs = function(_, kind)
            if kind == "mapping" then return pairs({ ["L3:"] = "cmd:TOGGLERUN" }) end
            return pairs({ ["A:LT"] = "spell:133" })
        end,
        ClearBindings = function(_, kind) calls[#calls + 1] = { "clear", kind } end,
    }
    M:Set("L3", "", "cmd:TOGGLEUI")
    assert(#calls == 0 and settings.mapping["L3:"] == "cmd:TOGGLEUI", "unready profiles must preserve legacy writes")
    CK.Profiles.ready = true
    M:Set("L3", "", "cmd:TOGGLEAUTORUN")
    assert(#calls == 1 and calls[1][1] == "mapping" and calls[1][2] == "L3:", "mapping write missed profile owner")
    M.TriggerModifier = function() return "SHIFT" end
    M:SetReplaced("A", "LT", "spell:133")
    assert(#calls == 2 and calls[2][1] == "replaced", "replacement write missed profile owner")
    settings.replaced = { ["B:"] = false, ["X:"] = false }
    assert(M:GetReplaced("B", "") == nil, "replacement tombstones must read as unassigned")
    assert(M:ReplacedCount() == 1, "replacement count must include shared entries and omit tombstones")
    M:RestoreGameButtons()
    assert(calls[3][1] == "clear" and calls[3][2] == "replaced", "restore bypassed profile ownership")
    settings.mapping = { ["L5:"] = false, ["R4:"] = "spell:4" }
    settings.paddles = { L4 = { action = "spell:1" }, L5 = { action = "spell:2" }, R4 = { action = "spell:3" } }
    M:Init()
    assert(calls[4][1] == "mapping" and calls[4][2] == "L4:" and settings.mapping["L4:"] == "spell:1",
        "legacy paddle migration must use the profile owner")
    assert(settings.mapping["L5:"] == false and M:Get("L5", "") == nil,
        "migration must preserve explicit removals and reads must normalize them")
    assert(settings.mapping["R4:"] == "spell:4" and not settings.paddles.L4.action,
        "migration must preserve current bindings and consume old paddle assignments")
    settings.mapping = {}
    M.Apply, M.CoreActive, M.State = apply, function() return true end, function() return "free" end
    M.ApplyPaddle, M.ApplyReplaced, M.BlockFallbacks, M.UpdateMarks = noop, noop, noop, noop
    M:Apply()
    assert(bindings.PADLSTICK == "TOGGLERUN", "shared utility must actually bind through the effective iterator")
end)
assert(#failures == 0, table.concat(failures, "\n"))
print(passed .. " refresh regression groups passed")