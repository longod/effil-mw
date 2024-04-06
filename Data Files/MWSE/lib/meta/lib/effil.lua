---@meta

--- Effil is a multithreading library for Lua. It allows to spawn native threads and safe data exchange. Effil has been designed to provide clear and simple API for lua developers.
--- https://github.com/effil/effil
---@class Effil
---@field G Effil.Table Is a global predefined shared table. This table always present in any thread (any Lua state).
---@field gc Effil.GarbageCollector
local effil = {}

-- effil.thread is the way to create a thread. Threads can be stopped, paused, resumed and cancelled. All operation with threads can be synchronous (with optional timeout) or asynchronous. Each thread runs with its own lua state.
-- Use effil.table and effil.channel to transmit data over threads. See example of thread usage here.
-- runner = effil.thread(func)
-- Creates thread runner. Runner spawns new thread for each invocation.
---@param func fun(...) Lua function
---@return Effil.ThreadRunner runner thread runner object to configure and run a new thread
function effil.thread(func) end

---comment
---@return string id returns unique string id for current thread.
function effil.thread_id() end

---comment
function effil.yield() end

---comment
---@param time number?
---@param metric string?
function effil.sleep(time, metric) end

---comment
---@return integer
function effil.hardware_threads() end

---comment
---@param func fun(...) : ...
---@param ... any
---@return string status
---@return ...
function effil.pcall(func, ...) end

---comment
---@param tbl Effil.Table?
---@return Effil.Table table
function effil.table(tbl) end

---comment
---@param tbl Effil.Table
---@param mtbl table|Effil.Table?
---@return Effil.Table table
function effil.setmetatable(tbl, mtbl) end

---comment
---@param tbl Effil.Table
---@return table? table
---@return Effil.Table? table
function effil.getmetatable(tbl) end

---comment
---@param tbl Effil.Table
---@param key any
---@param value any
function effil.rawset(tbl, key, value) end

---comment
---@param tbl Effil.Table
---@param key any
---@return any value
function effil.rawget(tbl, key) end

---Truns effil.table into regular Lua table.
---@param tbl Effil.Table
---@return table result
function effil.dump(tbl) end

---comments
---@param capacity integer?
---@return Effil.Channel
function effil.channel(capacity) end

---comment
---@param obj Effil.Table|Effil.Channel
---@return integer
function effil.size(obj) end

---comment
---@param obj any
---@return string
function effil.type(obj) end

-- Allows to configure and run a new thread.
-- thread = runner(...)
-- Run captured function with specified arguments in separate thread and returns thread handle.
---@class Effil.ThreadRunner
---@field path string Is a Lua package.path value for new state. Default value inherits package.path form parent state.
---@field cpath string Is a Lua package.cpath value for new state. Default value inherits package.cpath form parent state.
---@field step integer Number of lua instructions lua between cancelation points (where thread can be stopped or paused). Default value is 200. If this values is 0 then thread uses only explicit cancelation points.
---@overload fun(...) : Effil.ThreadHandle Run captured function with specified arguments in separate thread and returns thread handle. input: Any number of arguments required by captured function. output: Thread handle object.
local runner = {}


--- Thread handle provides API for interaction with thread.
---@class Effil.ThreadHandle
local thread = {}

--- Returns thread status.
---@param self Effil.ThreadHandle
---@return string status string values describes status of thread. Possible values are: "running", "paused", "cancelled", "completed" and "failed".
---@return string err error message, if any. This value is specified only if thread status == "failed".
---@return string stacktrace stacktrace of failed thread. This value is specified only if thread status == "failed".
function thread.status(self) end

---comment
---@param self Effil.ThreadHandle
---@param time number?
---@param metric string?
---@return ... Results of captured function invocation or nothing in case of error.
function thread.get(self, time, metric) end

---comment
---@param self Effil.ThreadHandle
---@param time number?
---@param metric string?
---@return string status string values describes status of thread. Possible values are: "running", "paused", "cancelled", "completed" and "failed".
---@return string err error message, if any. This value is specified only if thread status == "failed".
---@return string stacktrace stacktrace of failed thread. This value is specified only if thread status == "failed".
function thread.wait(self, time, metric) end

---comment
---@param self Effil.ThreadHandle
---@param metric string?
---@return boolean result Returns status of thread. The output is the same as thread:status()
function thread.cancel(self, metric) end

---comment
---@param self Effil.ThreadHandle
---@param time number?
---@param metric string?
---@return boolean result Returns true if thread was paused or false. If the thread is completed function will return false
function thread.pause(self, time, metric) end

---comment
---@param self Effil.ThreadHandle
function thread.resume(self) end

---comment
---@class Effil.Table
local tbl = {}


---comment
---@class Effil.Channel
local channel = {}

---comment
---@param self Effil.Channel
---@param ... any
---@return boolean pushed
function channel.push(self, ...) end

---comment
---@param self Effil.Channel
---@param time number?
---@param metric string?
---@return ...
function channel.pop(self, time, metric) end

---comment
---@param self Effil.Channel
---@return integer
function channel.size(self) end


---comment
---@class Effil.GarbageCollector
local gc = {}

---comment
function gc.collect() end

---comment
---@return integer count
function gc.count() end

---comment
---@param new_value number?
---@return number old_value
function gc.step(new_value) end

---comment
function gc.pause() end

---comment
function gc.resume() end

---comment
---@return boolean enabled
function gc.enabled() end

return effil
