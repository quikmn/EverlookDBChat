---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This module is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Flat tabs: the chat tabs as plain text, no Blizzard art.
--   * the selected tab is white with a thin blue line under it, the others muted
--     grey; the mouse over a tab lifts it a little;
--   * a tab with something new (an alert, like a whisper) gets a small blue dot
--     instead of Blizzard's glow;
--   * all tabs fade in together while the mouse is over the chat (or the chat box
--     is open) and fade out together a moment after it leaves (Idle fade and Calm
--     still apply on top).
--
-- How it stays out of Blizzard's way:
--   * the tabs stay Blizzard's own buttons: clicking, dragging, the right-click
--     menu, docking and whisper tabs all work as before. Only their textures are
--     emptied (SetTexture(nil), put back when this is turned off), the text gets
--     a colour after Blizzard sets its own (a post-hook of FCFTab_UpdateColors),
--     and a few textures of our own are added;
--   * the alpha is done by services/chatui.lua with SetAlpha only. Blizzard's tab
--     alpha tables are never written (that would taint its fading code);
--   * no Blizzard function is replaced and nothing here is protected, so it all
--     works the same in combat. Tab names can be secret values (whisper tabs);
--     they are never read.
---------------------------------------------------------------------------------

local _, private = ...

-- Colours and timing. Pure logic, also used by tests/tabstyle_test.py.
local Logic = {}
private.TabStyleLogic = Logic

Logic.ACCENT = { 0.30, 0.62, 1.00 }
Logic.TEXT_SELECTED = { 1.00, 1.00, 1.00 }
Logic.TEXT_HOVER = { 0.86, 0.88, 0.92 }
Logic.TEXT_NORMAL = { 0.56, 0.60, 0.66 }
Logic.HIDE_DELAY = 0.6 -- seconds the tabs stay after the mouse leaves the chat

-- The text colour of a tab.
function Logic.TextColor(selected, hover)
	if selected then
		return Logic.TEXT_SELECTED
	elseif hover then
		return Logic.TEXT_HOVER
	end
	return Logic.TEXT_NORMAL
end

-- The dot: shown for an alerting or flashing tab that is not the one on screen.
function Logic.ShowDot(selected, alerting, flashing)
	return (alerting or flashing) and not selected or false
end

-- Where the tabs fade to: 1 (shown) or 0. lastOver is when the mouse was last
-- over the chat (nil: never).
function Logic.Target(hoverOnly, now, lastOver, delay)
	if not hoverOnly then
		return 1
	end
	if lastOver and now - lastOver < (delay or Logic.HIDE_DELAY) then
		return 1
	end
	return 0
end

-- Texture keys on a chat tab that hold Blizzard's art (retail and classic names,
-- and the minimal ones). Any other texture found on the tab is emptied as well.
Logic.ART_KEYS = {
	"Left", "Middle", "Right",
	"ActiveLeft", "ActiveMiddle", "ActiveRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight",
	"SelectedLeft", "SelectedMiddle", "SelectedRight",
	"leftSelectedTexture", "middleSelectedTexture", "rightSelectedTexture",
	"leftTexture", "middleTexture", "rightTexture",
	"leftHighlightTexture", "middleHighlightTexture", "rightHighlightTexture",
	"glow",
}

if not EverlookDBChat or not EverlookDBChat.AddModuleToLoad then
	return
end

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("TabStyle", "AceHook-3.0", "AceEvent-3.0")
	local PL = module.PL
	local ChatUI = EverlookDBChat.ChatUI

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			hoveronly = true,
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
			hoveronly = {
				name = PL["hoveronly_name"],
				desc = PL["hoveronly_desc"],
				type = "toggle",
				order = 2,
			},
		}
	})

	local enabled = false
	local styled = {} -- [tab] = { saved = { [texture] = file }, line, hover, dot }
	local driver
	local lastOver
	local TICK = 0.05

	local function chatFrameOf(tab)
		local id = tab.GetID and tab:GetID()
		return id and _G["ChatFrame" .. id]
	end

	local function isSelected(tab)
		local cf = chatFrameOf(tab)
		if not cf then
			return false
		end
		if not cf.isDocked then
			return true
		end
		return GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == cf
	end

	local function isAlerting(tab)
		if ChatFrameUtil and ChatFrameUtil.IsTabAlerting then
			return ChatFrameUtil.IsTabAlerting(tab) and true or false
		end
		return tab.alerting and true or false
	end

	local function isFlashing(tab)
		local flash = _G[tab:GetName() .. "Flash"]
		return flash and flash.FlashAnim and flash.FlashAnim:IsPlaying() or false
	end

	local function empty(info, texture)
		if not texture or texture == info.line or texture == info.hover or texture == info.dot then
			return
		end
		local atlas = texture.GetAtlas and texture:GetAtlas()
		local file = texture:GetTexture()
		if info.saved[texture] == nil then
			info.saved[texture] = atlas and { atlas = atlas } or file or false
		end
		if file or atlas then
			texture:SetTexture(nil)
		end
	end

	-- Every Blizzard texture on the tab and its flash frame: empty.
	local function emptyArt(tab, info)
		for _, key in ipairs(Logic.ART_KEYS) do
			local t = tab[key]
			if type(t) == "table" and t.GetObjectType and t:GetObjectType() == "Texture" then
				empty(info, t)
			end
		end
		for _, region in ipairs({ tab:GetRegions() }) do
			if region:GetObjectType() == "Texture" and region ~= tab.conversationIcon then
				empty(info, region)
			end
		end
		local flash = _G[tab:GetName() .. "Flash"]
		if flash then
			for _, region in ipairs({ flash:GetRegions() }) do
				if region:GetObjectType() == "Texture" then
					empty(info, region)
				end
			end
		end
	end

	function module:Paint(tab)
		local info = styled[tab]
		if not info then
			return
		end
		local selected = isSelected(tab)
		local fs = tab:GetFontString()
		if fs then
			local c = Logic.TextColor(selected, info.over)
			fs:SetTextColor(c[1], c[2], c[3])
		end
		info.line:SetShown(selected)
		local dot = Logic.ShowDot(selected, isAlerting(tab), isFlashing(tab))
		info.dot:SetShown(dot)
	end

	function module:Style(tab)
		if not tab or not enabled then
			return
		end
		local info = styled[tab]
		if not info then
			info = { saved = {} }
			styled[tab] = info

			local fs = tab:GetFontString()
			local a = Logic.ACCENT

			info.line = tab:CreateTexture(nil, "ARTWORK")
			info.line:SetColorTexture(a[1], a[2], a[3], 1)
			info.line:SetHeight(2)
			if fs then
				info.line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
				info.line:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -3)
			else
				info.line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, 2)
				info.line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 2)
			end

			info.hover = tab:CreateTexture(nil, "BACKGROUND")
			info.hover:SetColorTexture(1, 1, 1, 0.06)
			info.hover:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 3, 0)
			info.hover:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -3, -10)
			info.hover:Hide()

			info.dot = tab:CreateTexture(nil, "OVERLAY")
			info.dot:SetColorTexture(a[1], a[2], a[3], 1)
			info.dot:SetSize(5, 5)
			if tab.CreateMaskTexture then
				local mask = tab:CreateMaskTexture()
				mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				mask:SetAllPoints(info.dot)
				info.dot:AddMaskTexture(mask)
			end
			if fs then
				info.dot:SetPoint("BOTTOMLEFT", fs, "TOPRIGHT", 1, -3)
			else
				info.dot:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -4, -10)
			end
			info.dot:Hide()

			tab:HookScript("OnEnter", function(t)
				local i = styled[t]
				if i and enabled then
					i.over = true
					i.hover:Show()
					module:Paint(t)
				end
			end)
			tab:HookScript("OnLeave", function(t)
				local i = styled[t]
				if i then
					i.over = nil
					i.hover:Hide()
					if enabled then
						module:Paint(t)
					end
				end
			end)
		end
		info.line:SetAlpha(1)
		info.dot:SetAlpha(1)
		emptyArt(tab, info)
		self:Paint(tab)
	end

	function module:Unstyle(tab)
		local info = styled[tab]
		if not info then
			return
		end
		for texture, file in pairs(info.saved) do
			if type(file) == "table" then
				texture:SetAtlas(file.atlas)
			elseif file then
				texture:SetTexture(file)
			end
		end
		wipe(info.saved)
		info.line:Hide()
		info.dot:Hide()
		info.hover:Hide()
		info.over = nil
		-- Blizzard's own colours back.
		if FCFTab_UpdateColors then
			FCFTab_UpdateColors(tab, isSelected(tab))
		end
	end

	function module:StyleAll()
		if not enabled then
			return
		end
		for _, name in ipairs(CHAT_FRAMES or {}) do
			self:Style(_G[name .. "Tab"])
		end
		ChatUI:Collect()
		ChatUI:Apply()
	end

	function module:PaintAll()
		for tab in pairs(styled) do
			self:Paint(tab)
		end
	end

	-- Blizzard has just set this tab's colours: put ours on top.
	function module:FCFTab_UpdateColors(tab)
		if enabled and styled[tab] then
			self:Paint(tab)
		end
	end

	local function menuOpen()
		local ok, open = pcall(function()
			return Menu and Menu.GetManager and Menu.GetManager():GetOpenMenu()
		end)
		return ok and open and true or false
	end

	local function overflowOpen()
		local dock = GENERAL_CHAT_DOCK
		return dock and dock.overflowButton and dock.overflowButton.list and dock.overflowButton.list:IsShown() or false
	end

	local sinceTick, sincePaint = 0, 0
	local function onUpdate(_, elapsed)
		sinceTick = sinceTick + elapsed
		if sinceTick < TICK then
			return
		end
		sincePaint = sincePaint + sinceTick
		sinceTick = 0
		local now = GetTime()
		if ChatUI:IsMouseOverChat() or ChatUI:IsChatFocus() or MOVING_CHATFRAME or overflowOpen() or menuOpen() then
			lastOver = now
		end
		ChatUI:SetTarget("tabs", Logic.Target(module.db.profile.hoveronly, now, lastOver))
		-- The dot follows Blizzard's alert state, which has no event of its own.
		if sincePaint >= 0.25 then
			sincePaint = 0
			module:PaintAll()
		end
	end

	function module:UPDATE_CHAT_WINDOWS()
		self:StyleAll()
	end

	function module:EverlookDBChat_FramesUpdated()
		self:StyleAll()
	end

	function module:OnValueChanged()
		self:StyleAll()
	end

	function module:OnModuleEnable()
		enabled = true
		lastOver = GetTime()
		ChatUI:AddUser()
		ChatUI:SetTabsMode(true)
		self:StyleAll()

		if FCFTab_UpdateColors and not self:IsHooked("FCFTab_UpdateColors") then
			self:SecureHook("FCFTab_UpdateColors")
		end
		local hooks = {
			FCF_OpenTemporaryWindow = "StyleAll", -- new whisper tabs
			FCF_OpenNewWindow = "StyleAll",
			FCF_DockUpdate = "PaintAll", -- tab switch, dock changes
			FCF_StartAlertFlash = "PaintAll",
			FCF_StopAlertFlash = "PaintAll",
		}
		for fn, handler in pairs(hooks) do
			if _G[fn] and not self:IsHooked(fn) then
				self:SecureHook(fn, handler)
			end
		end
		self:RegisterEvent("UPDATE_CHAT_WINDOWS")
		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.FRAMES_UPDATED)

		if not driver then
			driver = CreateFrame("Frame")
		end
		driver:SetScript("OnUpdate", onUpdate)
	end

	function module:OnModuleDisable()
		enabled = false
		if driver then
			driver:SetScript("OnUpdate", nil)
		end
		self:UnregisterAllEvents()
		EverlookDBChat.UnregisterAllChatEvents(self)
		self:UnhookAll()
		for tab in pairs(styled) do
			self:Unstyle(tab)
		end
		ChatUI:SetTabsMode(false)
		ChatUI:RemoveUser("tabs")
	end

	function module:GetDescription()
		return PL["module_desc"]
	end
end)
