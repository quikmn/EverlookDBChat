"""Small checks for EverlookDB Chat logic that doesn't need the game.

Run:  python -P tests/test_tabstyle.py   (needs lupa: pip install lupa)

* every .lua file in addon/, services/ and modules/ compiles under Lua 5.1;
* the flat tab colours, dot and fade target (modules/TabStyle.lua);
* the help-line collapse lookup (modules/Tidy.lua).
"""
import pathlib
import sys

import lupa.lua51 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
load = lua.eval("function(src, name, ...) local f, err = loadstring(src, name); if not f then return nil, err end; return f(...) end")
compile_only = lua.eval("function(src, name) local f, err = loadstring(src, name); return f ~= nil, err end")

failures = []


def check(cond, what):
    if not cond:
        failures.append(what)
        print("FAIL", what)


# 1. syntax
for folder in ("addon", "services", "modules"):
    for path in sorted((ROOT / folder).glob("*.lua")):
        ok, err = compile_only(path.read_text(encoding="utf-8-sig"), "@" + str(path.relative_to(ROOT)))
        check(ok, f"syntax {path.name}: {err}")

# 2. TabStyle logic
private = lua.table()
load((ROOT / "modules" / "TabStyle.lua").read_text(encoding="utf-8"), "@TabStyle.lua", "EverlookDBChat", private)
L = private.TabStyleLogic
check(L is not None, "TabStyleLogic exported")

sel = L.TextColor(True, False)
check((sel[1], sel[2], sel[3]) == (1, 1, 1), "selected tab is white")
hs = L.TextColor(True, True)
check((hs[1], hs[2], hs[3]) == (1, 1, 1), "hover doesn't change the selected tab")
normal = L.TextColor(False, False)
hover = L.TextColor(False, True)
check(normal[1] < hover[1] < 1, "unselected is muted grey, hover lifts it")

check(L.ShowDot(False, True, False) is True, "dot on an alerting tab")
check(L.ShowDot(False, False, True) is True, "dot on a flashing tab")
check(L.ShowDot(True, True, True) is False, "no dot on the selected tab")
check(L.ShowDot(False, False, False) is False, "no dot without news")

check(L.Target(False, 100, None) == 1, "always shown when not hover-only")
check(L.Target(True, 100, None) == 0, "hidden before the mouse ever came")
check(L.Target(True, 100, 99.8) == 1, "shown right after the mouse left")
check(L.Target(True, 100, 100 - L.HIDE_DELAY - 0.01) == 0, "hidden after the delay")

keys = set(L.ART_KEYS.values())
for k in ("Left", "Middle", "Right", "ActiveLeft", "HighlightMiddle", "glow"):
    check(k in keys, f"art key {k}")

# 3. Tidy logic
private2 = lua.table()
load((ROOT / "modules" / "Tidy.lua").read_text(encoding="utf-8"), "@Tidy.lua", "EverlookDBChat", private2)
T = private2.TidyLogic
HELP = "Type '/help' for a listing of a few commands."
make_entries = lua.eval("""function(list)
  return function(i) return list[i] end
end""")


def entries(*rows):
    t = lua.table()
    for i, (msg, ts) in enumerate(rows, 1):
        t[i] = lua.table(message=msg, timestamp=ts)
    return make_entries(t)


check(T.FindOlderCopy(entries(("[00:01] " + HELP, 100), ("hello", 99), ("[00:00] " + HELP, 50)), HELP, 100) == 3,
      "older help line found")
check(T.FindOlderCopy(entries((HELP, 300), (HELP, 100)), HELP, 300) is None, "too old help line kept")
check(T.FindOlderCopy(entries((HELP, 100), ("a", 1)), HELP, 100) is None, "single help line kept")

# 4. Chat focus check (services/chatui.lua) with a protected window's box focused:
# every method on a forbidden frame errors except IsForbidden.
focus_test = lua.eval(r"""function(src)
  local calls = { parent = 0 }
  local function frame(parent)
    local f = { __alpha = 1, __parent = parent }
    function f:GetParent() calls.parent = calls.parent + 1; return self.__parent end
    function f:GetAlpha() return self.__alpha end
    function f:SetAlpha(a) self.__alpha = a end
    function f:IsShown() return true end
    function f:IsMouseOver() return false end
    function f:IsForbidden() return false end
    return f
  end
  local forbidden = setmetatable({}, { __index = function(_, k)
    if k == "IsForbidden" then return function() return true end end
    return function() error("calling '" .. k .. "' on bad self (Attempt to access forbidden object)") end
  end })
  local env = setmetatable({}, { __index = _G })
  env._G = env
  env.CHAT_FRAMES = { "ChatFrame1" }
  env.ChatFrame1 = frame(nil)
  env.ChatFrame1EditBox = frame(env.ChatFrame1)
  env.Inner = frame(env.ChatFrame1)
  env.InnerBox = frame(env.Inner)
  env.Loose = frame(nil)
  env.hooksecurefunc = function() end
  env.CreateFrame = function() return { SetScript = function() end } end
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  local focus = forbidden
  env.GetCurrentKeyBoardFocus = function() return focus end
  local private = {}
  local chunk = assert(loadstring(src, "@chatui.lua"))
  setfenv(chunk, env)
  chunk("EverlookDBChat", private)
  local UI = private.ChatUI
  UI:Collect()
  local out = {}
  local ok, res = pcall(UI.IsChatFocus, UI)
  out.forbiddenOk, out.forbiddenRes = ok, res
  focus = env.InnerBox
  out.inner = UI:IsChatFocus()
  local before = calls.parent
  for i = 1, 20 do UI:IsChatFocus() end
  out.repeatCalls = calls.parent - before
  focus = env.Loose
  out.loose = UI:IsChatFocus()
  -- a parent that is forbidden ends the walk quietly
  focus = frame(forbidden)
  local ok2, res2 = pcall(UI.IsChatFocus, UI)
  out.forbiddenParentOk, out.forbiddenParentRes = ok2, res2
  return out
end""")
r = focus_test((ROOT / "services" / "chatui.lua").read_text(encoding="utf-8"))
check(r.forbiddenOk is True and r.forbiddenRes is False, f"protected window's focused box: no error, not chat ({r.forbiddenRes})")
check(r.inner is True, "a box inside a chat window counts as chat focus")
check(r.repeatCalls == 0, f"same focus is not walked again every tick ({r.repeatCalls} GetParent calls)")
check(r.loose is False, "a box outside the chat is not chat focus")
check(r.forbiddenParentOk is True and r.forbiddenParentRes is False, "forbidden parent: no error")

if failures:
    print(f"{len(failures)} failed")
    sys.exit(1)
print("all ok")
