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

local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or Constants.ChatFrameConstants.MaxChatWindows

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("Clear")
	local PL = module.PL

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = false,
		}
	})

	EverlookDBChat:SetModuleOptions(module.name, {
		name = PL["Clear"],
		desc = PL["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."],
		type = "group",
		args = {}
	})

	function module:OnModuleEnable()
		EverlookDBChat.RegisterChatCommand("clear", function()
			module:clear(SELECTED_CHAT_FRAME)
		end)
		EverlookDBChat.RegisterChatCommand("cls", function()
			module:clear(SELECTED_CHAT_FRAME)
		end)
		EverlookDBChat.RegisterChatCommand("clearall", function()
			module:clearAll()
		end)
		EverlookDBChat.RegisterChatCommand("clsall", function()
			module:clearAll()
		end)
	end

	--[[ - - ------------------------------------------------
	  Core Functions
	--------------------------------------------- - ]] --
	function module:GetDescription()
		return PL["Adds clear text slash commands (/clear)(/cls)(/clearall)(/clsall)."]
	end

	function module:clear(chatframe)
		local type = chatframe:GetObjectType()

		if self.db.profile.on and type == 'Frame' and chatframe.Clear then
			chatframe:Clear()
		end
	end

	function module:clearAll()
		for i = 1, NUM_CHAT_WINDOWS do
			self:clear(_G['ChatFrame' .. i])
		end
	end
end)
