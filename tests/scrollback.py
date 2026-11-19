"""Run the saved chat history tests (tests/scrollback.lua) in Lua 5.1 via lupa.

Usage: python -P tests/scrollback.py [copy-of-a-saved-EverlookDBChat.lua]
With a saved file (use a copy), it is also shrunk and the result written next to it as <name>.shrunk.lua.
"""
import os
import sys

from lupa import lua51

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")


def dump(v, ind=""):
    if v is None or isinstance(v, bool):
        return {None: "nil", True: "true", False: "false"}[v]
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    out = []
    for k, x in sorted(v.items(), key=lambda kv: (isinstance(kv[0], str), kv[0])):
        key = '["%s"]' % k if isinstance(k, str) else "[%d]" % k
        out.append("%s\t%s = %s," % (ind, key, dump(x, ind + "\t")))
    return "{\n" + "\n".join(out) + "\n" + ind + "}"


def main() -> int:
    real = sys.argv[1].replace("\\", "/") if len(sys.argv) > 1 else ""
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    with open(f"{ROOT}/tests/wowmock.lua", encoding="utf-8") as f:
        lua.execute(f.read())
    with open(f"{ROOT}/tests/scrollback.lua", encoding="utf-8") as f:
        chunk = lua.eval("loadstring")(f.read())
    failures = chunk(ROOT, real)
    out = lua.globals().MOCK.realOut if real else None
    if out is not None:
        ltype = lua.eval("type")

        def conv(t):
            return {k: conv(x) for k, x in t.items()} if ltype(t) == "table" else t

        target = real[:-4] + ".shrunk.lua"
        with open(target, "w", encoding="utf-8") as f:
            f.write('EverlookDBChatHighCPUCharDB = {\n\t["scrollback"] = ' + dump(conv(out), "\t") + ",\n}\n")
        print(f"         {os.path.getsize(real)} bytes -> {os.path.getsize(target)} bytes")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
