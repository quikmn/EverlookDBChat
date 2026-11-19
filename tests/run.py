"""Run EverlookDB Chat's offline command tests in Lua 5.1 (same version as WoW) via lupa.

Usage: python -P tests/run.py
"""
import os
import sys

from lupa import lua51

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")


def main() -> int:
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    with open(f"{ROOT}/tests/wowmock.lua", encoding="utf-8") as f:
        lua.execute(f.read())
    with open(f"{ROOT}/tests/run.lua", encoding="utf-8") as f:
        runner = lua.execute("return function(...) " + "local f = assert(loadstring(...)); return f end")(f.read())
    failures = runner(ROOT)
    # the saved chat history tests (tests/scrollback.py) in a fresh Lua state
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.dont_write_bytecode = True
    import scrollback

    print("saved chat history:")
    sys.argv = sys.argv[:1]
    return 1 if (failures or scrollback.main()) else 0


if __name__ == "__main__":
    sys.exit(main())
