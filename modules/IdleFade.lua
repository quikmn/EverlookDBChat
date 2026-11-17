---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This module is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Idle fade: when nothing has happened in chat for a while, the whole chat
-- (text, background, tabs, button bar, this addon's buttons) fades out to fully
-- invisible. Activity brings it back.
--
-- How it stays out of Blizzard's way (the fading itself is services/chatui.lua):
--   * it only calls SetAlpha on the containers (ChatFrameN, GeneralDockManager,
--     undocked tabs, the button frames, loose buttons). Nothing is protected, no
--     Blizzard function is replaced, so it is safe in combat;
--   * Blizzard's own fading (FCF_FadeInChatFrame, FCFTab_UpdateAlpha, UIFrameFade)
--     keeps setting tab and frame alphas. A post-hook on each managed frame's
--     SetAlpha remembers the value Blizzard wanted and, while faded, puts
--     "wanted x fade" on the frame. Blizzard's value comes back when it fades in;
--   * a frame whose parent is also managed is left alone (docked tabs live under
--     GeneralDockManager), so nothing is faded twice;
--   * chat events are read for their type only. The message text and sender are
--     never touched; for numbered channels only the channel's base name is looked
--     at, and only when it is not a secret value, to tell community channels from
--     General, Trade and the other numbered channels.
---------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function()
	return false
end

-- Chat types that are a conversation: a message of one of these wakes the chat.
-- Everything else (numbered channels, loot, money, xp, system, combat, monster
-- and NPC lines, achievements, addon messages) does not.
local ACTIVITY_EVENTS = {
	CHAT_MSG_SAY = true,
	CHAT_MSG_YELL = true,
	CHAT_MSG_EMOTE = true,
	CHAT_MSG_TEXT_EMOTE = true,
	CHAT_MSG_WHISPER = true,
	CHAT_MSG_WHISPER_INFORM = true,
	CHAT_MSG_BN_WHISPER = true,
	CHAT_MSG_BN_WHISPER_INFORM = true,
	CHAT_MSG_PARTY = true,
	CHAT_MSG_PARTY_LEADER = true,
	CHAT_MSG_RAID = true,
	CHAT_MSG_RAID_LEADER = true,
	CHAT_MSG_RAID_WARNING = true,
	CHAT_MSG_INSTANCE_CHAT = true,
	CHAT_MSG_INSTANCE_CHAT_LEADER = true,
	CHAT_MSG_GUILD = true,
	CHAT_MSG_OFFICER = true,
	CHAT_MSG_COMMUNITIES_CHANNEL = true,
}

local TICK = 0.1

-- Is this chat event activity? Reads the event name and, for a numbered
-- channel, only the channel base name (9th argument) when it is not secret.
local function IsActivity(event, ...)
	if ACTIVITY_EVENTS[event] then
		return true
	end
	if event == "CHAT_MSG_CHANNEL" then
		local baseName = select(9, ...)
		if baseName == nil or issecretvalue(baseName) or type(baseName) ~= "string" then
			return false
		end
		return baseName:sub(1, 10) == "Community:"
	end
	return false
end

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("IdleFade", "AceHook-3.0")
	local PL = module.PL

	module.ACTIVITY_EVENTS = ACTIVITY_EVENTS
	module.IsActivity = IsActivity

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			delay = 60,
			mousewake = true,
		}
	})

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
			delay = {
				name = PL["delay_name"],
				desc = PL["delay_desc"],
				type = "range",
				order = 2,
				min = 10,
				max = 600,
				step = 1,
				bigStep = 10,
			},
			mousewake = {
				name = PL["mousewake_name"],
				desc = PL["mousewake_desc"],
				type = "toggle",
				order = 3,
			},
		}
	})

	local ChatUI = EverlookDBChat.ChatUI
	local lastActivity = 0
	local driver

	function module:Wake()
		lastActivity = GetTime()
		ChatUI:SetTarget("idle", 1)
	end

	function module:HookChatFrames()
		for _, name in ipairs(CHAT_FRAMES or {}) do
			local cf = _G[name]
			if cf then
				if not self:IsHooked(cf, "OnMouseWheel") then
					self:SecureHookScript(cf, "OnMouseWheel", "Wake")
				end
				local editBox = cf.editBox or _G[name .. "EditBox"]
				if editBox and not self:IsHooked(editBox, "OnEditFocusGained") then
					self:SecureHookScript(editBox, "OnEditFocusGained", "Wake")
					self:SecureHookScript(editBox, "OnTextChanged", "Wake")
				end
			end
		end
	end

	-- In use: typing in the chat, the mouse over it (if that option is on), or a
	-- module holding it awake (an unread whisper).
	function module:IsInUse()
		return ChatUI:IsChatFocus() or ChatUI:IsHeld() or (self.db.profile.mousewake and ChatUI:IsMouseOverChat())
	end

	local sinceTick = 0
	local function onUpdate(_, elapsed)
		sinceTick = sinceTick + elapsed
		if sinceTick < TICK then
			return
		end
		sinceTick = 0
		local now = GetTime()
		if module:IsInUse() then
			lastActivity = now
		end
		ChatUI:SetTarget("idle", (now - lastActivity >= module.db.profile.delay) and 0 or 1)
	end

	local function onEvent(_, event, ...)
		if IsActivity(event, ...) then
			module:Wake()
		end
	end

	function module:OnModuleEnable()
		if not driver then
			driver = CreateFrame("Frame")
			for event in pairs(ACTIVITY_EVENTS) do
				pcall(driver.RegisterEvent, driver, event)
			end
			pcall(driver.RegisterEvent, driver, "CHAT_MSG_CHANNEL")
		end
		driver:SetScript("OnEvent", onEvent)
		lastActivity = GetTime()
		ChatUI:AddUser()
		self:HookChatFrames()
		if FCF_OpenTemporaryWindow and not self:IsHooked("FCF_OpenTemporaryWindow") then
			self:SecureHook("FCF_OpenTemporaryWindow", "HookChatFrames")
		end
		driver:SetScript("OnUpdate", onUpdate)
	end

	function module:OnModuleDisable()
		if driver then
			driver:SetScript("OnUpdate", nil)
			driver:SetScript("OnEvent", nil)
		end
		ChatUI:RemoveUser("idle")
		self:UnhookAll()
	end

	function module:GetDescription()
		return PL["module_desc"]
	end
end)
