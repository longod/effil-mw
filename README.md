# Effil-MW

Provide the multithreading library [Effil](https://github.com/effil/effil) for Morrowind.

Currently, it is confirmed to work on [MWSE](https://github.com/MWSE/MWSE).


## Known Issues
###  On LuaJIT (Not only in MWSE)

- Frequent accesses to the same object between threads will cause resource leaks.
This frequency is such that they read and write while in a busy loop with each other.
Generally, such processing should be avoided in multi-threading.
- A thread in a real busy loop cannot be terminated by `cancel`.
Should call `yield` or do some meaningful processing in a thread.

### On MWSE

- MWSE-specific functions and userdata cannot be called within a thread. This includes implicitly custom processes such as `print`.
- Although the detailed conditions are unknown, it seems that type conversions that do not match the `effil` type may cause resource leaks.


## Manual build on Windows

1. Setup
    1. Install latest of Visual Studio
        - require cmake
    1. git submodule update --init --recursive
1. Build LuaJIT used in MWSE
    1. vcvars32.bat
        - C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat
    1. cd src/MWSE/deps/LuaJIT/src
    1. msvcbuild.bat
1. Build Effil
    1. cd src/effil
    1. mkdir build
    1. cd build
    1. cmake .. -A Win32 -DLUA_INCLUDE_DIR="../../src/MWSE/deps/LuaJIT/src" -DLUA_LIBRARY="../../src/MWSE/deps/LuaJIT/src/lua*.lib"
    1. cmake --build . --target effil --config Release -- -m 
1. Copy into MWSE
    1. Copy "effil.dll" to "Data Files/MWSE/lib"
