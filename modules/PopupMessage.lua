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

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("PopupMessage", "LibSink-2.0")
	local PL = module.PL

	local EVENTS_EMOTES = {
		["CHAT_MSG_BG_SYSTEM_ALLIANCE"] = true,
		["CHAT_MSG_BG_SYSTEM_HORDE"] = true,
		["CHAT_MSG_BG_SYSTEM_NEUTRAL"] = true,
		["CHAT_MSG_EMOTE"] = true,
		["CHAT_MSG_TEXT_EMOTE"] = true,
		["CHAT_MSG_MONSTER_EMOTE"] = true,
		["CHAT_MSG_MONSTER_SAY"] = true,
		["CHAT_MSG_MONSTER_WHISPER"] = true,
		["CHAT_MSG_MONSTER_YELL"] = true,
		["CHAT_MSG_RAID_BOSS_EMOTE"] = true
	};

	local EVENTS_IGNORE = {
		["CHAT_MSG_CHANNEL_NOTICE_USER"] = true,
		["CHAT_MSG_SYSTEM"] = true,
		["CHAT_MSG_PING"] = true,
	}

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = false,
			separate = true,
			show = { ChatFrame1 = true },
			framealpha = 1.0,
			nickname = {},
			sinkoptions = { ["sink20OutputSink"] = "Popup" },
		}
	})

	local pluginOptions = { sink = {} }

	EverlookDBChat:SetModuleOptions(module, {
		name = PL["PopupMessage"],
		desc = PL["Shows messages with your name in a popup."],
		type = "group",
		plugins = pluginOptions,
		args = {
			helpheader = {
				name = "Settings",
				type = "header",
				order = 105,
			},
			show = {
				name = PL["Show Popups"],
				desc = PL["Show Popups for each window."],
				type = "multiselect",
				order = 110,
				values = EverlookDBChat.HookedFrameList,
				get = "GetSubValue",
				set = "SetSubValue"
			},
			addnick = {
				name = PL["Add Nickname"],
				desc = PL["Adds an alternate name to show in popups."],
				type = "input",
				order = 140,
				usage = "<string>",
				get = false,
				set = function(info, name)
					info.handler:AddNickname(name)
				end
			},
			removenick = {
				name = PL["Remove Nickname"],
				desc = PL["Removes an alternate name to show in popups."],
				type = "select",
				order = 150,
				get = function()
					return ""
				end,
				values = function(info)
					return info.handler.db.profile.nickname
				end,
				disabled = function(info)
					return #info.handler.db.profile.nickname == 0
				end,
				set = function(info, value)
					info.handler:RemoveNickname(value)
				end
			},
			clearnick = {
				name = PL["Clear Nickname"],
				desc = PL["Clears alternate name to show in popups."],
				type = "execute",
				order = 160,
				disabled = function(info)
					return (#info.handler.db.profile.nickname == 0)
				end,
				func = "ClearNickname",
			},
		},
	})

	--[[------------------------------------------------
		Module Event Functions
	------------------------------------------------]] --
	EverlookDBChat:SetModuleInit(module,
		function(self)
			self:RegisterSink(PL["Popup"],
				PL["PopupMessage"],
				PL["Shows messages in a popup window."],
				"Popup")
			self:SetSinkStorage(self.db.profile.sinkoptions)

			pluginOptions.sink["output"] = self:GetSinkAce3OptionsDataTable()
			pluginOptions.sink["output"].inline = true

			self.db.profile.show = self.db.profile.show or {}
		end)

	function module:OnModuleEnable()
		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.POST_ADDMESSAGE)

		self.nickpat = {}
		for _, v in ipairs(self.db.profile.nickname) do
			self.nickpat[v] = EverlookDBChat.GetNamePattern(v)
		end

		self.playerName = EverlookDBChat.GetNamePattern(UnitName("player"))
	end

	--[[------------------------------------------------
	  Core Functions
	------------------------------------------------]] --
	function module:GetDescription()
		return PL["Shows messages with your name in a popup."]
	end

	-- /dump module.moduleOptions.args.output.get():find("Default")
	-- /script module.moduleOptions.args.output.set("PopupMessage")
	-- /dump module.db.profile
	-- /script module.db.profile.sink10OutputSink = nil
	function module:Popup(_, text, r, g, b)
		if EverlookDBChat_PopupFrame.anim then
			EverlookDBChat_PopupFrame.anim:Stop()
		else
			EverlookDBChat_PopupFrame.anim = EverlookDBChat_PopupFrame:CreateAnimationGroup()
			EverlookDBChat_PopupFrame.anim:SetScript("OnFinished", function()
				EverlookDBChat_PopupFrameText:Hide()
			end)

			local fade1 = EverlookDBChat_PopupFrame.anim:CreateAnimation("Alpha")
			fade1:SetDuration(1)
			fade1:SetToAlpha(module.db.profile.framealpha or 1)
			fade1:SetEndDelay(4)
			fade1:SetOrder(1)

			local fade2 = EverlookDBChat_PopupFrame.anim:CreateAnimation("Alpha")
			fade2:SetDuration(5)
			fade2:SetToAlpha(0)
			fade2:SetOrder(2)
		end

		EverlookDBChat_PopupFrameText:SetTextColor(r, g, b)
		EverlookDBChat_PopupFrameText:SetText(text)

		local font, _, style = ChatFrame1:GetFont()
		local _, fontsize = GameFontNormal:GetFont()
		EverlookDBChat_PopupFrameText:SetFont(font, fontsize, style)
		EverlookDBChat_PopupFrameText:SetNonSpaceWrap(false)
		EverlookDBChat_PopupFrame:SetWidth(math.min(math.max(64, EverlookDBChat_PopupFrameText:GetStringWidth() + 20), 520))
		EverlookDBChat_PopupFrame:SetHeight(64)
		EverlookDBChat_PopupFrame:SetBackdropBorderColor(r, g, b)

		EverlookDBChat_PopupFrameText:ClearAllPoints()
		EverlookDBChat_PopupFrameText:SetPoint("TOPLEFT", EverlookDBChat_PopupFrame, "TOPLEFT", 10, 10)
		EverlookDBChat_PopupFrameText:SetPoint("BOTTOMRIGHT", EverlookDBChat_PopupFrame, "BOTTOMRIGHT", -10, -10)
		EverlookDBChat_PopupFrameText:Show()

		EverlookDBChat_PopupFrame:SetAlpha(0)
		EverlookDBChat_PopupFrame:Show()
		EverlookDBChat_PopupFrame.anim:Play()
	end

	function module:EverlookDBChat_PostAddMessage(_, message, frame, event, _, r, g, b)
		if self.pouring then
			return
		end
		if message.LINE_ID and
			message.LINE_ID == self.lastevent and
			self.lasteventtype == event then
			return
		end

		if not (EVENTS_EMOTES[event] or EVENTS_IGNORE[event]) then
			if self.db.profile.showall or self.db.profile.show[frame:GetName()] then
				if not (message.ORG.PLAYER and self.playerName and message.ORG.PLAYER:match(self.playerName)) then
					self:CheckText(message.ORG.MESSAGE, message.OUTPUT, event, r, g, b, message.LINE_ID)
				end
			end
		end
	end

	function module:AddNickname(name)
		for _, v in ipairs(self.db.profile.nickname) do
			if v:lower() == name:lower() then
				return
			end
		end
		tinsert(self.db.profile.nickname, name)

		self.nickpat[name] = EverlookDBChat.GetNamePattern(name)
	end

	function module:RemoveNickname(idx)
		self.nickpat[self.db.profile.nickname[idx]] = nil
		tremove(self.db.profile.nickname, idx)
	end

	function module:ClearNickname()
		local n = self.db.profile.nickname
		while #n > 0 do
			self.nickpat[n[#n]] = nil
			n[#n] = nil
			--		tremove(self.db.profile.nickname)
		end
	end

	function module:CheckText(text, display_text, event, r, g, b, eventId)
		local show = false

		if text:match(self.playerName) then
			show = true;
		else
			for _, v in pairs(self.nickpat) do
				if v:len() > 0 and text:match(v) then
					show = true
				end
			end
		end

		if show then
			self.lasteventtype = event
			self.lastevent = eventId
			self.pouring = true
			self:Pour(display_text or text, r, g, b)
			EverlookDBChat:PlaySound("popup");
			self.pouring = nil
		end
	end

	return
end) -- EverlookDBChat:AddModuleToLoad
