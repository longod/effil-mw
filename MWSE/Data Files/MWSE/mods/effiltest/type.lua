local effil = require("effil")
local util = require("effiltest.util")

local unitwind = require("unitwind").new({
    enabled = require("effiltest.config").testType,
    highlight = false,
    afterEach = util.default_tear_down,
})

unitwind:start("effil type")

unitwind:test("check all types", function()
    unitwind:expect(effil.type(1)).toBe("number")
    unitwind:expect(effil.type("string")).toBe("string")
    unitwind:expect(effil.type(true)).toBe("boolean")
    unitwind:expect(effil.type(nil)).toBe("nil")
    unitwind:expect(effil.type(function() end)).toBe("function")
    unitwind:expect(effil.type(effil.table())).toBe("effil.table")
    unitwind:expect(effil.type(effil.channel())).toBe("effil.channel")
    local thr = effil.thread(function() end)()
    unitwind:expect(effil.type(thr)).toBe("effil.thread")
    thr:wait()
end)

unitwind:finish()
