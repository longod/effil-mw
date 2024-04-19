local effil = require("effil")
local util = require("effiltest.util")

local unitwind = require("unitwind").new({
    enabled = util.STRESS > 0 and require("effiltest.config").testChannelStress,
    highlight = false,
    afterEach = util.default_tear_down,
})

---@param l number
---@param r number
---@param diff number
local function almost_equal(l, r, diff)
    unitwind:expect(require("math").abs(l - r) > diff).toBe(false)
    -- fail("|" .. tostring(l) .. " - " .. tostring(r) .."| > " .. tostring(diff))
end

unitwind:start("effil channel-stress")

unitwind:test("with_multiple_threads", function()
    local exchange_channel, result_channel = effil.channel(), effil.channel()

    local threads_number = 20 * util.STRESS
    local threads = {}
    for i = 1, threads_number do
        threads[i] = effil.thread(function(exchange_channel, result_channel, indx)
            if indx % 2 == 0 then
                for i = 1, 10000 do
                    exchange_channel:push(indx .. "_" .. i)
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
            unitwind:expect(data[thr_id .. "_" .. iter]).toBe(true)
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
