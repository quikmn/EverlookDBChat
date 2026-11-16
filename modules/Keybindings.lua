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
	local module = EverlookDBChat:NewModule("KeyBindings")
	local PL = module.PL

	EverlookDBChat:SetModuleInit(module,
		function()
			BINDING_HEADER_EverlookDBChat = PL["EverlookDBChat Keybindings"]
			BINDING_NAME_EDBCHAT_OFFICER = PL["Officer Channel"]
			BINDING_NAME_EDBCHAT_GUILD = PL["Guild Channel"]
			BINDING_NAME_EDBCHAT_PARTY = PL["Party Channel"]
			BINDING_NAME_EDBCHAT_RAID = PL["Raid Channel"]
			BINDING_NAME_EDBCHAT_RAIDWARN = PL["Raid Warning Channel"]
			BINDING_NAME_EDBCHAT_INSTANCE = PL["Instance Channel"]
			BINDING_NAME_EDBCHAT_SAY = PL["Say"]
			BINDING_NAME_EDBCHAT_YELL = PL["Yell"]
			BINDING_NAME_EDBCHAT_WHISPER = PL["Whisper"]
			BINDING_NAME_EDBCHAT_CHANNEL1 = (PL["Channel %d"]):format(1)
			BINDING_NAME_EDBCHAT_CHANNEL2 = (PL["Channel %d"]):format(2)
			BINDING_NAME_EDBCHAT_CHANNEL3 = (PL["Channel %d"]):format(3)
			BINDING_NAME_EDBCHAT_CHANNEL4 = (PL["Channel %d"]):format(4)
			BINDING_NAME_EDBCHAT_CHANNEL5 = (PL["Channel %d"]):format(5)
			BINDING_NAME_EDBCHAT_CHANNEL6 = (PL["Channel %d"]):format(6)
			BINDING_NAME_EDBCHAT_CHANNEL7 = (PL["Channel %d"]):format(7)
			BINDING_NAME_EDBCHAT_CHANNEL8 = (PL["Channel %d"]):format(8)
			BINDING_NAME_EDBCHAT_CHANNEL9 = (PL["Channel %d"]):format(9)
			BINDING_NAME_EDBCHAT_SMARTGROUP = PL["Smart Group Channel"]
			--	    BINDING_HEADER_EverlookDBChat_TellTarget = PL["EverlookDBChat TellTarget"]
			--	    BINDING_HEADER_EverlookDBChat_CopyChat = PL["EverlookDBChat CopyChat"]
			BINDING_NAME_EDBCHAT_NEXTTAB = PL["Next Chat Tab"]
			BINDING_NAME_EDBCHAT_COPYCHAT = PL["Copy Selected Chat Frame"]
			BINDING_NAME_EDBCHAT_TELLTARGET = PL["TellTarget"]
			BINDING_NAME_EDBCHAT_SCROLLBOTTOM = "Scroll To Bottom"
			BINDING_NAME_EDBCHAT_SCROLLTOP = "Scroll To Top"
		end)

	-- /script keybindings:CycleChatTabs()
	function module:CycleChatTabs()
		local current = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
		local idx
		local dockedFrames = FCFDock_GetChatFrames(GENERAL_CHAT_DOCK)

		for i, v in ipairs(dockedFrames) do
			if v == current then
				idx = i
			end
		end

		if idx == nil then
			return
		end

		idx = idx + 1
		if dockedFrames[idx] == nil then
			idx = 1
		end

		FCFDock_SelectWindow(GENERAL_CHAT_DOCK, dockedFrames[idx])
	end

	return
end) -- EverlookDBChat:AddModuleToLoad
