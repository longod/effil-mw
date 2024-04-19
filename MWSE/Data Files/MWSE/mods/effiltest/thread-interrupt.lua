local effil = require("effil")
local util = require("effiltest.util")

local unitwind = require("unitwind").new({
    enabled = require("effiltest.config").testThreadInterrupt,
    highlight = false,
    afterEach = util.default_tear_down,
})

---@param l number
---@param r number
---@param diff number
local function almost_equal(l, r, diff)
    unitwind:expect(require("math").abs(l - r) > diff).toBe(false)
    -- fail("|" .. tostring(l) .. " - " .. tostring(r) .."| > " .. tostring(diff))
end

unitwind:start("effil thread-interrupt")

local function interruption_test(worker)
    local state = effil.table { stop = false }

    local ctx = effil.thread(worker)
    ctx.step = 0
    local thr = ctx(state)

    effil.sleep(500, 'ms') -- let thread starts

    local start_time = os.time()
    thr:cancel(1)

    unitwind:expect(thr:status()).toBe("cancelled")
    almost_equal(os.time(), start_time, 1)
    state.stop = true
end

local get_thread_for_test = function(state)
    local runner = effil.thread(function()
        while not state.stop do end
    end)
    runner.step = 0
    return runner()
end

unitwind:test("thread_wait", function()
    interruption_test(function(state)
        get_thread_for_test(state):wait()
    end)
end)

unitwind:test("thread_get", function()
    interruption_test(function(state)
        get_thread_for_test(state):get()
    end)
end)

unitwind:test("thread_cancel", function()
    interruption_test(function(state)
        get_thread_for_test(state):cancel()
    end)
end)

unitwind:test("thread_pause", function()
    interruption_test(function(state)
        get_thread_for_test(state):pause()
    end)
end)

unitwind:test("channel_pop", function()
    interruption_test(function()
        effil.channel():pop()
    end)
end)

unitwind:test("sleep", function()
    interruption_test(function()
        effil.sleep(20)
    end)
end)

unitwind:test("yield", function()
    interruption_test(function()
        while true do
            effil.yield()
        end
    end)
end)

unitwind:finish()
