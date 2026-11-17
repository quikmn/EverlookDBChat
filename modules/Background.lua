---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This module is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Chat background: caps how visible the chat windows' background and border
-- textures can get. Default 0: no background at all, also on mouse-over.
--
-- Why not just Blizzard's own "Background" opacity (FCF_SetWindowAlpha)? Set to 0
-- it still comes back on mouse-over: FCF_FadeInChatFrame fades the background
-- textures to max(chatFrame.oldAlpha, DEFAULT_CHATFRAME_ALPHA), and that default
-- is 0.25. So this module leaves the game's setting alone and post-hooks SetAlpha
-- on each background texture instead: whatever Blizzard (or UIFrameFade) sets, the
-- texture shows at most the opacity chosen here. Only textures are touched, no
-- protected frames and no Blizzard function is replaced, so it is combat-safe.
---------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function()
	return false
end

-- Background and border textures of a chat window (and its button bar), by name
-- suffix. Blizzard's CHAT_FRAME_TEXTURES is used as well when it exists.
local TEXTURE_SUFFIXES = {
	"Background",
	"TopLeftTexture",
	"BottomLeftTexture",
	"TopRightTexture",
	"BottomRightTexture",
	"LeftTexture",
	"RightTexture",
	"BottomTexture",
	"TopTexture",
	"ButtonFrameBackground",
	"ButtonFrameTopLeftTexture",
	"ButtonFrameBottomLeftTexture",
	"ButtonFrameTopRightTexture",
	"ButtonFrameBottomRightTexture",
	"ButtonFrameLeftTexture",
	"ButtonFrameRightTexture",
	"ButtonFrameBottomTexture",
	"ButtonFrameTopTexture",
}

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("Background", "AceHook-3.0")
	local PL = module.PL

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			opacity = 0,
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
			opacity = {
				name = PL["opacity_name"],
				desc = PL["opacity_desc"],
				type = "range",
				order = 2,
				min = 0,
				max = 1,
				step = 0.05,
				isPercent = true,
			},
		}
	})

	local wanted = {} -- [texture] = the alpha its owner set
	local hooked = {}
	local applying = false
	local enabled = false

	local function cap()
		return module.db.profile.opacity
	end

	local function setAlpha(texture, alpha)
		applying = true
		texture:SetAlpha(alpha)
		applying = false
	end

	local function onSetAlpha(texture, alpha)
		if applying or not enabled or type(alpha) ~= "number" or issecretvalue(alpha) then
			return
		end
		wanted[texture] = alpha
		if alpha > cap() then
			setAlpha(texture, cap())
		end
	end

	local function manage(texture)
		if not texture or type(texture.SetAlpha) ~= "function" then
			return
		end
		if wanted[texture] == nil then
			wanted[texture] = texture:GetAlpha()
		end
		if not hooked[texture] then
			hooked[texture] = true
			hooksecurefunc(texture, "SetAlpha", onSetAlpha)
		end
		setAlpha(texture, math.min(wanted[texture], cap()))
	end

	function module:Apply()
		if not enabled then
			return
		end
		local suffixes = {}
		for _, suffix in ipairs(TEXTURE_SUFFIXES) do
			suffixes[suffix] = true
		end
		if type(CHAT_FRAME_TEXTURES) == "table" then
			for _, suffix in pairs(CHAT_FRAME_TEXTURES) do
				if type(suffix) == "string" then
					suffixes[suffix] = true
				end
			end
		end
		for _, name in ipairs(CHAT_FRAMES or {}) do
			local cf = _G[name]
			if cf then
				for suffix in pairs(suffixes) do
					manage(_G[name .. suffix])
				end
				manage(cf.Background)
			end
		end
	end

	function module:OnValueChanged()
		self:Apply()
	end

	function module:EverlookDBChat_FramesUpdated()
		self:Apply()
	end

	function module:OnModuleEnable()
		enabled = true
		self:Apply()
		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.FRAMES_UPDATED)
		if FCF_OpenTemporaryWindow and not self:IsHooked("FCF_OpenTemporaryWindow") then
			self:SecureHook("FCF_OpenTemporaryWindow", "Apply")
		end
	end

	function module:OnModuleDisable()
		enabled = false
		for texture, alpha in pairs(wanted) do
			setAlpha(texture, alpha)
		end
		wipe(wanted)
		self:UnhookAll()
	end

	function module:GetDescription()
		return PL["module_desc"]
	end
end)
