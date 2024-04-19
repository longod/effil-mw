local effil = require("effil")
local util = require("effiltest.util")

-- This test is originally called from a thread test, but since that does not work correctly in MWSE, it is called separately.

local unitwind = require("unitwind").new({
    enabled = require("effiltest.config").testSize,
    highlight = false,
    afterEach = util.default_tear_down, -- Not necessary when calling from thread.lua
})

unitwind:start("effil size")

unitwind:test("size", function()
    local st = effil.table()
    st[0] = 1
    st[1] = 0

    local chan = effil.channel()
    chan:push(0)
    chan:push(2)

    unitwind:expect(effil.size(st)).toBe(2)
    unitwind:expect(effil.size(chan)).toBe(2)
end)

unitwind:finish()

