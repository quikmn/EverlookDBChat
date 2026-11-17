---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This module is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Tidy lines: fewer repeated system lines.
--   * "Type '/help' for a listing of a few commands." is what the game prints
--     for a slash command it doesn't know. When it shows again within two
--     minutes, the older copy is taken out, so there is one;
--   * for 30 seconds after logging in or reloading, a system line that already
--     showed in that window this session is not shown again (login messages
--     that come twice).
--
-- Only plain text is compared; lines whose text is a secret value are never
-- looked at and always show.
---------------------------------------------------------------------------------

local _, private = ...

local issecretvalue = issecretvalue or function()
	return false
end

local Logic = {}
private.TidyLogic = Logic

Logic.REPEAT_WINDOW = 120 -- seconds: an older copy of the help line this recent is removed
Logic.REPEAT_LOOKBACK = 12 -- lines back to look for it
Logic.LOGIN_WINDOW = 30 -- seconds after login/reload with the system line dedupe

-- Index (2..) of an older copy of the help line among the newest entries, or nil.
-- entries(i) returns the i-th newest entry ({ message = , timestamp = }).
function Logic.FindOlderCopy(entries, helpText, now)
	for i = 2, Logic.REPEAT_LOOKBACK do
		local e = entries(i)
		if not e then
			return nil
		end
		local m = e.message
		if type(m) == "string" and not issecretvalue(m) and m:find(helpText, 1, true) then
			local t = e.timestamp
			if type(t) ~= "number" or issecretvalue(t) or now - t <= Logic.REPEAT_WINDOW then
				return i
			end
			return nil
		end
	end
	return nil
end

if not EverlookDBChat or not EverlookDBChat.AddModuleToLoad then
	return
end

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("Tidy", "AceHook-3.0")
	local PL = module.PL

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
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
		}
	})

	local loginAt
	local seen = setmetatable({}, { __mode = "k" }) -- [chatFrame] = { [text] = true }
	local events

	function module:AddMessage(frame, text)
		local help = HELP_TEXT_SIMPLE
		if type(text) ~= "string" or issecretvalue(text) or type(help) ~= "string" or not text:find(help, 1, true) then
			return
		end
		local buffer = frame.historyBuffer
		if not (buffer and buffer.GetEntryAtIndex and buffer.RemoveIf) then
			return
		end
		local index = Logic.FindOlderCopy(function(i)
			return buffer:GetEntryAtIndex(i)
		end, help, GetTime())
		if index then
			local old = buffer:GetEntryAtIndex(index)
			if buffer:RemoveIf(function(entry)
					return entry == old
				end) and frame.MarkDisplayDirty then
				frame:MarkDisplayDirty()
			end
		end
	end

	function module:EverlookDBChat_PreAddMessage(_, message, frame)
		if not loginAt or message.DONOTPROCESS or message.EVENT ~= "CHAT_MSG_SYSTEM" then
			return
		end
		if GetTime() - loginAt > Logic.LOGIN_WINDOW then
			loginAt = nil
			wipe(seen)
			return
		end
		-- The whole line as the game sent it (MESSAGE can be cut down, like
		-- " has come online." without the name).
		local body = type(message.ARGS) == "table" and message.ARGS[1]
		if type(body) ~= "string" or issecretvalue(body) or body == "" then
			return
		end
		local set = seen[frame]
		if not set then
			set = {}
			seen[frame] = set
		end
		if set[body] then
			message.DONOTPROCESS = true
		else
			set[body] = true
		end
	end

	function module:HookFrames()
		for _, frame in pairs(EverlookDBChat.HookedFrames) do
			if not self:IsHooked(frame, "AddMessage") then
				self:SecureHook(frame, "AddMessage")
			end
		end
	end

	function module:EverlookDBChat_FramesUpdated()
		self:HookFrames()
	end

	function module:OnModuleEnable()
		loginAt = GetTime()
		if not events then
			events = CreateFrame("Frame")
			events:SetScript("OnEvent", function(_, _, isLogin, isReload)
				if isLogin or isReload then
					loginAt = GetTime()
				end
			end)
		end
		events:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:HookFrames()
		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.FRAMES_UPDATED)
		EverlookDBChat.RegisterChatEvent(self, "EverlookDBChat_PreAddMessage")
	end

	function module:OnModuleDisable()
		if events then
			events:UnregisterAllEvents()
		end
		loginAt = nil
		wipe(seen)
		self:UnhookAll()
	end

	function module:GetDescription()
		return PL["module_desc"]
	end
end)
