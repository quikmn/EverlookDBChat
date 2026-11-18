-- Offline tests for /echat (addon/commands.lua): loads LibStub, EverlookUI and the command file against wowmock.lua
-- with a stand-in for the addon (its modules, AceDB profile and AceConfig window), then drives the slash command.
local ROOT = ...
local failures, passes = {}, 0

local function step(name, fn)
	local ok, err = pcall(fn)
	if ok then passes = passes + 1; print("  ok   " .. name)
	else failures[#failures + 1] = name .. ": " .. tostring(err); print("  FAIL " .. name .. "\n         " .. tostring(err)) end
end
local function check(cond, msg) if not cond then error(msg, 2) end end
local function eq(a, b, what) if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function logHas(s)
	for _, l in ipairs(MOCK.log) do if l:find(s, 1, true) then return true end end
	return false
end
local function lastLog() return MOCK.log[#MOCK.log] or "" end

-- The addon, as far as the commands see it.
local calls = {}
local function module(name, on)
	local m = { moduleName = name, enabled = on, db = { profile = { on = on } } }
	function m:IsEnabled() return self.enabled end
	function m:Enable() self.enabled = true end
	function m:Disable() self.enabled = false end
	function m:GetDescription() return name .. " module" end
	return m
end
local modules = {
	Timestamps = module("Timestamps", true),
	Search = module("Search", true),
	Clear = module("Clear", false),
	CopyChat = module("CopyChat", true),
	Calm = module("Calm", true),
	Alias = module("Alias", true),
	Placement = module("Placement", true),
}
-- placement mode with the real lock state (addon/placement.lua, loaded below)
function modules.Placement:IsUnlocked() return self.state ~= nil and not self.state:IsLocked() end
function modules.Placement:SetUnlocked(on) self.state:SetLocked(not on) end
function modules.Search:Find(word, all) calls[#calls + 1] = "find " .. word .. (all and " all" or "") end
function modules.CopyChat:DoCopyChat(f) calls[#calls + 1] = "copy " .. tostring(f and f:GetName()) end
function modules.Calm:ToggleFocus() calls[#calls + 1] = "focus" end
function modules.Alias:listAliases(q) calls[#calls + 1] = "aliases " .. tostring(q) end

local windowOpen = false
local private = {
	EnableTasks = {},
	db = {
		profile = { modules = {} },
		realm = { PlayerNameBlackList = { you = true } },
	},
}
function private.db:ResetProfile() calls[#calls + 1] = "resetprofile" end
private.Addon = {
	IterateModules = function() return pairs(modules) end,
	GetModule = function(_, name) return modules[name] end,
}
function private:GetModule(name) local m = modules[name]; return m and m:IsEnabled() and m or nil end
function private:ToggleOptionsWindow() windowOpen = not windowOpen end
function private:IsOptionsWindowShown() return windowOpen end
function private:UpdateOptions() end

strmatch = strmatch or string.match -- Ace's LibStub uses it
local cleared = {}
for i = 1, 10 do
	local f = CreateFrame("Frame", "ChatFrame" .. i)
	f.Clear = function() cleared[i] = true end
end
NUM_CHAT_WINDOWS = 10
SELECTED_CHAT_FRAME = ChatFrame3

local function load(path, ...)
	local chunk, err = loadfile(ROOT .. "/" .. path)
	if not chunk then error("syntax: " .. err) end
	return chunk(...)
end

step("load LibStub, EverlookUI and addon/commands.lua", function()
	load("Libs/LibStub/LibStub.lua")
	load("Libs/EverlookUI/EverlookUI.lua")
	load("addon/placement.lua", "EverlookDBChat", private)
	modules.Placement.state = private.Placement.NewState({}, {})
	load("addon/commands.lua", "EverlookDBChat", private)
	for _, task in ipairs(private.EnableTasks) do task(private) end
	check(private.app, "app made")
	eq(SLASH_EDBCHAT1, "/echat", "main command")
	eq(SLASH_EDBCHAT2, "/edbchat", "old name kept")
end)

local function slash(msg) SlashCmdList.EDBCHAT(msg) end

step("/echat and /edbchat open the window", function()
	slash("")
	check(windowOpen, "bare /echat opens the window")
	slash("")
	check(not windowOpen, "and closes it")
	slash("options")
	check(windowOpen, "/echat options opens it")
	slash("options")
	check(windowOpen, "options never closes it")
	windowOpen = false
end)

step("/echat help lists find, clear, copy, focus and blacklist", function()
	MOCK.log = {}
	slash("help")
	for _, want in ipairs({ "/echat find <words>", "/echat clear [all]", "/echat copy", "/echat focus", "/echat blacklist <word>",
		"/echat unblacklist <word>", "/echat aliases", "/echat reset", "/echat get [setting]" }) do
		check(logHas(want), "help lists " .. want)
	end
	check(not logHas("debugmsg"), "debugmsg is hidden")
	check(not logHas("search <words>"), "no search box to offer")
	check(logHas("Also works as /edbchat"), "names the old command")
	check(MOCK.log[1]:find("EverlookDB Chat|r: ", 1, true), "prefix: " .. MOCK.log[1])
end)

step("modules are on/off settings: /echat timestamps off, off timestamps, get", function()
	slash("timestamps off")
	check(not modules.Timestamps.enabled and not modules.Timestamps.db.profile.on, "disabled")
	eq(private.db.profile.modules.Timestamps, 2, "Module control value off")
	slash("on timestamps")
	check(modules.Timestamps.enabled, "enabled")
	eq(private.db.profile.modules.Timestamps, 3, "Module control value on")
	MOCK.log = {}
	slash("get")
	check(logHas("timestamps") and logHas("copychat"), "get lists the modules")
	MOCK.log = {}
	slash("clear on")
	check(modules.Clear.enabled, "/echat clear on switches the Clear module")
	slash("clear off")
	check(not modules.Clear.enabled, "/echat clear off")
	slash("search off")
	check(not modules.Search.enabled, "/echat search off")
	slash("search on")
	check(modules.Search.enabled, "/echat search on")
end)

step("find, clear, copy, focus, aliases, blacklist under /echat", function()
	calls = {}
	slash("find dragon")
	eq(calls[1], "find dragon all", "find")
	slash("copy")
	eq(calls[2], "copy ChatFrame3", "copy the selected window")
	slash("focus")
	eq(calls[3], "focus", "focus")
	slash("aliases")
	eq(calls[4], "aliases nil", "aliases")
	slash("clear")
	check(cleared[3] and not cleared[1], "clear: the selected window only")
	slash("clear all")
	check(cleared[1] and cleared[10], "clear all")
	slash("blacklist Bob")
	check(private.db.realm.PlayerNameBlackList.bob, "blacklisted")
	slash("unblacklist bob")
	check(not private.db.realm.PlayerNameBlackList.bob, "unblacklisted")
	-- a command whose module is off says so and how to turn it on
	modules.Calm.enabled = false
	calls, MOCK.log = {}, {}
	slash("focus")
	check(#calls == 0, "nothing run")
	check(logHas("/echat calm on"), "says how to turn it on: " .. lastLog())
	modules.Calm.enabled = true
end)

step("/echat reset asks first", function()
	calls, MOCK.log = {}, {}
	slash("reset")
	eq(#calls, 0, "asked first")
	check(logHas("again within 10 s"), "says how")
	slash("reset")
	eq(calls[1], "resetprofile", "then resets the profile")
end)

step("/echat fnd x suggests find; status", function()
	MOCK.log = {}
	slash("fnd x")
	check(logHas("Did you mean /echat find x?"), "suggestion: " .. lastLog())
	MOCK.log = {}
	slash("status")
	check(logHas("6 of 7 modules on"), "status: " .. table.concat(MOCK.log, " / "))
	check(logHas("/chatfocus"), "names the standalone commands")
end)

------------------------------------------------------------------------
-- Chat placement (addon/placement.lua): edit box anchors, the Bottom-left preset, snapping, lock state
------------------------------------------------------------------------
local P = private.Placement

local function near(a, b, what) if math.abs(a - b) > 0.01 then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function rectEq(r, l, b, w, h, what)
	near(r.l, l, what .. " left"); near(r.b, b, what .. " bottom"); near(r.w, w, what .. " width"); near(r.h, h, what .. " height")
end
local SCREEN = { w = 1365.33, h = 768 } -- 1920x1080, pixel-perfect UI scale
local CHAT = { l = 8, b = 40, w = 430, h = 180 }
local CFG = { height = 22 }

step("edit box below the chat, same width; above when the chat is on the bottom edge", function()
	local r, side, lift = P.EditBoxRect("BELOW", CHAT, SCREEN, CFG)
	rectEq(r, 8, 16, 430, 22, "below"); eq(side, "below", "side"); eq(lift, 0, "no lift")
	check(r.b + r.h <= CHAT.b, "never overlaps the chat")
	local flush = { l = 0, b = 0, w = 658, h = 193 } -- the owner's Edit Mode placement
	r, side = P.EditBoxRect("BELOW", flush, SCREEN, CFG)
	eq(side, "above", "no room below")
	near(r.b, 193 + P.TAB_HEIGHT + P.GAP, "above the tabs")
	check(r.b >= flush.b + flush.h, "never overlaps the chat")
	r, side = P.EditBoxRect("BELOW", { l = 0, b = 24, w = 400, h = 100 }, SCREEN, CFG)
	eq(side, "below", "exactly fits"); near(r.b, 0, "on the bottom edge")
end)

step("edit box above, inside and free", function()
	local r, side = P.EditBoxRect("ABOVE", CHAT, SCREEN, CFG)
	rectEq(r, 8, 40 + 180 + P.TAB_HEIGHT + P.GAP, 430, 22, "above"); eq(side, "above", "side")
	r, side = P.EditBoxRect("ABOVE", { l = 8, b = 560, w = 430, h = 190 }, SCREEN, CFG)
	eq(side, "below", "no room above"); near(r.b, 560 - 2 - 22, "below instead")
	local lift
	r, side, lift = P.EditBoxRect("INSIDE", CHAT, SCREEN, CFG)
	rectEq(r, 8, 40, 430, 22, "inside"); eq(side, "inside", "side"); eq(lift, 22 + P.GAP, "lines move up by the box")
	r, side = P.EditBoxRect("FREE", CHAT, SCREEN, { height = 22, free = { l = 500, top = 300, w = 300 } })
	rectEq(r, 500, 278, 300, 22, "free"); eq(side, "free", "side")
	r = P.EditBoxRect("FREE", CHAT, SCREEN, { height = 22, free = { l = 1300, top = 5, w = 300 } })
	rectEq(r, SCREEN.w - 300, 0, 300, 22, "free, kept on screen")
	r = P.EditBoxRect("FREE", CHAT, SCREEN, CFG)
	rectEq(r, 8, 16, 430, 22, "free without a saved place starts below")
end)

step("edit box always fully on screen; old Prat values", function()
	local r = P.EditBoxRect("BELOW", { l = -50, b = 100, w = 400, h = 100 }, SCREEN, CFG)
	near(r.l, 0, "pulled in from the left")
	r = P.EditBoxRect("BELOW", { l = 1200, b = 100, w = 400, h = 100 }, SCREEN, CFG)
	near(r.l + r.w, SCREEN.w, "pulled in from the right")
	eq(P.NormalizeMode("BOTTOM"), "BELOW", "BOTTOM"); eq(P.NormalizeMode("TOP"), "ABOVE", "TOP")
	eq(P.NormalizeMode("LOCK"), "FREE", "LOCK"); eq(P.NormalizeMode(nil), "BELOW", "default")
	eq(P.NormalizeMode("INSIDE"), "INSIDE", "INSIDE")
	local x, y = P.Offset({ l = 8, b = 16 }, CHAT)
	eq(x, 0, "offset x"); eq(y, -24, "offset y")
end)

step("Bottom-left preset on a few screens: flush left, box below inside the screen", function()
	for _, s in ipairs({ { w = 1365.33, h = 768 }, { w = 1024, h = 768 }, { w = 1834.67, h = 768 }, { w = 1280, h = 720 }, { w = 800, h = 600 } }) do
		local name = s.w .. "x" .. s.h
		local r = P.Preset(s, 22, 8)
		eq(r.l, 8, name .. " left margin")
		eq(r.b, 8 + 22 + P.GAP, name .. " room for the box")
		check(r.w >= 340 and r.w <= 520, name .. " width " .. r.w)
		check(r.h >= 120 and r.h <= 220, name .. " height " .. r.h)
		check(r.b + r.h + P.TAB_HEIGHT <= s.h, name .. " fits")
		local eb, side = P.EditBoxRect("BELOW", r, s, CFG)
		eq(side, "below", name .. " box below")
		near(eb.b, 8, name .. " box on the margin")
	end
	rectEq(P.Preset(SCREEN, 22, 8), 8, 32, 437, 184, "1920x1080")
end)

step("drag snaps to the edges and keeps room for the box; resize keeps the opposite corner", function()
	local snap = { margin = 8, reserve = P.ReserveBelow("BELOW", 22), dist = 12 }
	local r = P.Drag(CHAT, -5, -15, SCREEN, snap) -- to l=3, b=25: near the margin and the reserve line
	rectEq(r, 8, 32, 430, 180, "snapped")
	r = P.Drag(CHAT, -100, -100, SCREEN, nil)
	rectEq(r, 0, 0, 430, 180, "no snap: kept on screen")
	r = P.Drag(CHAT, 925, 0, SCREEN, snap) -- right edge at 1363, within 12 of 1357
	near(r.l + r.w, SCREEN.w - 8, "snapped right")
	eq(P.ReserveBelow("INSIDE", 22), 0, "no reserve inside")
	r = P.Resize(CHAT, "TOPRIGHT", 50, 20, SCREEN, nil)
	rectEq(r, 8, 40, 480, 200, "top-right")
	r = P.Resize(CHAT, "BOTTOMLEFT", 30, -10, SCREEN, nil)
	rectEq(r, 38, 30, 400, 190, "bottom-left")
	r = P.Resize(CHAT, "TOPLEFT", 1000, -1000, SCREEN, nil)
	eq(r.w, P.MIN_W, "min width"); eq(r.h, P.MIN_H, "min height"); eq(r.l + r.w, 438, "right edge stays")
end)

step("lock state: unlock shows, lock saves only a moved chat, release hands it back", function()
	local db, shown, moved = {}, false, nil
	local st = P.NewState(db, {
		show = function() shown = true end,
		hide = function() shown = false end,
		read = function() return moved end,
	})
	check(st:IsLocked(), "starts locked")
	eq(st:Wanted(), nil, "Edit Mode keeps the chat at first")
	check(st:Unlock() and shown and not st:IsLocked(), "unlocked")
	check(not st:Unlock(), "unlock twice does nothing")
	check(st:Lock() and not shown, "locked")
	check(not db.managed, "nothing moved: Edit Mode still has it")
	st:Unlock()
	moved = { l = 8.4, b = 31.6, w = 437, h = 184 }
	eq(st:Toggle(), true, "toggle locks")
	check(db.managed, "placed")
	rectEq(st:Wanted(), 8, 32, 437, 184, "saved, rounded")
	check(not st:Lock(), "lock twice does nothing")
	st:Release()
	eq(st:Wanted(), nil, "back to Edit Mode")
	check(P.Same({ l = 1, b = 1, w = 2, h = 2 }, { l = 1.5, b = 1, w = 2, h = 2 }), "same within a pixel")
end)

step("/echat move, unlock and lock drive placement mode", function()
	local m = modules.Placement
	slash("unlock")
	check(m:IsUnlocked(), "unlocked")
	slash("lock")
	check(not m:IsUnlocked(), "locked")
	slash("move")
	check(m:IsUnlocked(), "move flips it on")
	slash("move")
	check(not m:IsUnlocked(), "and off")
	MOCK.log = {}
	slash("help")
	check(logHas("unlock") and logHas("move the chat and see where the chat box goes"), "help lists unlock and lock")
	m.enabled = false
	MOCK.log = {}
	slash("unlock")
	check(not m:IsUnlocked() and logHas("/echat placement on"), "module off says how: " .. lastLog())
	m.enabled = true
end)

print(string.format("\n%d passed, %d failed", passes, #failures))
return #failures
