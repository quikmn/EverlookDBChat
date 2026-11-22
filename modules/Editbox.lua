local ChatEdit_ChooseBoxForSend = _G.ChatEdit_ChooseBoxForSend or _G.ChatFrameUtil.ChooseBoxForSend
local ChatEdit_DeactivateChat = _G.ChatEdit_DeactivateChat or _G.ChatFrameUtil.DeactivateChat

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("Editbox", "AceHook-3.0")
	local PL = module.PL

	local Media = EverlookDBChat.Media
	local backgrounds, borders, fonts = {}, {}, {}

	local Placement = EverlookDBChat.Placement

	-- Where the edit box goes (see addon/placement.lua for the maths).
	local VALID_ATTACH_POINTS = {
		BELOW = PL["attach_below"],
		ABOVE = PL["attach_above"],
		INSIDE = PL["attach_inside"],
		FREE = PL["attach_free"],
	}

	-- The flat look: a thin dark background, a 1 px border, blue while you type.
	local WHITE = "Interface\\Buttons\\WHITE8X8"
	local FLAT_BG = { 0.055, 0.060, 0.074, 0.88 }
	local FLAT_BORDER = { 0.180, 0.196, 0.235, 1 }
	local FLAT_FOCUS = { 0.353, 0.663, 1.000, 0.85 }

	local function updateEditBox(method, ...)
		for i = 1, #CHAT_FRAMES do
			local f = _G["ChatFrame" .. i .. "EditBox"]
			f[method](f, ...)
		end
	end

	local function isFlat()
		return module.db.profile.flat
	end

	EverlookDBChat:SetModuleOptions(module, {
		name = PL["Editbox"],
		desc = PL["Editbox options."],
		type = "group",
		args = {
			attach = {
				type = "select",
				name = PL["attach_name"],
				desc = PL["attach_desc"],
				order = 1,
				width = "double",
				get = function()
					return Placement.NormalizeMode(module.db.profile.attach)
				end,
				values = VALID_ATTACH_POINTS,
				sorting = Placement.MODES,
				set = function(_, v)
					module.db.profile.attach = v
					module:SetAttach()
					if module.OnAttachChanged then module.OnAttachChanged() end
				end
			},
			placement = {
				type = "execute",
				name = PL["placement_name"],
				desc = PL["placement_desc"],
				order = 2,
				func = function()
					local p = EverlookDBChat.Addon and EverlookDBChat.Addon:GetModule("Placement", true)
					if p and p:IsEnabled() then p:SetUnlocked(true) end
				end
			},
			flat = {
				type = "toggle",
				name = PL["flat_name"],
				desc = PL["flat_desc"],
				order = 3,
				width = "full",
				get = function()
					return module.db.profile.flat
				end,
				set = function(_, v)
					module.db.profile.flat = v
					module:SetBackdrop()
				end
			},
			background = {
				hidden = isFlat,
				type = "select",
				name = PL["Background texture"],
				desc = PL["Background texture"],
				values = backgrounds,
				get = function()
					return module.db.profile.background
				end,
				set = function(_, v)
					module.db.profile.background = v
					module:SetBackdrop()
				end
			},
			border = {
				hidden = isFlat,
				type = "select",
				name = PL["Border texture"],
				desc = PL["Border texture"],
				values = borders,
				get = function()
					return module.db.profile.border
				end,
				set = function(_, v)
					module.db.profile.border = v
					module:SetBackdrop()
				end
			},
			backgroundColor = {
				hidden = isFlat,
				type = "color",
				name = PL["Background color"],
				desc = PL["Background color"],
				hasAlpha = true,
				get = function()
					local c = module.db.profile.backgroundColor
					return c.r, c.g, c.b, c.a
				end,
				set = function(_, r, g, b, a)
					local c = module.db.profile.backgroundColor
					c.r, c.g, c.b, c.a = r, g, b, a
					module:SetBackdrop()
				end
			},
			borderColor = {
				hidden = isFlat,
				type = "color",
				name = PL["Border color"],
				desc = PL["Border color"],
				hasAlpha = true,
				get = function()
					local c = module.db.profile.borderColor
					return c.r, c.g, c.b, c.a
				end,
				set = function(_, r, g, b, a)
					local c = module.db.profile.borderColor
					c.r, c.g, c.b, c.a = r, g, b, a
					module:SetBackdrop()
				end
			},
			inset = {
				hidden = isFlat,
				type = "range",
				name = PL["Background Inset"],
				desc = PL["Background Inset"],
				min = 1,
				max = 64,
				step = 1,
				bigStep = 1,
				get = function()
					return module.db.profile.inset
				end,
				set = function(_, v)
					module.db.profile.inset = v
					module:SetBackdrop()
				end
			},
			tileSize = {
				hidden = isFlat,
				type = "range",
				name = PL["Tile Size"],
				desc = PL["Tile Size"],
				min = 1,
				max = 64,
				step = 1,
				bigStep = 1,
				get = function()
					return module.db.profile.tileSize
				end,
				set = function(_, v)
					module.db.profile.tileSize = v
					module:SetBackdrop()
				end
			},
			edgeSize = {
				hidden = isFlat,
				type = "range",
				name = PL["Edge Size"],
				desc = PL["Edge Size"],
				min = 1,
				max = 64,
				step = 1,
				bigStep = 1,
				get = function()
					return module.db.profile.edgeSize
				end,
				set = function(_, v)
					module.db.profile.edgeSize = v
					module:SetBackdrop()
				end
			},
			colorByChannel = {
				type = "toggle",
				name = PL["Color border by channel"],
				desc = PL["Sets the frame's border color to the color of your currently active channel"],
				get = function()
					return module.db.profile.colorByChannel
				end,
				set = function(_, v)
					module.db.profile.colorByChannel = v
					for i in ipairs(module.frames) do
						module:UpdateBorder(i)
					end
				end
			},
			useAltKey = {
				type = "toggle",
				name = PL["Use Alt key for cursor movement"],
				desc = PL["Requires the Alt key to be held down to move the cursor in chat"],
				get = function()
					return module.db.profile.useAltKey
				end,
				set = function(_, v)
					module.db.profile.useAltKey = v
					updateEditBox("SetAltArrowKeyMode", v)
				end,
			},
			font = {
				type = "select",
				name = PL["Font"],
				desc = PL["Select the font to use for the edit box"],
				values = fonts,
				get = function()
					return module.db.profile.font
				end,
				set = function(_, v)
					module.db.profile.font = v
					for i = 1, #CHAT_FRAMES do
						local ff = _G["ChatFrame" .. i .. "EditBox"]
						local header = _G[ff:GetName() .. "Header"]
						local _, s, m = ff:GetFont()
						local font = Media:Fetch("font", v)
						ff:SetFont(font, s, m)
						header:SetFont(font, s, m)
					end
				end
			},
		},
	})

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			background = "Blizzard Tooltip",
			border = "Blizzard Tooltip",
			backgroundColor = { r = 0, g = 0, b = 0, a = 1 },
			borderColor = { r = 1, g = 1, b = 1, a = 1 },
			inset = 3,
			edgeSize = 12,
			tileSize = 16,
			height = 22,
			attach = "BELOW",
			flat = true,
			colorByChannel = false,
			useAltKey = false,
			font = (function()
				for i = 1, #CHAT_FRAMES do
					local ff = _G["ChatFrame" .. i .. "EditBox"]
					local f = ff:GetFont()
					for k, v in pairs(Media:HashTable("font")) do
						if v == f then
							return k
						end
					end
				end
			end)()
		}
	})

	function module:LibSharedMedia_Registered()
		for _, v in pairs(Media:List("background")) do
			backgrounds[v] = v
		end
		for _, v in pairs(Media:List("border")) do
			borders[v] = v
		end
		for _, v in pairs(Media:List("font")) do
			fonts[v] = v
		end
	end

	local function MakeEverlookDBChatEditbox(self, i)
		if not self.frames[i] then
			local parent = _G["ChatFrame" .. i .. "EditBox"]

			local frame = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
			frame:SetFrameStrata("DIALOG")
			frame:SetFrameLevel(parent:GetFrameLevel() - 1)
			frame:SetAllPoints(parent)
			frame:Hide()
			parent.edbchatFrame = frame
			self.frames[i] = frame

			-- The flat look, drawn with plain textures (no backdrop maths on secret sizes).
			frame.flatBg = frame:CreateTexture(nil, "BACKGROUND")
			frame.flatBg:SetTexture(WHITE)
			frame.flatBg:SetAllPoints()
			frame.flatEdges = {}
			for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
				local t = frame:CreateTexture(nil, "BORDER")
				t:SetTexture(WHITE)
				if side == "TOP" or side == "BOTTOM" then
					t:SetPoint(side .. "LEFT")
					t:SetPoint(side .. "RIGHT")
				else
					t:SetPoint("TOP" .. side)
					t:SetPoint("BOTTOM" .. side)
				end
				t.side = side
				frame.flatEdges[#frame.flatEdges + 1] = t
			end

			-- Placement and the blue line while typing.
			parent:HookScript("OnShow", function()
				module:PlaceEditBox(i)
				module:SetLift(i, true)
			end)
			parent:HookScript("OnHide", function()
				module:SetLift(i, false)
			end)
			parent:HookScript("OnEditFocusGained", function()
				module:UpdateBorder(i)
			end)
			parent:HookScript("OnEditFocusLost", function()
				module:UpdateBorder(i)
			end)
			if parent.UpdateHeader then
				hooksecurefunc(parent, "UpdateHeader", function()
					if module:IsEnabled() then
						module:SetBorderByChannel()
					end
				end)
			end

			-- Backdrop hack
			if frame.SetupTextureCoordinates and issecretvalue then
				local setupTextureCoordinates = frame.SetupTextureCoordinates
				frame.SetupTextureCoordinates = function(f)
					if issecretvalue(f:GetWidth()) or issecretvalue(f:GetHeight()) or issecretvalue(f:GetEffectiveScale()) then
						return
					end
					return setupTextureCoordinates(f)
				end
			end
		end
	end

	local function ChatFrameTab_OnClick(i)
		if GetCVar("chatStyle") ~= "classic" then
			local chatFrame = _G["ChatFrame" .. i];
			chatFrame.editBox.edbOpen = nil
			ChatEdit_DeactivateChat(chatFrame.editBox)
			chatFrame.editBox:Hide()
		end
	end

	EverlookDBChat:SetModuleInit(module, function(self)
		Media.RegisterCallback(module, "LibSharedMedia_Registered")
		self.frames = {}
		-- Prat's "attach to" values (TOP, BOTTOM, FREE, LOCK) become the new ones.
		self.db.profile.attach = Placement.NormalizeMode(self.db.profile.attach)

		self:LibSharedMedia_Registered()

		for i = 1, #CHAT_FRAMES do
			MakeEverlookDBChatEditbox(self, i)
		end
	end)

	local function OnArrowPressed(self, key)
		-- We cannot call SetText while in lockdown
		if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
			return
		end
		if #self.history_lines == 0 then
			return
		end
		if key ~= "DOWN" and key ~= "UP" then
			return
		end

		if key == "DOWN" then
			self.history_index = self.history_index - 1

			if self.history_index < 1 then
				self.history_index = #self.history_lines
			end
		elseif key == "UP" then
			self.history_index = self.history_index + 1

			if self.history_index > #self.history_lines then
				self.history_index = 1
			end
		end

		self:SetText(self.history_lines[self.history_index])
	end

	local function enableArrowKeys(e)
		e.history_lines = e.history_lines or {}
		e.history_index = e.history_index or 0
		e:HookScript("OnArrowPressed", OnArrowPressed)
	end

	-- The game's own chat box textures. Their names differ between clients (and a
	-- new whisper window may not have them yet), so each one is looked up and
	-- skipped when it isn't there.
	local function showBlizzardTextures(f, i, show)
		local prefix = "ChatFrame" .. i .. "EditBox"
		for _, part in ipairs({ "Left", "Right", "Mid" }) do
			local t = _G[prefix .. part] or (f and f[part])
			if t and t.SetShown then
				t:SetShown(show)
			end
		end
		if f then
			for _, key in ipairs({ "focusLeft", "focusRight", "focusMid" }) do
				if f[key] and f[key].SetAlpha then
					f[key]:SetAlpha(show and 1 or 0)
				end
			end
		end
	end

	local function setHeaderFont(f, font)
		local header = f and (_G[f:GetName() .. "Header"] or f.header)
		if not (header and header.GetFont and font) then
			return
		end
		local _, size, flags = header:GetFont()
		if size then
			header:SetFont(font, size, flags)
		end
	end

	function module:EverlookDBChat_FramesUpdated(_, _, chatFrame)
		local i = chatFrame:GetID()
		local f = _G["ChatFrame" .. i .. "EditBox"]
		if not f then
			return
		end
		showBlizzardTextures(f, i, false)
		f:Hide()
		f:SetAlpha(0)
		f:EnableMouse(false)

		MakeEverlookDBChatEditbox(self, i)
		self.frames[i]:Show()
		self:HookClearChat(f)

		local _, s, m = f:GetFont()
		f:SetFont(Media:Fetch("font", self.db.profile.font), s, m)

		setHeaderFont(f, Media:Fetch("font", self.db.profile.font))

		f:SetAltArrowKeyMode(module.db.profile.useAltKey and 1 or nil)
		if not module.db.profile.useAltKey then
			enableArrowKeys(f)
		end
		self:SetBackdrop()
		self:UpdateHeight()
		self:SetAttach()
	end

	function module:OnModuleEnable()
		self:LibSharedMedia_Registered()

		for i = 1, #CHAT_FRAMES do
			local f = _G["ChatFrame" .. i .. "EditBox"]
			showBlizzardTextures(f, i, false)
			f:Hide()
			f:SetAlpha(0)
			f:EnableMouse(false)

			MakeEverlookDBChatEditbox(self, i) -- For new temporary chat frames created between init and now
			self.frames[i]:Show()
			self:HookClearChat(f)
			local _, s, m = f:GetFont()
			f:SetFont(Media:Fetch("font", self.db.profile.font), s, m)

			setHeaderFont(f, Media:Fetch("font", self.db.profile.font))

			f:SetAltArrowKeyMode(module.db.profile.useAltKey and 1 or nil)
			if not module.db.profile.useAltKey then
				enableArrowKeys(f)
			end

			local tab = _G["ChatFrame" .. i .. "Tab"]
			tab:HookScript("OnClick", function()
				ChatFrameTab_OnClick(i)
			end)
		end

		self:SetAttach()

		if _G.ChatFrameUtil then
			if _G.ChatFrameUtil.DeactivateChat then
				self:SecureHook(_G.ChatFrameUtil, "DeactivateChat", "ChatEdit_DeactivateChat")
			end
			if _G.ChatFrameUtil.SetLastActiveWindow then
				self:SecureHook(_G.ChatFrameUtil, "ActivateChat", "ChatEdit_ActivateChat")
			end
			if _G.ChatFrameUtil.OpenChat then
				self:SecureHook(_G.ChatFrameUtil, "OpenChat", "ChatFrame_OpenChat")
			end
		else
			self:SecureHook("ChatFrame_OpenChat")
		end
		-- Color border by channel: older clients have the global function; newer edit boxes have the method
		-- (hooked per edit box, see MakeEverlookDBChatEditbox).
		if _G.ChatEdit_UpdateHeader and not self:IsHooked("ChatEdit_UpdateHeader") then
			self:SecureHook("ChatEdit_UpdateHeader", "SetBorderByChannel", true)
		end

		self:SetBackdrop()
		self:UpdateHeight()

		EverlookDBChat.RegisterChatEvent(self, EverlookDBChat.Events.FRAMES_UPDATED)
	end

	function module:ChatFrame_OpenChat(_, chatFrame)
		if not self.db.profile.useAltKey then
			local frame = ChatEdit_ChooseBoxForSend(chatFrame)

			frame.history_index = 0
		end
	end


	function module:OnModuleDisable()
		for i = 1, #CHAT_FRAMES do
			local f = _G["ChatFrame" .. i .. "EditBox"]
			showBlizzardTextures(f, i, true)
			f:SetAltArrowKeyMode(true)
			f:EnableMouse(true)
			f.edbchatFrame:Hide()
			self:SetLift(i, false)
			-- restore Blizz size/position
			f:ClearAllPoints()
			f:SetHeight(32)
			f:SetPoint("TOPLEFT", f.chatFrame, "BOTTOMLEFT", -5, -2)
			if EverlookDBChat.IsClassic then
				f:SetPoint("TOPRIGHT", f.chatFrame, "BOTTOMRIGHT", 5, -2)
			else
				f:SetPoint("RIGHT", f.chatFrame.ScrollBar, "RIGHT", 5, 0)
			end
		end
	end

	function module:GetDescription()
		return PL["Editbox options."]
	end

	function module:ChatEdit_ActivateChat(frame)
		frame.edbOpen = true
		frame.edbCleared = nil
		frame:SetAlpha(1)
		frame:EnableMouse(true)
		local i = frame.chatFrame and frame.chatFrame:GetID()
		if i then
			self:SetLift(i, true)
		end
	end

	-- The box closes only when you send or press Escape (both clear it) or click a chat tab. Losing focus any other
	-- way (clicking a character, the world, another window) leaves it open, dimmed: click it or press Enter to go on
	-- typing. Decided one frame later, once we know whether the box was cleared.
	local function closeBox(frame)
		frame.edbOpen = nil
		frame:SetAlpha(0)
		frame:EnableMouse(false)
		local i = frame.chatFrame and frame.chatFrame:GetID()
		if i then
			module:SetLift(i, false)
		end
	end
	module.CloseBox = closeBox

	function module:ChatEdit_DeactivateChat(frame)
		if not frame.edbOpen or frame.edbCleared or not C_Timer then
			frame.edbCleared = nil
			closeBox(frame)
			return
		end
		C_Timer.After(0, function()
			if frame:HasFocus() then return end
			if frame.edbCleared or not frame.edbOpen then
				frame.edbCleared = nil
				closeBox(frame)
				return
			end
			if not frame:IsShown() and not (InCombatLockdown() and frame:IsProtected()) then
				frame:Show()
			end
			frame:SetAlpha(0.6)
			frame:EnableMouse(true)
		end)
	end

	-- Sending and Escape clear the box: then it closes.
	function module:HookClearChat(editbox)
		if not editbox or editbox.edbClearHooked then return end
		editbox.edbClearHooked = true
		local function done(e)
			if e:HasFocus() then return end
			e.edbCleared = true
			e.edbOpen = nil
			closeBox(e)
		end
		if editbox.ClearChat then hooksecurefunc(editbox, "ClearChat", done) end
		editbox:HookScript("OnEnterPressed", done)
		editbox:HookScript("OnEscapePressed", done)
	end

	local issecret = issecretvalue or function()
		return false
	end

	local function num(v)
		if type(v) == "number" and not issecret(v) then
			return v
		end
		return nil
	end

	-- One physical pixel in the frame's units, for the 1 px border.
	local function pixel(frame)
		local _, physH = GetPhysicalScreenSize()
		local scale = num(frame:GetEffectiveScale())
		if not num(physH) or physH <= 0 or not scale or scale <= 0 then
			return 1
		end
		return 768 / physH / scale
	end

	function module:SetBackdrop()
		local p = self.db.profile
		for i, frame in ipairs(self.frames) do
			if p.flat then
				if frame.SetBackdrop then
					frame:SetBackdrop(nil)
				end
				frame.flatBg:SetVertexColor(FLAT_BG[1], FLAT_BG[2], FLAT_BG[3], FLAT_BG[4])
				frame.flatBg:Show()
				local px = pixel(frame)
				for _, t in ipairs(frame.flatEdges) do
					if t.side == "TOP" or t.side == "BOTTOM" then
						t:SetHeight(px)
					else
						t:SetWidth(px)
					end
					t:Show()
				end
			else
				frame.flatBg:Hide()
				for _, t in ipairs(frame.flatEdges) do
					t:Hide()
				end
				frame:SetBackdrop({
					bgFile = Media:Fetch("background", p.background),
					edgeFile = Media:Fetch("border", p.border),
					tile = true,
					tileSize = p.tileSize,
					edgeSize = p.edgeSize,
					insets = {
						left = p.inset,
						right = p.inset,
						top = p.inset,
						bottom = p.inset
					}
				})
				local c = p.backgroundColor
				frame:SetBackdropColor(c.r, c.g, c.b, c.a)
			end
			self:UpdateBorder(i)
		end
	end

	local function setBorderColor(frame, r, g, b, a)
		if module.db.profile.flat then
			for _, t in ipairs(frame.flatEdges) do
				t:SetVertexColor(r, g, b, a)
			end
		else
			frame:SetBackdropBorderColor(r, g, b, a)
		end
	end

	-- The border: the channel's colour (Color border by channel), else blue while typing and grey otherwise
	-- (flat), else the chosen border colour.
	function module:UpdateBorder(i)
		local frame = self.frames and self.frames[i]
		if not frame or not self:IsEnabled() then
			return
		end
		local p = self.db.profile
		if p.colorByChannel then
			return self:SetBorderByChannel()
		end
		if p.flat then
			local eb = _G["ChatFrame" .. i .. "EditBox"]
			local c = (eb and eb:HasFocus()) and FLAT_FOCUS or FLAT_BORDER
			setBorderColor(frame, c[1], c[2], c[3], c[4])
		else
			local c = p.borderColor
			setBorderColor(frame, c.r, c.g, c.b, c.a)
		end
	end

	function module:SetBorderByChannel()
		if not self.db.profile.colorByChannel then
			return
		end
		for index, frame in ipairs(self.frames) do
			local f = _G["ChatFrame" .. index .. "EditBox"]
			local attr = f:GetAttribute("chatType")
			if attr == "CHANNEL" then
				local chan = f:GetAttribute("channelTarget")
				if chan == 0 then
					local c = self.db.profile.borderColor
					setBorderColor(frame, c.r, c.g, c.b, c.a)
				elseif chan and ChatTypeInfo["CHANNEL" .. chan] then
					local r, g, b = GetMessageTypeColor("CHANNEL" .. chan)
					setBorderColor(frame, r, g, b, 1)
				end
			elseif attr then
				local r, g, b = GetMessageTypeColor(attr)
				setBorderColor(frame, r, g, b, 1)
			end
		end
	end

	------------------------------------------------------------------------
	-- Placement (the maths is in addon/placement.lua)
	------------------------------------------------------------------------

	-- A frame's rectangle and the screen, both in that frame's units. nil while it has no size yet.
	function module.FrameRect(frame)
		local l, b, w, h = num(frame:GetLeft()), num(frame:GetBottom()), num(frame:GetWidth()), num(frame:GetHeight())
		local fs, us = num(frame:GetEffectiveScale()), num(UIParent:GetEffectiveScale())
		local sw, sh = num(UIParent:GetWidth()), num(UIParent:GetHeight())
		if not (l and b and w and h and fs and us and sw and sh) or fs <= 0 or w <= 0 then
			return nil
		end
		local k = us / fs
		return { l = l, b = b, w = w, h = h }, { w = sw * k, h = sh * k }
	end

	-- The edit box settings, for the maths (placement mode's ghost uses them too).
	function module:GetConfig()
		local p = self.db.profile
		local free
		if p.editX and p.editY then
			free = { l = p.editX, top = p.editY, w = p.editW }
		end
		return {
			mode = Placement.NormalizeMode(p.attach),
			height = p.height,
			free = free,
			tabHeight = Placement.TAB_HEIGHT,
		}
	end

	-- Where chat frame i's edit box goes when the chat is at `chat` on `screen`: rectangle, side, lift.
	function module:ComputeEditBox(chat, screen)
		local cfg = self:GetConfig()
		return Placement.EditBoxRect(cfg.mode, chat, screen, cfg)
	end

	-- Put chat frame i's edit box where the settings say, measured from where the chat is now.
	function module:PlaceEditBox(i)
		if not self:IsEnabled() then
			return
		end
		local eb = _G["ChatFrame" .. i .. "EditBox"]
		local cf = _G["ChatFrame" .. i]
		if not eb or not cf then
			return
		end
		eb:SetHeight(self.db.profile.height)
		local chat, screen = module.FrameRect(cf)
		eb:ClearAllPoints()
		if not chat then
			-- not laid out yet: plain below; the next show measures again
			eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", 0, -Placement.GAP)
			eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 0, -Placement.GAP)
			return
		end
		local r, side, lift = self:ComputeEditBox(chat, screen)
		eb.edbchatSide, eb.edbchatLift = side, lift
		eb:SetWidth(r.w)
		if side == "free" then
			eb:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", r.l, r.b)
		else
			local x, y = Placement.Offset(r, chat)
			eb:SetPoint("BOTTOMLEFT", cf, "BOTTOMLEFT", x, y)
		end
	end

	function module:SetAttach()
		for i = 1, #CHAT_FRAMES do
			self:PlaceEditBox(i)
		end
	end

	-- Inside, at the bottom: while the edit box is open the newest chat line sits just above it, so the box
	-- never covers it. Only the anchor of the frame's first line changes; no Blizzard variable is written.
	local function liftFirstLine(cf, y)
		local first = cf.visibleLines and cf.visibleLines[1]
		local top = cf.GetInsertMode and SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP and cf:GetInsertMode() == SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
		if first and first.SetPoint and not top then
			first:SetPoint("BOTTOMLEFT", cf, "BOTTOMLEFT", 0, y)
		end
	end

	module.lifted = {}
	function module:SetLift(i, on)
		local cf = _G["ChatFrame" .. i]
		local eb = _G["ChatFrame" .. i .. "EditBox"]
		if not cf or not eb then
			return
		end
		local y = 0
		if on and self:IsEnabled() and eb.edbchatSide == "inside" and eb:IsShown() then
			y = eb.edbchatLift or 0
		end
		if (self.lifted[cf] or 0) == y then
			return
		end
		self.lifted[cf] = y
		if y > 0 and cf.RefreshLayout and not cf.edbchatLiftHooked then
			cf.edbchatLiftHooked = true
			hooksecurefunc(cf, "RefreshLayout", function(f)
				local ly = module.lifted[f]
				if ly and ly > 0 then
					liftFirstLine(f, ly)
				end
			end)
		end
		liftFirstLine(cf, y)
	end

	-- Placement mode's free edit box was dragged: save it (top-left and width, as Prat did).
	function module:SetFree(l, top, w)
		local p = self.db.profile
		p.editX, p.editY, p.editW = l, top, w
		self:SetAttach()
	end

	function module:UpdateHeight()
		for i, _ in ipairs(self.frames) do
			local ff = _G["ChatFrame" .. i .. "EditBox"]
			ff:SetHeight(module.db.profile.height)
		end
	end

	return
end)
