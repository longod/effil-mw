local this = {}
local major, minor = _VERSION:match("Lua (%d).(%d)")
this.LUA_VERSION = major * 10 + minor
this.STRESS = 1

local effil = require("effil")

---@return boolean
function this.default_tear_down()
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
    local c = effil.gc.count()
    if c ~= 1 then
        print(("gc.count() shoud be %d, but %d"):format(1, c))
        return false
    end
    return true
end

return this