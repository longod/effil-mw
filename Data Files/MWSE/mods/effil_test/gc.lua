local effil = require("effil")
local util = require("effil_test.util")


local unitwind = require("unitwind").new({
    enabled = true,
    highlight = false,
    afterEach = util.default_tear_down,
})

unitwind:start("effil gc")

unitwind:test("cleanup", function()
    collectgarbage()
    effil.gc.collect()
    unitwind:expect(effil.gc.count()).toBe(1)

    for i = 0, 10000 do
        local tmp = effil.table()
    end

    collectgarbage()
    effil.gc.collect()
    unitwind:expect(effil.gc.count()).toBe(1)
end)

unitwind:test("disable", function()
    local nobjects = 10000

    collectgarbage()
    effil.gc.collect()
    unitwind:expect(effil.gc.count()).toBe(1)

    effil.gc.pause()
    unitwind:expect(effil.gc.enabled()).toBe(false)

    for i = 1, nobjects do
        local tmp = effil.table()
    end

    unitwind:expect(effil.gc.count()).toBe(nobjects + 1)
    collectgarbage()
    effil.gc.collect()
    unitwind:expect(effil.gc.count()).toBe(1)

    effil.gc.resume()
end)

unitwind:test("store_same_value", function()
    local fill = function(c)
        local a = effil.table {}
        c:push(a)
        c:push(a)
    end

    local c = effil.channel()
    fill(c)

    c:pop()
    collectgarbage()
    effil.gc.collect()
    c:pop()[1] = 0
end)

local function create_fabric()
    local f = { data = {} }

    function f:create(num)
        for i = 1, num do
            table.insert(self.data, effil.table())
        end
    end

    function f:remove(num)
        for i = 1, num do
            table.remove(self.data, 1)
        end
    end

    return f
end

unitwind:test("check_iterative", function()
    unitwind:expect(effil.gc.count()).toBe(1)
    local fabric = create_fabric()
    unitwind:expect(effil.gc.step()).toBe(2)

    fabric:create(199)
    unitwind:expect(effil.gc.count()).toBe(200)

    fabric:remove(50)
    collectgarbage()
    unitwind:expect(effil.gc.count()).toBe(200)

    fabric:create(1) -- trigger GC
    unitwind:expect(effil.gc.count()).toBe(151)
    fabric:remove(150)

    fabric:create(149)
    unitwind:expect(effil.gc.count()).toBe(300)
    collectgarbage()

    fabric:create(1) -- trigger GC
    unitwind:expect(effil.gc.count()).toBe(151)
end)

unitwind:test("check_step", function()
    local fabric = create_fabric()
    effil.gc.step(3)

    fabric:create(299)
    fabric:remove(100)
    unitwind:expect(effil.gc.count()).toBe(300)
    collectgarbage()

    fabric:create(1) -- trigger GC
    unitwind:expect(effil.gc.count()).toBe(201)

    unitwind:expect(effil.gc.step(2.5)).toBe(3)

    fabric:create(299)
    fabric:remove(250)
    unitwind:expect(effil.gc.count()).toBe(500)
    collectgarbage()

    fabric:create(1) -- trigger GC
    unitwind:expect(effil.gc.count()).toBe(251)
end)

unitwind:finish()
