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
	end

	local function onEvent(_, event)
	end

	function module:OnValueChanged()
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
