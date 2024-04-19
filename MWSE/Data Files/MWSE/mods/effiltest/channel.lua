local effil = require("effil")
local util = require("effiltest.util")

local unitwind = require("unitwind").new({
    enabled = require("effiltest.config").testChannel,
    highlight = false,
    afterEach = util.default_tear_down,
})

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
