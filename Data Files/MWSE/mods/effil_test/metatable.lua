local effil = require("effil")
local util = require("effil_test.util")

local function tear_down(metatable)
    collectgarbage()
    effil.gc.collect()

    -- if metatable is shared_table - it counts as gr object
    -- and it will be destroyed after tear_down
    if type(metatable) == "table" then
        local c = effil.gc.count()
        if c ~= 1 then
            print(("gc.count() shoud be %d, but %d"):format(1, c))
        end
    else
        local c = effil.gc.count()
        if c ~= 3 then
            print(("gc.count() shoud be %d, but %d"):format(3, c))
        end
    end
end

-- Register effil in global for iterators_p
local registerd = false

local unitwind = require("unitwind").new({
    enabled = require("effil_test.config").testMetatable,
    highlight = false,
    afterEach = tear_down,
    beforeAll = function ()
        if util.LUA_VERSION > 51 then
            -- something
        else
            if not _G.effil then
                _G.effil = effil
                registerd = true
            end
        end
    end,
    afterAll = function ()
        if util.LUA_VERSION > 51 then
            -- something
        else
            if registerd then
                _G.effil = nil
                registerd = false
            end
        end
    end
})

unitwind:start("effil metatable")

local function run_test_with_different_metatables(name, func, ...)
    local args = table.pack(...)
    unitwind:test(name .. "(regular table)", function() func({}, table.unpack(args)) end)
    unitwind:test(name .. "(shared table)", function() func(effil.table(), table.unpack(args)) end)
end

local function index_p(metatable)
    local share = effil.table()
    metatable.__index = function(t, key)
        return "mt_" .. effil.rawget(t, key .. "_origin")
    end
    effil.setmetatable(share, metatable)

    share.table_key_origin = "table_value"
    unitwind:expect(share.table_key).toBe("mt_table_value")
end

local function new_index_p(metatable)
    local share = effil.table()
    metatable.__newindex = function(t, key, value)
        effil.rawset(t, "mt_" .. key, "mt_" .. value)
    end
    effil.setmetatable(share, metatable)

    share.table_key = "table_value"
    unitwind:expect(share.mt_table_key).toBe("mt_table_value")
end

local function call_p(metatable)
    local share = effil.table()
    metatable.__call = function(t, val1, val2, val3)
        return tostring(val1) .. "_" .. tostring(val2), tostring(val2) .. "_" .. tostring(val3)
    end
    effil.setmetatable(share, metatable)

    local first_ret, second_ret = share("val1", "val2", "val3")
    unitwind:expect(first_ret).toBe("val1_val2")
    unitwind:expect(second_ret).toBe("val2_val3")
end

run_test_with_different_metatables("index_p", index_p)
run_test_with_different_metatables("new_index_p", new_index_p)
run_test_with_different_metatables("call_p", call_p)

local function binary_op_p(metatable, metamethod, op, exp_value)
    local testTable, operand = effil.table(), effil.table()
    metatable['__' .. metamethod] = function(left, right)
        left.was_called = true
        return left.value .. '_' .. right.value
    end
    effil.setmetatable(testTable, metatable)
    testTable.was_called = false
    testTable.value = "left"
    operand.value = "right"
    local left_operand, right_operand = table.unpack({ testTable, operand })
    unitwind:expect(op(left_operand, right_operand)).toBe(exp_value == nil and "left_right" or exp_value)
    unitwind:expect(testTable.was_called).toBe(true)
end

local function test_binary_op(...)
    run_test_with_different_metatables("binary_op_p", binary_op_p, ...)
end

test_binary_op("concat", function(a, b) return a .. b end)
test_binary_op("add", function(a, b) return a + b end)
test_binary_op("sub", function(a, b) return a - b end)
test_binary_op("mul", function(a, b) return a * b end)
test_binary_op("div", function(a, b) return a / b end)
test_binary_op("mod", function(a, b) return a % b end)
test_binary_op("pow", function(a, b) return a ^ b end)
test_binary_op("le", function(a, b) return a <= b end, true)
test_binary_op("lt", function(a, b) return a < b end, true)
test_binary_op("eq", function(a, b) return a == b end, true)


local function unary_op_p(metatable, metamethod, op)
    local share = effil.table()
    metatable['__' .. metamethod] = function(t)
        t.was_called = true
        return t.value .. "_suffix"
    end
    effil.setmetatable(share, metatable)

    share.was_called = false
    share.value = "value"
    unitwind:expect(op(share)).toBe("value_suffix")
    unitwind:expect(share.was_called).toBe(true)
end

local function test_unary_op(...)
    run_test_with_different_metatables("unary_op_p", unary_op_p, ...)
end

test_unary_op("unm", function(a) return -a end)
test_unary_op("tostring", function(a) return tostring(a) end)
test_unary_op("len", function(a) return #a end)

unitwind:finish()

unitwind.afterEach = util.default_tear_down
unitwind:start("effil shared_table_with_metatable")

local function iterators_p(iterator_type, iterator_trigger)
    local share = effil.table()
    local iterator = iterator_type
    effil.setmetatable(share, {
        ["__" .. iterator] = function(table)
            return function(t, key)
                local effil = require("effil")
                local ret = (key and key * 2) or 1
                if ret > 2 ^ 10 then
                    return nil
                end
                return ret, effil.rawget(t, ret)
            end, table
        end
    })
    -- Add some values
    for i = 0, 10 do
        local pow = 2 ^ i
        share[pow] = math.random(pow)
    end
    -- Add some noise
    for i = 1, 100 do
        share[math.random(1000) * 10 - 1] = math.random(1000)
    end

    -- Check that *pairs iterator works
    local pow_iter = 1
    for k, v in _G[iterator_trigger][iterator](share) do
        unitwind:expect(k).toBe(pow_iter)
        unitwind:expect(v).toBe(share[pow_iter])
        pow_iter = pow_iter * 2
    end
    unitwind:expect(pow_iter).toBe(2 ^ 11)
end

unitwind:test("iterators_p(\"pairs\", \"effil\")", function() iterators_p("pairs", "effil") end)
unitwind:test("iterators_p(\"ipairs\", \"effil\")", function() iterators_p("ipairs", "effil") end)

if util.LUA_VERSION > 51 then
    unitwind:test("iterators_p(\"pairs\", \"_G\")", function() iterators_p("pairs", "_G") end)
    unitwind:test("iterators_p(\"ipairs\", \"_G\")", function() iterators_p("ipairs", "_G") end)
end -- LUA_VERSION > 51

unitwind:test("as_shared_table", function()
    local share = effil.table()
    local mt = effil.table()
    effil.setmetatable(share, mt)
    -- Empty metatable
    unitwind:expect(share.table_key).toBe(nil)

    -- Only __index metamethod
    mt.__index = function(t, key)
        return "mt_" .. effil.rawget(t, key .. "_origin")
    end
    share.table_key_origin = "table_value"
    unitwind:expect(share.table_key).toBe("mt_table_value")

    -- Both __index and __newindex metamethods
    mt.__newindex = function(t, key, value)
        effil.rawset(t, key, "mt_" .. value)
    end
    share.table_key = "table_value"
    unitwind:expect(share.table_key).toBe("mt_table_value")

    -- Remove __index, use only __newindex metamethods
    mt.__index = nil
    share.table_key = "table_value"
    unitwind:expect(share.table_key).toBe("mt_table_value")
end)

unitwind:test("metatable_serialization", function()
    local table_with_mt = setmetatable({}, { a = 1 })
    local tbl = effil.table(table_with_mt)

    unitwind:expect(effil.getmetatable(tbl)).NOT.toBe(nil)
    unitwind:expect(effil.getmetatable(tbl).a).toBe(1)
end)

unitwind:test("metatable_with_function_with_upvalues", function()
    local common_table = { aa = 2 }
    local tbl = setmetatable({}, {
        a = function() return common_table end,
        b = function() return common_table end
    })

    local mt = effil.getmetatable(effil.table(tbl))
    unitwind:expect(mt).NOT.toBe(nil)
    if mt then
        unitwind:expect(select(2, debug.getupvalue(mt.a, 1))).toBe(select(2, debug.getupvalue(mt.b, 1)))
    end
end)

unitwind:test("check_eq_metamethod", function()
    local left_table = effil.table()
    local right_table = effil.table()
    local left_table_clone = (effil.table { left_table }[1]) -- userdata will change

    unitwind:expect(left_table == right_table).toBe(false)
    unitwind:expect(left_table == left_table_clone).toBe(true)
    unitwind:expect(left_table == effil.channel()).toBe(false)

    effil.setmetatable(left_table, { __eq = function() return false end })
    unitwind:expect(left_table == left_table_clone).toBe(false)

    effil.setmetatable(left_table, { __eq = function() return true end })
    unitwind:expect(left_table == right_table).toBe(true)
    unitwind:expect(left_table == effil.channel()).toBe(false)

    effil.setmetatable(left_table, { __eq = function() return false end })
    effil.setmetatable(right_table, { __eq = function() return true end })
    unitwind:expect(left_table == right_table).toBe(false)

    effil.setmetatable(left_table, nil)
    unitwind:expect(left_table == right_table).toBe(true)
end)

unitwind:test("table_as_index", function()
    local tbl = effil.table {}
    local mt = effil.table { a = 1 }
    local mt2 = effil.table { b = 2 }
    local mt3 = effil.table { c = 2 }

    effil.setmetatable(tbl, { __index = mt })
    unitwind:expect(tbl.a).toBe(1)
    unitwind:expect(tbl.b).toBe(nil)

    effil.setmetatable(mt, { __index = mt2 })
    unitwind:expect(tbl.a).toBe(1)
    unitwind:expect(tbl.b).toBe(2)

    effil.setmetatable(mt2, { __index = mt3 })
    unitwind:expect(tbl.a).toBe(1)
    unitwind:expect(tbl.b).toBe(2)
    unitwind:expect(tbl.c).toBe(2)
end)

unitwind:test("next_iterator", function()
    local visited = { a = 1, [2] = 3, [true] = "asd", [2.2] = "qwe" }
    local share = effil.table(visited)

    local key, value = effil.next(share)
    while key do
        unitwind:expect(visited[key]).toBe(value)
        visited[key] = nil
        key, value = effil.next(share, key)
    end
    unitwind:expect(next(visited)).toBe(nil) -- table is empty
end)

unitwind:finish()
