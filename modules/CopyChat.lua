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

local issecretvalue = issecretvalue or function() return false end

local ChatEdit_GetActiveWindow = _G.ChatEdit_GetActiveWindow or _G.ChatFrameUtil.GetActiveWindow
local ChatEdit_ChooseBoxForSend = _G.ChatEdit_ChooseBoxForSend or _G.ChatFrameUtil.ChooseBoxForSend

local ChatFrame_OpenChat = _G.ChatFrame_OpenChat or _G.ChatFrameUtil.OpenChat
local StripHyperlinks = _G.StripHyperlinks or _G.C_StringUtil.StripHyperlinks

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("CopyChat", "AceHook-3.0", "AceTimer-3.0")
	local PL = module.PL

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			showbutton = { ["*"] = true },
			buttonpos = "TOPLEFT",
			copyformat = "plain",
			copytimestamps = true,
			activealpha = 0.9,
			inactivealpha = 0.2,
		}
	})

	EverlookDBChat:SetModuleOptions(module.name, {
		name = PL["CopyChat"],
		desc = PL["Copy text from the active chat window."],
		type = "group",
		args = {
			showbutton = {
				name = PL["showbutton_name"],
				desc = PL["showbutton_desc"],
				type = "multiselect",
				values = EverlookDBChat.FrameList,
				get = "GetSubValue",
				set = "SetSubValue"
			},
			buttonpos = {
				name = PL.buttonpos_name,
				desc = PL.buttonpos_desc,
				type = "select",
				order = 195,
				get = "GetValue",
				set = "SetValue",
				values = {
					["TOPLEFT"] = PL.TOPLEFT,
					["TOPRIGHT"] = PL.TOPRIGHT,
					["BOTTOMLEFT"] = PL.BOTTOMLEFT,
					["BOTTOMRIGHT"] = PL.BOTTOMRIGHT
				},
			},
			copy = {
				name = PL["Copy Text"],
				desc = PL["Copy all of the text in the selected chat frame into an edit box"],
				type = "execute",
				order = 190,
				func = function()
					module:DoCopyChat(SELECTED_CHAT_FRAME)
				end
			},
			copyformat = {
				name = PL["Copy Text Format"],
				desc = PL["Should the copied text be plain, or formatted so you can see the colors."],
				type = "select",
				order = 195,
				get = "GetValue",
				set = "SetValue",
				values = { ["plain"] = PL["Plain"], ["bbcode"] = PL["BBCode"], ["html"] = PL["HTML"], ["wowace"] = PL["Wowace.com Forums"] },
			},
			copytimestamps = {
				name = PL.copytimestamps_name,
				desc = PL.copytimestamps_desc,
				type = "toggle",
				order = 200,
			},
			activealpha = {
				name = PL["activealpha"],
				type = "range",
				order = 210,
				min = 0,
				max = 1.0,
				step = 0.1,
			},
			inactivealpha = {
				name = PL["inactivealpha"],
				type = "range",
				order = 220,
				min = 0,
				max = 1.0,
				step = 0.1,
			},
		}
	})

	local EverlookDBChatCCFrame, EverlookDBChatCCText, EverlookDBChatCCFrameScrollText
	EverlookDBChat:SetModuleInit(module.name, function(self)
		self:CreateCopyFrame()

		EverlookDBChatCCFrameScrollText:SetScript("OnTextChanged", function(this)
			self:OnTextChanged(this)
		end)
		EverlookDBChatCCFrameScrollText:SetScript("OnEscapePressed", function()
			EverlookDBChatCCFrame:Hide()
			self.str = nil
		end)

		EverlookDBChat.RegisterChatCommand("copychat", function()
			local frame = SELECTED_CHAT_FRAME
			if frame then
				self:DoCopyChat(frame)
			end
		end)

		EverlookDBChat.RegisterLinkType({ linkid = "edbchatcopy", linkfunc = self.CopyLink, handler = module }, self.name)

		module.timestamps = EverlookDBChat:GetModule("Timestamps")

		if self.timestamps then
			self:RawHook(self.timestamps, "GetTime")
		end
	end)

	function module:OnModuleEnable()
		self.buttons = {}
		for k, v in pairs(EverlookDBChat.Frames) do
			self.buttons[k] = self:MakeReminder(v:GetID())
			self:showbutton(k, self.db.profile.showbutton[k])
		end

		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.FRAMES_UPDATED)
	end

	function module:GetDescription()
		return PL["Copy text from the active chat window."]
	end

	function module:EverlookDBChat_FramesUpdated(_, _, chatFrame)
		local id = chatFrame:GetID()
		self.buttons[id] = self:MakeReminder(id)
		self:showbutton(id, self.db.profile.showbutton[1])
	end

	function module:OnModuleDisable()
		EverlookDBChat.UnregisterAllChatEvents(self)
		self:hidebuttons()
		EverlookDBChatCCFrame:Hide()
	end

	local function CleanText(text)
		text = text:gsub("|K.-|k", "???")
		return StripHyperlinks(text, false, true)
	end

	--[[------------------------------------------------
		Core Functions
	------------------------------------------------]] --
	function module:CopyLink(_, frame)
		if frame and self.db.profile.on and self.db.profile.copytimestamps then
			for _, visibleLine in ipairs(frame.visibleLines) do
				local isMouseOver = visibleLine:IsMouseOver()
				if not issecretvalue(isMouseOver) and isMouseOver then
					local info = visibleLine.messageInfo
					if info and info.message then
						local text = issecretvalue(info.message) and "<SECRET>" or CleanText(info.message)
						local editBox = ChatEdit_ChooseBoxForSend(frame);

						if editBox ~= ChatEdit_GetActiveWindow() then
							ChatFrame_OpenChat(text, frame);
						else
							editBox:SetText(text);
						end
					end
					return false
				end
			end
		end

		return false
	end

	function module:GetTime(...)
		local stamp = self.hooks[self.timestamps].GetTime(...)
		if module.db.profile.on and module.db.profile.copytimestamps then
			return "|Hedbchatcopy|h" .. stamp .. "|h"
		end

		return stamp
	end

	module.str = nil

	function module:GetFormattedLine(line, r, g, b)
		local fmt = self.db.profile.copyformat
		local CLR = EverlookDBChat.CLR

		line = line:gsub("|c00000000|r", "")

		if fmt == "plain" then
			return line
		end

		if fmt == "bbcode" or fmt == "wowace" then
			local fline = line:gsub("|c[fF][fF](%w%w%w%w%w%w)", "[color=#%1]"):gsub("|r", "[/color]")
			return "[color=#" .. CLR:GetHexColor(r, g, b) .. "]" .. fline .. "[/color]"
		end

		if fmt == "html" then
			local fline = line:gsub("|c[fF][fF](%w%w%w%w%w%w)", "<font color='#%1'>"):gsub("|r", "</font>")
			return "<p><font color='#" .. CLR:GetHexColor(r, g, b) .. "' face='monospace'>" .. fline .. "</font></p>"
		end
	end

	function module:DoCopyChat(frame)
		local lines = {}
		for i = 1, frame:GetNumMessages() do
			local msg = frame:GetMessageInfo(i)

			if msg then
				if issecretvalue(msg) then
					lines[#lines + 1] = "<SECRET>"
				else
					lines[#lines + 1] = CleanText(msg)
				end
			end
		end

		local str = table.concat(lines, "\n")
		if self.db.profile.copyformat == "wowace" then
			str = "[bgcolor=black]" .. str .. "[/bgcolor]"
		end
		self.str = str
		EverlookDBChatCCFrameScrollText:SetText(str or "")
		EverlookDBChatCCText:SetText(PL["ChatFrame"] .. frame:GetName():gsub("ChatFrame", "") .. PL[" Text"])
		EverlookDBChatCCFrame:Show()
	end

	function module:CopyChat() -- Used by bindings
		module:DoCopyChat(SELECTED_CHAT_FRAME)
	end

	function module:OnTextChanged(this)
		if self.str and this:GetText() ~= self.str then
			this:SetText(self.str)
		end
		this:GetParent():UpdateScrollChildRect()
		local _, m = EverlookDBChatCCFrameScrollScrollBar:GetMinMaxValues()
		if m > 0 and this.max ~= m then
			this.max = m
			EverlookDBChatCCFrameScrollScrollBar:SetValue(m)
		end
	end

	function module:hidebuttons()
		for _, v in pairs(self.buttons) do
			v:Hide()
		end
	end

	function module:showbutton(id, show)
		local b = self.buttons[id]
		if show then
			b:Show()
		else
			b:Hide()
		end
	end

	do
		local function reminderOnClick(self)
			PlaySound(SOUNDKIT.IG_CHAT_BOTTOM);
			module:DoCopyChat(self:GetParent())
		end

		local function reminderOnEnter(self)
			self:SetAlpha(module.db.profile.activealpha)
		end

		local function reminderOnLeave(self)
			self:SetAlpha(module.db.profile.inactivealpha)
		end

		function module:MakeReminder(id)
			local cf = _G["ChatFrame" .. id]
			local name = "ChatFrame" .. id .. "EverlookDBChatCCReminder"
			local b = _G[name]
			if not b then
				b = CreateFrame("Button", name, cf)
				b:SetFrameStrata("MEDIUM")
				b:SetWidth(24)
				b:SetHeight(24)
				b:SetNormalTexture("Interface\\Addons\\EverlookDBChat\\textures\\edbchat-chatcopy2")
				b:SetPushedTexture("Interface\\Addons\\EverlookDBChat\\textures\\edbchat-chatcopy")
				b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
				b:SetPoint(self.db.profile.buttonpos, cf, self.db.profile.buttonpos, 0, 0)
				b:SetScript("OnClick", reminderOnClick)
				b:SetScript("OnEnter", reminderOnEnter)
				b:SetScript("OnLeave", reminderOnLeave)
				b:SetAlpha(module.db.profile.inactivealpha)
				b:RegisterForClicks("AnyUp")
				b:Hide()
			end

			return b
		end
	end

	function module:OnValueChanged()
		for k, v in pairs(EverlookDBChat.Frames) do
			local cf = _G["ChatFrame" .. v:GetID()]
			local btn = self.buttons[k]
			btn:ClearAllPoints()
			btn:SetPoint(self.db.profile.buttonpos, cf, self.db.profile.buttonpos, 0, 0)
			btn:SetAlpha(module.db.profile.inactivealpha)
		end
	end

	function module:CreateCopyFrame()
		EverlookDBChatCCFrame = CreateFrame("Frame", "EverlookDBChatCCFrame", UIParent, "DialogBoxFrame,BackdropTemplate")
		EverlookDBChatCCFrame:SetSize(500, 400)
		EverlookDBChatCCFrame:SetMovable(true)
		EverlookDBChatCCFrame:EnableMouse(true)
		EverlookDBChatCCFrame:SetClampedToScreen(true)
		EverlookDBChatCCFrame:RegisterForDrag("LeftButton")
		EverlookDBChatCCFrame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 },
		})
		EverlookDBChatCCFrame:SetScript("OnDragStart", function(frame)
			frame:StartMoving()
		end)
		EverlookDBChatCCFrame:SetScript("OnDragStop", function(frame)
			frame:StopMovingOrSizing()
		end)

		EverlookDBChatCCText = EverlookDBChatCCFrame:CreateFontString("EverlookDBChatCCText", "ARTWORK", "GameFontHighlight")
		EverlookDBChatCCText:SetPoint("TOPLEFT", EverlookDBChatCCFrame, "TOPLEFT", 5, -5)

		local EverlookDBChatCCFrameScroll = CreateFrame("ScrollFrame", "EverlookDBChatCCFrameScroll", EverlookDBChatCCFrame, "UIPanelScrollFrameTemplate")
		EverlookDBChatCCFrameScroll:SetToplevel(true)
		EverlookDBChatCCFrameScroll:SetSize(455, 330)
		EverlookDBChatCCFrameScroll:SetPoint("TOP", EverlookDBChatCCFrame, "TOP", -10, -30)
		EverlookDBChatCCFrameScroll:SetPoint("BOTTOM", _G["EverlookDBChatCCFrameButton"], "TOP", 0, 5)

		EverlookDBChatCCFrameScrollText = CreateFrame("EditBox", "EverlookDBChatCCFrameScrollText", EverlookDBChatCCFrameScroll)
		EverlookDBChatCCFrameScrollText:SetSize(450, 344)
		EverlookDBChatCCFrameScrollText:SetMultiLine(true)
		EverlookDBChatCCFrameScrollText:SetAutoFocus(true)
		EverlookDBChatCCFrameScrollText:EnableMouse(true)
		EverlookDBChatCCFrameScrollText:SetMaxLetters(999999)
		EverlookDBChatCCFrameScrollText:SetFontObject("ChatFontNormal")

		EverlookDBChatCCFrameScroll:SetScrollChild(EverlookDBChatCCFrameScrollText)
	end
end)
