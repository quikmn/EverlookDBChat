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
}
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
	check(logHas("5 of 6 modules on"), "status: " .. table.concat(MOCK.log, " / "))
	check(logHas("/chatfocus"), "names the standalone commands")
end)

print(string.format("\n%d passed, %d failed", passes, #failures))
return #failures
