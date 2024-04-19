local effil = require("effil")
local util = require("effiltest.util")

local unitwind = require("unitwind").new({
    enabled = util.STRESS > 0 and require("effiltest.config").testGCStress,
    highlight = false,
    afterEach = util.default_tear_down,
})

unitwind:start("effil gc-stress")

unitwind:test("create_and_collect_in_parallel", function()
    local function worker()
        local nested_table = {
            {}, --[[1 level]]
            { {} }, --[[2 levels]]
            { { {} } }, --[[3 levels]]
            { { { {} } } } --[[4 levels]]
        }
        for i = 1, 20 * util.STRESS do
            for t = 1, 10 do
                local tbl = effil.table(nested_table)
                for l = 1, 10 do
                    tbl[l] = nested_table
                end
            end
            collectgarbage()
            effil.gc.collect()
        end
    end

    local thread_num = 10
    local threads = {}

    for i = 1, thread_num do
        threads[i] = effil.thread(worker)(i)
    end

    for i = 1, thread_num do
        unitwind:expect(threads[i]:wait()).toBe("completed")
    end
end)

unitwind:test("regress_for_concurent_thread_creation", function()
    local a = function() end
    local b = function() end

    for i = 1, 2000 do
        effil.thread(function(aa, bb)
            aa()
            bb()
        end)(a, b)
    end
end)


unitwind:test("regress_for_concurent_function_creation", function()
    local a = function() end
    local b = function() end

    for i = 1, 2000 do
        effil.thread(function()
            a()
            b()
        end)()
    end
end)

unitwind:finish()
