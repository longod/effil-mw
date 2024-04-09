local effil = require("effil")
local util = require("effil_test.util")

---@param timeInSec integer?
---@param condition any
---@param silent boolean?
---@return boolean
local function wait(timeInSec, condition, silent)
    local result = false
    local startTime = os.time()
    while ((os.time() - startTime) <= timeInSec) do

        -- Not only the version used by MWSE, but LuaJIT seems to have a resource leak when frequently accessing data that locks with another thread.
        -- Even if it does not, or even if it does not leak, such accesses should be avoided.
        effil.sleep(100, "ms")

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
    wait(timeInSec, nil, true)
end

local unitwind = require("unitwind").new({
    enabled = true,
    highlight = false,
    afterEach = util.default_tear_down,
})

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

-- FIXME It shouldn't be expected to call 'require' in a thread.
-- unitwind:test("runner_path_check_p(\"path\", \"size\")", function() runner_path_check_p("path", "effil_test.size") end) -- some testing Lua file to import
unitwind:test("runner_path_check_p(\"cpath\", \"effil\")", function() runner_path_check_p("cpath", "effil") end)

unitwind:test("wait", function()
    local thread = effil.thread(function()
        print 'Effil is not that tower'
        return nil
    end)()

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
    local thread = effil.thread(function()
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

unitwind:test("async_cancel", function()
    local thread_runner = effil.thread(
        jit ~= nil and
        function()
            local startTime = os.time()
            while ((os.time() - startTime) <= 10) do
                -- In the case of LuaJIT, it seems that if it's a truly busy loop, it can't be interrupted and cancelled.
                effil.yield()
            end
        end
        or
        function()
            local startTime = os.time()
            while ((os.time() - startTime) <= 10) do
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

unitwind:test("returns", function()
    local share = effil.table()
    share.value = "some value"

    local thread_factory = effil.thread(
        function(share)
            return 100500, "string value", true, share, function(a, b) return a + b end
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
            share["child.function"] = share["function"](11, 45)
        end
    )
    local thread = thread_factory(share)
    thread:wait()

    unitwind:expect(share["child.number"]).toBe(share["number"])
    unitwind:expect(share["child.string"]).toBe(share["string"])
    unitwind:expect(share["child.bool"]).toBe(share["bool"])
    unitwind:expect(share["child.function"]).toBe(share["function"](11, 45))
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
    local share = effil.table({ stop = false })
    local spec = effil.thread(function(share)
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
    while not cmd.need_to_stop do
        effil.yield()
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
    local worker_thread = effil.thread(worker)({ need_to_stop = false })
    effil.sleep(1, 's')
    worker_thread:cancel()
    unitwind:expect(worker_thread:wait(2, "s")).toBe("cancelled")
    unitwind:expect(effil.thread(call_pause)(worker_thread):get(5, "s")).toBe(true)
end)

-- Regress test to check hanging when invoke pause on finished thread
unitwind:test("pause_on_finished_thread", function()
    local cmd = effil.table({ need_to_stop = false })
    local worker_thread = effil.thread(worker)(cmd)
    effil.sleep(1, 's')
    cmd.need_to_stop = true
    unitwind:expect(worker_thread:get(2, "s")).toBe(true)
    unitwind:expect(effil.thread(call_pause)(worker_thread):get(5, "s")).toBe(true)
end)

if util.LUA_VERSION > 51 then
    unitwind:test("traceback", function()
        local curr_file = debug.getinfo(1, 'S').short_src

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
    local steps = effil.table { step1 = false, step2 = false }
    local pcall_results = effil.table {}

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
