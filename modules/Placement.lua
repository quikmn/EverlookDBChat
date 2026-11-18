---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This module is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Chat placement: see and set where the chat and its chat box go.
--
--   * Placement mode (/echat move, unlock, lock, or the button in the settings):
--     the chat gets an outline and corner handles, and a ghost of the chat box
--     shows exactly where it will open (the Chat box module's position). Drag
--     with the left button, resize from a corner; in Free mode the ghost can be
--     dragged on its own. Escape or right-click locks it. Optional snapping to
--     the screen edges with a margin. "Bottom-left" puts it flush bottom-left.
--   * While Blizzard's Edit Mode is open the same ghost follows the chat, so the
--     chat box's place is visible there too.
--   * Edit Mode owns ChatFrame1 until the chat is placed here. From then on the
--     saved rectangle (per profile) is put back after Edit Mode applies its
--     layout; a move or resize made in Edit Mode is taken over as the new
--     placement. "Give the chat back to Edit Mode" ends it.
--
-- How it stays out of Blizzard's way: ChatFrame1 is not protected; it is only
-- moved with SetPoint/SetSize. Edit Mode is watched with HookScript and
-- hooksecurefunc only; nothing of Edit Mode is called or written. No
-- UIPanelWindows, ShowUIPanel, HideUIPanel or UISpecialFrames: Escape is the
-- overlay's own key handler (EverlookUI's CloseOnEscape), which leaves the
-- keyboard alone in combat.
---------------------------------------------------------------------------------

EverlookDBChat:AddModuleToLoad(function()
	local module = EverlookDBChat:NewModule("Placement", "AceHook-3.0")
	local PL = module.PL
	local P = EverlookDBChat.Placement
	local UI = LibStub("EverlookUI-1")
	local U, T = UI.Util, UI.Theme

	local issecret = issecretvalue or function()
		return false
	end

	EverlookDBChat:SetModuleDefaults(module.name, {
		profile = {
			on = true,
			managed = false, -- true once the chat is placed here
			rect = nil,      -- { l, b, w, h } of ChatFrame1, UIParent units from the bottom-left
			snap = true,
			margin = P.MARGIN,
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
			status = {
				name = function()
					return module:StatusText()
				end,
				type = "description",
				order = 2,
			},
			move = {
				name = PL["move_name"],
				desc = PL["move_desc"],
				type = "execute",
				order = 3,
				func = function()
					module:SetUnlocked(true)
				end,
			},
			preset = {
				name = PL["preset_name"],
				desc = PL["preset_desc"],
				type = "execute",
				order = 4,
				func = function()
					module:BottomLeft()
				end,
			},
			snap = {
				name = PL["snap_name"],
				desc = PL["snap_desc"],
				type = "toggle",
				order = 5,
				width = "full",
			},
			margin = {
				name = PL["margin_name"],
				desc = PL["margin_desc"],
				type = "range",
				order = 6,
				min = 0,
				max = 40,
				step = 1,
			},
			release = {
				name = PL["release_name"],
				desc = PL["release_desc"],
				type = "execute",
				order = 7,
				disabled = function()
					return not module.db.profile.managed
				end,
				func = function()
					module:Release()
				end,
			},
		}
	})

	------------------------------------------------------------------------
	-- Geometry
	------------------------------------------------------------------------

	local function num(v)
		if type(v) == "number" and not issecret(v) then
			return v
		end
		return nil
	end

	local function chatFrame()
		return ChatFrame1
	end

	-- ChatFrame1's rectangle and the screen, in ChatFrame1's units.
	local function readChat()
		local cf = chatFrame()
		if not cf then
			return nil
		end
		local l, b, w, h = num(cf:GetLeft()), num(cf:GetBottom()), num(cf:GetWidth()), num(cf:GetHeight())
		local fs, us = num(cf:GetEffectiveScale()), num(UIParent:GetEffectiveScale())
		local sw, sh = num(UIParent:GetWidth()), num(UIParent:GetHeight())
		if not (l and b and w and h and fs and us and sw and sh) or fs <= 0 or w <= 0 then
			return nil
		end
		local k = us / fs
		return { l = l, b = b, w = w, h = h }, { w = sw * k, h = sh * k }, fs
	end
	module.ReadChat = readChat

	local function cursor()
		local x, y = GetCursorPosition()
		local cf = chatFrame()
		local s = cf and num(cf:GetEffectiveScale()) or 1
		return x / s, y / s
	end

	local function editbox()
		local m = EverlookDBChat.Addon and EverlookDBChat.Addon:GetModule("Editbox", true)
		if m and m:IsEnabled() then
			return m
		end
	end

	-- The chat box settings (Blizzard's own place below the chat when the Chat box module is off).
	local function ebConfig()
		local m = editbox()
		if m then
			return m:GetConfig()
		end
		return { mode = "BELOW", height = 32, tabHeight = P.TAB_HEIGHT }
	end

	local function snapOptions()
		local p = module.db.profile
		if not p.snap then
			return nil
		end
		local cfg = ebConfig()
		return { margin = p.margin, reserve = P.ReserveBelow(cfg.mode, cfg.height), dist = P.SNAP }
	end

	local function inEditMode()
		return EditModeManagerFrame and EditModeManagerFrame:IsShown() and true or false
	end

	------------------------------------------------------------------------
	-- Putting the chat somewhere
	------------------------------------------------------------------------

	local applying = false
	local editTouched = false -- the chat was moved or resized in Edit Mode; taken over when it closes
	function module:Apply(r)
		local cf = chatFrame()
		if not cf or not r then
			return
		end
		applying = true
		cf:ClearAllPoints()
		cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", r.l, r.b)
		cf:SetSize(r.w, r.h)
		applying = false
		local m = editbox()
		if m then
			m:SetAttach()
		end
	end

	-- Our placement, after Blizzard has put the chat where Edit Mode says (login, layout change, scale change).
	local pending = false
	function module:Reapply()
		if pending then
			return
		end
		pending = true
		C_Timer.After(0, function()
			pending = false
			module.state.db = module.db.profile
			if not module:IsEnabled() or inEditMode() or module:IsUnlocked() or editTouched then
				return
			end
			local want = module.state:Wanted()
			local now = readChat()
			if want and not P.Same(want, now) then
				module:Apply(want)
			end
		end)
	end

	------------------------------------------------------------------------
	-- The ghost chat box (placement mode and Edit Mode)
	------------------------------------------------------------------------

	local ghost
	local function makeGhost()
		if ghost then
			return ghost
		end
		local g = CreateFrame("Frame", "EverlookDBChatGhostEditBox", UIParent)
		g:SetFrameStrata("DIALOG")
		g:SetFrameLevel(50)
		g:SetClampedToScreen(true)
		g.bg = U.Solid(g, "BACKGROUND", 0.055, 0.060, 0.074, 0.92)
		g.bg:SetAllPoints()
		g.border = U.Border(g, 1, T.accent[1], T.accent[2], T.accent[3], 0.9)
		g.label = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		g.label:SetPoint("LEFT", 8, 0)
		g.label:SetTextColor(T.text[1], T.text[2], T.text[3])
		g.side = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		g.side:SetPoint("RIGHT", -8, 0)
		g.side:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
		g:Hide()

		-- Free mode: the ghost is dragged on its own.
		g:SetScript("OnMouseDown", function(self, button)
			if button ~= "LeftButton" or not module:IsUnlocked() then
				return
			end
			local cx, cy = cursor()
			self.drag = { x = cx, y = cy, r = self.rect }
		end)
		g:SetScript("OnMouseUp", function(self, button)
			if button == "RightButton" then
				module:SetUnlocked(false)
				return
			end
			if self.drag then
				self.drag = nil
				local r = self.rect
				local m = editbox()
				if m and r then
					m:SetFree(P.Round(r.l), P.Round(r.b + r.h), P.Round(r.w))
				end
			end
		end)
		ghost = g
		return g
	end

	local SIDE_TEXT = { below = "below", above = "above (no room below)", inside = "inside", free = "free" }

	-- Where the ghost goes now: following the chat, or under the mouse while it is dragged.
	local function updateGhost()
		local g = ghost
		if not g or not g:IsShown() then
			return
		end
		local chat, screen, fs = readChat()
		if not chat then
			return
		end
		local cfg = ebConfig()
		local r, side
		if g.drag and g.drag.r then
			local cx, cy = cursor()
			r = P.ClampToScreen({ l = g.drag.r.l + cx - g.drag.x, b = g.drag.r.b + cy - g.drag.y, w = g.drag.r.w, h = g.drag.r.h }, screen)
			side = "free"
		else
			r, side = P.EditBoxRect(cfg.mode, chat, screen, cfg)
		end
		g.rect = r
		-- the ghost lives on UIParent; drawn at the chat's scale so the units match
		local us = num(UIParent:GetEffectiveScale()) or 1
		g:SetScale(fs / us)
		g:ClearAllPoints()
		g:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", r.l, r.b)
		g:SetSize(r.w, r.h)
		local free = cfg.mode == "FREE"
		g.label:SetText(free and module:IsUnlocked() and PL["ghost_free"] or PL["ghost"])
		g.side:SetText(SIDE_TEXT[side] or "")
		g:EnableMouse(free and module:IsUnlocked())
	end

	local ghostReasons = {}
	local ghostDriver
	local function setGhost(reason, on)
		ghostReasons[reason] = on or nil
		local g = makeGhost()
		if next(ghostReasons) then
			if not ghostDriver then
				ghostDriver = CreateFrame("Frame")
				local since = 0
				ghostDriver:SetScript("OnUpdate", function(_, elapsed)
					since = since + elapsed
					if since >= 0.02 then
						since = 0
						updateGhost()
					end
				end)
			end
			ghostDriver:Show()
			g:Show()
			updateGhost()
		else
			g.drag = nil
			g:Hide()
			if ghostDriver then
				ghostDriver:Hide()
			end
		end
	end

	------------------------------------------------------------------------
	-- Placement mode: outline, handles, toolbar
	------------------------------------------------------------------------

	local overlay
	local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

	local function updateSizeText()
		if overlay and overlay:IsShown() then
			local r = readChat()
			if r then
				overlay.size:SetFormattedText("%d x %d", P.Round(r.w), P.Round(r.h))
			end
		end
	end

	local function startDrag(kind, corner)
		local r, screen = readChat()
		if not r then
			return
		end
		local cx, cy = cursor()
		overlay.drag = { kind = kind, corner = corner, x = cx, y = cy, r = r, screen = screen }
	end

	local function dragTick()
		local d = overlay.drag
		if not d then
			return
		end
		local cx, cy = cursor()
		local dx, dy = cx - d.x, cy - d.y
		local r
		if d.kind == "move" then
			r = P.Drag(d.r, dx, dy, d.screen, snapOptions())
		else
			r = P.Resize(d.r, d.corner, dx, dy, d.screen, snapOptions())
		end
		module.moved = true
		module:Apply(r)
		updateSizeText()
	end

	local function makeOverlay()
		if overlay then
			return overlay
		end
		local o = CreateFrame("Frame", "EverlookDBChatPlacementOverlay", UIParent)
		o.eluiTheme = T
		o:SetFrameStrata("DIALOG")
		o:SetFrameLevel(40)
		o:EnableMouse(true)
		o.fill = U.Solid(o, "BACKGROUND", T.accent[1], T.accent[2], T.accent[3], 0.08)
		o.fill:SetAllPoints()
		o.border = U.Border(o, 1, T.accent[1], T.accent[2], T.accent[3], 1)

		o.hint = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		o.hint:SetPoint("TOP", 0, -8)
		o.hint:SetText(PL["hint"])
		o.size = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		o.size:SetPoint("BOTTOMRIGHT", -16, 6)
		o.size:SetTextColor(T.muted[1], T.muted[2], T.muted[3])

		o.handles = {}
		for _, corner in ipairs(CORNERS) do
			local h = CreateFrame("Frame", nil, o)
			h:SetSize(12, 12)
			h:SetPoint(corner, o, corner)
			h:SetFrameLevel(o:GetFrameLevel() + 5)
			h:EnableMouse(true)
			h.tex = U.Solid(h, "OVERLAY", T.accent[1], T.accent[2], T.accent[3], 1)
			h.tex:SetAllPoints()
			h:SetScript("OnMouseDown", function(_, button)
				if button == "LeftButton" then
					startDrag("size", corner)
				end
			end)
			h:SetScript("OnMouseUp", function(_, button)
				if button == "RightButton" then
					module:SetUnlocked(false)
				end
				o.drag = nil
			end)
			h:SetScript("OnEnter", function(self)
				self.tex:SetVertexColor(1, 1, 1, 1)
			end)
			h:SetScript("OnLeave", function(self)
				self.tex:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
			end)
			o.handles[corner] = h
		end

		o:SetScript("OnMouseDown", function(_, button)
			if button == "LeftButton" then
				startDrag("move")
			end
		end)
		o:SetScript("OnMouseUp", function(self, button)
			self.drag = nil
			if button == "RightButton" then
				module:SetUnlocked(false)
			end
		end)
		o:SetScript("OnUpdate", function()
			dragTick()
		end)

		-- Toolbar above the chat: Bottom-left, Snap, and Lock (the one primary button).
		local bar = CreateFrame("Frame", nil, o)
		bar.eluiTheme = T
		bar:SetSize(300, 34)
		bar:SetClampedToScreen(true)
		bar:SetPoint("BOTTOMLEFT", o, "TOPLEFT", 0, P.TAB_HEIGHT + 6)
		bar.bg = U.Solid(bar, "BACKGROUND", T.bg[1], T.bg[2], T.bg[3], T.bg[4])
		bar.bg:SetAllPoints()
		bar.accent = U.Solid(bar, "BORDER", T.accent[1], T.accent[2], T.accent[3], 1)
		bar.accent:SetPoint("TOPLEFT")
		bar.accent:SetPoint("TOPRIGHT")
		bar.accent:SetHeight(1)
		bar.border = U.Border(bar, 1, T.border[1], T.border[2], T.border[3], 1)
		bar.preset = UI.Button(bar, PL["preset_name"], function()
			module:BottomLeft()
		end, 96)
		bar.preset:SetPoint("LEFT", 4, 0)
		bar.snap = UI.Button(bar, "", function()
			module.db.profile.snap = not module.db.profile.snap
			module:UpdateToolbar()
		end, 96)
		bar.snap:SetPoint("LEFT", bar.preset, "RIGHT", 4, 0)
		bar.lock = UI.Button(bar, PL["lock"], function()
			module:SetUnlocked(false)
		end, 88, "accent")
		bar.lock:SetPoint("LEFT", bar.snap, "RIGHT", 4, 0)
		o.bar = bar

		o:Hide()
		-- Escape locks (the overlay's own key handler; leaves the keyboard alone in combat).
		UI.CloseOnEscape(o)
		o:HookScript("OnHide", function(self)
			self.drag = nil
			if module:IsUnlocked() then
				module:SetUnlocked(false)
			end
		end)
		overlay = o
		return o
	end

	function module:UpdateToolbar()
		if overlay then
			overlay.bar.snap:SetText(self.db.profile.snap and PL["snap_on"] or PL["snap_off"])
		end
	end

	local function showOverlay()
		local o = makeOverlay()
		local cf = chatFrame()
		o:ClearAllPoints()
		o:SetAllPoints(cf)
		module.moved = false
		module:UpdateToolbar()
		o:Show()
		updateSizeText()
		setGhost("placement", true)
	end

	local function hideOverlay()
		if overlay and overlay:IsShown() then
			overlay:Hide()
		end
		setGhost("placement", false)
	end

	------------------------------------------------------------------------
	-- Lock state (addon/placement.lua)
	------------------------------------------------------------------------

	module.state = P.NewState({}, {
		show = showOverlay,
		hide = hideOverlay,
		read = function()
			if module.moved then
				return readChat()
			end
		end,
	})

	local function bindState()
		module.state.db = module.db.profile
	end

	function module:IsUnlocked()
		return not self.state:IsLocked()
	end

	function module:SetUnlocked(on)
		bindState()
		if on then
			if not self:IsEnabled() or not chatFrame() then
				return
			end
			if inEditMode() then
				EverlookDBChat.app:Print(PL["editmode_open"]) -- Edit Mode has the chat now; the ghost shows there
				return
			end
			if self.state:Unlock() then
				EverlookDBChat.app:Print(PL["hint"])
			end
		else
			if self.state:Lock() then
				local m = editbox()
				if m then
					m:SetAttach()
				end
			end
		end
	end

	function module:BottomLeft()
		bindState()
		local _, screen = readChat()
		if not screen then
			return
		end
		local cfg = ebConfig()
		local r = P.Preset(screen, cfg.height, self.db.profile.margin)
		self.moved = true
		self:Apply(r)
		updateSizeText()
		if self.state:IsLocked() then
			self.state:Save(r)
		end
	end

	function module:Release()
		bindState()
		self.state:Release()
		self.db.profile.rect = nil
	end

	function module:StatusText()
		local r = self.db.profile.managed and self.db.profile.rect
		if r and r.w then
			return PL["status_ours"]:format(r.w, r.h, r.l, r.b)
		end
		return PL["status_editmode"]
	end

	------------------------------------------------------------------------
	-- Edit Mode: show the ghost while it is open; take over what it changes
	------------------------------------------------------------------------

	local function onEditModeShow()
		if not module:IsEnabled() then
			return
		end
		if module:IsUnlocked() then
			module:SetUnlocked(false)
		end
		editTouched = false
		setGhost("editmode", true)
	end

	local function onEditModeHide()
		setGhost("editmode", false)
		if not module:IsEnabled() then
			return
		end
		C_Timer.After(0, function()
			bindState()
			local touched = editTouched
			editTouched = false
			if not module.db.profile.managed then
				return
			end
			if touched then
				local r = readChat()
				if r then
					module.state:Save(r) -- moved or resized in Edit Mode: that is the placement now
				end
			else
				module:Reapply()
			end
		end)
	end

	local hooked = false
	local function hookBlizzard()
		if hooked then
			return
		end
		local cf = chatFrame()
		if not cf then
			return
		end
		hooked = true
		if EditModeManagerFrame then
			EditModeManagerFrame:HookScript("OnShow", onEditModeShow)
			EditModeManagerFrame:HookScript("OnHide", onEditModeHide)
		end
		local function touched()
			if inEditMode() and not applying then
				editTouched = true
			end
		end
		-- Edit Mode drags the chat with StartMoving/StopMovingOrSizing, sizes it with SetSize and puts its
		-- saved layout back with ApplySystemAnchor.
		hooksecurefunc(cf, "StopMovingOrSizing", touched)
		cf:HookScript("OnSizeChanged", touched)
		if cf.ResetToDefaultPosition then
			hooksecurefunc(cf, "ResetToDefaultPosition", touched)
		end
		for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystem" }) do
			if type(cf[method]) == "function" then
				hooksecurefunc(cf, method, function()
					module:Reapply()
				end)
			end
		end
	end

	local events
	function module:OnModuleEnable()
		bindState()
		hookBlizzard()
		if not events then
			events = CreateFrame("Frame")
			for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
				pcall(events.RegisterEvent, events, e)
			end
		end
		events:SetScript("OnEvent", function()
			module:Reapply()
		end)
		self:Reapply()
	end

	function module:OnModuleDisable()
		if self:IsUnlocked() then
			self:SetUnlocked(false)
		end
		setGhost("editmode", false)
		if events then
			events:SetScript("OnEvent", nil)
		end
	end

	function module:GetDescription()
		return PL["module_desc"]
	end
end)
