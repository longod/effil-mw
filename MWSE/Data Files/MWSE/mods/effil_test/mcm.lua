--- @param e modConfigReadyEventData
local function OnModConfigReady(e)
    local config = require("effil_test.config")
    local template = mwse.mcm.createTemplate("effil test")
    template:saveOnClose("effil_test", config)
    template:register()

    ---@param value boolean
    ---@return string
    local function GetOnOff(value)
        return (value and tes3.findGMST(tes3.gmst.sOn).value --[[@as string]] or tes3.findGMST(tes3.gmst.sOff).value --[[@as string]])
    end
    ---@param value boolean
    ---@return string
    local function GetYesNo(value)
        return (value and tes3.findGMST(tes3.gmst.sYes).value --[[@as string]] or tes3.findGMST(tes3.gmst.sNo).value --[[@as string]])
    end

    local page = template:createSideBarPage({
        label = "effil test",
    })
    page.sidebar:createInfo({
        text = "This is a TEST mod. The game doesn't need it."
    })
    page:createOnOffButton({
        label = "Test",
        description = "Unit tests are run at startup. Some items are very heavy and loaded.",
        variable = mwse.mcm.createTableVariable({
            id = "testAll",
            table = config,
        })
    })

    do
        local test = page:createCategory({
            label = "Test",
            description = "Toggle individual items.",
        })
        test:createOnOffButton({
            label = "type",
            description = "type test",
            variable = mwse.mcm.createTableVariable({
                id = "testType",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "GC",
            description = "",
            variable = mwse.mcm.createTableVariable({
                id = "GC test",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "size",
            description = "size test",
            variable = mwse.mcm.createTableVariable({
                id = "testSize",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "channel",
            description = "channel test",
            variable = mwse.mcm.createTableVariable({
                id = "testChannel",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "thread",
            description = "thread test",
            variable = mwse.mcm.createTableVariable({
                id = "testThread",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "thread interrupt",
            description = "thread interrupt test",
            variable = mwse.mcm.createTableVariable({
                id = "testThreadInterrupt",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "shared table",
            description = "shared table test",
            variable = mwse.mcm.createTableVariable({
                id = "testSharedTable",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "metatable",
            description = "metatable test",
            variable = mwse.mcm.createTableVariable({
                id = "testMetatable",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "type mismatch",
            description = "type mismatch test",
            variable = mwse.mcm.createTableVariable({
                id = "testTypeMismatch",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "upvalues",
            description = "upvalues test",
            variable = mwse.mcm.createTableVariable({
                id = "testUpvalues",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "dump table",
            description = "dump table test",
            variable = mwse.mcm.createTableVariable({
                id = "testDumpTable",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "function",
            description = "function test",
            variable = mwse.mcm.createTableVariable({
                id = "testFunction",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "channel stress",
            description = "[Heavy] Channel stress test",
            variable = mwse.mcm.createTableVariable({
                id = "testChannelStress",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "thread stress",
            description = "[Heavy] Thread stress test",
            variable = mwse.mcm.createTableVariable({
                id = "testThreadStress",
                table = config,
            })
        })
        test:createOnOffButton({
            label = "GC stress",
            description = "[Heavy] GC stress test",
            variable = mwse.mcm.createTableVariable({
                id = "testGCStress",
                table = config,
            })
        })
    end
end
event.register(tes3.event.modConfigReady, OnModConfigReady)
