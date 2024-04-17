local effil = require("effil")
local util = require("effil_test.util")

local unitwind = require("unitwind").new({
    enabled = require("effil_test.config").testSharedTable,
    highlight = false,
    afterEach = util.default_tear_down,
})

unitwind:start("effil shared-table")

unitwind:test("constructor", function()
    local share = effil.table {
        key = "value"
    }
    unitwind:expect(share.key).toBe("value")
    unitwind:expect(pcall(effil.table, "")).toBe(false)
    unitwind:expect(pcall(effil.table, 22)).toBe(false)
    unitwind:expect(pcall(effil.table, effil.table())).toBe(false)
end)

if util.LUA_VERSION > 51 then
    unitwind:test("pairs", function()
        local share = effil.table()
        local data = { 0, 0, 0, ["key1"] = 0, ["key2"] = 0, ["key3"] = 0 }

        for k, _ in pairs(data) do
            share[k] = k .. "-value"
        end

        for k, v in pairs(share) do
            unitwind:expect(data[k]).toBe(0)
            data[k] = 1
            unitwind:expect(v).toBe(k .. "-value")
        end

        for k, v in pairs(data) do
            unitwind:expect(v).toBe(1)
        end

        for k, v in ipairs(share) do
            unitwind:expect(data[k]).toBe(1)
            data[k] = 2
            unitwind:expect(v).toBe(k .. "-value")
        end

        for k, v in ipairs(data) do
            unitwind:expect(v).toBe(2)
        end
    end)
end -- LUA_VERSION > 51

unitwind:test("length", function()
    local share = effil.table()
    share[1] = 10
    share[2] = 20
    share[3] = 30
    share[4] = 40
    share["str"] = 50
    unitwind:expect(#share).toBe(4)
    share[3] = nil
    unitwind:expect(#share).toBe(2)
    share[1] = nil
    unitwind:expect(#share).toBe(0)
end)

unitwind:test("size", function()
    local share = effil.table()
    unitwind:expect(effil.size(share)).toBe(0)
    share[1] = 10
    unitwind:expect(effil.size(share)).toBe(1)
    share[2] = "value1"
    share["key1"] = function() end
    unitwind:expect(effil.size(share)).toBe(3)
    share[2] = nil
    unitwind:expect(effil.size(share)).toBe(2)
end)

unitwind:test("user_data_classification", function()
    local share = effil.table()
    share.thread = effil.thread(function(a, b) return a + b end)(19, 33)
    share.sub_table = effil.table()
    share.sub_table.some_key = "some_value"

    local result = share.thread:get()
    unitwind:expect(result).toBe(52)
    unitwind:expect(share.sub_table.some_key).toBe("some_value")
end)

unitwind:test("global", function()
    unitwind:expect(effil.G).NOT.toBe(nil)
    effil.G.test_key = "test_value"
    local thr = effil.thread(function()
        if effil.G == nil or effil.G.test_key ~= "test_value" then
            error("Invalid value of global table: " .. tostring(effil.G and effil.G.test_key or nil))
        end
        effil.G.test_key = "checked"
    end)()
    local status, err = thr:wait()
    if status == "failed" then
        print("Thread failed with message: " .. err)
    end
    unitwind:expect(status).toBe("completed")
    unitwind:expect(effil.G.test_key).toBe("checked")
end)

unitwind:finish()
