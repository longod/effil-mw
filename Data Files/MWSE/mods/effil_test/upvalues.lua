local effil = require("effil")
local util = require("effil_test.util")

local unitwind = require("unitwind").new({
    enabled = true,
    highlight = false,
    afterEach = util.default_tear_down,
})

unitwind:start("effil upvalues")

local foo = function() return 22 end

local function check_single_upvalue_p(type_creator, type_checker)
    local obj = type_creator()
    local thread_worker = function(checker) return effil.type(obj) .. ": " .. checker(obj) end
    local ret = effil.thread(thread_worker)(type_checker):get()

    print("Returned: " .. ret)
    unitwind:expect(ret).toBe(effil.type(obj) .. ": " .. type_checker(obj))
end

unitwind:test("check_single_upvalue_p(1488)", function()
    check_single_upvalue_p(function() return 1488 end,
        function() return "1488" end)
end)

unitwind:test("check_single_upvalue_p(\"awesome\")", function()
    check_single_upvalue_p(function() return "awesome" end,
        function() return "awesome" end)
end)

unitwind:test("check_single_upvalue_p(true)", function()
    check_single_upvalue_p(function() return true end,
        function() return "true" end)
end)

unitwind:test("check_single_upvalue_p(nil)", function()
    check_single_upvalue_p(function() return nil end,
        function() return "nil" end)
end)

unitwind:test("check_single_upvalue_p(function)", function()
    check_single_upvalue_p(function() return foo end,
        function(f) return f() end)
end)

unitwind:test("check_single_upvalue_p(effil.table)",
    function()
        check_single_upvalue_p(function() return effil.table({ key = 44 }) end,
            function(t) return t.key end)
    end)

unitwind:test("check_single_upvalue_p(effil.channel)",
    function()
        check_single_upvalue_p(function()
                local c = effil.channel()
                c:push(33)
                c:push(33)
                return c
            end,
            function(c) return c:pop() end)
    end)

unitwind:test("check_single_upvalue_p (effil.thread)",
    function()
        check_single_upvalue_p(function() return effil.thread(foo)() end,
            function(t) return t:get() end)
    end)

unitwind:test("check_invalid_coroutine", function()
    local obj = coroutine.create(foo)
    local thread_worker = function() return tostring(obj) end
    local ret, err = pcall(effil.thread, thread_worker)
    if ret then
        err():wait()
    end
    unitwind:expect(ret).toBe(false)
    print("Returned: " .. err)
    local upvalue_num = util.LUA_VERSION > 51 and 2 or 1
    unitwind:expect(err).toBe("effil.thread: bad function upvalue #" .. upvalue_num ..
        " (unable to store object of thread type)")
end)

unitwind:test("check_table", function()
    local obj = { key = "value" }
    local thread_worker = function() return effil.type(obj) .. ": " .. obj.key end
    local ret = effil.thread(thread_worker)():get()

    print("Returned: " .. ret)
    unitwind:expect(ret).toBe("effil.table: value")
end)

unitwind:test("check_global_env", function()
    local obj1 = 13           -- local
    Obj2 = { key = "origin" } -- global
    local obj3 = 79           -- local

    local function foo()      -- _ENV is 2nd upvalue
        return obj1, Obj2.key, obj3
    end

    local function thread_worker(func)
        obj1 = 31                -- global
        Obj2 = { key = "local" } -- global
        obj3 = 97                -- global
        return table.concat({ func() }, ", ")
    end

    local ret = effil.thread(thread_worker)(foo):get()
    print("Returned: " .. ret)
    unitwind:expect(ret).toBe("13, local, 79")
end)

if util.LUA_VERSION > 51 then
    unitwind:test("check_custom_env", function()
        local function create_foo()
            local _ENV = { key = 'value' }
            return function()
                ---@diagnostic disable-next-line: undefined-global
                return key
            end
        end

        local foo = create_foo()
        local ret = effil.thread(foo)():get()
        unitwind:expect(ret).toBe('value')
    end)
end -- LUA_VERSION > 51

unitwind:finish()
