local effil = require("effil")
local util = require("effil_test.util")

local unitwind = require("unitwind").new({
    enabled = true,
    highlight = false,
})

unitwind:start("effil type_mismatch")

local function generate_tests()
    local function create_object_generator(name, func)
        return setmetatable({ name = name }, {
            __call = func,
            __tostring = function() return name end
        })
    end
    local basic_type_mismatch_test_p = function(err_msg, wrong_arg_num, func_name, ...)
        local func_to_call = func_name
        if type(func_name) == "string" then
            func_to_call = effil
            for word in string.gmatch(func_name, "[^%.]+") do
                func_to_call = func_to_call[word]
                unitwind:expect(func_to_call).NOT.toBe(nil)
            end
        end

        local ret, err = pcall(func_to_call, ...)
        unitwind:expect(ret).toBe(false)
        print("Original error: '" .. err .. "'")

        -- because error may start with trace back
        local trunc_err = err
        if string.len(err) > string.len(err_msg) then
            trunc_err = string.sub(err, string.len(err) - string.len(err_msg) + 1, string.len(err))
        end
        unitwind:expect(trunc_err).toBe(err_msg)
    end

    local function input_types_mismatch_p(wrong_arg_num, expected_type, func_name, ...)
        local args = { ... }
        local err_msg = "bad argument #" .. wrong_arg_num .. " to " ..
            (type(func_name) == "string" and "'effil." .. func_name or func_name.name) ..
            "' (" .. expected_type .. " expected, got " .. effil.type(args[wrong_arg_num]) .. ")"
        basic_type_mismatch_test_p(err_msg, wrong_arg_num, func_name, ...)
    end

    local function unsupported_type_p(wrong_arg_num, func_name, ...)
        local args = { ... }
        local err_msg = (type(func_name) == "string" and "effil." .. func_name or func_name.name)
            .. ": unable to store object of " .. effil.type(args[wrong_arg_num]) .. " type"
        basic_type_mismatch_test_p(err_msg, wrong_arg_num, func_name, ...)
    end

    local channel_push_generator = create_object_generator("effil.channel:push",
        function(_, ...)
            return effil.channel():push(...)
        end
    )

    local thread_runner_generator = create_object_generator("effil.thread",
        function(_, ...)
            return effil.thread(function() end)(...)
        end
    )

    local table_set_value_generator = create_object_generator("effil.table",
        function(_, key, value)
            effil.table()[key] = value
        end
    )

    local table_get_value_generator = create_object_generator("effil.table",
        function(_, key)
            return effil.table()[key]
        end
    )

    local func = function() end
    local stable = effil.table()
    local thread = effil.thread(func)()
    thread:wait()
    local lua_thread = coroutine.create(func)

    local all_types = { 22, "s", true, {}, stable, func, thread, effil.channel(), lua_thread }

    for _, type_instance in ipairs(all_types) do
        local typename = effil.type(type_instance)

        -- effil.getmetatable
        if typename ~= "effil.table" then
            unitwind:test("input_types_mismatch_p(1, \"effil.table\", \"getmetatable\", type_instance)",
                function() input_types_mismatch_p(1, "effil.table", "getmetatable", type_instance) end)
        end

        -- effil.setmetatable
        if typename ~= "table" and typename ~= "effil.table" then
            unitwind:test("input_types_mismatch_p(1, \"table\", \"setmetatable\", type_instance, 44)",
                function() input_types_mismatch_p(1, "table", "setmetatable", type_instance, 44) end)
            unitwind:test("input_types_mismatch_p(2, \"table or nil\", \"setmetatable\", {}, type_instance)",
                function() input_types_mismatch_p(2, "table or nil", "setmetatable", {}, type_instance) end)
        end

        if typename ~= "effil.table" then
            -- effil.rawset
            unitwind:test("input_types_mismatch_p(1, \"effil.table\", \"rawset\", type_instance, 44, 22)",
                function() input_types_mismatch_p(1, "effil.table", "rawset", type_instance, 44, 22) end)
            -- effil.rawget
            unitwind:test("input_types_mismatch_p(1, \"effil.table\", \"rawget\", type_instance, 44)",
                function() input_types_mismatch_p(1, "effil.table", "rawget", type_instance, 44) end)
            -- effil.ipairs
            unitwind:test("input_types_mismatch_p(1, \"effil.table\", \"ipairs\", type_instance)",
                function() input_types_mismatch_p(1, "effil.table", "ipairs", type_instance) end)
            -- effil.pairs
            unitwind:test("input_types_mismatch_p(1, \"effil.table\", \"pairs\", type_instance)",
                function() input_types_mismatch_p(1, "effil.table", "pairs", type_instance) end)
        end

        -- effil.thread
        if typename ~= "function" then
            unitwind:test("input_types_mismatch_p(1, \"function\", \"thread\", type_instance)",
                function() input_types_mismatch_p(1, "function", "thread", type_instance) end)
        end

        -- effil.sleep
        if typename ~= "number" then
            unitwind:test("input_types_mismatch_p(1, \"number\", \"sleep\", type_instance, \"s\")",
                function() input_types_mismatch_p(1, "number", "sleep", type_instance, "s") end)
        end
        if typename ~= "string" then
            unitwind:test("input_types_mismatch_p(2, \"string\", \"sleep\", 1, type_instance)",
                function() input_types_mismatch_p(2, "string", "sleep", 1, type_instance) end)
        end

        if typename ~= "number" then
            -- effil.channel
            unitwind:test("input_types_mismatch_p(1, \"number\", \"channel\", type_instance)",
                function() input_types_mismatch_p(1, "number", "channel", type_instance) end)

            --  effil.gc.step
            unitwind:test("input_types_mismatch_p(1, \"number\", \"gc.step\", type_instance)",
                function() input_types_mismatch_p(1, "number", "gc.step", type_instance) end)
        end

        -- effil.dump
        if typename ~= "table" and typename ~= "effil.table" then
            unitwind:test("input_types_mismatch_p(1, \"table\", \"dump\", type_instance)",
                function() input_types_mismatch_p(1, "table", "dump", type_instance) end)
        end
    end

    -- Below presented tests which support everything except coroutines

    -- effil.rawset
    unitwind:test("unsupported_type_p(2, \"rawset\", stable, lua_thread, 22)",
        function() unsupported_type_p(2, "rawset", stable, lua_thread, 22) end)
    unitwind:test("unsupported_type_p(3, \"rawset\", stable, 44, lua_thread)",
        function() unsupported_type_p(3, "rawset", stable, 44, lua_thread) end)

    -- effil.rawget
    unitwind:test("unsupported_type_p(2, \"rawget\", stable, lua_thread)",
        function() unsupported_type_p(2, "rawget", stable, lua_thread) end)

    -- effil.channel:push()
    unitwind:test("unsupported_type_p(1, channel_push_generator, lua_thread)",
        function() unsupported_type_p(1, channel_push_generator, lua_thread) end)

    -- effil.thread()()
    unitwind:test("unsupported_type_p(1, thread_runner_generator, lua_thread)",
        function() unsupported_type_p(1, thread_runner_generator, lua_thread) end)

    -- effil.table[key] = value
    unitwind:test("unsupported_type_p(1, table_set_value_generator, lua_thread, 2)",
        function() unsupported_type_p(1, table_set_value_generator, lua_thread, 2) end)
    unitwind:test("unsupported_type_p(2, table_set_value_generator, 2, lua_thread)",
        function() unsupported_type_p(2, table_set_value_generator, 2, lua_thread) end)
    -- effil.table[key]
    unitwind:test("unsupported_type_p(1, table_get_value_generator, lua_thread)",
        function() unsupported_type_p(1, table_get_value_generator, lua_thread) end)
end

-- FIXME error gc.count()
--[[
-- Put it to function to limit the lifetime of objects
generate_tests()
--]]

unitwind:test("gc_checks_after_tests", function()
    local ret = util.default_tear_down()
    unitwind:expect(ret).toBe(true)
end)

unitwind:finish()
