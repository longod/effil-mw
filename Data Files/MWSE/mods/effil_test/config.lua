
---@class Config
local defaultConfig = {
    testAll = false,
    testType = true,
    testGC = true,
    testSize = true,
    testChannel = true,
    testThread = true,
    testThreadInterrupt = true,
    testSharedTable = true,
    testMetatable = true,
    testTypeMismatch = true,
    testUpvalues = true,
    testDumpTable = true,
    testFunction = true,
    testChannelStress = false,
    testThreadStress = false,
    testGCStress = false,
}

---@type Config
local config = mwse.loadConfig("effil_test", defaultConfig)

return config