-- Run from the addon root with Lua 5.1. Only the clock and motor APIs are simulated.
local function equal(actual, expected, message)
    assert(actual == expected, (message or "unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function fixture()
    local clock, serial, scheduled = 0, 0, {}
    local result = { stops = 0, writes = {} }
    function wipe(t) for k in pairs(t) do t[k] = nil end end
    function GetTime() return clock end
    C_Timer = { NewTimer = function(delay, callback)
        serial = serial + 1
        local timer = { at = clock + delay, callback = callback, serial = serial }
        function timer:Cancel() self.cancelled = true end
        scheduled[#scheduled + 1] = timer
        return timer
    end }
    C_GamePad = {
        SetVibration = function(motor, intensity)
            result.writes[#result.writes + 1] = { motor = motor, intensity = intensity, at = clock }
        end,
        StopVibration = function() result.stops = result.stops + 1 end,
    }
    local CK = { db = { settings = { vibration = { enabled = true, intensity = 0.6, events = {} } } } }
    assert(loadfile("Vibration.lua"))("EasyController", CK)
    result.vibration, result.settings = CK.Vibration, CK.Vibration:Settings()
    function result:advance(seconds)
        local target = clock + seconds
        while true do
            local nextTimer
            for _, timer in ipairs(scheduled) do
                if not timer.cancelled and not timer.done and timer.at <= target
                    and (not nextTimer or timer.at < nextTimer.at
                        or (timer.at == nextTimer.at and timer.serial < nextTimer.serial)) then
                    nextTimer = timer
                end
            end
            if not nextTimer then break end
            clock, nextTimer.done = nextTimer.at, true
            nextTimer.callback()
        end
        clock = target
    end
    return result
end

local tests = {
    { "wheel and keyboard feedback cannot cut off a death alert", function()
        local f = fixture()
        f.settings.events.keyPress.on = true
        f.vibration:Fire("death")
        local stops, writes = f.stops, #f.writes
        f:advance(0.01)
        f.vibration:Fire("wheelTick")
        f.vibration:Fire("keyPress")
        equal(f.stops, stops, "feedback stopped the alert")
        equal(#f.writes, writes, "feedback changed the motors")
        f:advance(0.30)
        assert(#f.writes > writes, "death alert stopped refreshing its motors")
        equal(f.stops, stops, "death alert ended early")
        f:advance(0.30)
        equal(f.stops, stops + 1, "death alert did not finish")
        local finishedWrites = #f.writes
        f:advance(1)
        equal(#f.writes, finishedWrites, "suppressed feedback was queued")
    end },
    { "important alerts replace feedback without an old completion stopping them", function()
        local f = fixture()
        f.vibration:Fire("wheelTick")
        f:advance(0.01)
        f.vibration:Fire("death")
        local stops = f.stops
        equal(f.writes[#f.writes - 1].intensity, 0.8 * 0.6, "death motor intensity")
        f:advance(0.04)
        equal(f.stops, stops, "cancelled feedback completion stopped the death alert")
        f:advance(0.57)
        equal(f.stops, stops + 1, "replacement alert did not finish")
    end },
    { "combat warnings survive ordinary notifications and feedback", function()
        local f = fixture()
        f.vibration:Fire("interrupted")
        local stops = f.stops
        f.vibration:Fire("whisper")
        f.vibration:Fire("wheelTick")
        equal(f.stops, stops, "lower-priority notification replaced warning")
        f.vibration:Fire("death")
        equal(f.stops, stops + 1, "higher-priority death did not replace warning")
    end },
    { "equal-priority notifications retain newest-event behavior", function()
        local f = fixture()
        f.vibration:Fire("whisper")
        local stops = f.stops
        f.vibration:Fire("invite")
        equal(f.stops, stops + 1, "equal-priority notification did not replace")
    end },
    { "completion and explicit stop release the priority", function()
        local f = fixture()
        f.vibration:Fire("death")
        f:advance(0.61)
        local stops = f.stops
        f.vibration:Fire("wheelTick")
        equal(f.stops, stops + 1, "completed alert still blocks feedback")
        f.vibration:Fire("death")
        f.vibration:Stop()
        f:advance(0.04)
        stops = f.stops
        f.vibration:Fire("wheelTick")
        equal(f.stops, stops + 1, "explicit stop still blocks feedback")
    end },
    { "settings and diagnostic previews can replace alerts", function()
        local f = fixture()
        f.vibration:Fire("death")
        local stops = f.stops
        f.vibration:Play("pulse", 0.5)
        equal(f.stops, stops + 1, "preview could not replace alert")
        equal(f.writes[#f.writes - 1].intensity, 0.8 * 0.6 * 0.5, "preview strength changed")
        stops = f.stops
        f.vibration:Fire("wheelTick")
        equal(f.stops, stops, "feedback interrupted preview")
        f:advance(0.19)
        f.vibration:Fire("wheelTick")
        equal(f.stops, stops + 2, "preview did not release priority")
    end },
    { "disabling and stopping cancels all pending vibration", function()
        local f = fixture()
        f.vibration:Fire("death")
        f.settings.enabled = false
        f.vibration:Stop() -- Same callback used by the settings switches.
        local stops, writes = f.stops, #f.writes
        f:advance(1)
        f.vibration:Fire("wheelTick")
        equal(f.stops, stops, "disabled event or cancelled timer stopped motors again")
        equal(#f.writes, writes, "disabled event or cancelled timer wrote motors")
        f.settings.enabled = true
        f.settings.events.death.on = false
        f.vibration:Fire("death")
        equal(#f.writes, writes, "disabled event played")
        f.vibration:Play("pulse") -- Settings enable/intensity/pattern callbacks preview directly.
        assert(#f.writes > writes, "settings preview failed after disabling an event")
    end },
    { "event rate limits remain unchanged", function()
        local f = fixture()
        for _, case in ipairs({ { "whisper", 0.4 }, { "aggroLost", 3 }, { "wheelTick", 0.03 } }) do
            local key, gap = case[1], case[2]
            f.settings.events[key].on = true
            f.vibration:Fire(key)
            f.vibration:Stop()
            local writes = #f.writes
            f:advance(gap * 0.9)
            f.vibration:Fire(key)
            equal(#f.writes, writes, key .. " rate limit shortened")
            f:advance(gap * 0.2)
            f.vibration:Fire(key)
            assert(#f.writes > writes, key .. " rate limit lengthened")
            f.vibration:Stop()
        end
    end },
}

local failed = 0
for _, test in ipairs(tests) do
    local ok, err = pcall(test[2])
    if ok then
        print("PASS: " .. test[1])
    else
        failed = failed + 1
        print("FAIL: " .. test[1] .. " - " .. tostring(err))
    end
end
assert(failed == 0, tostring(failed) .. " vibration regression(s) failed")
print("All vibration regressions passed (" .. #tests .. ").")
