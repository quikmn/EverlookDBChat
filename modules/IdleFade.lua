---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This module is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Idle fade: when nothing has happened in chat for a while, the whole chat
-- (text, background, tabs, button bar, this addon's buttons) fades out to fully
-- invisible. Activity brings it back.
--
-- How it stays out of Blizzard's way:
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

-- Seconds for a full fade.
local FADE_OUT_TIME = 1.0
local FADE_IN_TIME = 0.2
local TICK = 0.1

-- Blizzard frames that may sit outside the chat frames (absent ones are skipped).
local LOOSE_FRAMES = {
	"GeneralDockManager",
	"GeneralDockManagerOverflowButton",
	"ChatFrameMenuButton",
	"ChatFrameChannelButton",
	"ChatFrameToggleVoiceDeafenButton",
	"ChatFrameToggleVoiceMuteButton",
	"QuickJoinToastButton",
	"TextToSpeechButtonFrame",
	"CombatLogQuickButtonFrame_Custom",
}

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

	local factor = 1 -- the fade now: 1 = fully shown, 0 = invisible
	local target = 1
	local lastActivity = 0
	local managed = {} -- [frame] = the alpha the frame's owner wants
	local applied = {} -- [frame] = true while it carries a faded alpha
	local hooked = {}
	local applying = false
	local driver

	local function hasManagedAncestor(frame)
		local parent = frame:GetParent()
		while parent do
			if managed[parent] then
				return true
			end
			parent = parent:GetParent()
		end
		return false
	end

	local function setAlpha(frame, alpha)
		applying = true
		frame:SetAlpha(alpha)
		applying = false
	end

	-- Post-hook of SetAlpha: someone (Blizzard's FCF code, UIFrameFade, a module)
	-- set the alpha it wants. Remember it, and while faded put the faded one back.
	local function onSetAlpha(frame, alpha)
		if applying or managed[frame] == nil or type(alpha) ~= "number" or issecretvalue(alpha) then
			return
		end
		managed[frame] = alpha
		if factor < 1 and not hasManagedAncestor(frame) then
			setAlpha(frame, alpha * factor)
			applied[frame] = true
		end
	end

	local function manage(frame)
		if not frame or managed[frame] ~= nil or type(frame.SetAlpha) ~= "function" then
			return
		end
		managed[frame] = frame:GetAlpha()
		if not hooked[frame] then
			hooked[frame] = true
			hooksecurefunc(frame, "SetAlpha", onSetAlpha)
		end
	end

	local function apply()
		for frame, base in pairs(managed) do
			if hasManagedAncestor(frame) then
				if applied[frame] then
					setAlpha(frame, base)
					applied[frame] = nil
				end
			elseif factor < 1 then
				setAlpha(frame, base * factor)
				applied[frame] = true
			elseif applied[frame] then
				setAlpha(frame, base)
				applied[frame] = nil
			end
		end
	end

	function module:Wake()
		lastActivity = GetTime()
		target = 1
	end

	function module:HookChatFrame(cf)
		if not self:IsHooked(cf, "OnMouseWheel") then
			self:SecureHookScript(cf, "OnMouseWheel", "Wake")
		end
		local editBox = cf.editBox or _G[cf:GetName() .. "EditBox"]
		if editBox and not self:IsHooked(editBox, "OnEditFocusGained") then
			self:SecureHookScript(editBox, "OnEditFocusGained", "Wake")
			self:SecureHookScript(editBox, "OnTextChanged", "Wake")
		end
	end

	function module:Collect()
		for _, name in ipairs(CHAT_FRAMES or {}) do
			local cf = _G[name]
			if cf then
				manage(cf)
				manage(cf.buttonFrame or _G[name .. "ButtonFrame"])
				manage(_G[name .. "Tab"])
				self:HookChatFrame(cf)
			end
		end
		for _, name in ipairs(LOOSE_FRAMES) do
			manage(_G[name])
		end
	end

	local function isChatFrameFocus()
		local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
		if not focus then
			return false
		end
		if focus.chatFrame or managed[focus] ~= nil then
			return true
		end
		return hasManagedAncestor(focus)
	end

	local function isMouseOverChat()
		for _, name in ipairs(CHAT_FRAMES or {}) do
			local cf = _G[name]
			-- the window plus its tabs above and the button bar to the left
			if cf and cf:IsShown() and cf:IsMouseOver(32, -10, -40, 10) then
				return true
			end
		end
		for frame in pairs(managed) do
			if frame:IsShown() and frame:IsMouseOver() then
				return true
			end
		end
		return false
	end
	module.IsMouseOverChat = isMouseOverChat

	function module:IsInUse()
		return isChatFrameFocus() or (self.db.profile.mousewake and isMouseOverChat())
	end

	local sinceTick, sinceCollect = 0, 0
	local function onUpdate(_, elapsed)
		sinceTick = sinceTick + elapsed
		if sinceTick >= TICK then
			sinceCollect = sinceCollect + sinceTick
			sinceTick = 0
			if sinceCollect >= 2 then
				sinceCollect = 0
				module:Collect()
			end
			local now = GetTime()
			if module:IsInUse() then
				lastActivity = now
			end
			target = (now - lastActivity >= module.db.profile.delay) and 0 or 1
		end
		if factor ~= target then
			if target > factor then
				factor = math.min(target, factor + elapsed / FADE_IN_TIME)
			else
				factor = math.max(target, factor - elapsed / FADE_OUT_TIME)
			end
			apply()
		end
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
		factor, target = 1, 1
		lastActivity = GetTime()
		self:Collect()
		if FCF_OpenTemporaryWindow and not self:IsHooked("FCF_OpenTemporaryWindow") then
			self:SecureHook("FCF_OpenTemporaryWindow", "Collect")
		end
		driver:SetScript("OnUpdate", onUpdate)
	end

	function module:OnModuleDisable()
		if driver then
			driver:SetScript("OnUpdate", nil)
			driver:SetScript("OnEvent", nil)
		end
		factor, target = 1, 1
		apply()
		wipe(managed)
		wipe(applied)
		self:UnhookAll()
	end

	function module:GetDescription()
		return PL["module_desc"]
	end
end)
