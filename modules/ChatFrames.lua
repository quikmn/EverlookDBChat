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
	local module = EverlookDBChat:NewModule("Frames", "AceHook-3.0")
	local PL = module.PL

	-- We have to set the insets here before blizzard has a chance to move them
	for i = 1, NUM_CHAT_WINDOWS do
		local f = _G["ChatFrame" .. i]
		f:SetClampRectInsets(0, 0, 0, 0)
	end

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			minchatwidth = 160,
			minchatwidthdefault = 160,
			maxchatwidth = 800,
			maxchatwidthdefault = 800,
			minchatheight = 120,
			minchatheightdefault = 120,
			maxchatheight = 600,
			maxchatheightdefault = 600,
			mainchatonload = true,
			removeclamp = true,
			framealphastatic = false,
			defaultframealpha = 0.25,
			framemetrics = {
				['*'] = {
					width = 430,
					height = 120,
				}
			}
		}
	})

	do
		local frameoption = {
			name = function(info)
				return PL[info[#info] .. "_name"]
			end,
			desc = function(info)
				return PL[info[#info] .. "_desc"]
			end,
			type = "range",
			min = 25,
			max = 1024,
			step = 1
		}

		EverlookDBChat:SetModuleOptions(module.name, {
			name = PL["Frames"],
			desc = PL["Chat window frame parameter options"],
			type = "group",
			args = {
				minchatwidth = frameoption,
				maxchatwidth = frameoption,
				minchatheight = frameoption,
				maxchatheight = frameoption,
				removeclamp = {
					type = "toggle",
					order = 110,
					name = PL["removeclamp_name"],
					desc = PL["removeclamp_desc"],
				},
				framealphastatic = {
					type = "toggle",
					order = 130,
					name = PL.framealphastatic_name,
					desc = PL.framealphastatic_desc,
				},
				defaultframealpha = {
					name = PL["defaultframealpha_name"],
					desc = PL["defaultframealpha_desc"],
					type = "range",
					order = 140,
					min = 0.0,
					max = 1,
					step = 0.01,
				},
			}
		})
	end


	--[[------------------------------------------------
		Module Event Functions
	------------------------------------------------]] --

	EverlookDBChat:SetModuleInit(module, function()
		module:GetDefaults()
	end)

	function module:OnModuleEnable()
		CHAT_FRAME_BUTTON_FRAME_MIN_ALPHA = 0
		self:ConfigureAllChatFrames(true)

		self:SecureHook("FCF_DockFrame")
		self:SecureHook("FCF_UnDockFrame")
		self:SecureHook("FloatingChatFrame_UpdateBackgroundAnchors")

		self:SecureHook("FCF_SetWindowAlpha")
		self:SecureHook("FCF_SetWindowColor")

		local prevClamp = ChatFrame1.SetClampRectInsets
		self:SecureHook(ChatFrame1, "SetClampRectInsets", function(frame)
			-- If in combat, SetClampRectInsets is protected... This should likely never happen, but to be safe.
			if _G.InCombatLockdown() then
				return
			end
			if self.db.profile.on and self.db.profile.removeclamp then
				prevClamp(frame, 0, 0, 0, 0)
			end
		end)
	end

	function module:OnModuleDisable()
		CHAT_FRAME_BUTTON_FRAME_MIN_ALPHA = 0.2
		self:ConfigureAllChatFrames(false)
	end

	function module:GetDescription()
		return PL["Chat window frame parameter options"]
	end

	function module:FloatingChatFrame_UpdateBackgroundAnchors(frame)
		if self.db.profile.removeclamp then
			frame:SetClampRectInsets(0, 0, 0, 0)
		end
		EverlookDBChat.Frames[frame:GetName()] = frame
		local m = EverlookDBChat:GetModule("Font")
		if m then
			m:ConfigureAllChatFrames()
		end

	end
	function module:FCF_DockFrame(frame)
		if self.db.profile.removeclamp then
			frame:SetClampRectInsets(0, 0, 0, 0)
		end
		EverlookDBChat.Frames[frame:GetName()] = frame
		local m = EverlookDBChat:GetModule("Font")
		if m then
			m:ConfigureAllChatFrames()
		end
	end

	function module:FCF_UnDockFrame(frame)
		if self.db.profile.removeclamp then
			frame:SetClampRectInsets(0, 0, 0, 0)
		end
		EverlookDBChat.Frames[frame:GetName()] = frame
		local m = EverlookDBChat:GetModule("Font")
		if m then
			m:ConfigureAllChatFrames()
		end
	end

	--[[------------------------------------------------
		Core Functions
	------------------------------------------------]] --
	-- set parameters for each chatframe
	function module:ConfigureAllChatFrames(enabled)
		for _, v in pairs(EverlookDBChat.Frames) do
			self:SetParameters(v, enabled)
		end
	end

	function module:RecreateBackgroundTextures(frame)
		if frame.EverlookDBChatTextures then
			return
		end
		frame.EverlookDBChatTextures = {}
		for _, name in ipairs(CHAT_FRAME_TEXTURES) do
			local texture = _G[frame:GetName() .. name]
			local layer, sublevel = texture:GetDrawLayer()

			local newTexture = texture:GetParent():CreateTexture(nil, layer, nil, sublevel)
			for i = 1, texture:GetNumPoints() do
				newTexture:SetPoint(texture:GetPoint(i))
			end

			newTexture:SetTexture(texture:GetTexture())
			newTexture:SetTexCoord(texture:GetTexCoord())

			newTexture:SetSize(texture:GetSize())

			table.insert(frame.EverlookDBChatTextures, newTexture)
			texture:Hide()
		end
	end

	function module:HideEverlookDBChatTextures(frame)
		if frame.EverlookDBChatTextures then
			for _, name in ipairs(CHAT_FRAME_TEXTURES) do
				local texture = _G[frame:GetName() .. name]
				texture:Show()
			end
			for _, texture in ipairs(frame.EverlookDBChatTextures) do
				texture:Hide()
			end
		end
	end

	function module:RestoreEverlookDBChatTextures(frame)
		if not frame.EverlookDBChatTextures then
			self:RecreateBackgroundTextures(frame)
		end

		for _, name in ipairs(CHAT_FRAME_TEXTURES) do
			local texture = _G[frame:GetName() .. name]
			texture:Hide()
		end
		local _, _, r, g, b, a = FCF_GetChatWindowInfo(frame:GetID())
		for _, texture in ipairs(frame.EverlookDBChatTextures) do
			texture:Show()
			texture:SetVertexColor(r, g, b)
			texture:SetAlpha(a)
		end
	end

	-- get the defaults for chat frame1 max/min width/height for use when disabling the module
	function module:GetDefaults()
		local cf = _G["ChatFrame1"]
		local prof = self.db.profile

		local minwidthdefault, minheightdefault, maxwidthdefault, maxheightdefault
		if cf.GetResizeBounds then
			minwidthdefault, minheightdefault, maxwidthdefault, maxheightdefault = cf:GetResizeBounds()
		else
			minwidthdefault, minheightdefault = cf:GetMinResize()
			maxwidthdefault, maxheightdefault = cf:GetMaxResize()
		end

		prof.minchatwidthdefault = minwidthdefault
		prof.maxchatwidthdefault = maxwidthdefault
		prof.minchatheightdefault = minheightdefault
		prof.maxchatheightdefault = maxheightdefault

		prof.initialized = true
	end

	function module:FCF_SetWindowColor(frame, r, g, b)
		if frame.EverlookDBChatTextures then
			for _, texture in ipairs(frame.EverlookDBChatTextures) do
				texture:SetVertexColor(r, g, b)
			end
		end
	end

	function module:FCF_SetWindowAlpha(frame)
		local _, _, _, _, _, a = FCF_GetChatWindowInfo(frame:GetID())
		if frame.EverlookDBChatTextures then
			for _, texture in ipairs(frame.EverlookDBChatTextures) do
				texture:SetAlpha(a)
			end
		end
	end
	-- set the max/min width/height for a chatframe
	function module:SetParameters(cf, enabled)
		local prof = self.db.profile

		local minWidth, minHeight, maxWidth, maxHeight
		if enabled then
			if prof.framealphastatic then
				self:RestoreEverlookDBChatTextures(cf)
			else
				self:HideEverlookDBChatTextures(cf)
			end

			DEFAULT_CHATFRAME_ALPHA = prof.defaultframealpha

			minWidth, minHeight = prof.minchatwidth, prof.minchatheight
			maxWidth, maxHeight = prof.maxchatwidth, prof.maxchatheight

			if prof.removeclamp then
				cf:SetClampedToScreen(false)
				cf:SetClampRectInsets(0, 0, 0, 0)
				EventRegistry:RegisterCallback("EditMode.Enter", function()
					cf:SetClampedToScreen(true)
					EventRegistry:UnregisterCallback("EditMode.Enter", cf)
				end, cf)
			end

			if cf.ScrollBar then
				cf.ScrollBar:SetAlpha(0)
			end
		else
			self:HideEverlookDBChatTextures(cf)
			DEFAULT_CHATFRAME_ALPHA = 0.25

			minWidth, minHeight = prof.minchatwidthdefault, prof.minchatheightdefault
			maxWidth, maxHeight = prof.maxchatwidthdefault, prof.maxchatheightdefault
		end

		if cf.SetResizeBounds then
			cf:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
		else
			cf:SetMinResize(minWidth, minHeight)
			cf:SetMaxResize(maxWidth, maxHeight)
		end
	end

	function module:OnValueChanged()
		self:ConfigureAllChatFrames(true)
	end

	return
end) -- EverlookDBChat:AddModuleToLoad
