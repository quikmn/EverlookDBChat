-- Chat placement maths, kept free of frames so tests/run.lua can check it offline.
-- Every rectangle is { l = left, b = bottom, w = width, h = height } in UIParent units, from the screen's
-- bottom-left corner, the way GetLeft/GetBottom report it. The screen is { w = UIParent width, h = height }.
local _, private = ...

local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local P = {}
private.Placement = P

P.GAP = 2          -- between the chat and the edit box
P.TAB_HEIGHT = 24  -- room left for the chat tabs above the chat frame
P.MARGIN = 8       -- default distance from the screen edges
P.SNAP = 12        -- how close to an edge (or the margin line) a drag snaps
P.MIN_W, P.MIN_H = 200, 60

-- Edit box modes, in the order the settings list them.
P.MODES = { "BELOW", "ABOVE", "INSIDE", "FREE" }
-- Older saved values (Prat's "attach to") and what they mean now.
P.OLD_MODES = { BOTTOM = "BELOW", TOP = "ABOVE", LOCK = "FREE", FREE = "FREE" }

function P.NormalizeMode(mode)
	if mode == "BELOW" or mode == "ABOVE" or mode == "INSIDE" or mode == "FREE" then return mode end
	return P.OLD_MODES[mode] or "BELOW"
end

local function round(v) return floor(v + 0.5) end
P.Round = round

local function clamp(v, lo, hi)
	if hi < lo then return lo end
	return min(max(v, lo), hi)
end
P.Clamp = clamp

local function top(r) return r.b + r.h end

-- Keep a rectangle fully on screen (moves it, never resizes it unless it is bigger than the screen).
function P.ClampToScreen(r, screen)
	local w, h = min(r.w, screen.w), min(r.h, screen.h)
	return { l = clamp(r.l, 0, screen.w - w), b = clamp(r.b, 0, screen.h - h), w = w, h = h }
end

-- Where the edit box goes for a chat frame.
-- mode: BELOW ("below, or above when there's no room"), ABOVE (above the tabs; below when there's no room),
-- INSIDE (inside the chat, at its bottom; the chat lines move up by `lift` while it shows), FREE (free.l/top/w).
-- opts: { height, gap, tabHeight, free = { l, top, w } }.
-- Returns the rectangle, the side it ended up on ("below", "above", "inside", "free") and the lift for INSIDE.
function P.EditBoxRect(mode, chat, screen, opts)
	opts = opts or {}
	mode = P.NormalizeMode(mode)
	local h = opts.height or 22
	local gap = opts.gap or P.GAP
	local tabH = opts.tabHeight or P.TAB_HEIGHT
	local r = { l = chat.l, w = chat.w, h = h }
	local side, lift = mode:lower(), 0

	local belowB = chat.b - gap - h
	local aboveB = top(chat) + tabH + gap
	if mode == "BELOW" then
		if belowB >= 0 then r.b = belowB else r.b, side = aboveB, "above" end
	elseif mode == "ABOVE" then
		if aboveB + h <= screen.h then r.b = aboveB else r.b, side = belowB, "below" end
	elseif mode == "INSIDE" then
		r.b = chat.b
		lift = h + gap
	else -- FREE
		local f = opts.free
		if f and f.l and f.top then
			r.l, r.w, r.b = f.l, (f.w and f.w >= 40) and f.w or chat.w, f.top - h
		else
			r.b = belowB >= 0 and belowB or aboveB
		end
	end
	return P.ClampToScreen(r, screen), side, lift
end

-- The edit box's offset from the chat frame's bottom-left corner, for SetPoint("BOTTOMLEFT", chat, "BOTTOMLEFT", x, y).
function P.Offset(eb, chat)
	return eb.l - chat.l, eb.b - chat.b
end

-- The "Bottom-left" preset: a sensible size for the screen, flush left with a small margin, and room for the
-- edit box under it inside the screen.
function P.Preset(screen, ebHeight, margin)
	margin = margin or P.MARGIN
	ebHeight = ebHeight or 22
	local w = clamp(round(screen.w * 0.32), 340, 520)
	local h = clamp(round(screen.h * 0.24), 120, 220)
	w = min(w, screen.w - 2 * margin)
	return { l = margin, b = margin + ebHeight + P.GAP, w = w, h = h }
end

-- Room the edit box takes under the chat when it sits below (0 otherwise): the chat snaps so that the box
-- still fits on screen.
function P.ReserveBelow(mode, ebHeight)
	if P.NormalizeMode(mode) == "BELOW" then return (ebHeight or 22) + P.GAP end
	return 0
end

-- One axis: snap `v` (the low edge, size `size`) to the low edge plus margin (`lo`) or the high edge minus margin.
local function snapAxis(v, size, lo, hi, dist)
	if abs(v - lo) <= dist then return lo end
	if abs(v + size - hi) <= dist then return hi - size end
	return v
end

-- Snap a chat rectangle to the screen edges (keeping `margin`), with `reserve` extra room at the bottom for an
-- edit box below it. dist: how close counts. Also keeps the rectangle (and the reserve) on screen.
function P.Snap(r, screen, margin, reserve, dist)
	margin, reserve, dist = margin or P.MARGIN, reserve or 0, dist or P.SNAP
	local out = { l = r.l, b = r.b, w = r.w, h = r.h }
	out.l = snapAxis(out.l, out.w, margin, screen.w - margin, dist)
	out.b = snapAxis(out.b, out.h, margin + reserve, screen.h - margin - P.TAB_HEIGHT, dist)
	return out
end

-- A drag: the chat moves by (dx, dy) from where it started, stays on screen, and snaps if asked.
function P.Drag(start, dx, dy, screen, snap)
	local r = { l = start.l + dx, b = start.b + dy, w = start.w, h = start.h }
	if snap then r = P.Snap(r, screen, snap.margin, snap.reserve, snap.dist) end
	return P.ClampToScreen(r, screen)
end

-- A resize from one corner ("TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"): the opposite corner stays put.
function P.Resize(start, corner, dx, dy, screen, snap)
	local l, b, r, t = start.l, start.b, start.l + start.w, start.b + start.h
	if corner:find("LEFT") then l = min(l + dx, r - P.MIN_W) else r = max(r + dx, l + P.MIN_W) end
	if corner:find("BOTTOM") then b = min(b + dy, t - P.MIN_H) else t = max(t + dy, b + P.MIN_H) end
	l, b = max(l, 0), max(b, 0)
	r, t = min(r, screen.w), min(t, screen.h)
	if snap then
		local m, dist, reserve = snap.margin or P.MARGIN, snap.dist or P.SNAP, snap.reserve or 0
		if corner:find("LEFT") and abs(l - m) <= dist then l = m end
		if corner:find("RIGHT") and abs(r - (screen.w - m)) <= dist then r = screen.w - m end
		if corner:find("BOTTOM") and abs(b - (m + reserve)) <= dist then b = m + reserve end
		if corner:find("TOP") and abs(t - (screen.h - m - P.TAB_HEIGHT)) <= dist then t = screen.h - m - P.TAB_HEIGHT end
	end
	return { l = l, b = b, w = r - l, h = t - b }
end

-- Same place, give or take a pixel.
function P.Same(a, b)
	if not a or not b then return false end
	return abs(a.l - b.l) < 1 and abs(a.b - b.b) < 1 and abs(a.w - b.w) < 1 and abs(a.h - b.h) < 1
end

------------------------------------------------------------------------
-- Lock state: placement mode is "unlocked". Leaving it (Escape, right-click, /echat lock) saves the chat's
-- rectangle; from then on that rectangle is the chat's place ("managed") until it is handed back to Edit Mode.
------------------------------------------------------------------------
local State = {}
State.__index = State

-- db: the profile table ({ managed, rect = {l,b,w,h} }). hooks: { show(), hide(), read() -> rect, apply(rect) }.
function P.NewState(db, hooks)
	return setmetatable({ db = db, hooks = hooks or {}, unlocked = false }, State)
end

function State:IsLocked() return not self.unlocked end

function State:Unlock()
	if self.unlocked then return false end
	self.unlocked = true
	if self.hooks.show then self.hooks.show() end
	return true
end

function State:Lock()
	if not self.unlocked then return false end
	self.unlocked = false
	local r = self.hooks.read and self.hooks.read()
	if r then self:Save(r) end
	if self.hooks.hide then self.hooks.hide() end
	return true
end

function State:SetLocked(locked)
	if locked then return self:Lock() end
	return self:Unlock()
end

function State:Toggle()
	if self.unlocked then self:Lock() else self:Unlock() end
	return not self.unlocked
end

function State:Save(r)
	self.db.rect = { l = round(r.l), b = round(r.b), w = round(r.w), h = round(r.h) }
	self.db.managed = true
end

-- The rectangle to put the chat at, or nil when Edit Mode keeps the chat.
function State:Wanted()
	if self.db.managed and self.db.rect and self.db.rect.w then return self.db.rect end
	return nil
end

function State:Release()
	self.db.managed = false
end

return P
