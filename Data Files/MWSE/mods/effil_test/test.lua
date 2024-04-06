local effil = require("effil")

local function default_tear_down()
    collectgarbage()
    effil.gc.collect()
    -- effil.G is always present
    -- thus, gc has one object
    if effil.gc.count() ~= 1 then
        print("Not all objects were removed, gonna sleep for 2 seconds")
        effil.sleep(2)

        collectgarbage()
        effil.gc.collect()
    end
    assert(effil.gc.count() == 1)
end

local unitwind = require("unitwind").new({
    enabled = true,
    highlight = false,
    -- beforeAll = nil,
    -- afterAll = nil,
    -- beforeEach = nil,
    afterEach = default_tear_down,
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

unitwind:test("store same value", function()
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

unitwind:test("check iterative", function()
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

unitwind:test("check step", function()
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
