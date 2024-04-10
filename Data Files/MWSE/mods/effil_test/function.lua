local effil = require("effil")
local util = require("effil_test.util")

local unitwind = require("unitwind").new({
    enabled = require("effil_test.config").testFunction,
    highlight = false,
    afterEach = util.default_tear_down,
})

unitwind:start("effil function")

local function check_truly_c_functions_p(func)
    unitwind:expect(type(func)).toBe("function")

    local t = effil.table()
    local ret, _ = pcall(function() t["func"] = func end)
    unitwind:expect(ret).toBe(true)
end
unitwind:test("check_truly_c_functions_p(coroutine.create)", function() check_truly_c_functions_p(coroutine.create) end)
unitwind:test("check_truly_c_functions_p(effil.size)", function() check_truly_c_functions_p(effil.size) end)

unitwind:test("check_tosting_c_functions", function()
    local t = effil.table()

    if jit then
        -- in LuaJIT it's not real C function
        local ret, msg = pcall(function() t["tostring"] = tostring end)
        unitwind:expect(ret).toBe(false)
        unitwind:expect(msg).toBe("effil.table: can't get C function pointer")
    else
        t["tostring"] = tostring

        if util.LUA_VERSION > 51 then
            unitwind:expect(t["tostring"]).toBe(tostring)
        else
            unitwind:expect(t["tostring"]).NOT.toBe(tostring)
        end -- LUA_VERSION > 51

        unitwind:expect(t["tostring"](123)).toBe(tostring(123))
        unitwind:expect(effil.thread(function() return t["tostring"](123) end)():get()).toBe(tostring(123))

        local foo = tostring
        unitwind:expect(foo).toBe(tostring)
        unitwind:expect(foo(123)).toBe(tostring(123))
        unitwind:expect(effil.thread(function() return foo(123) end)():get()).toBe(tostring(123))
    end -- jit
end)

unitwind:finish()


