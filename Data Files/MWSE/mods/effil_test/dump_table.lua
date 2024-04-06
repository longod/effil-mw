local effil = require("effil")
local util = require("effil_test.util")

local unitwind = require("unitwind").new({
    enabled = true,
    highlight = false,
    afterEach = util.default_tear_down,
})

unitwind:start("effil dump_table")

local function table_included(left, right, path)
    local path = path or ""
    if type(left) ~= type(right) then
        return false, "[" .. path .. "]: " .. " got " .. type(right) .. "instead of " .. type(left)
    end

    for k, v in pairs(left) do
        local subpath = path .. '.' .. tostring(k)
        if type(v) == 'table' then
            local ret, msg = table_included(v, right[k], subpath)
            if not ret then
                return false, msg
            end
        elseif right[k] ~= v then
            return false, "[" .. subpath .. "]: got " .. tostring(right[k]) .. " instead of " .. tostring(v)
        end
    end
    return true
end

local function table_equals(left, right)
    local ret, msg = table_included(left, right)
    if not ret then
        return false, msg
    end
    return table_included(right, left)
end

unitwind:test("compare_primitives", function()
    local origin = {
        1,
        "str",
        key = "value",
        key2 = { 2, [false] = "asd", { [44] = { true } } }
    }

    local result = effil.dump(effil.table(origin))
    local ret, err = table_equals(origin, result)
    if ret == false then
        print(err)
    end
    unitwind:expect(ret).toBe(true)
end)

unitwind:test("compare_functions", function()
    local origin = {
        func = function(a, b) return a + b end,
        nested = {
            [function(a, b) return a - b end] = 2
        },
    }

    local result = effil.dump(effil.table(origin))
    unitwind:expect(origin.func(2, 53)).toBe(result.func(2, 53))
    for origin_key, origin_value in pairs(origin.nested) do
        for res_key, res_value in pairs(result.nested) do
            unitwind:expect(origin_key(23, 11)).toBe(res_key(23, 11))
            unitwind:expect(origin_value).toBe(res_value)
        end
    end
end)

unitwind:test("reference_loop", function()
    local origin = {}
    origin.nested = { 1, origin, 2 }
    origin.nested.nested_loop = { [origin] = origin.nested }

    local result = effil.dump(effil.table(origin))
    unitwind:expect(result.nested[1]).toBe(1)
    unitwind:expect(result.nested[2]).toBe(result)
    unitwind:expect(result.nested[3]).toBe(2)
    unitwind:expect(result.nested.nested_loop[result]).toBe(result.nested)
end)

unitwind:test("regular_table", function()
    local origin = {}
    unitwind:expect(origin).toBe(effil.dump(origin))
end)

unitwind:test("upvalues_with_loop", function()
    local origin = {}
    local function foo()
        origin.key = "value"
    end
    origin.foo = foo

    local result = effil.dump(origin)
    local name, value = debug.getupvalue(result.foo, 1)
    unitwind:expect(value).toBe(result)
    result.foo()
    unitwind:expect(result.key).toBe("value")
end)

unitwind:test("with_metatable", function()
    local tbl = effil.setmetatable({}, effil.setmetatable({ a = 1 }, { b = 2 }))
    local dumped = effil.dump(tbl)

    local mt = getmetatable(dumped)
    unitwind:expect(mt).NOT.toBe(nil)
    unitwind:expect(mt.a).toBe(1)

    local mt2 = getmetatable(mt)
    unitwind:expect(mt2).NOT.toBe(nil)
    unitwind:expect(mt2.b).toBe(2)
end)

unitwind:finish()
