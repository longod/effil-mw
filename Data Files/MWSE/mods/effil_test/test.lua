local effil = require("effil")
local jit = true
local major, minor = _VERSION:match("Lua (%d).(%d)")
local LUA_VERSION = major * 10 + minor

local STRESS = 1

print("JIT: " .. tostring(jit))
print("LUA_VERSION: " .. tostring(LUA_VERSION))

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
    if effil.gc.count() ~= 1 then
        print("gc.count() should be 1")
    end
end

---@param timeInSec integer?
---@param condition any
---@param silent boolean?
---@return boolean
local function wait(timeInSec, condition, silent)
    local result = false
    local startTime = os.time()
    while ( (os.time() - startTime) <= timeInSec) do
        if condition ~= nil then
            if type(condition) == 'function' then
                if condition() then
                    result = true
                    break
                end
            else
                if condition then
                    result = true
                    break
                end
            end
        end
    end
    return result
end

---@param timeInSec integer?
---@param silent boolean?
local function sleep(timeInSec, silent)
    --wait(timeInSec, nil, true)
    effil.sleep(timeInSec)
end

local unitwind = require("unitwind").new({
    enabled = true,
    highlight = false,
    -- beforeAll = nil,
    -- afterAll = nil,
    -- beforeEach = nil,
    afterEach = default_tear_down,
})

---@param l number
---@param r number
---@param diff number
local function almost_equal(l, r, diff)
    unitwind:expect(require("math").abs(l - r) > diff).toBe(false)
    -- fail("|" .. tostring(l) .. " - " .. tostring(r) .."| > " .. tostring(diff))
end

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

unitwind:start("effil channel")

unitwind:test("capacity_usage", function()
    local chan = effil.channel(2)

    unitwind:expect(chan:push(14)).toBe(true)
    unitwind:expect(chan:push(88)).toBe(true)
    unitwind:expect(chan:size()).toBe(2)

    unitwind:expect(chan:push(1488)).toBe(false)

    unitwind:expect(chan:pop()).toBe(14)
    unitwind:expect(chan:pop()).toBe(88)
    unitwind:expect(chan:pop(0)).toBe(nil)
    unitwind:expect(chan:size()).toBe(0)

    unitwind:expect(chan:push(14, 88)).toBe(true)
    local ret1, ret2 = chan:pop()
    unitwind:expect(ret1).toBe(14)
    unitwind:expect(ret2).toBe(88)
end)

unitwind:test("recursive", function()
    local chan1 = effil.channel()
    local chan2 = effil.channel()
    local msg1, msg2 = "first channel", "second channel"
    unitwind:expect(chan1:push(msg1, chan2)).toBe(true)
    unitwind:expect(chan2:push(msg2, chan1)).toBe(true)

    local ret1 = { chan1:pop() }
    unitwind:expect(ret1[1]).toBe(msg1)
    unitwind:expect(type(ret1[2])).toBe("userdata")
    local ret2 = { ret1[2]:pop() }
    unitwind:expect(ret2[1]).toBe(msg2)
    unitwind:expect(type(ret2[2])).toBe("userdata")
end)

unitwind:test("with_threads", function()
    local chan = effil.channel()
    local thread = effil.thread(function(chan)
            chan:push("message1")
            chan:push("message2")
            chan:push("message3")
            chan:push("message4")
        end
    )(chan)

    local start_time = os.time()
    unitwind:expect(chan:pop()).toBe("message1")
    thread:wait()
    unitwind:expect(chan:pop(0)).toBe("message2")
    unitwind:expect(chan:pop(1)).toBe("message3")
    unitwind:expect(chan:pop(1, 'm')).toBe("message4")
    unitwind:expect(os.time() < start_time + 1).toBe(true)
end)

unitwind:test("with_shared_table", function()
    local chan = effil.channel()
    local table = effil.table()

    local test_value = "i'm value"
    table.test_key = test_value

    chan:push(table)
    unitwind:expect(chan:pop().test_key).toBe(test_value)

    table.channel = chan
    table.channel:push(test_value)
    unitwind:expect(table.channel:pop()).toBe(test_value)
end)

unitwind:finish()

unitwind:start("effil thread")
unitwind:test("hardware_threads", function()
    unitwind:expect(effil.hardware_threads() >= 0).toBe(true)
end)

unitwind:test("runner_is_serializible", function()
    local table = effil.table()
    local runner = effil.thread(function(n) return n * 2 end)

    table["runner"] = runner
    unitwind:expect(table["runner"](123):get()).toBe(246)
end)

local function runner_path_check_p(config_key, pkg)
    local table = effil.table()
    local runner = effil.thread(function()
        require(pkg)
    end)
    unitwind:expect(runner():wait()).toBe("completed")

    runner[config_key] = ""
    unitwind:expect(runner():wait()).toBe("failed")
end
-- FIXME no lib
--[[
unitwind:test("runner_path_check_p (\"path\", \"size\")", function() runner_path_check_p("path", "size") end) -- some testing Lua file to import
--]]
unitwind:test("runner_path_check_p (\"cpath\", \"effil\")", function() runner_path_check_p("cpath", "effil") end)

unitwind:test("wait", function()
    local thread = effil.thread(function()
        print 'Effil is not that tower'
        return nil end)()

    local status = thread:wait()
    unitwind:expect(thread:get()).toBe(nil)
    unitwind:expect(status).toBe("completed")
    unitwind:expect(thread:status()).toBe("completed")
end)

unitwind:test("multiple_wait_get", function()
    local thread = effil.thread(function() return "test value" end)()
    local status1 = thread:wait()
    local status2 = thread:wait()
    unitwind:expect(status1).toBe("completed")
    unitwind:expect(status2).toBe(status1)

    local value = thread:get()
    unitwind:expect(value).toBe("test value")
end)

unitwind:test("timed_get 1", function()
    local thread = effil.thread(function()
        effil.sleep(2)
        return "-_-"
    end)()
    unitwind:expect(thread:get(1)).toBe(nil)
    unitwind:expect(thread:get(2)).toBe("-_-")
end)

unitwind:test("timed_get 2", function()
    local thread = effil.thread(function()
        effil.sleep(2)
        return 8
    end)()

    local status = thread:wait(1)
    unitwind:expect(status).toBe("running")

    local value = thread:get(2, "s")
    unitwind:expect(value).toBe(8);

    unitwind:expect(thread:status()).toBe("completed")
end)

unitwind:test("async_wait", function()
    local thread = effil.thread( function()
        effil.sleep(1)
    end)()

    local iter = 0
    while thread:wait(0) == "running" do
        iter = iter + 1
    end

    unitwind:expect(iter > 10).toBe(true)
    unitwind:expect(thread:status()).toBe("completed")
end)

unitwind:test("detached", function()
    local st = effil.table()

    for i = 1, 32 do
        effil.thread(function(st, index)
            st[index] = index
        end)(st, i)
    end

    -- here all thead temporary objects have to be destroyed
    collectgarbage()
    effil.sleep(1)

    for i = 1, 32 do
        unitwind:expect(st[i]).toBe(i)
    end
end)

-- FIXME: what is it for?
unitwind:test("cancel", function()
    local thread = effil.thread(
        jit ~= nil and
            function()
                while true do
                    effil.yield()
                end
            end
        or
            function()
                while true do end
            end
    )()

    unitwind:expect(thread:cancel()).toBe(true)
    unitwind:expect(thread:status()).toBe("cancelled")
end)

-- FIXME error gc.count()
--[[
print("async_cancel")
unitwind:test("async_cancel", function()
    local thread_runner = effil.thread(
        function()
            local startTime = os.time()
            while ( (os.time() - startTime) <= 10) do
                -- Just sleep
            end
        end
    )

    local thread = thread_runner()
    sleep(2) -- let thread starts working
    thread:cancel(0)

    unitwind:expect(wait(2, function() return thread:status() ~= 'running' end)).toBe(true)
    unitwind:expect(thread:status()).toBe('cancelled')
end)
--]]

-- FIXME error gc.count()
--[[
print("pause_resume_cancel")
unitwind:test("pause_resume_cancel", function()
    local data = effil.table()
    data.value = 0
    local thread = effil.thread(
        function(data)
            while true do
                data.value = data.value + 1
            end
        end
    )(data)
    unitwind:expect(wait(2, function() return data.value > 100 end)).toBe(true)
    unitwind:expect(thread:pause()).toBe(true)
    unitwind:expect(thread:status()).toBe("paused")
    
    local savedValue = data.value
    sleep(1)
    unitwind:expect(data.value).toBe(savedValue)

    thread:resume()
    unitwind:expect(wait(5, function() return (data.value - savedValue) > 100 end)).toBe(true)
    unitwind:expect(thread:cancel()).toBe(true)
end)
--]]

-- FIXME error gc.count()
--[[
unitwind:test("pause_cancel", function()
    local data = effil.table()
    data.value = 0
    local thread = effil.thread(
        function(data)
            while true do
                data.value = data.value + 1
            end
        end
    )(data)

    unitwind:expect(wait(2, function() return data.value > 100 end)).toBe(true)
    thread:pause(0)
    unitwind:expect(wait(2, function() return thread:status() == "paused" end)).toBe(true)
    local savedValue = data.value
    sleep(1)
    unitwind:expect(data.value).toBe(savedValue)

    unitwind:expect(thread:cancel(1)).toBe(true)
end)
--]]

-- FIXME error gc.count()
--[[
unitwind:test("async_pause_resume_cancel", function()
    local data = effil.table()
    data.value = 0
    local thread = effil.thread(
        function(data)
            while true do
                data.value = data.value + 1
            end
        end
    )(data)

    unitwind:expect(wait(2, function() return data.value > 100 end)).toBe(true)
    thread:pause()

    local savedValue = data.value
    sleep(1)
    unitwind:expect(data.value).toBe(savedValue)

    thread:resume()
    unitwind:expect(wait(5, function() return (data.value - savedValue) > 100 end)).toBe(true)

    thread:cancel(0)
    unitwind:expect(wait(5, function() return thread:status() == "cancelled" end)).toBe(true)
    thread:wait()
end)
--]]

unitwind:test("returns", function()
    local share = effil.table()
    share.value = "some value"

    local thread_factory = effil.thread(
        function(share)
            return 100500, "string value", true, share, function(a,b) return a + b end
        end
    )
    local thread = thread_factory(share)
    local status = thread:wait()
    local returns = { thread:get() }

    unitwind:expect(status).toBe("completed")

    unitwind:expect(returns[1]).toBeType("number")
    unitwind:expect(returns[1]).toBe(100500)

    unitwind:expect(returns[2]).toBeType("string")
    unitwind:expect(returns[2]).toBe("string value")

    unitwind:expect(returns[3]).toBeType("boolean")
    unitwind:expect(returns[3]).toBe(true)

    unitwind:expect(returns[4]).toBeType("userdata")
    unitwind:expect(returns[4].value).toBe(share.value)

    unitwind:expect(returns[5]).toBeType("function")
    unitwind:expect(returns[5](11, 89)).toBe(100)
end)

unitwind:test("types", function()
    local share = effil.table()

    share["number"] = 100500
    share["string"] = "string value"
    share["bool"] = true
    share["function"] = function(left, right) return left + right end

    local thread_factory = effil.thread(
        function(share)
            share["child.number"]   = share["number"]
            share["child.string"]   = share["string"]
            share["child.bool"]     = share["bool"]
            share["child.function"] = share["function"](11,45)
        end
    )
    local thread = thread_factory(share)
    thread:wait()

    unitwind:expect(share["child.number"]).toBe(share["number"])
    unitwind:expect(share["child.string"]).toBe(share["string"])
    unitwind:expect(share["child.bool"]).toBe(share["bool"])
    unitwind:expect(share["child.function"]).toBe(share["function"](11,45))
end)

unitwind:test("recursive", function()
    local share = effil.table()

    local magic_number = 42
    share["subtable1"] = effil.table()
    share["subtable1"]["subtable1"] = effil.table()
    share["subtable1"]["subtable2"] = share["subtable1"]["subtable1"]
    share["subtable2"] = share["subtable1"]["subtable1"]
    share["magic_number"] = magic_number

    local thread_factory = effil.thread(
        function(share)
            share["subtable1"]["subtable1"]["magic_number"] = share["magic_number"]
            share["magic_number"] = nil
        end
    )
    local thread = thread_factory(share)
    thread:wait()

    unitwind:expect(share["subtable1"]["subtable1"]["magic_number"]).toBe(magic_number)
    unitwind:expect(share["subtable1"]["subtable2"]["magic_number"]).toBe(magic_number)
    unitwind:expect(share["subtable2"]["magic_number"]).toBe(magic_number)
    unitwind:expect(share["magic_number"]).toBe(nil)
end)

unitwind:test("functions", function()
    local share = effil.table()

    local thread_factory = effil.thread(
        function(share)
            share["child.id"] = effil.thread_id()
        end
    )
    local thread = thread_factory(share)
    thread:get()

    unitwind:expect(share["child.id"]).toBeType("string")
    unitwind:expect(tonumber(share["child.id"])).toBeType("number")
    unitwind:expect(share["child.id"]).NOT.toBe(effil.thread_id())
end)

unitwind:test("cancel_with_yield", function()
    local ctx = effil.table()
    local spec = effil.thread(function()
        while not ctx.stop do
           -- Just waiting
        end
        ctx.done = true
        while true do
            effil.yield()
        end
        ctx.after_yield = true
    end)
    spec.step = 0
    local thr = spec()

    unitwind:expect(thr:cancel(1)).toBe(false)
    ctx.stop = true

    unitwind:expect(thr:cancel()).toBe(true)
    unitwind:expect(thr:status()).toBe("cancelled")
    unitwind:expect(ctx.done).toBe(true)
    unitwind:expect(ctx.after_yield).toBe(nil)
end)

unitwind:test("pause_with_yield", function()
    local share = effil.table({stop = false})
    local spec = effil.thread(function (share)
        while not share.stop do
            effil.yield()
        end
        share.done = true
        return true
    end)
    spec.step = 0
    local thr = spec(share)

    thr:pause()
    unitwind:expect(share.done).toBe(nil)
    unitwind:expect(thr:status()).toBe("paused")
    share.stop = true
    effil.sleep(100, "ms")
    unitwind:expect(share.done).toBe(nil)
    thr:resume()

    unitwind:expect(thr:get()).toBe(true)
    unitwind:expect(share.done).toBe(true)
end)

local function worker(cmd)
    eff = effil
    while not cmd.need_to_stop do
        eff.yield()
    end
    return true
end

local function call_pause(thr)
    -- 'pause()' may hang infinitelly, so lets to run it in separate thread
    thr:pause()
    return true
end

-- Regress test to check hanging when invoke pause on cancelled thread
unitwind:test("pause_on_cancelled_thread", function()
    local worker_thread = effil.thread(worker)({ need_to_stop = false})
    effil.sleep(1, 's')
    worker_thread:cancel()
    unitwind:expect(worker_thread:wait(2, "s")).toBe("cancelled")
    unitwind:expect(effil.thread(call_pause)(worker_thread):get(5, "s")).toBe(true)
end)

-- Regress test to check hanging when invoke pause on finished thread
unitwind:test("pause_on_finished_thread", function()
    local cmd = effil.table({ need_to_stop = false})
    local worker_thread = effil.thread(worker)(cmd)
    effil.sleep(1, 's')
    cmd.need_to_stop = true
    unitwind:expect(worker_thread:get(2, "s")).toBe(true)
    unitwind:expect(effil.thread(call_pause)(worker_thread):get(5, "s")).toBe(true)
end)

if LUA_VERSION > 51 then

unitwind:test("traceback", function()
    local curr_file = debug.getinfo(1,'S').short_src

    local function foo()
        local function boom()
            error("err msg")
        end
        local function bar()
            boom()
        end
        bar()
    end

    local status, err, trace = effil.thread(foo)():wait()
    print("status: ", status)
    print("error: ", err)
    print("stacktrace:")
    print(trace)

    unitwind:expect(status).toBe("failed")
    -- <souce file>.lua:<string number>: <error message>
    unitwind:expect(string.find(err, curr_file .. ":%d+: err msg")).NOT.toBe(nil)
    unitwind:expect(string.find(trace, (
[[stack traceback:
%%s%%[C%%]: in function 'error'
%%s%s:%%d+: in function 'boom'
%%s%s:%%d+: in function 'bar'
%%s%s:%%d+: in function <%s:%%d+>]]
        ):format(curr_file, curr_file, curr_file, curr_file)
    )).NOT(nil)
end)

end -- LUA_VERSION > 51

unitwind:test("cancel_thread_with_pcall", function()
    local steps = effil.table{step1 = false, step2 = false}
    local pcall_results = effil.table{}

    local thr = effil.thread(
        function()
            pcall_results.ret, pcall_results.msg = pcall(function()
                while true do
                    effil.yield()
                end
            end)

            steps.step1 = true
            effil.yield()
            steps.step2 = true -- should never reach
        end
    )()

    unitwind:expect(thr:cancel()).toBe(true)
    unitwind:expect(thr:wait()).toBe("cancelled")
    unitwind:expect(steps.step1).toBe(true)
    unitwind:expect(steps.step2).toBe(false)
    unitwind:expect(pcall_results.ret).toBe(false)
    unitwind:expect(pcall_results.msg).toBe("Effil: thread is cancelled")
end)

unitwind:test("cancel_thread_with_pcall_not_cancelled", function()
    local thr = effil.thread(
        function()
            pcall(function()
                while true do
                    effil.yield()
                end
            end)
        end
    )()
    unitwind:expect(thr:cancel()).toBe(true)
    unitwind:expect(thr:wait()).toBe("completed")
end)

unitwind:test("cancel_thread_with_pcall_and_another_error", function()
    local msg = 'some text'
    local thr = effil.thread(
        function()
            pcall(function()
                while true do
                    effil.yield()
                end
            end)
            error(msg)
        end
    )()
    unitwind:expect(thr:cancel()).toBe(true)
    local status, message = thr:wait()
    unitwind:expect(status).toBe("failed")
    unitwind:expect(string.find(message, ".+: " .. msg)).NOT.toBe(nil)
end)

if not jit then

unitwind:test("cancel_thread_with_pcall_without_yield", function()
    local thr = effil.thread(
        function()
            while true do
                -- pass
            end
        end
    )
    local runner = thr()
    unitwind:expect(runner:cancel()).toBe(true)
    unitwind:expect(runner:wait()).toBe("cancelled")
end)

end

unitwind:test("check_effil_pcall_success", function()
    local inp1, inp2, inp3 = 1, "str", {}
    local res, ret1, ret2, ret3 = effil.pcall(function(...) return ... end, inp1, inp2, inp3)
    unitwind:expect(res).toBe(true)
    unitwind:expect(ret1).toBe(inp1)
    unitwind:expect(ret2).toBe(inp2)
    unitwind:expect(ret3).toBe(inp3)
end)

unitwind:test("check_effil_pcall_fail", function()
    local err = "some text"
    local res, msg = effil.pcall(function(err) error(err) end, err)
    unitwind:expect(res).toBe(false)
    unitwind:expect(string.find(msg, ".+: " .. err)).NOT.toBe(nil)
end)

unitwind:test("check_effil_pcall_with_cancel_thread", function()
    local thr = effil.thread(
        function()
            effil.pcall(function()
                while true do
                    effil.yield()
                end
            end)
        end
    )()
    unitwind:expect(thr:cancel()).toBe(true)
    unitwind:expect(thr:wait()).toBe("cancelled")
end)

unitwind:finish()

unitwind:start("effil thread-interrupt")

local function interruption_test(worker)
    local state = effil.table { stop = false }

    local ctx = effil.thread(worker)
    ctx.step = 0
    local thr = ctx(state)

    effil.sleep(500, 'ms') -- let thread starts

    local start_time = os.time()
    thr:cancel(1)

    unitwind:expect(thr:status()).toBe("cancelled")
    almost_equal(os.time(), start_time, 1)
    state.stop = true
end

local get_thread_for_test = function(state)
    local runner = effil.thread(function()
        while not state.stop do end
    end)
    runner.step = 0
    return runner()
end

unitwind:test("thread_wait", function()
    interruption_test(function(state)
        get_thread_for_test(state):wait()
    end)
end)

unitwind:test("thread_get", function()
    interruption_test(function(state)
        get_thread_for_test(state):get()
    end)
end)

unitwind:test("thread_cancel", function()
    interruption_test(function(state)
        get_thread_for_test(state):cancel()
    end)
end)

unitwind:test("thread_pause", function()
    interruption_test(function(state)
        get_thread_for_test(state):pause()
    end)
end)

unitwind:test("channel_pop", function()
    interruption_test(function()
        effil.channel():pop()
    end)
end)

unitwind:test("sleep", function()
    interruption_test(function()
        effil.sleep(20)
    end)
end)

unitwind:test("yield", function()
    interruption_test(function()
        while true do
            effil.yield()
        end
    end)
end)

unitwind:finish()

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

if LUA_VERSION > 51 then

unitwind:test("pairs", function()
    local share = effil.table()
    local data = { 0, 0, 0, ["key1"] = 0, ["key2"] = 0, ["key3"] = 0 }

    for k, _ in pairs(data) do
        share[k] = k .. "-value"
    end

    for k,v in pairs(share) do
        unitwind:expect(data[k]).toBe(0)
        data[k] = 1
        unitwind:expect(v).toBe(k .. "-value")
    end

    for k,v in pairs(data) do
        unitwind:expect(v).toBe(1)
    end

    for k,v in ipairs(share) do
        unitwind:expect(data[k]).toBe(1)
        data[k] = 2
        unitwind:expect(v).toBe(k .. "-value")
    end

    for k,v in ipairs(data) do
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

unitwind:start("effil type_mismatch")

local function generate_tests()
    local function create_object_generator(name, func)
        return setmetatable({ name = name }, {
            __call = func,
            __tostring = function() return name end
        })
    end
    local basic_type_mismatch_test_p = function(err_msg, wrong_arg_num, func_name , ...)
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
        local args = {...}
        local err_msg = "bad argument #" .. wrong_arg_num .. " to " ..
                (type(func_name) == "string" and "'effil." .. func_name or func_name.name) ..
                "' (" .. expected_type .. " expected, got " .. effil.type(args[wrong_arg_num]) .. ")"
        basic_type_mismatch_test_p(err_msg, wrong_arg_num, func_name, ...)
    end

    local function unsupported_type_p(wrong_arg_num, func_name, ...)
        local args = {...}
        local err_msg = (type(func_name) == "string" and "effil." ..  func_name or func_name.name)
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
            return effil.thread(function()end)(...)
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

    local func = function()end
    local stable = effil.table()
    local thread = effil.thread(func)()
    thread:wait()
    local lua_thread = coroutine.create(func)

    local all_types = { 22, "s", true, {}, stable, func, thread, effil.channel(), lua_thread }

    for _, type_instance in ipairs(all_types) do
        local typename = effil.type(type_instance)

        -- effil.getmetatable
        if typename ~= "effil.table" then
            unitwind:test("input_types_mismatch_p (1, \"effil.table\", \"getmetatable\", type_instance)", function() input_types_mismatch_p(1, "effil.table", "getmetatable", type_instance) end)
        end

        -- effil.setmetatable
        if typename ~= "table" and typename ~= "effil.table" then
            unitwind:test("input_types_mismatch_p (1, \"table\", \"setmetatable\", type_instance, 44)", function() input_types_mismatch_p(1, "table", "setmetatable", type_instance, 44) end)
            unitwind:test("input_types_mismatch_p (2, \"table or nil\", \"setmetatable\", {}, type_instance)", function() input_types_mismatch_p(2, "table or nil", "setmetatable", {}, type_instance) end)
        end

        if typename ~= "effil.table" then
            -- effil.rawset
            unitwind:test("input_types_mismatch_p (1, \"effil.table\", \"rawset\", type_instance, 44, 22)", function() input_types_mismatch_p(1, "effil.table", "rawset", type_instance, 44, 22) end)
            -- effil.rawget
            unitwind:test("input_types_mismatch_p (1, \"effil.table\", \"rawget\", type_instance, 44)", function() input_types_mismatch_p(1, "effil.table", "rawget", type_instance, 44) end)
            -- effil.ipairs
            unitwind:test("input_types_mismatch_p (1, \"effil.table\", \"ipairs\", type_instance)", function() input_types_mismatch_p(1, "effil.table", "ipairs", type_instance) end)
            -- effil.pairs
            unitwind:test("input_types_mismatch_p (1, \"effil.table\", \"pairs\", type_instance)", function() input_types_mismatch_p(1, "effil.table", "pairs", type_instance) end)
        end

        -- effil.thread
        if typename ~= "function" then
            unitwind:test("input_types_mismatch_p (1, \"function\", \"thread\", type_instance)", function() input_types_mismatch_p(1, "function", "thread", type_instance) end)
        end

        -- effil.sleep
        if typename ~= "number" then
            unitwind:test("input_types_mismatch_p (1, \"number\", \"sleep\", type_instance, \"s\")", function() input_types_mismatch_p(1, "number", "sleep", type_instance, "s") end)
        end
        if typename ~= "string" then
            unitwind:test("input_types_mismatch_p (2, \"string\", \"sleep\", 1, type_instance)", function() input_types_mismatch_p(2, "string", "sleep", 1, type_instance) end)
        end

        if typename ~= "number" then
            -- effil.channel
            unitwind:test("input_types_mismatch_p (1, \"number\", \"channel\", type_instance)", function() input_types_mismatch_p(1, "number", "channel", type_instance) end)

            --  effil.gc.step
            unitwind:test("input_types_mismatch_p (1, \"number\", \"gc.step\", type_instance)", function() input_types_mismatch_p(1, "number", "gc.step", type_instance) end)
        end

        -- effil.dump
        if typename ~= "table" and typename ~= "effil.table" then
            unitwind:test("input_types_mismatch_p (1, \"table\", \"dump\", type_instance)", function() input_types_mismatch_p(1, "table", "dump", type_instance) end)
        end
    end

    -- Below presented tests which support everything except coroutines

    -- effil.rawset
    unitwind:test("unsupported_type_p (2, \"rawset\", stable, lua_thread, 22)", function() unsupported_type_p(2, "rawset", stable, lua_thread, 22) end)
    unitwind:test("unsupported_type_p (3, \"rawset\", stable, 44, lua_thread)", function() unsupported_type_p(3, "rawset", stable, 44, lua_thread) end)

    -- effil.rawget
    unitwind:test("unsupported_type_p (2, \"rawget\", stable, lua_thread)", function() unsupported_type_p(2, "rawget", stable, lua_thread) end)

    -- effil.channel:push()
    unitwind:test("unsupported_type_p (1, channel_push_generator, lua_thread)", function() unsupported_type_p(1, channel_push_generator, lua_thread) end)

    -- effil.thread()()
    unitwind:test("unsupported_type_p (1, thread_runner_generator, lua_thread)", function() unsupported_type_p(1, thread_runner_generator, lua_thread) end)

    -- effil.table[key] = value
    unitwind:test("unsupported_type_p (1, table_set_value_generator, lua_thread, 2)", function() unsupported_type_p(1, table_set_value_generator, lua_thread, 2) end)
    unitwind:test("unsupported_type_p (2, table_set_value_generator, 2, lua_thread)", function() unsupported_type_p(2, table_set_value_generator, 2, lua_thread) end)
    -- effil.table[key]
    unitwind:test("unsupported_type_p (1, table_get_value_generator, lua_thread)", function() unsupported_type_p(1, table_get_value_generator, lua_thread) end)
end

-- FIXME error gc.count()
--[[
-- Put it to function to limit the lifetime of objects
generate_tests()
--]]

unitwind:test("gc_checks_after_tests", function()
    default_tear_down()
end)

unitwind:finish()

unitwind:start("effil upvalues")

local foo = function() return 22 end

local function check_single_upvalue_p(type_creator, type_checker)
    local obj = type_creator()
    local thread_worker = function(checker) return effil.type(obj) .. ": " .. checker(obj) end
    local ret = effil.thread(thread_worker)(type_checker):get()

    print("Returned: " .. ret)
    unitwind:expect(ret).toBe(effil.type(obj) .. ": " .. type_checker(obj))
end

unitwind:test("check_single_upvalue_p (1488)", function() check_single_upvalue_p(function() return 1488 end,
                                   function() return "1488" end) end)

unitwind:test("check_single_upvalue_p (\"awesome\")", function() check_single_upvalue_p(function() return "awesome" end,
                                   function() return "awesome" end) end)

unitwind:test("check_single_upvalue_p (true)", function() check_single_upvalue_p(function() return true end,
                                   function() return "true" end) end)

unitwind:test("check_single_upvalue_p (nil)", function() check_single_upvalue_p(function() return nil end,
                                   function() return "nil" end) end)

unitwind:test("check_single_upvalue_p (function)", function() check_single_upvalue_p(function() return foo end,
                                   function(f) return f() end) end)

unitwind:test("check_single_upvalue_p (effil.table)", function() check_single_upvalue_p(function() return effil.table({key = 44}) end,
                                   function(t) return t.key end) end)

unitwind:test("check_single_upvalue_p (effil.channel)", function() check_single_upvalue_p(function() local c = effil.channel() c:push(33) c:push(33) return c end,
                                   function(c) return c:pop() end) end)

unitwind:test("check_single_upvalue_p (effil.thread)", function() check_single_upvalue_p(function() return effil.thread(foo)() end,
                                   function(t) return t:get() end) end)

unitwind:test("check_invalid_coroutine", function()
    local obj = coroutine.create(foo)
    local thread_worker = function() return tostring(obj) end
    local ret, err = pcall(effil.thread, thread_worker)
    if ret then
        ret:wait()
    end
    unitwind:expect(ret).toBe(false)
    print("Returned: " .. err)
    local upvalue_num = LUA_VERSION > 51 and 2 or 1
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
    local obj1 = 13 -- local
    obj2 = { key = "origin" } -- global
    local obj3 = 79 -- local

    local function foo() -- _ENV is 2nd upvalue
        return obj1, obj2.key, obj3
    end

    local function thread_worker(func)
        obj1 = 31 -- global
        obj2 = { key = "local" } -- global
        obj3 = 97 -- global
        return table.concat({func()}, ", ")
    end

    local ret = effil.thread(thread_worker)(foo):get()
    print("Returned: " .. ret)
    unitwind:expect(ret).toBe("13, local, 79")
end)

if LUA_VERSION > 51 then

unitwind:test("check_custom_env", function()
    local function create_foo()
        local _ENV = { key = 'value' }
        return function()
            return key
        end
    end

    local foo = create_foo()
    local ret = effil.thread(foo)():get()
    unitwind:expect(ret).toBe('value')
end)

end -- LUA_VERSION > 51

unitwind:finish()

unitwind:start("effil dump_table")

local function table_included(left, right, path)
    local path = path or ""
    if type(left) ~= type(right) then
        return false, "[" .. path .. "]: " .." got " .. type(right) .. "instead of " .. type(left)
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
        1, "str", key = "value",
        key2 = { 2, [false] = "asd", { [44] = {true} } }
    }

    local result = effil.dump(effil.table(origin))
    assert(table_equals(origin, result))
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
    origin.nested = {1, origin, 2}
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
    local tbl = effil.setmetatable({}, effil.setmetatable({a=1}, {b = 2}))
    local dumped = effil.dump(tbl)

    local mt = getmetatable(dumped)
    unitwind:expect(mt).NOT.toBe(nil)
    unitwind:expect(mt.a).toBe(1)

    local mt2 = getmetatable(mt)
    unitwind:expect(mt2).NOT.toBe(nil)
    unitwind:expect(mt2.b).toBe(2)
end)

unitwind:finish()

unitwind:start("effil function")

local function check_truly_c_functions_p(func)
    unitwind:expect(type(func)).toBe("function")

    local t = effil.table()
    local ret, _ = pcall(function() t["func"] = func end)
    unitwind:expect(ret).toBe(true)
end
unitwind:test("check_truly_c_functions_p (coroutine.create)", function() check_truly_c_functions_p(coroutine.create) end)
unitwind:test("check_truly_c_functions_p (effil.size)", function() check_truly_c_functions_p(effil.size) end)

unitwind:test("check_tosting_c_functions", function()
    local t = effil.table()

    if jit then
        -- in LuaJIT it's not real C function
        local ret, msg = pcall(function() t["tostring"] = tostring end)
        unitwind:expect(ret).toBe(false)
        unitwind:expect(msg).toBe("effil.table: can't get C function pointer")
    else
        t["tostring"] = tostring

        if LUA_VERSION > 51 then
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

unitwind:start("effil channel-stress")

unitwind:test("with_multiple_threads", function()
    local exchange_channel, result_channel = effil.channel(), effil.channel()

    local threads_number = 20 * STRESS
    local threads = {}
    for i = 1, threads_number do
        threads[i] = effil.thread(function(exchange_channel, result_channel, indx)
            if indx % 2 == 0 then
                for i = 1, 10000 do
                    exchange_channel:push(indx .. "_".. i)
                end
            else
                repeat
                    local ret = exchange_channel:pop(10)
                    if ret then
                        result_channel:push(ret)
                    end
                until ret == nil
            end
        end
        )(exchange_channel, result_channel, i)
    end

    local data = {}
    for i = 1, (threads_number / 2) * 10000 do
        local ret = result_channel:pop(10)
        unitwind:expect(ret).NOT.toBe(nil)
        unitwind:expect(ret).toBeType("string")
        unitwind:expect(data[ret]).toBe(nil)
        data[ret] = true
    end

    for thr_id = 2, threads_number, 2 do
        for iter = 1, 10000 do
            unitwind:expect(data[thr_id .. "_".. iter]).toBe(true)
        end
    end

    for _, thread in ipairs(threads) do
        thread:wait()
    end
end)

unitwind:test("timed_read", function()
    local chan = effil.channel()
    local delayed_writer = function(channel, delay)
        effil.sleep(delay)
        channel:push("hello!")
    end
    effil.thread(delayed_writer)(chan, 70)

    local function check_time(real_time, use_time, metric, result)
        local start_time = os.time()
        unitwind:expect(chan:pop(use_time, metric)).toBe(result)
        almost_equal(os.time(), start_time + real_time, 2)
    end
    check_time(2, 2, nil, nil) -- second by default
    check_time(2, 2, 's', nil)
    check_time(60, 1, 'm', nil)

    local start_time = os.time()
    unitwind:expect(chan:pop(10)).toBe("hello!")
    unitwind:expect(os.time() < start_time + 10).toBe(true)
end)

-- regress for channel returns
unitwind:test("retun_tables", function()
    local function worker()
        local ch = effil.channel()
        for i = 1, 1000 do
            ch:push(effil.table())
            local ret = { ch:pop() }
        end
    end

    local threads = {}

    for i = 1, 20 do
        table.insert(threads, effil.thread(worker)())
    end
    for _, thr in ipairs(threads) do
        thr:wait()
    end
end)

-- regress for multiple wait on channel
unitwind:test("regress_for_multiple_waiters", function()
    for i = 1, 20 do
        local chan = effil.channel()
        local function receiver()
            return chan:pop(5) ~= nil
        end

        local threads = {}
        for j = 1, 10 do
            table.insert(threads, effil.thread(receiver)())
        end

        effil.sleep(0.1)
        for j = 1, 100 do
            chan:push(1)
        end

        for _, thr in ipairs(threads) do
            local ret = thr:get()
            unitwind:expect(ret).toBe(true)
            if not ret then
                return
            end
        end
    end
end)

unitwind:finish()

unitwind:start("effil thread-stress")
unitwind:test("time", function()
    local function check_time(real_time, use_time, metric)
        local start_time = os.time()
        effil.sleep(use_time, metric)
        almost_equal(os.time(), start_time + real_time, 2)
    end
    check_time(4, 4, nil) -- seconds by default
    check_time(4, 4, 's')
    check_time(4, 4000, 'ms')
    check_time(60, 1, 'm')
end)

unitwind:finish()

unitwind:start("effil gc-stress")
unitwind:test("create_and_collect_in_parallel", function()
    function worker()
        local nested_table = {
                {}, --[[1 level]]
                {{}}, --[[2 levels]]
                {{{}}}, --[[3 levels]]
                {{{{}}}} --[[4 levels]]
        }
        for i = 1, 20 * STRESS do
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
        effil.thread(function(aa, bb) aa() bb() end)(a, b)
    end
end)


unitwind:test("regress_for_concurent_function_creation", function()
    local a = function() end
    local b = function() end

    for i = 1, 2000 do
        effil.thread(function() a() b() end)()
    end
end)

unitwind:finish()
