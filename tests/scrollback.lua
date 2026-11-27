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

-- Every frame that listens for PLAYER_LOGOUT, in the order they were made (the
-- game calls them in that order). The settings library loads first, as in game.
local logoutFrames = {}
local realCreateFrame = CreateFrame
CreateFrame = function(...)
	local f = realCreateFrame(...)
	local reg = f.RegisterEvent
	f.RegisterEvent = function(self, e, ...)
		if e == "PLAYER_LOGOUT" then logoutFrames[#logoutFrames + 1] = self end
		return reg(self, e, ...)
	end
	return f
end
local function firePlayerLogout()
	for _, f in ipairs(logoutFrames) do
		local fn = f:GetScript("OnEvent")
		if fn then fn(f, "PLAYER_LOGOUT") end
	end
end
geterrorhandler = geterrorhandler or function() return error end
strmatch = strmatch or string.match
UnitFactionGroup = UnitFactionGroup or function() return "Alliance" end
GetLocale = GetLocale or function() return "enUS" end
UnitClass = UnitClass or function() return "Mage", "MAGE" end
UnitRace = UnitRace or function() return "Human", "Human" end
GetRealmName = GetRealmName or function() return "Realm" end
UnitNameUnmodified = UnitNameUnmodified or function() return "Tester" end
GetCurrentRegionName = GetCurrentRegionName or function() return "EU" end
GetCurrentRegion = GetCurrentRegion or function() return 3 end
wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
for _, lib in ipairs({ "LibStub/LibStub.lua", "CallbackHandler-1.0/CallbackHandler-1.0.lua", "AceDB-3.0/AceDB-3.0.lua" }) do
	assert(loadfile(ROOT .. "/Libs/" .. lib))()
end

-- the module's settings the way the addon makes them: a real AceDB namespace with the History defaults
local historyDefaults = { profile = { on = true, scrollback = true, scrollbacklines = 1000, scrollbackduration = 24, removespam = true, divider = "line" } }
EverlookDBChatDB = {}
local rootDB = LibStub("AceDB-3.0"):New("EverlookDBChatDB", { profile = { modules = {} } }, true)

local enabled = true
local module = { PL = setmetatable({}, { __index = function(_, k) return k end }), pluginopts = {},
	db = rootDB:RegisterNamespace("History", historyDefaults) }
function module:IsEnabled() return enabled end
function module.OnModuleEnable() end
function module.OnModuleDisable() end
EverlookDBChat = { HookedFrames = {} }
function EverlookDBChat:AddModuleExtension(fn) fn() end
function EverlookDBChat:GetModule() return module end

local chunk = assert(loadfile(ROOT .. "/modules/Scrollback.lua"))
chunk()
CreateFrame = realCreateFrame
local ourFrame = logoutFrames[#logoutFrames]
local function logoutScript() ourFrame:GetScript("OnEvent")(ourFrame, "PLAYER_LOGOUT") end

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

-- The game's own chat window storage (Blizzard_SharedXML CircularBuffer +
-- ScrollingMessageFrame on this client): the head index is a SecureNumber object
-- read through GetValue, lines are pushed by AddMessage as
-- { message, r, g, b, extraData = { ..., n }, timestamp }.
local function secureNumber(v)
	local n = { value = v or 0 }
	function n:GetValue() return self.value end
	function n:SetValue(x) self.value = x end
	function n:Increment() self.value = self.value + 1 end
	return n
end
local function circularBuffer(max)
	local b = { headIndex = secureNumber(0), maxElements = secureNumber(max), elements = {} }
	function b:GetNumElements() return #self.elements end
	function b:GetMaxNumElements() return self.maxElements:GetValue() end
	function b:PushFront(e)
		self.headIndex:Increment()
		local at = self.headIndex:GetValue()
		self.elements[at] = e
		self.headIndex:SetValue(at % self.maxElements:GetValue())
		return at
	end
	function b:CalculateElementIndex(index)
		local g = self.headIndex:GetValue() - index + 1
		if g == 0 then return self:GetMaxNumElements() end
		return (g - 1) % self:GetMaxNumElements() + 1
	end
	function b:GetEntryAtIndex(index)
		if index > 0 and index <= self:GetNumElements() then
			return self.elements[self:CalculateElementIndex(index)]
		end
	end
	return b
end
local function chatFrame(name, maxLines)
	local f = { historyBuffer = circularBuffer(maxLines) }
	function f:GetName() return name end
	function f:AddMessage(message, r, g, b, ...)
		local extra
		if select("#", ...) > 0 then extra = { ... }; extra.n = select("#", ...) end
		self.historyBuffer:PushFront({ message = message, r = r, g = g, b = b, extraData = extra, timestamp = 12.5 })
		module:AddMessage(self) -- the module's hook stamps the server time
	end
	function f:GetNumMessages() return self.historyBuffer:GetNumElements() end
	function f:GetMessageInfo(i)
		local e = self.historyBuffer:GetEntryAtIndex(self.historyBuffer:GetNumElements() - i + 1)
		if e then return e.message, e.r, e.g, e.b end
	end
	_G[name] = f
	return f
end

local function freshChat(lines, maxLines)
	for i = 1, 10 do _G["ChatFrame" .. i] = nil end
	windows = { [1] = { shown = true, docked = 1 }, [2] = { docked = 1 } }
	local f = chatFrame("ChatFrame1", maxLines or 3000)
	chatFrame("ChatFrame2", 3000):AddMessage("combat line", 1, 1, 1)
	for i = 1, lines do
		if i % 7 == 0 then
			f:AddMessage(MOCK.Secret("secret " .. i), 1, 1, 1, 0, 0, 0, 0, 1) -- arrived during a chat lockdown
		else
			f:AddMessage("|cffffffff[Trade] Someone: line " .. i .. "|r", 1, 0.75, 0.75, 0, 3, 4, 5, 6)
		end
	end
	return f
end

step("logout in game order (settings library first) saves the newest real lines", function()
	module.db:RegisterDefaults(historyDefaults)
	local f = freshChat(1400, 1200)
	eq(f:GetNumMessages(), 1200, "live lines (ring buffer wrapped)")
	EverlookDBChatHighCPUCharDB = { scrollback = {} }
	firePlayerLogout()
	local saved = EverlookDBChatHighCPUCharDB.scrollback
	check(saved.ChatFrame1, "chat window saved (was empty: defaults gone before the copy)")
	check(saved.ChatFrame2 == nil, "combat log not saved")
	local c = saved.ChatFrame1
	check(#c.elements > 800, "most lines kept, got " .. #c.elements)
	eq(module:GetEntryAtIndex(c, 1).message, "|cffffffff[Trade] Someone: line 1399|r", "newest real line first (1400 was secret)")
	for _, l in ipairs(c.elements) do
		check(type(l.message) == "string", "only plain text saved")
		check(l.serverTime, "line has its time")
		eq(l.extraData.n, 5, "real chat count")
	end
end)

step("a setting changed from its default still counts at logout", function()
	module.db:RegisterDefaults(historyDefaults)
	freshChat(300)
	module.db.profile.scrollbacklines = 100
	EverlookDBChatHighCPUCharDB = { scrollback = {} }
	firePlayerLogout()
	eq(#EverlookDBChatHighCPUCharDB.scrollback.ChatFrame1.elements, 100, "lines kept")
	module.db:RegisterDefaults(historyDefaults)
	module.db.profile.scrollbacklines = 1000
	module.db.profile.scrollback = false
	firePlayerLogout()
	eq(next(EverlookDBChatHighCPUCharDB.scrollback), nil, "scrollback turned off: nothing saved")
	module.db:RegisterDefaults(historyDefaults)
	module.db.profile.scrollback = true
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
