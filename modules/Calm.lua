---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This module is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Calm: how much of the chat you see while it is on screen.
--
--   * Fewer lines: while the chat is not in use (no mouse over it, no chat box
--     open, not scrolled up), only the newest lines show. The older lines on
--     screen get alpha 0 after the chat frame's own update each frame, and their
--     own alpha back when the chat is in use. Nothing is deleted.
--   * Paced channel chat: lines from numbered channels (General, Trade, ...) come
--     out one at a time. This uses this addon's own message pipeline: a channel
--     line is blocked (DONOTPROCESS) before it is added, and the finished line
--     (links, colours, names) is added later with AddMessage, the same call the
--     pipeline makes. Lines whose text is a secret value are never held back.
--
-- Only event types, channel base names and message text that is not a secret
-- value are read. Nothing protected is touched, so all of it is combat-safe.
---------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function()
	return false
end

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("Calm", "AceHook-3.0")
	local PL = module.PL
	local ChatUI = EverlookDBChat.ChatUI

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			fewlines = true,
			fewlinescount = 6,
			pace = true,
			pacesecs = 2,
		}
	})

	local function isOff(key)
		return function()
			return not module.db.profile[key]
		end
	end

	EverlookDBChat:SetModuleOptions(module.name, {
		name = PL["module_name"],
		desc = PL["module_desc"],
		type = "group",
		args = {
			info = {
				name = PL["module_info"],
				type = "description",
				order = 1,
			},
			fewlines = {
				name = PL["fewlines_name"],
				desc = PL["fewlines_desc"],
				type = "toggle",
				order = 10,
			},
			fewlinescount = {
				name = PL["fewlinescount_name"],
				desc = PL["fewlinescount_desc"],
				type = "range",
				order = 11,
				min = 1,
				max = 30,
				step = 1,
				disabled = isOff("fewlines"),
			},
			pace = {
				name = PL["pace_name"],
				desc = PL["pace_desc"],
				type = "toggle",
				order = 20,
			},
			pacesecs = {
				name = PL["pacesecs_name"],
				desc = PL["pacesecs_desc"],
				type = "range",
				order = 21,
				min = 0.5,
				max = 10,
				step = 0.5,
				disabled = isOff("pace"),
			},
			linefade = {
				name = PL["linefade_info"],
				type = "description",
				order = 30,
			},
			linefadeopen = {
				name = PL["linefade_open"],
				type = "execute",
				order = 31,
				func = function()
					local acd = LibStub("AceConfigDialog-3.0", true)
					if acd then
						acd:SelectGroup("EverlookDB Chat", "display", "EverlookDBChat_Fading")
					end
				end,
			},
		}
	})

	local TICK = 0.1
	local driver
	local enabled = false
	local full = true -- show every line on screen

	local function chatInUse()
		return ChatUI:IsChatFocus() or ChatUI:IsMouseOverChat()
	end

	--[[------------------------------------------------
		Fewer lines on screen
	------------------------------------------------]] --

	local lineAlpha = setmetatable({}, { __mode = "k" }) -- [fontString] = its own alpha while hidden here
	local bottomFirst = setmetatable({}, { __mode = "k" }) -- [chatFrame] = visibleLines[1] is the bottom line

	-- Is visibleLines[1] the newest (bottom) line? Found once per frame by position.
	local function isBottomFirst(cf, lines)
		local known = bottomFirst[cf]
		if known ~= nil then
			return known
		end
		local a, b = lines[1], lines[2]
		if not (a and b and a:IsShown() and b:IsShown()) then
			return true
		end
		local ya, yb = a:GetBottom(), b:GetBottom()
		if type(ya) ~= "number" or type(yb) ~= "number" or issecretvalue(ya) or issecretvalue(yb) then
			return true
		end
		bottomFirst[cf] = ya <= yb
		return bottomFirst[cf]
	end

	local function restoreLines(lines)
		for _, fs in ipairs(lines) do
			local alpha = lineAlpha[fs]
			if alpha then
				if fs:GetAlpha() == 0 then
					fs:SetAlpha(alpha)
				end
				lineAlpha[fs] = nil
			end
		end
	end

	-- Runs after the chat frame's own OnUpdate, so the frame's own line fading
	-- has set its alphas for this frame already.
	function module:CapLines(cf)
		local lines = cf.visibleLines
		if type(lines) ~= "table" then
			return
		end
		if full or not enabled or not self.db.profile.fewlines then
			if next(lineAlpha) then
				restoreLines(lines)
			end
			return
		end
		local keep = self.db.profile.fewlinescount
		local n = #lines
		local fromBottom = isBottomFirst(cf, lines)
		local rank = 0
		for i = 1, n do
			local fs = lines[fromBottom and i or (n - i + 1)]
			if fs and fs:IsShown() then
				rank = rank + 1
				local alpha = fs:GetAlpha()
				if rank > keep then
					if alpha ~= 0 then
						lineAlpha[fs] = alpha -- the frame set it this update
						fs:SetAlpha(0)
					elseif lineAlpha[fs] == nil then
						lineAlpha[fs] = 0
					end
				elseif lineAlpha[fs] then
					if alpha == 0 then
						fs:SetAlpha(lineAlpha[fs])
					end
					lineAlpha[fs] = nil
				end
			end
		end
	end

	function module:OnChatUpdate(cf)
		self:CapLines(cf)
	end

	function module:HookChatFrames()
		for _, name in ipairs(CHAT_FRAMES or {}) do
			local cf = _G[name]
			if cf and not self:IsHooked(cf, "OnUpdate") then
				self:SecureHookScript(cf, "OnUpdate", "OnChatUpdate")
			end
		end
	end

	--[[------------------------------------------------
		Paced channel chat
	------------------------------------------------]] --

	local DEDUPE_SECONDS = 60
	local QUEUE_MAX = 10
	local queues = {} -- [chatFrame] = lines waiting, oldest first
	local lastRelease = {} -- [chatFrame] = GetTime() of the last channel line shown
	local recent = {} -- [frame + channel + text] = GetTime() it was last seen

	local function keepText(text)
		return text
	end

	function module:Release(frame, entry)
		lastRelease[frame] = GetTime()
		frame:AddMessage(entry.text, entry.r, entry.g, entry.b, entry.id, entry.accessID, entry.typeID, entry.event, entry.args, keepText)
	end

	function module:FlushQueues()
		for frame, q in pairs(queues) do
			for _, entry in ipairs(q) do
				self:Release(frame, entry)
			end
		end
		wipe(queues)
	end

	function module:ReleaseDue(now)
		local pace = self.db.profile.pacesecs
		for frame, q in pairs(queues) do
			if #q > 0 and now - (lastRelease[frame] or 0) >= pace then
				self:Release(frame, table.remove(q, 1))
			end
		end
	end

	function module:PruneRecent(now)
		for key, seen in pairs(recent) do
			if now - seen >= DEDUPE_SECONDS then
				recent[key] = nil
			end
		end
	end

	--[[------------------------------------------------
		Channel lines in this addon's message pipeline
	------------------------------------------------]] --

	-- A line from a numbered channel (General, Trade, LookingForGroup, ...), not a
	-- community channel. Reads the channel base name only when it is not secret.
	local function isNumberedChannelLine(message)
		if message.EVENT ~= "CHAT_MSG_CHANNEL" then
			return false
		end
		local baseName = message.ARGS and message.ARGS[9]
		if baseName == nil then
			return true
		end
		if issecretvalue(baseName) or type(baseName) ~= "string" then
			return false
		end
		return baseName:sub(1, 10) ~= "Community:"
	end

	function module:EverlookDBChat_PreAddMessage(_, message, frame, _, text)
		if not enabled or message.DONOTPROCESS or not isNumberedChannelLine(message) then
			return
		end
		local body = message.MESSAGE
		if issecretvalue(text) or issecretvalue(body) or type(body) ~= "string" then
			return -- hidden from addons: shown as usual
		end
		if not self.db.profile.pace then
			return
		end
		local now = GetTime()
		local key = frame:GetName() .. "\001" .. tostring(message.CHANNELNUM or message.CHANNEL or "") .. "\001" .. body
		local seen = recent[key]
		recent[key] = now
		if seen and now - seen < DEDUPE_SECONDS then
			message.DONOTPROCESS = true -- the same line again within a minute
			return
		end
		local q = queues[frame]
		if (not q or #q == 0) and now - (lastRelease[frame] or 0) >= self.db.profile.pacesecs then
			lastRelease[frame] = now -- quiet channel: show it now
			return
		end
		message.DONOTPROCESS = true
		message.EDB_CALM_QUEUE = true
	end

	-- The pipeline has built the finished line and skipped adding it: queue it.
	function module:EverlookDBChat_PostAddMessageBlocked(_, message, frame, event, text, r, g, b, id)
		if not message.EDB_CALM_QUEUE then
			return
		end
		message.EDB_CALM_QUEUE = nil
		if type(text) ~= "string" or issecretvalue(text) or text == "" then
			return
		end
		-- the same clean-up the pipeline does before AddMessage
		local fmt = ChatFrameUtil and ChatFrameUtil.GetTimestampFormat and ChatFrameUtil.GetTimestampFormat()
		if fmt and TimeUtil and TimeUtil.BetterDate then
			text = text:gsub(TimeUtil.BetterDate(fmt, time()), "")
		end
		local args = { n = 0 }
		if type(message.ARGS) == "table" then
			args.n = table.maxn(message.ARGS)
			for i = 1, args.n do
				args[i] = message.ARGS[i]
			end
		end
		local q = queues[frame] or {}
		queues[frame] = q
		q[#q + 1] = {
			text = text, r = r, g = g, b = b, id = id,
			accessID = message.ACCESSID, typeID = message.TYPEID,
			event = event, args = args,
		}
		while #q > QUEUE_MAX do
			table.remove(q, 1)
		end
	end

	--[[------------------------------------------------
		Tick
	------------------------------------------------]] --

	local sinceTick, sincePrune = 0, 0
	local function onUpdate(_, elapsed)
		sinceTick = sinceTick + elapsed
		if sinceTick < TICK then
			return
		end
		sincePrune = sincePrune + sinceTick
		sinceTick = 0
		local p = module.db.profile
		local now = GetTime()
		local inUse = chatInUse()
		full = inUse or ChatUI:IsScrolledUp()
		module:ReleaseDue(now)
		if sincePrune >= 30 then
			sincePrune = 0
			module:PruneRecent(now)
		end
	end

	local function onEvent(_, event)
	end

	function module:OnValueChanged()
		if not self.db.profile.pace then
			self:FlushQueues()
		end
	end

	function module:OnModuleEnable()
		enabled = true
		if not driver then
			driver = CreateFrame("Frame")
		end
		driver:SetScript("OnEvent", onEvent)
		driver:SetScript("OnUpdate", onUpdate)
		ChatUI:AddUser()
		EverlookDBChat.RegisterChatEvent(self, "EverlookDBChat_PreAddMessage")
		EverlookDBChat.RegisterChatEvent(self, "EverlookDBChat_PostAddMessageBlocked")
		self:HookChatFrames()
		if FCF_OpenTemporaryWindow and not self:IsHooked("FCF_OpenTemporaryWindow") then
			self:SecureHook("FCF_OpenTemporaryWindow", "HookChatFrames")
		end
	end

	function module:OnModuleDisable()
		enabled = false
		if driver then
			driver:SetScript("OnUpdate", nil)
			driver:SetScript("OnEvent", nil)
		end
		self:FlushQueues()
		full = true
		for _, name in ipairs(CHAT_FRAMES or {}) do
			local cf = _G[name]
			if cf and type(cf.visibleLines) == "table" then
				restoreLines(cf.visibleLines)
			end
		end
		ChatUI:RemoveUser("chrome")
		self:UnhookAll()
	end

	function module:GetDescription()
		return PL["module_desc"]
	end
end)
