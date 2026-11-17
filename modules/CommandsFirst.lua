---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This module is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Commands first: a line that starts with "/" is a command in every chat mode.
--
-- In a whisper to a Battle.net friend (or a character), the edit box carries the
-- friend's name, and the client hides that name from addons (a "secret value").
-- An addon command typed in that mode can fail ("Type /help ..." instead of the
-- command running), while the same line in /say works.
--
-- When the first character typed is "/", this module puts the edit box in Say
-- mode for that one line, so Blizzard's own parser runs the command exactly as
-- it does in /say. Nothing is sent by this module and it never reads the
-- whisper text or the friend's name:
--   * the whisper target (tellTarget) and the sticky chat type are never touched,
--     so after the command Blizzard's own ClearChat puts the box back in whisper
--     mode for the next line;
--   * if the "/" is erased, or the line no longer starts with "/" when Enter is
--     pressed, the whisper mode is put back before the text is sent, so a normal
--     line still goes to the friend and never to /say;
--   * a chat-type command typed on purpose (/s, /g, /w name, /r ...) wins.
---------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function()
	return false
end

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("CommandsFirst", "AceHook-3.0")
	local PL = module.PL

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			report = false,
		}
	})

	EverlookDBChat:SetModuleOptions(module.name, {
		name = PL["CommandsFirst"],
		desc = PL["module_desc"],
		type = "group",
		args = {
			info = {
				name = PL["module_info"],
				type = "description",
				order = 1,
			},
			report = {
				name = PL["report_name"],
				desc = PL["report_desc"],
				type = "toggle",
				order = 2,
			},
		}
	})

	-- Chat modes that carry a whisper target, which the client may keep secret.
	local TELL_TYPES = {
		WHISPER = true,
		BN_WHISPER = true,
	}

	local saved = {} -- [editBox] = the chat type this line was switched away from
	local busy = false -- true while this module changes the edit box itself

	local function yesno(b)
		return b and PL["yes"] or PL["no"]
	end

	local function getChatType(editBox)
		local chatType = editBox:GetAttribute("chatType")
		if issecretvalue(chatType) then
			return nil, true
		end
		return chatType, false
	end

	-- Refresh the "Say:" / "To <friend>:" label in front of the text. pcall: in a
	-- whisper mode Blizzard measures the friend's name, which addons may not do.
	local function updateHeader(editBox)
		if editBox.UpdateHeader then
			pcall(editBox.UpdateHeader, editBox)
		end
	end

	-- The first character is "/" (seen by OnChar, or read from text that is not secret).
	function module:Switch(editBox, typedSlash)
		if saved[editBox] then
			return
		end
		local chatType, attributesSecret = getChatType(editBox)
		if not chatType then
			if attributesSecret and self.db.profile.report then
				self:Output(PL["report_attributes_secret"])
			end
			return
		end
		if chatType == "SAY" then
			return
		end
		local secretBefore = issecretvalue(editBox:GetText())
		if not (TELL_TYPES[chatType] or secretBefore) then
			return -- every other mode already runs commands first
		end

		busy = true
		saved[editBox] = chatType
		editBox:SetAttribute("chatType", "SAY")
		-- The label may hold the friend's secret name; clear it before Blizzard
		-- redraws it as "Say:", so its width is not secret either.
		local header = editBox.header
		if header and header.ClearText then
			pcall(header.ClearText, header)
		end
		updateHeader(editBox)

		local secretAfter = issecretvalue(editBox:GetText())
		local replaced = false
		if secretAfter and typedSlash and editBox:GetNumLetters() == 1 then
			-- The only character in the box is the "/" that was just typed. Put a
			-- plain "/" in its place so the rest of the line is typed in Say mode.
			replaced = pcall(editBox.SetText, editBox, "/")
			secretAfter = issecretvalue(editBox:GetText())
		end
		busy = false

		if self.db.profile.report then
			self:Output(PL["report_switch"]:format(chatType, yesno(secretBefore), yesno(secretAfter), yesno(replaced)))
		end
	end

	-- Put the whisper mode back (the line is not a command after all).
	function module:Restore(editBox, redraw)
		local chatType = saved[editBox]
		if not chatType then
			return
		end
		saved[editBox] = nil
		local current = getChatType(editBox)
		if current ~= "SAY" then
			return -- someone else changed the mode; leave it
		end
		busy = true
		editBox:SetAttribute("chatType", chatType)
		if redraw then
			updateHeader(editBox)
		end
		busy = false
		if self.db.profile.report then
			self:Output(PL["report_restore"]:format(chatType))
		end
	end

	function module:OnChar(editBox, char)
		if busy or issecretvalue(char) then
			return
		end
		if editBox:GetNumLetters() ~= 1 then
			return
		end
		if char == "/" then
			self:Switch(editBox, true)
		elseif saved[editBox] then
			-- The "/" was replaced by something else (select all, then type).
			self:Restore(editBox, true)
		end
	end

	-- true when the line no longer starts with "/" (erased, or replaced). Secret text
	-- counts as still a command: whisper mode then comes back at Enter at the latest.
	local function slashGone(editBox)
		if editBox:GetNumLetters() == 0 then
			return true
		end
		local text = editBox:GetText()
		if issecretvalue(text) then
			return false
		end
		return text:sub(1, 1) ~= "/"
	end

	-- Checked one frame later, so that a chat-type command Blizzard is processing
	-- right now (it rewrites the text, which fires OnTextChanged) is seen first.
	function module:CheckLater(editBox)
		C_Timer.After(0, function()
			if saved[editBox] and slashGone(editBox) then
				module:Restore(editBox, true)
			end
		end)
	end

	function module:OnTextChanged(editBox)
		if busy then
			return
		end
		if saved[editBox] then
			if slashGone(editBox) then
				self:CheckLater(editBox)
			end
			return
		end
		if editBox:GetNumLetters() == 0 then
			return
		end
		local text = editBox:GetText()
		if issecretvalue(text) then
			return -- OnChar handles typing; nothing more can be known here
		end
		if text:sub(1, 1) == "/" then
			-- Pasted, or opened with the "/" key (Blizzard sets the text to "/").
			self:Switch(editBox, false)
		end
	end

	-- Blizzard reset the box to its sticky type (ClearChat, Deactivate): the line is
	-- over, and the box is already back in whisper mode if that was sticky.
	function module:OnResetChatTypeToSticky(editBox)
		saved[editBox] = nil
	end

	-- A chat-type command was typed on purpose (/s, /g, /r, /w name ...): it wins.
	-- Blizzard has then cut the command off the text. If the text still starts
	-- with "/", nothing was switched yet (for example "/w" before the name is
	-- complete), so keep watching.
	function module:OnProcessChatType(editBox, msg, index)
		if not saved[editBox] then
			return
		end
		local current = getChatType(editBox)
		if current and current ~= "SAY" then
			saved[editBox] = nil -- Blizzard set another mode (/g, /w name ...)
			return
		end
		if index == "SAY" then
			-- /s or /say on purpose: Say is what the player asked for, so it must stay
			-- Say at Enter even when the text is hidden from addons.
			local info = ChatTypeInfo and ChatTypeInfo.SAY
			if not (info and info.ignoreChatTypeProcessing) then
				saved[editBox] = nil
			end
			return
		end
		if slashGone(editBox) and not issecretvalue(editBox:GetText()) then
			saved[editBox] = nil
		end
	end

	-- Enter was pressed and Blizzard's parser did not take the line as a command,
	-- so it is about to be sent as chat. If this module switched it to Say, put the
	-- whisper mode back first so it goes to the friend as the user meant.
	function module:OnPreSendText(editBox)
		if not saved[editBox] then
			return
		end
		if editBox:GetNumLetters() > 0 then
			self:Restore(editBox, false)
		else
			saved[editBox] = nil
		end
	end

	function module:HookEditBox(editBox)
		if not editBox or self:IsHooked(editBox, "OnTextChanged") then
			return
		end
		if not (editBox.GetNumLetters and editBox.ResetChatTypeToSticky and editBox.ProcessChatType) then
			return -- not the edit box this module was written for
		end
		self:SecureHookScript(editBox, "OnChar", "OnChar")
		self:SecureHookScript(editBox, "OnTextChanged", "OnTextChanged")
		self:SecureHook(editBox, "ResetChatTypeToSticky", "OnResetChatTypeToSticky")
		self:SecureHook(editBox, "ProcessChatType", "OnProcessChatType")
	end

	function module:HookAllEditBoxes()
		for _, frameName in ipairs(CHAT_FRAMES or {}) do
			local frame = _G[frameName]
			self:HookEditBox(frame and frame.editBox or _G[frameName .. "EditBox"])
		end
	end

	function module:OnModuleEnable()
		if not (ChatFrameEditBoxMixin and EventRegistry and ChatFrame1EditBox and ChatFrame1EditBox.OnPreSendText) then
			return -- only for the modern chat edit box
		end
		self:HookAllEditBoxes()
		if FCF_OpenTemporaryWindow and not self:IsHooked("FCF_OpenTemporaryWindow") then
			self:SecureHook("FCF_OpenTemporaryWindow", "HookAllEditBoxes")
		end
		EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", function(_, editBox)
			module:OnPreSendText(editBox)
		end, self)
	end

	function module:OnModuleDisable()
		for editBox in pairs(saved) do
			self:Restore(editBox, true)
		end
		wipe(saved)
		if EventRegistry then
			EventRegistry:UnregisterCallback("ChatFrame.OnEditBoxPreSendText", self)
		end
		self:UnhookAll()
	end

	function module:GetDescription()
		return PL["module_desc"]
	end
end)
