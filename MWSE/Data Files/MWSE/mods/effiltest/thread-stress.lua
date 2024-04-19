local effil = require("effil")
local util = require("effiltest.util")

local unitwind = require("unitwind").new({
    enabled = util.STRESS > 0 and require("effiltest.config").testThreadStress,
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

unitwind:start("effil thread-stress")
unitwind:test("time", function()
    local function check_time(real_time, use_time, metric)
        local start_time = os.time()
        effil.sleep(use_time, metric)
        almost_equal(os.time(), start_time + real_time, 2)
    end
    check_time(4, 4, nil) -- seconds by default
    check_time(4, 4, 's')
    check_time(4, 4000, 'ms')
    check_time(60, 1, 'm')
end)

unitwind:finish()

