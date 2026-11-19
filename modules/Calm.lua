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
--   * Focus: in combat (and optionally in dungeons and raids, or by hand with
--     /chat focus or a key) numbered channels are not shown at all.
--   * Whispers: an incoming whisper keeps the chat awake and every line on
--     screen until you have seen it, with a small marker to reply.
--   * Mentions: a channel line with your character's name shows even in focus
--     and is never held back.
--   * Chrome on hover: tabs and chat buttons only show while the mouse is over
--     the chat or the chat box is open (services/chatui.lua does the fading).
--
-- Only event types, channel base names and message text that is not a secret
-- value are read. Nothing protected is touched, so all of it is combat-safe.
---------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function()
	return false
end

BINDING_NAME_EDBCHAT_FOCUS = "Toggle chat focus"

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
			focuscombat = true,
			focusinstance = false,
			whisperpin = true,
			whispermarker = true,
			whispersound = false,
			mentions = true,
			chromehover = true,
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
			focusheader = {
				name = PL["focus_header"],
				type = "header",
				order = 40,
			},
			focusinfo = {
				name = PL["focus_info"],
				type = "description",
				order = 41,
			},
			focuscombat = {
				name = PL["focuscombat_name"],
				desc = PL["focuscombat_desc"],
				type = "toggle",
				order = 42,
			},
			focusinstance = {
				name = PL["focusinstance_name"],
				desc = PL["focusinstance_desc"],
				type = "toggle",
				order = 43,
			},
			whisperpin = {
				name = PL["whisperpin_name"],
				desc = PL["whisperpin_desc"],
				type = "toggle",
				order = 50,
			},
			whispermarker = {
				name = PL["whispermarker_name"],
				desc = PL["whispermarker_desc"],
				type = "toggle",
				order = 51,
			},
			whispersound = {
				name = PL["whispersound_name"],
				desc = PL["whispersound_desc"],
				type = "toggle",
				order = 52,
			},
			mentions = {
				name = PL["mentions_name"],
				desc = PL["mentions_desc"],
				type = "toggle",
				order = 60,
			},
			chromehover = {
				name = PL["chromehover_name"],
				desc = PL["chromehover_desc"],
				type = "toggle",
				order = 70,
			},
		}
	})

	local TICK = 0.1
	local driver
	local enabled = false
	local full = true -- show every line on screen
	local focusActive = false
	local manualFocus = false
	local inCombat = false
	local inInstance = false
	local unread = 0

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
	-- Capping is on only while Calm is on, Fewer lines is on and the chat isn't
	-- in use or scrolled up. The per-frame work below runs only then; when it
	-- turns off, the hidden lines are given back once (UpdateCapping).
	local capping = false

	function module:UpdateCapping()
		local want = enabled and not full and self.db.profile.fewlines and true or false
		if want == capping then
			return
		end
		capping = want
		if not want and next(lineAlpha) then
			for _, name in ipairs(CHAT_FRAMES or {}) do
				local cf = _G[name]
				if cf and type(cf.visibleLines) == "table" then
					restoreLines(cf.visibleLines)
				end
			end
		end
	end

	function module:CapLines(cf)
		local lines = cf.visibleLines
		if not capping or type(lines) ~= "table" then
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
		if capping then
			self:CapLines(cf)
		end
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
		Mentions
	------------------------------------------------]] --

	local function isMention(text)
		local me = UnitName("player")
		if type(me) ~= "string" or issecretvalue(me) or me == "" then
			return false
		end
		return text:lower():find(me:lower(), 1, true) ~= nil
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
		if self.db.profile.mentions and isMention(body) then
			return
		end
		if focusActive then
			message.DONOTPROCESS = true
			return
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
		Focus
	------------------------------------------------]] --

	function module:UpdateFocus()
		local p = self.db.profile
		local active = manualFocus or (p.focuscombat and inCombat) or (p.focusinstance and inInstance)
		active = active and true or false
		if active ~= focusActive then
			focusActive = active
			if active then
				wipe(queues) -- channel lines from before are skipped, not replayed
			end
		end
	end

	function module:ToggleFocus()
		if not enabled then
			return
		end
		manualFocus = not manualFocus
		self:UpdateFocus()
		self:Output(manualFocus and PL["focus_on"] or PL["focus_off"])
	end

	function EverlookDBChat_ToggleFocus()
		module:ToggleFocus()
	end

	-- "/chat focus". /chat is the game's chat help: every other use of it is
	-- passed on unchanged. /chatfocus works as well.
	function module:SetupSlash()
		if self.slashDone then
			return
		end
		self.slashDone = true
		SLASH_EDBCHAT_FOCUS1 = "/chatfocus"
		SlashCmdList["EDBCHAT_FOCUS"] = function()
			module:ToggleFocus()
		end
		local original = SlashCmdList["CHAT_HELP"]
		if type(original) == "function" then
			SlashCmdList["CHAT_HELP"] = function(msg, ...)
				if enabled and type(msg) == "string" and not issecretvalue(msg) and strlower(strtrim(msg)) == "focus" then
					module:ToggleFocus()
					return
				end
				return original(msg, ...)
			end
		end
	end

	local function updateInstance()
		local _, instanceType = IsInInstance()
		inInstance = instanceType == "party" or instanceType == "raid"
	end

	--[[------------------------------------------------
		Whispers
	------------------------------------------------]] --

	local fadingSaved -- [chatFrame] = its line fading before a whisper held it

	-- While a whisper is unread every line stays on screen: the frames' own line
	-- fading is paused and put back as it was once the whisper is seen.
	function module:HoldLines(hold)
		if hold then
			if fadingSaved then
				return
			end
			fadingSaved = {}
			for _, name in ipairs(CHAT_FRAMES or {}) do
				local cf = _G[name]
				if cf and cf.GetFading and cf.SetFading then
					fadingSaved[cf] = cf:GetFading() and true or false
					cf:SetFading(false)
				end
			end
		elseif fadingSaved then
			for cf, was in pairs(fadingSaved) do
				cf:SetFading(was)
			end
			fadingSaved = nil
		end
	end

	function module:GetMarker()
		if self.marker then
			return self.marker
		end
		local b = CreateFrame("Button", nil, UIParent)
		b:SetSize(80, 16)
		b:SetFrameStrata("MEDIUM")
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.text:SetPoint("LEFT")
		b.text:SetTextColor(1, 0.5, 1)
		b:SetAlpha(0.8)
		b:SetScript("OnClick", function()
			module:ReplyToWhisper()
		end)
		b:SetScript("OnEnter", function(self)
			self:SetAlpha(1)
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
			GameTooltip:SetText(PL["marker_tip"])
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self)
			self:SetAlpha(0.8)
			GameTooltip:Hide()
		end)
		b:Hide()
		self.marker = b
		return b
	end

	function module:UpdateMarker()
		local show = enabled and unread > 0 and self.db.profile.whispermarker
		if not show then
			if self.marker then
				self.marker:Hide()
			end
			return
		end
		local b = self:GetMarker()
		local anchor = DEFAULT_CHAT_FRAME or ChatFrame1
		b:ClearAllPoints()
		-- Just above the chat frame's top edge, so it moves and resizes with the chat. The tabs that share
		-- that strip only show with the mouse over the chat, and that marks the whisper as seen.
		b:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
		b.text:SetText(unread == 1 and PL["marker_one"] or PL["marker_many"]:format(unread))
		b:SetWidth(b.text:GetStringWidth() + 4)
		b:Show()
	end

	-- Blizzard's own reply (as the R key does): this addon never sees the name.
	function module:ReplyToWhisper()
		unread = 0
		self:UpdateMarker()
		local reply = (ChatFrameUtil and ChatFrameUtil.ReplyTell) or ChatFrame_ReplyTell
		if reply then
			pcall(reply, DEFAULT_CHAT_FRAME)
		end
	end

	function module:OnWhisper()
		unread = unread + 1
		if self.db.profile.whispersound then
			PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081, "Master")
		end
		self:UpdateMarker()
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
		if unread > 0 and inUse then
			unread = 0
			module:UpdateMarker()
		end
		local pinned = unread > 0 and p.whisperpin
		ChatUI:Hold("calm-whisper", pinned)
		module:HoldLines(pinned)
		full = inUse or ChatUI:IsScrolledUp()
		full = full or pinned
		module:UpdateCapping()
		ChatUI:SetTarget("chrome", (not p.chromehover or inUse) and 1 or 0)
		module:ReleaseDue(now)
		if sincePrune >= 30 then
			sincePrune = 0
			module:PruneRecent(now)
		end
	end

	local function onEvent(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			inCombat = true
			module:UpdateFocus()
		elseif event == "PLAYER_REGEN_ENABLED" then
			inCombat = false
			module:UpdateFocus()
		elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
			updateInstance()
			module:UpdateFocus()
		end
		if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
			module:OnWhisper()
		end
	end

	function module:OnValueChanged()
		if not self.db.profile.pace then
			self:FlushQueues()
		end
		self:UpdateFocus()
		self:UpdateMarker()
		self:UpdateCapping()
	end

	function module:OnModuleEnable()
		enabled = true
		if not driver then
			driver = CreateFrame("Frame")
			driver:RegisterEvent("PLAYER_REGEN_DISABLED")
			driver:RegisterEvent("PLAYER_REGEN_ENABLED")
			driver:RegisterEvent("PLAYER_ENTERING_WORLD")
			driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			driver:RegisterEvent("CHAT_MSG_WHISPER")
			pcall(driver.RegisterEvent, driver, "CHAT_MSG_BN_WHISPER")
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
		inCombat = InCombatLockdown() and true or false
		updateInstance()
		self:UpdateFocus()
		self:SetupSlash()
	end

	function module:OnModuleDisable()
		enabled = false
		if driver then
			driver:SetScript("OnUpdate", nil)
			driver:SetScript("OnEvent", nil)
		end
		self:FlushQueues()
		manualFocus = false
		focusActive = false
		unread = 0
		self:UpdateMarker()
		self:HoldLines(false)
		ChatUI:Hold("calm-whisper", false)
		full = true
		capping = false
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
