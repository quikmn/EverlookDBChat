---------------------------------------------------------------------------------
-- Search: a search box on each chat window, and /find.
--
-- EverlookDB Chat changes (GPL-3.0): Ctrl+F opens the box (while typing in the
-- chat, or with the mouse over a chat window); typing jumps to the newest match;
-- Enter, Shift+Enter and the arrow keys step through matches; Esc closes it.
-- Lines whose text is hidden from addons (secret values) are skipped.
--
-- Ctrl+F is only taken where it is meant for the chat:
--   * in a chat edit box: a post-hook of its OnKeyDown, nothing else changes;
--   * with the mouse over the chat: a keyboard frame that passes every key on
--     (SetPropagateKeyboardInput) and keeps only Ctrl+F while the mouse is over a
--     chat window. That call is not allowed in combat, so this frame is hidden in
--     combat and Ctrl+F then works as it does without this addon.
---------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function()
	return false
end

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("Search", "AceHook-3.0")
	local PL = module.PL
	local ChatUI = EverlookDBChat.ChatUI

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			searchactivealpha = 1.0,
			searchinactivealpha = 0.1,
			ctrlf = true,
		}
	})

	EverlookDBChat:SetModuleOptions(module.name, {
		name = PL.module_name,
		desc = PL.module_desc,
		type = "group",
		args = {
			info = {
				name = PL.module_info,
				type = "description",
				order = 10,
			},
			ctrlf = {
				name = PL["ctrlf_name"],
				desc = PL["ctrlf_desc"],
				type = "toggle",
				order = 15,
			},
			searchinactivealpha = {
				name = PL["unused_alpha"],
				type = "range",
				order = 20,
				min = 0,
				max = 1.0,
				step = 0.1,
			},
			searchactivealpha = {
				name = PL["used_alpha"],
				type = "range",
				order = 30,
				min = 0,
				max = 1.0,
				step = 0.1,
			},
		}
	})

	function module:StashSearch(frame)
		frame:SetAlpha(self.db.profile.searchinactivealpha)
		frame:SetWidth(30)
	end

	function module:UnstashSearch(frame)
		frame:SetAlpha(self.db.profile.searchactivealpha)
		frame:SetWidth(130)
	end

	function module:CreateSearchBox(chatFrame)
		local name = chatFrame:GetName()
		local f = CreateFrame("EditBox", name .. "ChatSearchEditBox", chatFrame, "SearchBoxTemplate")

		f:SetWidth(130)
		f:SetHeight(16)
		f:SetFrameStrata("HIGH")
		f:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT")
		f:SetScript("OnEnter", function()
			local hoverAlpha = self.db.profile.searchinactivealpha + (self.db.profile.searchactivealpha - self.db.profile.searchinactivealpha) / 2
			if f:HasFocus() then
				self:UnstashSearch(f)
			else
				f:SetAlpha(hoverAlpha)
			end
		end)
		f:SetScript("OnLeave", function()
			if f:HasFocus() then
				self:UnstashSearch(f)
			else
				self:StashSearch(f)
			end
		end)
		f:SetScript("OnEditFocusLost", function()
			self:StashSearch(f)
		end)
		f:SetScript("OnEditFocusGained", function()
			self:UnstashSearch(f)
		end)
		f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		f.count:SetPoint("RIGHT", f, "RIGHT", -18, 0)
		f:SetScript("OnEscapePressed", function()
			module:CloseSearch(f)
		end)
		f:SetScript("OnEnterPressed", function()
			module:Step(f, IsShiftKeyDown() and -1 or 1)
		end)
		f:SetScript("OnArrowPressed", function(_, key)
			if key == "UP" then
				module:Step(f, 1)
			elseif key == "DOWN" then
				module:Step(f, -1)
			end
		end)
		f:HookScript("OnTextChanged", function(_, userInput)
			if userInput then
				module:UpdateMatches(f)
				module:Step(f, 0)
			end
		end)
		f.anim = f:CreateAnimationGroup()
		f.anim.fade1 = f.anim:CreateAnimation("Alpha")
		f.anim.fade1:SetFromAlpha(self.db.profile.searchactivealpha)
		f.anim.fade1:SetDuration(3)
		f.anim.fade1:SetToAlpha(self.db.profile.searchinactivealpha)
		f.anim.fade1:SetSmoothing("IN")
		f.anim:SetScript("OnFinished", function()
			if f:HasFocus() then
				self:UnstashSearch(f)
			else
				self:StashSearch(f)
			end
		end)

		f.anim:Play()

		return f
	end

	EverlookDBChat:SetModuleInit(module, function(self)
		self.searchBoxes = {}
	end)

	function module:EverlookDBChat_FramesUpdated(_, name, chatFrame)
		if not self.searchBoxes[name] then
			self.searchBoxes[name] = self:CreateSearchBox(chatFrame)
		end
	end

	--[[------------------------------------------------
		Search box: matches and jumping
	------------------------------------------------]] --

	-- Plain text of a chat line: colours, links and icons removed.
	local function plain(text)
		text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "")
		return text:lower()
	end

	-- f.matches = history indices (1 = newest line) of the lines that contain the text.
	function module:UpdateMatches(f)
		local chatFrame = f:GetParent()
		f.matches = {}
		f.pos = 0
		local query = f:GetText()
		if not query or issecretvalue(query) or query == "" or not chatFrame.historyBuffer then
			f.count:SetText("")
			return
		end
		query = query:lower()
		for i = 1, chatFrame:GetNumMessages() do
			local entry = chatFrame.historyBuffer:GetEntryAtIndex(i)
			local text = entry and entry.message
			if type(text) == "string" and not issecretvalue(text) and plain(text):find(query, 1, true) then
				f.matches[#f.matches + 1] = i
			end
		end
	end

	-- step 1 = older match, -1 = newer, 0 = the newest (after typing).
	function module:Step(f, step)
		local chatFrame = f:GetParent()
		if not f.matches then
			self:UpdateMatches(f)
		end
		local total = #f.matches
		if total == 0 then
			local text = f:GetText()
			f.count:SetText((text and not issecretvalue(text) and text ~= "") and "0" or "")
			return
		end
		if step == 0 then
			f.pos = 1
		else
			f.pos = ((f.pos or 0) - 1 + step) % total + 1
		end
		f.count:SetText(("%d/%d"):format(f.pos, total))
		local index = f.matches[f.pos]
		local visible = type(chatFrame.visibleLines) == "table" and #chatFrame.visibleLines or 0
		local offset = math.max(0, index - 1 - math.floor(visible / 2))
		if chatFrame.ResetAllFadeTimes then
			chatFrame:ResetAllFadeTimes()
		end
		chatFrame:SetScrollOffset(offset)
	end

	function module:OpenSearch(chatFrame)
		chatFrame = chatFrame or SELECTED_CHAT_FRAME
		if not (chatFrame and self:IsEnabled()) then
			return
		end
		local name = chatFrame:GetName()
		local f = self.searchBoxes[name]
		if not f and EverlookDBChat.HookedFrames[name] then
			f = self:CreateSearchBox(chatFrame)
			self.searchBoxes[name] = f
		end
		if not f then
			return
		end
		f:Show()
		self:UnstashSearch(f)
		f:SetFocus()
		f:HighlightText()
		f.matches = nil
	end

	function module:CloseSearch(f)
		f:SetText("")
		f.count:SetText("")
		f.matches = nil
		f:ClearFocus()
		f:GetParent():ScrollToBottom()
	end

	--[[------------------------------------------------
		Ctrl+F
	------------------------------------------------]] --

	local function isCtrlF(key)
		return key == "F" and IsControlKeyDown() and not IsAltKeyDown() and module.db.profile.ctrlf
	end

	-- Typing in a chat edit box: open the search of that window.
	function module:OnChatEditKeyDown(editBox, key)
		if issecretvalue(key) or not isCtrlF(key) then
			return
		end
		local chatFrame = editBox.chatFrame or SELECTED_CHAT_FRAME
		C_Timer.After(0, function()
			module:OpenSearch(chatFrame)
		end)
	end

	function module:HookEditBoxes()
		for _, frameName in ipairs(CHAT_FRAMES or {}) do
			local editBox = _G[frameName .. "EditBox"]
			if editBox and not self:IsHooked(editBox, "OnKeyDown") then
				self:SecureHookScript(editBox, "OnKeyDown", "OnChatEditKeyDown")
			end
		end
	end

	-- Mouse over the chat: a frame that sees keys first and passes all of them on,
	-- except Ctrl+F while the mouse is over a chat window. Out of combat only.
	function module:CreateKeyCatcher()
		if self.keyCatcher or InCombatLockdown() then
			return
		end
		local catcher = CreateFrame("Frame", nil, UIParent)
		self.keyCatcher = catcher
		catcher:SetPropagateKeyboardInput(true)
		catcher:EnableKeyboard(true)
		catcher:SetScript("OnKeyDown", function(frame, key)
			if InCombatLockdown() or issecretvalue(key) or not isCtrlF(key) then
				return
			end
			local over, chatFrame = ChatUI:IsMouseOverChat()
			if not over then
				return
			end
			frame:SetPropagateKeyboardInput(false) -- keep this one key
			C_Timer.After(0, function()
				if not InCombatLockdown() then
					frame:SetPropagateKeyboardInput(true)
				end
			end)
			module:OpenSearch(chatFrame or SELECTED_CHAT_FRAME)
		end)
		catcher:RegisterEvent("PLAYER_REGEN_DISABLED")
		catcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		catcher:SetScript("OnEvent", function(frame, event)
			if event == "PLAYER_REGEN_DISABLED" then
				frame:Hide()
			elseif module:IsEnabled() then
				frame:SetPropagateKeyboardInput(true)
				frame:Show()
			end
		end)
	end

	function module:OnModuleEnable()
		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.FRAMES_UPDATED)

		self:HookEditBoxes()
		if FCF_OpenTemporaryWindow and not self:IsHooked("FCF_OpenTemporaryWindow") then
			self:SecureHook("FCF_OpenTemporaryWindow", "HookEditBoxes")
		end
		if self.keyCatcher then
			if not InCombatLockdown() then
				self.keyCatcher:SetPropagateKeyboardInput(true)
				self.keyCatcher:Show()
			end
		elseif InCombatLockdown() then
			self.waitFrame = self.waitFrame or CreateFrame("Frame")
			self.waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
			self.waitFrame:SetScript("OnEvent", function(frame)
				frame:UnregisterAllEvents()
				if module:IsEnabled() then
					module:CreateKeyCatcher()
				end
			end)
		else
			self:CreateKeyCatcher()
		end

		for name, frame in pairs(EverlookDBChat.HookedFrames) do
			if not self.searchBoxes[name] then
				self.searchBoxes[name] = self:CreateSearchBox(frame)
			end
		end

		for _, f in pairs(self.searchBoxes) do
			f:Show()
		end
	end

	function module:OnModuleDisable()
		for _, f in pairs(self.searchBoxes) do
			f:Hide()
		end
		if self.keyCatcher then
			self.keyCatcher:Hide()
		end
		self:UnhookAll()
	end

	SLASH_EDBCHAT_FIND1 = "/find"
	SlashCmdList["EDBCHAT_FIND"] = function(msg)
		module:Find(msg, true)
	end

	local foundlines = {}
	local scrapelines = {}

	local CLR = EverlookDBChat.CLR
	local function SearchTerm(term)
		return CLR:Colorize("ffff40", term)
	end

	function module:Find(word, all, frame)
		if not self.db.profile.on then
			return
		end

		if frame == nil then
			frame = SELECTED_CHAT_FRAME
		end

		if not word then
			return
		end

		if #word <= 1 then
			frame:ScrollToBottom()
			self:Output(frame, PL.err_tooshort)
			return
		end

		if frame:GetNumMessages() == 0 then
			frame:ScrollToBottom()
			self:Output(frame, PL.err_notfound)
			return
		end

		self.lastsearch = word

		self:ScrapeFrame(frame, nil, true)

		for _, v in ipairs(scrapelines) do
			if v.message and v.message:find(EverlookDBChat:CaseInsensitveWordPattern(word)) then
				if all then
					table.insert(foundlines, v)
				else
					return
				end
			end
		end

		self.lastsearch = nil

		frame:ScrollToBottom()

		if all and #foundlines > 0 then
			self:Output(frame, "-------------------------------------------------------------")
			self:Output(frame, PL.find_results .. ": " .. SearchTerm(word))

			EverlookDBChat.loading = true -- prevent double timestamp
			for _, v in ipairs(foundlines) do
				frame:AddMessage(v.message:gsub("|K.-|k", PL.bnet_removed), v.r, v.g, v.b)
			end
			EverlookDBChat.loading = nil
			self:Output(frame, "-------------------------------------------------------------")
		else
			self:Output(frame, PL.err_notfound)
		end

		wipe(foundlines)
		wipe(scrapelines)
	end

	function module:ScrapeFrame(frame)
		wipe(scrapelines)

		for i = frame:GetNumMessages(), 1, -1 do
			local msg = frame.historyBuffer:GetEntryAtIndex(i)

			if msg and msg.message then
				table.insert(scrapelines, msg)
			end
		end
	end

	return
end) -- EverlookDBChat:AddModuleToLoad
