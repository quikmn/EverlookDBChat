---------------------------------------------------------------------------------
--
-- Prat - A framework for World of Warcraft chat mods
--
-- Copyright (C) 2006-2018  Prat Development Team
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to:
--
-- Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor,
-- Boston, MA  02110-1301, USA.
--
--
-------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function()
	return false
end

local ChatFrame_TimeBreakDown = _G.ChatFrame_TimeBreakDown or _G.ChatFrameUtil.TimeBreakDown

EverlookDBChat:AddModuleExtension(function()
	local module = EverlookDBChat:GetModule("History")
	if not module then
		return
	end

	local PL = module.PL

	module.pluginopts["GlobalPatterns"] = {
		scrollbackhistheader = {
			name = PL["Scrollback Options"],
			type = "header",
			order = 124,
		},
		scrollback = {
			type = "toggle",
			name = PL["Scrollback"],
			desc = PL["Store the chat lines between sessions"],
			order = 125
		},
		scrollbackduration = {
			name = PL.scrollbackduration_name,
			desc = PL.scrollbackduration_desc,
			type = "range",
			order = 126,
			min = 0,
			max = 168,
			step = 1,
			bigStep = 24,
			disabled = function()
				return not module.db.profile.scrollback
			end
		},
		scrollbacklines = {
			name = PL.scrollbacklines_name,
			desc = PL.scrollbacklines_desc,
			type = "range",
			order = 126.5,
			min = 100,
			max = 5000,
			step = 50,
			bigStep = 100,
			disabled = function()
				return not module.db.profile.scrollback
			end
		},
		removespam = {
			name = PL.removespam_name,
			desc = PL.removespam_desc,
			type = "toggle",
			order = 127,
			disabled = function()
				return not module.db.profile.scrollback
			end
		},
		divider = {
			name = PL.divider_name,
			desc = PL.divider_desc,
			type = "select",
			order = 128,
			values = {
				line = PL.divider_line,
				none = PL.divider_none,
			},
			disabled = function()
				return not module.db.profile.scrollback
			end
		},
	}

	-- What is saved between sessions: a plain copy, built at logout, of the newest
	-- lines of each real chat window (never the combat log, never a whisper
	-- window). Each line keeps only its text, colour, time and the "this was real
	-- chat" count (extraData.n, which Remove Spam reads). The window's live history
	-- (3000 lines, with all its functions) is never stored: that made the saved
	-- file grow to megabytes per character.
	local function isSavedWindowName(name)
		local id = type(name) == "string" and tonumber(name:match("^ChatFrame(%d+)$"))
		return id ~= nil and id ~= 2 and id <= (NUM_CHAT_WINDOWS or 10)
	end
	module.IsSavedWindowName = isSavedWindowName

	local function plainLine(line)
		if type(line) ~= "table" or type(line.message) ~= "string" or issecretvalue(line.message) then
			return nil
		end
		local copy = {
			message = line.message,
			r = tonumber(line.r),
			g = tonumber(line.g),
			b = tonumber(line.b),
			serverTime = tonumber(line.serverTime),
		}
		if type(line.extraData) == "table" and tonumber(line.extraData.n) then
			copy.extraData = { n = tonumber(line.extraData.n) }
		end
		return copy
	end

	-- getEntry(i) gives the i-th newest line (1 = newest), or nil past the end.
	-- Returns { elements = oldest..newest, headIndex = count, maxElements = count },
	-- the layout RestoreLastSession reads.
	function module.CopyNewest(getEntry, keep)
		local lines, i = {}, 1
		while #lines < keep do
			local ok, line = pcall(getEntry, i)
			if not ok or line == nil then
				break
			end
			lines[#lines + 1] = plainLine(line)
			i = i + 1
		end
		local count = #lines
		local elements = {}
		for n = 1, count do
			elements[count - n + 1] = lines[n]
		end
		return { elements = elements, headIndex = count, maxElements = math.max(count, 1) }
	end

	function module:KeepLines()
		return math.max(0, math.floor(tonumber(self.db and self.db.profile.scrollbacklines) or 1000))
	end

	-- Saved data from older versions held each window's whole live history (and
	-- the combat log). Shrink it to the same plain copy the logout builds.
	function module:ShrinkSaved(saved, keep)
		if type(saved) ~= "table" then
			return {}
		end
		local out = {}
		for name, buffer in pairs(saved) do
			if isSavedWindowName(name) and type(buffer) == "table" and type(buffer.elements) == "table"
				and buffer.headIndex and buffer.maxElements then
				local copy = module.CopyNewest(function(i)
					return self:GetEntryAtIndex(buffer, i)
				end, keep)
				if #copy.elements > 0 then
					out[name] = copy
				end
			end
		end
		return out
	end

	local function isOpenChatWindow(frame, id)
		if not frame or frame.isTemporary or (IsCombatLog and IsCombatLog(frame)) then
			return false
		end
		if not GetChatWindowInfo then
			return true
		end
		local _, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(id)
		return (shown and shown ~= 0) or (docked and docked ~= 0) or false
	end

	-- Built at PLAYER_LOGOUT, just before the game writes the saved file.
	function module:BuildSavedScrollback()
		if not (self.db and self.db.profile.on and self.db.profile.scrollback and self:IsEnabled()) then
			return {}
		end
		local keep = self:KeepLines()
		local out = {}
		for id = 1, NUM_CHAT_WINDOWS or 10 do
			local name = "ChatFrame" .. id
			local frame = _G[name]
			local buffer = frame and frame.historyBuffer
			if isSavedWindowName(name) and buffer and isOpenChatWindow(frame, id) then
				local copy = module.CopyNewest(function(i)
					if buffer.GetEntryAtIndex then
						return buffer:GetEntryAtIndex(i)
					end
					return self:GetEntryAtIndex(buffer, i)
				end, keep)
				if #copy.elements > 0 then
					out[name] = copy
				end
			end
		end
		return out
	end

	local logoutFrame = CreateFrame("Frame")
	logoutFrame:RegisterEvent("PLAYER_LOGOUT")
	logoutFrame:SetScript("OnEvent", function()
		local ok, saved = pcall(module.BuildSavedScrollback, module)
		EverlookDBChatHighCPUCharDB = EverlookDBChatHighCPUCharDB or {}
		if ok then
			EverlookDBChatHighCPUCharDB.scrollback = saved
		else
			-- never leave the live history in the file; keep the last good copy
			EverlookDBChatHighCPUCharDB.scrollback = module:ShrinkSaved(module.scrollback, module:KeepLines())
		end
	end)

	local orgOME = module.OnModuleEnable
	function module:OnModuleEnable(...)
		orgOME(self, ...)

		EverlookDBChatHighCPUCharDB = EverlookDBChatHighCPUCharDB or {}
		-- older versions saved the whole live history: shrink it now
		local saved = self.db.profile.scrollback and self:ShrinkSaved(EverlookDBChatHighCPUCharDB.scrollback, self:KeepLines()) or {}
		EverlookDBChatHighCPUCharDB.scrollback = saved
		self.scrollback = saved

		if self.db.profile.scrollback and not self.restored then
			self.restored = true
			self:RestoreLastSession()
		end

		for _, v in pairs(EverlookDBChat.HookedFrames) do
			if not self:IsHooked(v, "AddMessage") then
				self:SecureHook(v, "AddMessage")
			end
		end

		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.FRAMES_UPDATED)
		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.FRAMES_REMOVED)
	end

	local orgOMD = module.OnModuleDisable
	function module:OnModuleDisable(...)
		orgOMD(self, ...)

		for _, v in pairs(EverlookDBChat.HookedFrames) do
			if self:IsHooked(v, "AddMessage") then
				self:Unhook(v, "AddMessage")
			end
		end
	end

	function module:OnValueChanged()
	end

	function module:EverlookDBChat_FramesUpdated(_, _, chatFrame)
		if not self:IsHooked(chatFrame, "AddMessage") then
			self:SecureHook(chatFrame, "AddMessage")
		end
	end

	function module:EverlookDBChat_FramesRemoved(_, _, chatFrame)
		if self:IsHooked(chatFrame, "AddMessage") then
			self:Unhook(chatFrame, "AddMessage")
		end
	end

	-- Stamp each new line with the server time, so a restored line knows its age.
	function module:AddMessage(frame)
		if self.db.profile.on and self.db.profile.scrollback and isSavedWindowName(frame:GetName()) and frame.historyBuffer then
			local entry = frame.historyBuffer:GetEntryAtIndex(1)
			if entry and not entry.serverTime then
				entry.serverTime = GetServerTime()
			end
		end
	end

	function module:GetEntryAtIndex(scrollback, index)
		if index > 0 and index <= #scrollback.elements then
			local _headIndex = type(scrollback.headIndex) == 'table' and scrollback.headIndex.value or scrollback.headIndex
			local _maxElementstype = type(scrollback.maxElements) == 'table' and scrollback.maxElements.value or scrollback.maxElements

			local globalIndex = _headIndex - index + 1;
			local elementIndex = (globalIndex - 1) % _maxElementstype + 1
			return scrollback.elements[elementIndex];
		end
	end

	local function isRealChatMessage(message)
		return message.extraData and message.extraData.n >= #message.extraData
	end

	-- "X has come online." / "X has gone offline." (friends and Battle.net
	-- friends): stale after a logout, and a Battle.net friend's name can't be
	-- shown again (it is a per-session token; the old line would read "[???]").
	-- The endings come from the game's own strings, so other languages work too.
	local presenceEndings
	local function isPresenceLine(text)
		if not presenceEndings then
			presenceEndings = {}
			for _, key in ipairs({ "BN_INLINE_TOAST_FRIEND_ONLINE", "BN_INLINE_TOAST_FRIEND_OFFLINE", "ERR_FRIEND_ONLINE_SS", "ERR_FRIEND_OFFLINE_S" }) do
				local fmt = _G[key]
				local ending = type(fmt) == "string" and fmt:match(".*%%s(.*)$")
				if ending and #ending >= 4 then
					presenceEndings[#presenceEndings + 1] = ending
				end
			end
		end
		local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+$", "")
		for _, ending in ipairs(presenceEndings) do
			if plain:sub(-#ending) == ending then
				return true
			end
		end
		return false
	end
	module.IsPresenceLine = isPresenceLine

	-- How long ago, short: "2 min", "3 h", "2 days".
	local function ago(seconds)
		seconds = math.max(0, math.floor(seconds or 0))
		if seconds < 60 then
			return PL.ago_now
		elseif seconds < 3600 then
			return PL.ago_min:format(math.floor(seconds / 60))
		elseif seconds < 86400 then
			return PL.ago_hours:format(math.floor(seconds / 3600))
		end
		return PL.ago_days:format(math.floor(seconds / 86400))
	end

	-- One quiet line between the last session and this one (or nothing).
	function module:DividerText(seconds)
		return "|cff5f6b7a\226\128\148  " .. PL.divider_text:format(ago(seconds)) .. "  \226\128\148|r"
	end

	local function getBattlettagLookupTable()
		local lookup = {}
		local numBNet = BNGetNumFriends();
		for i = 1, numBNet do
			if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
				local accountInfo = C_BattleNet.GetFriendAccountInfo(i);
				if accountInfo then
					lookup[accountInfo.battleTag] = accountInfo
				end
			else
				local bnetAccountID, accountName, battleTag = BNGetFriendInfo(i)
				local accountInfo = { bnetAccountID = bnetAccountID, accountName = accountName }
				if battleTag then
					lookup[battleTag] = accountInfo
				end
			end
		end

		return lookup
	end

	local battleTagLookup

	local function getBNPlayerLink(name, linkDisplayText, bnetIDAccount, lineID, chatType, chatTarget, battleTag)
		return EverlookDBChat.FormatLink("BNplayer", linkDisplayText, name, bnetIDAccount, lineID or 0, chatType, chatTarget, battleTag);
	end

	local function updateBnet(data, display)
		battleTagLookup = battleTagLookup or getBattlettagLookupTable()

		local name, bnetIDAccount, _, chatType, chatTarget, battleTag = strsplit(":", data)

		if battleTag then
			local info = battleTagLookup[battleTag]
			if info then
				name, bnetIDAccount = info.accountName, info.bnetAccountID
				display = display:gsub("%?%?%?", name)
				chatTarget = chatTarget:gsub("%?%?%?", name)
			end
		end

		return getBNPlayerLink(name, display, bnetIDAccount, 0, chatType, chatTarget, battleTag)
	end

	function module:RestoreLastSession()
		local now, uptime, maxTime = GetServerTime(), GetTime(), self.db.profile.scrollbackduration * 60 * 60
		for frame, scrollback in pairs(self.scrollback) do
			local f = _G[frame]
			if type(scrollback) == "table" and scrollback.elements and scrollback.headIndex and scrollback.maxElements and isSavedWindowName(frame) then
				if f and #scrollback.elements then
					local timeShown = false
					for i = 1, #scrollback.elements do
						local line = self:GetEntryAtIndex(scrollback, i)
						if line and type(line.message) == "string" and (not self.db.profile.removespam or isRealChatMessage(line)) then
							line.serverTime = line.serverTime or now
							line.timestamp = uptime

							if maxTime == 0 or (now - line.serverTime) <= maxTime then
								if not timeShown then
									if self.db.profile.divider ~= "none" then
										f:BackFillMessage(self:DividerText(now - line.serverTime))
									end
									timeShown = true
								end

								if not (self.db.profile.removespam and isPresenceLine(line.message)) then
									line.message = line.message:gsub("|K.-|k", "???")
									line.message = line.message:gsub([[|HBNplayer:(.-)|h(.-)|h]], updateBnet)
									f.historyBuffer:PushBack(line)
								end
							end
						end
					end

					f:ResetAllFadeTimes()
				end
			end
		end
	end
end)
