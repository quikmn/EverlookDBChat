---------------------------------------------------------------------------------
--
-- EverlookDB Chat, a modified version of Prat-3.0 (GPL-3.0).
-- This file is new in EverlookDB Chat. License: GPL-3.0, see LICENSE.txt.
--
-- Shared helpers for the modules that fade parts of the chat (Idle fade, Calm):
--
--   * an alpha engine: each managed frame shows at "the alpha its owner wants"
--     x the fade factors that apply to it. Factors: "idle" (the whole chat) and
--     "chrome" (tabs, button bar, buttons). Only SetAlpha is used, on plain
--     (unprotected) frames, so it is combat-safe and replaces nothing of Blizzard's.
--     Blizzard's FCF code and UIFrameFade keep setting tab and frame alphas; a
--     post-hook on SetAlpha remembers their value and puts the faded one back,
--     so the fade wins while it lasts and Blizzard's value returns after;
--   * "is the chat in use" checks: mouse over a chat window, keyboard focus in a
--     chat edit box (or a box inside the chat, like the search box), scrolled up.
--   * holds: a module can keep the chat awake (an unread whisper).
---------------------------------------------------------------------------------

local _, private = ...

local issecretvalue = issecretvalue or function()
	return false
end

local ChatUI = {}
private.ChatUI = ChatUI

local FADE_TIMES = {
	idle = { out = 1.0, ["in"] = 0.2 },
	chrome = { out = 0.3, ["in"] = 0.15 },
}

-- Frames outside the chat frames that belong to the chat's chrome. Absent ones
-- are skipped.
local LOOSE_CHROME = {
	"GeneralDockManager",
	"GeneralDockManagerOverflowButton",
	"ChatFrameMenuButton",
	"ChatFrameChannelButton",
	"ChatFrameToggleVoiceDeafenButton",
	"ChatFrameToggleVoiceMuteButton",
	"QuickJoinToastButton",
	"TextToSpeechButtonFrame",
	"CombatLogQuickButtonFrame_Custom",
}

-- Per chat frame: name suffixes of this addon's own buttons and boxes (chrome).
local OWN_CHROME_SUFFIXES = {
	"ChatSearchEditBox",
	"EverlookDBChatCCReminder",
	"ScrollDownReminder",
}

local factors = { idle = 1, chrome = 1 }
local targets = { idle = 1, chrome = 1 }
local managed = {} -- [frame] = the alpha its owner wants
local chrome = {} -- [frame] = true for chrome frames
local applied = {} -- [frame] = true while it carries a faded alpha
local hooked = {}
local holds = {}
local applying = false
local users = 0
local driver

local function hasAncestor(frame, set)
	local parent = frame:GetParent()
	while parent do
		if set[parent] then
			return true
		end
		parent = parent:GetParent()
	end
	return false
end

-- The fade this frame must carry itself (the rest comes from its parents).
local function frameFactor(frame)
	local f = 1
	if not hasAncestor(frame, managed) then
		f = f * factors.idle
	end
	if chrome[frame] and not hasAncestor(frame, chrome) then
		f = f * factors.chrome
	end
	return f
end

local function setAlpha(frame, alpha)
	applying = true
	frame:SetAlpha(alpha)
	applying = false
end

local function onSetAlpha(frame, alpha)
	if applying or managed[frame] == nil or type(alpha) ~= "number" or issecretvalue(alpha) then
		return
	end
	managed[frame] = alpha
	local f = frameFactor(frame)
	if f < 1 then
		setAlpha(frame, alpha * f)
		applied[frame] = true
	else
		applied[frame] = nil
	end
end

local function manage(frame, isChrome)
	if not frame or type(frame.SetAlpha) ~= "function" then
		return
	end
	if managed[frame] == nil then
		managed[frame] = frame:GetAlpha()
	end
	if isChrome then
		chrome[frame] = true
	end
	if not hooked[frame] then
		hooked[frame] = true
		hooksecurefunc(frame, "SetAlpha", onSetAlpha)
	end
end

function ChatUI:Apply()
	for frame, base in pairs(managed) do
		local f = frameFactor(frame)
		if f < 1 then
			setAlpha(frame, base * f)
			applied[frame] = true
		elseif applied[frame] then
			setAlpha(frame, base)
			applied[frame] = nil
		end
	end
end

function ChatUI:Collect()
	for _, name in ipairs(CHAT_FRAMES or {}) do
		local cf = _G[name]
		if cf then
			manage(cf, false)
			manage(cf.buttonFrame or _G[name .. "ButtonFrame"], true)
			manage(_G[name .. "Tab"], true)
			for _, suffix in ipairs(OWN_CHROME_SUFFIXES) do
				manage(_G[name .. suffix], true)
			end
		end
	end
	for _, name in ipairs(LOOSE_CHROME) do
		manage(_G[name], true)
	end
end

-- The chat windows that are on screen.
function ChatUI:IterateShownChatFrames()
	local list = {}
	for _, name in ipairs(CHAT_FRAMES or {}) do
		local cf = _G[name]
		if cf and cf:IsShown() then
			list[#list + 1] = cf
		end
	end
	return ipairs(list)
end

-- The mouse is over a chat window (with its tabs above and button bar to the
-- left), or over one of the managed chat buttons. Works while faded out.
function ChatUI:IsMouseOverChat()
	for _, name in ipairs(CHAT_FRAMES or {}) do
		local cf = _G[name]
		if cf and cf:IsShown() and cf:IsMouseOver(32, -10, -40, 10) then
			return true, cf
		end
	end
	for frame in pairs(managed) do
		if frame:IsShown() and frame:IsMouseOver() then
			return true
		end
	end
	return false
end

-- Keyboard focus is in a chat edit box, or in a box inside the chat.
function ChatUI:IsChatFocus()
	local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if not focus then
		return false
	end
	if focus.chatFrame or managed[focus] ~= nil then
		return true
	end
	return hasAncestor(focus, managed)
end

function ChatUI:IsScrolledUp()
	for _, cf in self:IterateShownChatFrames() do
		if cf.GetScrollOffset then
			local offset = cf:GetScrollOffset()
			if type(offset) == "number" and not issecretvalue(offset) and offset > 0 then
				return true
			end
		end
	end
	return false
end

function ChatUI:Hold(key, on)
	holds[key] = on and true or nil
end

function ChatUI:IsHeld()
	return next(holds) ~= nil
end

function ChatUI:SetTarget(kind, target)
	targets[kind] = target
end

function ChatUI:GetFactor(kind)
	return factors[kind]
end

local sinceCollect = 0
local function onUpdate(_, elapsed)
	sinceCollect = sinceCollect + elapsed
	if sinceCollect >= 2 then
		sinceCollect = 0
		ChatUI:Collect()
	end
	local changed = false
	for kind, target in pairs(targets) do
		local f = factors[kind]
		if f ~= target then
			local times = FADE_TIMES[kind]
			if target > f then
				f = math.min(target, f + elapsed / times["in"])
			else
				f = math.max(target, f - elapsed / times.out)
			end
			factors[kind] = f
			changed = true
		end
	end
	if changed then
		ChatUI:Apply()
	end
end

-- A module starts or stops using the engine. When the last one stops, every
-- frame gets its own alpha back.
function ChatUI:AddUser()
	users = users + 1
	if not driver then
		driver = CreateFrame("Frame")
	end
	self:Collect()
	if FCF_OpenTemporaryWindow and not self.hookedTemporary then
		self.hookedTemporary = true
		hooksecurefunc("FCF_OpenTemporaryWindow", function()
			if users > 0 then
				ChatUI:Collect()
			end
		end)
	end
	driver:SetScript("OnUpdate", onUpdate)
end

function ChatUI:RemoveUser(kind)
	users = math.max(0, users - 1)
	if kind then
		factors[kind], targets[kind] = 1, 1
	end
	self:Apply()
	if users == 0 then
		for k in pairs(factors) do
			factors[k], targets[k] = 1, 1
		end
		self:Apply()
		wipe(managed)
		wipe(chrome)
		wipe(applied)
		if driver then
			driver:SetScript("OnUpdate", nil)
		end
	end
end
