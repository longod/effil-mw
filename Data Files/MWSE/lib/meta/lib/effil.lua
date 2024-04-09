---@meta

--- Effil is a multithreading library for Lua. It allows to spawn native threads and safe data exchange. Effil has been designed to provide clear and simple API for lua developers.
---
--- https://github.com/effil/effil
---@class Effil
---@field G Effil.Table is a global predefined shared table. This table always present in any thread (any Lua state).
---@field gc Effil.GarbageCollector provides a set of method configure effil garbage collector.
local effil = {}

--- Creates thread runner. Runner spawns new thread for each invocation.
---@param func fun(...) : ... Lua function
---@return Effil.ThreadRunner runner thread runner object to configure and run a new thread
function effil.thread(func) end

--- Gives unique identifier.
---@return string id returns unique string id for current thread.
function effil.thread_id() end

--- Explicit cancellation point. Function checks cancellation or pausing flags of current thread and if it's required it performs corresponding actions (cancel or pause thread).
function effil.yield() end

--- Suspend current thread.
---@param time number? is a number of intervals.
---@param metric string? is time interval like `'s'` (seconds).
function effil.sleep(time, metric) end

--- Returns the number of concurrent threads supported by implementation. Basically forwards value from std::thread::hardware_concurrency.
---@return integer number of concurrent hardware threads.
function effil.hardware_threads() end

--- Works exactly the same way as standard pcall except that it will not catch thread cancellation error caused by `thread:cancel()` call.
---@param func fun(...) : ... function to call
---@param ... any arguments to pass to functions
---@return string status `true` if no error occurred, `false` otherwise
---@return ... in case of error return one additional result with message of error, otherwise return function call results
function effil.pcall(func, ...) end

--- Creates new empty shared table.
---@param tbl table|Effil.Table? is optional parameter, it can be only regular Lua table which entries will be copied to shared table.
---@return Effil.Table table new instance of empty shared table. It can be empty or not, depending on `tbl` content.
function effil.table(tbl) end

--- Sets a new metatable to shared table. Similar to standard setmetatable.
---@param tbl Effil.Table should be shared table for which you want to set metatable.
---@param mtbl table|Effil.Table? should be regular table or shared table which will become a metatable. If it's a regular table effil will create a new shared table and copy all fields of `mtbl`. Set `mtbl` equal to `nil` to delete metatable from shared table.
---@return Effil.Table tbl just returns `tbl` with a new metatable value similar to standard Lua setmetatable method.
function effil.setmetatable(tbl, mtbl) end

--- Returns current metatable. Similar to standard getmetatable
---@param tbl Effil.Table should be shared table.
---@return Effil.Table? mtbl returns metatable of specified shared table. Returned table always has type `effil.table`. Default metatable is `nil`.
function effil.getmetatable(tbl) end

--- Set table entry without invoking metamethod `__newindex`. Similar to standard rawset
---@param tbl Effil.Table is shared table.
---@param key any key of table to override. The key can be of any supported type.
---@param value any value to set. The value can be of any supported type.
---@return Effil.Table? tbl returns the same shared table `tbl`
function effil.rawset(tbl, key, value) end

--- Gets table value without invoking metamethod `__index`. Similar to standard rawget
---@param tbl Effil.Table is shared table.
---@param key any key of table to receive a specific value. The key can be of any supported type.
---@return any value returns required `value` stored under a specified `key`
function effil.rawget(tbl, key) end

--- Turns `effil.table` into regular Lua table.
---@param tbl Effil.Table is shared table.
---@return table result returns turned regular table
function effil.dump(tbl) end

--- Allows a program to traverse all fields of a table.
---@param tbl Effil.Table is shared table.
---@param index? any index in this table. A call to next returns the next index of the table and its associated value.
---@return any key
---@return any value
function effil.next(tbl, index) end

--- Creates a new channel.
---@param capacity integer? optional capacity of channel. If `capacity` equals to `0` or to `nil` size of channel is unlimited. Default capacity is 0.
---@return Effil.Channel channel returns a new instance of channel.
function effil.channel(capacity) end

--- Returns number of entries in Effil object.
---@param obj Effil.Table|Effil.Channel is shared table or channel.
---@return integer size number of entries in shared table or number of messages in channel
function effil.size(obj) end

--- hreads, channels and tables are userdata. Thus, `type()` will return `userdata` for any type. If you want to detect type more precisely use `effil.type`. It behaves like regular `type()`, but it can detect effil specific userdata.
---@param obj any is object of any type.
---@return string type string name of type. If `obj` is Effil object then function returns string like `effil.table` in other cases it returns result of lua_typename function.
function effil.type(obj) end


--- Allows to configure and run a new thread.
---@class Effil.ThreadRunner
---@field path string is a Lua `package.path` value for new state. Default value inherits `package.path` form parent state.
---@field cpath string is a Lua `package.cpath` value for new state. Default value inherits `package.cpath` form parent state.
---@field step integer number of lua instructions lua between cancelation points (where thread can be stopped or paused). Default value is 200. If this values is 0 then thread uses only explicit cancelation points.
---@overload fun(...) : Effil.ThreadHandle Run captured function with specified arguments in separate thread and returns thread handle. input: Any number of arguments required by captured function. output: Thread handle object.
local runner = {}


--- Thread handle provides API for interaction with thread.
---@class Effil.ThreadHandle
local thread = {}

--- Returns thread status.
---@param self Effil.ThreadHandle
---@return string status string values describes status of thread. Possible values are: `"running"`, `"paused"`, `"cancelled"`, `"completed"` and `"failed"`.
---@return string err error message, if any. This value is specified only if thread status == `"failed"`.
---@return string stacktrace stacktrace of failed thread. This value is specified only if thread status == `"failed"`.
function thread.status(self) end

--- Waits for thread completion and returns function result or nothing in case of error.
---@param self Effil.ThreadHandle
---@param time number? is a number of intervals.
---@param metric string? is time interval like `'s'` (seconds).
---@return ... results of captured function invocation or nothing in case of error.
function thread.get(self, time, metric) end

--- Waits for thread completion and returns thread status.
---@param self Effil.ThreadHandle
---@param time number? is a number of intervals.
---@param metric string? is time interval like `'s'` (seconds).
---@return string status string values describes status of thread. Possible values are: "running", "paused", "cancelled", "completed" and "failed".
---@return string err error message, if any. This value is specified only if thread status == "failed".
---@return string stacktrace stacktrace of failed thread. This value is specified only if thread status == "failed".
function thread.wait(self, time, metric) end

--- Interrupts thread execution. Once this function was invoked 'cancellation' flag is set and thread can be stopped sometime in the future (even after this function call done). To be sure that thread is stopped invoke this function with infinite timeout. Cancellation of finished thread will do nothing and return `true`.
---@param self Effil.ThreadHandle
---@param time number? is a number of intervals.
---@param metric string? is time interval like `'s'` (seconds).
---@return boolean result returns `true` if thread was stopped or `false`.
function thread.cancel(self, time, metric) end

--- Pauses thread. Once this function was invoked 'pause' flag is set and thread can be paused sometime in the future (even after this function call done). To be sure that thread is paused invoke this function with infinite timeout.
---@param self Effil.ThreadHandle
---@param time number? is a number of intervals.
---@param metric string? is time interval like `'s'` (seconds).
---@return boolean result returns `true` if thread was paused or `false`. If the thread is completed function will return `false`.
function thread.pause(self, time, metric) end

--- Resumes paused thread. Function resumes thread immediately if it was paused. This function does nothing for completed thread.
---@param self Effil.ThreadHandle
function thread.resume(self) end


--- `effil.table` is a way to exchange data between effil threads. It behaves almost like standard lua tables. All operations with shared table are thread safe. Shared table stores primitive types (number, boolean, string), function, table, light userdata and effil based userdata. Shared table doesn't store lua threads (coroutines) or arbitrary userdata.
---@alias Effil.Table table shared table
local tbl = {}


--- effil.channel is a way to sequentially exchange data between effil threads. It allows to push message from one thread and pop it from another. Channel's message is a set of values of supported types. All operations with channels are thread safe.
---@class Effil.Channel
local channel = {}

--- Pushes message to channel.
---@param self Effil.Channel
---@param ... any any number of values of supported types. Multiple values are considered as a single channel message so one push to channel decreases capacity by one.
---@return boolean pushed is equal to `true` if value(-s) fits channel capacity, `false` otherwise.
function channel.push(self, ...) end

--- Pop message from channel. Removes value(-s) from channel and returns them. If the channel is empty wait for any value appearance.
---@param self Effil.Channel
---@param time number? is a number of intervals (used only if channel is empty).
---@param metric string? is time interval like `'s'` (seconds).
---@return ... variable amount of values which were pushed by a single `channel:push()` call.
function channel.pop(self, time, metric) end

---Get actual amount of messages in channel.
---@param self Effil.Channel
---@return integer size amount of messages in channel.
function channel.size(self) end


---Effil provides custom garbage collector for `effil.table` and `effil.channel` (and functions with captured upvalues). It allows safe manage cyclic references for tables and channels in multiple threads. However it may cause extra memory usage. `effil.gc` provides a set of method configure effil garbage collector. But, usually you don't need to configure it.
---@class Effil.GarbageCollector
local gc = {}

--- Force garbage collection, however it doesn't guarantee deletion of all effil objects.
function gc.collect() end

--- Show number of allocated shared tables and channels.
---@return integer count returns current number of allocated objects. Minimum value is 1, `effil.G` is always present.
function gc.count() end

--- Get/set GC memory step multiplier. Default is `2.0`. GC triggers collecting when amount of allocated objects growth in `step` times.
---@param new_value number? is optional value of step to set. If it's `nil` then function will just return a current value.
---@return number old_value is current (if `new_value == nil`) or previous (if `new_value ~= nil`) value of step.
function gc.step(new_value) end

--- Pause GC. Garbage collecting will not be performed automatically. Function does not have any input or output.
function gc.pause() end

--- Resume GC. Enable automatic garbage collecting.
function gc.resume() end

--- Get GC state.
---@return boolean enabled return `true` if automatic garbage collecting is enabled or `false` otherwise. By default returns `true`.
function gc.enabled() end

return effil
