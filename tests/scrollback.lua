-- Offline tests for the saved chat history (modules/Scrollback.lua): what is written at logout
-- and how saved data from older versions is shrunk on load.
-- Optional second argument: path to a copy of a character's EverlookDBChat.lua saved file.
local ROOT, REAL_SV = ...
local failures, passes = {}, 0
local function step(name, fn)
	local ok, err = pcall(fn)
	if ok then passes = passes + 1; print("  ok   " .. name)
	else failures[#failures + 1] = name; print("  FAIL " .. name .. "\n         " .. tostring(err)) end
end
local function check(cond, msg) if not cond then error(msg, 2) end end
local function eq(a, b, what) if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

-- stand-ins for the addon and the game
ChatFrameUtil = ChatFrameUtil or { TimeBreakDown = function() end }
NUM_CHAT_WINDOWS = 10
GetServerTime = GetServerTime or function() return 1000000 end
local windows = {}
function GetChatWindowInfo(id) local w = windows[id] or {}; return "w", 14, 1, 1, 1, 1, w.shown, false, w.docked end
function IsCombatLog(f) return f == _G.ChatFrame2 end

local enabled = true
local module = { PL = setmetatable({}, { __index = function(_, k) return k end }), pluginopts = {},
	db = { profile = { on = true, scrollback = true, scrollbacklines = 1000, scrollbackduration = 24, removespam = true, divider = "line" } } }
function module:IsEnabled() return enabled end
function module.OnModuleEnable() end
function module.OnModuleDisable() end
EverlookDBChat = { HookedFrames = {} }
function EverlookDBChat:AddModuleExtension(fn) fn() end
function EverlookDBChat:GetModule() return module end

local logoutScript
local realCreateFrame = CreateFrame
CreateFrame = function(...)
	local f = realCreateFrame(...)
	local set = f.SetScript
	f.SetScript = function(self, what, fn) if what == "OnEvent" then logoutScript = fn end; if set then return set(self, what, fn) end end
	return f
end
local chunk = assert(loadfile(ROOT .. "/modules/Scrollback.lua"))
chunk()
CreateFrame = realCreateFrame

-- a window's live history the way the game keeps it: ring buffer, index 1 = newest
local function liveBuffer(n, max)
	local b = { elements = {}, headIndex = { value = n }, maxElements = { value = max } }
	for i = 1, n do
		b.elements[(i - 1) % max + 1] = { message = "line " .. i, r = 1, g = 0.5, b = 0, timestamp = 12.5, serverTime = 900000 + i,
			extraData = { 1, 2, { big = string.rep("x", 50) }, n = 3 } }
	end
	function b:GetEntryAtIndex(i) return module:GetEntryAtIndex(self, i) end
	return b
end

step("old saved data shrinks to the newest lines, plain fields, no combat log", function()
	local saved = { ChatFrame1 = liveBuffer(1500, 3000), ChatFrame2 = liveBuffer(50, 3000), ChatFrame14 = liveBuffer(5, 3000),
		ChatFrame4 = { elements = {}, headIndex = { value = 0 }, maxElements = { value = 3000 } } }
	local out = module:ShrinkSaved(saved, 1000)
	check(out.ChatFrame2 == nil, "combat log dropped")
	check(out.ChatFrame14 == nil, "whisper window dropped")
	check(out.ChatFrame4 == nil, "empty window dropped")
	local c = out.ChatFrame1
	eq(#c.elements, 1000, "lines kept")
	eq(c.headIndex, 1000, "headIndex"); eq(c.maxElements, 1000, "maxElements")
	eq(module:GetEntryAtIndex(c, 1).message, "line 1500", "newest first")
	eq(module:GetEntryAtIndex(c, 1000).message, "line 501", "oldest kept")
	local line = c.elements[1]
	eq(line.extraData.n, 3, "extraData.n kept"); eq(#line.extraData, 0, "extraData values dropped")
	eq(line.timestamp, nil, "no session timestamp")
	for k, v in pairs(line) do check(k == "extraData" or type(v) ~= "table", "plain field " .. k) end
	eq(line.g, 0.5, "colour kept")
end)

step("a wrapped ring buffer is read newest first", function()
	local out = module:ShrinkSaved({ ChatFrame3 = liveBuffer(3500, 3000) }, 10)
	eq(module:GetEntryAtIndex(out.ChatFrame3, 1).message, "line 3500")
	eq(module:GetEntryAtIndex(out.ChatFrame3, 10).message, "line 3491")
end)

step("shrinking twice changes nothing", function()
	local once = module:ShrinkSaved({ ChatFrame1 = liveBuffer(20, 3000) }, 1000)
	local twice = module:ShrinkSaved(once, 1000)
	eq(#twice.ChatFrame1.elements, 20)
	eq(module:GetEntryAtIndex(twice.ChatFrame1, 1).message, "line 20")
end)

step("logout saves only open chat windows, never the live history", function()
	for i = 1, 10 do _G["ChatFrame" .. i] = { historyBuffer = liveBuffer(i == 1 and 2000 or 30, 3000) } end
	windows = { [1] = { docked = 1 }, [2] = { docked = 1 }, [3] = { shown = true }, [4] = {} }
	_G.ChatFrame3.isTemporary = true
	_G.ChatFrame5.historyBuffer = nil
	windows[5] = { shown = true }
	EverlookDBChatHighCPUCharDB = { scrollback = { ChatFrame1 = _G.ChatFrame1.historyBuffer } }
	logoutScript()
	local saved = EverlookDBChatHighCPUCharDB.scrollback
	local names = {}
	for k in pairs(saved) do names[#names + 1] = k end
	table.sort(names)
	eq(table.concat(names, ","), "ChatFrame1")
	check(saved.ChatFrame1 ~= _G.ChatFrame1.historyBuffer, "not the live buffer")
	eq(#saved.ChatFrame1.elements, 1000)
	check(saved.ChatFrame1.GetEntryAtIndex == nil, "no functions")
end)

step("logout with scrollback off or the module off saves nothing", function()
	module.db.profile.scrollback = false
	logoutScript()
	eq(next(EverlookDBChatHighCPUCharDB.scrollback), nil, "scrollback off")
	module.db.profile.scrollback = true
	enabled = false
	logoutScript()
	eq(next(EverlookDBChatHighCPUCharDB.scrollback), nil, "module off")
	enabled = true
end)

step("module enable shrinks old saved data in place", function()
	EverlookDBChatHighCPUCharDB = { scrollback = { ChatFrame1 = liveBuffer(1200, 3000), ChatFrame2 = liveBuffer(10, 3000) } }
	module.RestoreLastSession = function() end
	module.IsHooked = function() return true end
	EverlookDBChat.RegisterChatEvent = function() end
	EverlookDBChat.Events = {}
	module:OnModuleEnable()
	local s = EverlookDBChatHighCPUCharDB.scrollback
	check(s.ChatFrame2 == nil, "combat log gone")
	eq(#s.ChatFrame1.elements, 1000)
	check(module.scrollback == s, "module uses the shrunk copy")
end)

if REAL_SV and REAL_SV ~= "" then
	step("real saved file shrinks", function()
		EverlookDBChatHighCPUCharDB = nil
		assert(loadfile(REAL_SV))()
		local before = 0
		for _, b in pairs(EverlookDBChatHighCPUCharDB.scrollback or {}) do before = before + #(b.elements or {}) end
		local out = module:ShrinkSaved(EverlookDBChatHighCPUCharDB.scrollback, 1000)
		local after, wins = 0, {}
		for name, b in pairs(out) do
			after = after + #b.elements
			wins[#wins + 1] = name .. "=" .. #b.elements
			for _, l in ipairs(b.elements) do check(type(l.message) == "string", "message") end
		end
		table.sort(wins)
		print("         lines " .. before .. " -> " .. after .. " (" .. table.concat(wins, " ") .. ")")
		check(out.ChatFrame2 == nil, "combat log dropped")
		MOCK.realOut = out
	end)
end

print(("\n%d passed, %d failed"):format(passes, #failures))
return #failures
