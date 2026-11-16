---------------------------------------------------------------------------------
--
-- Prat - A framework for World of Warcraft chat modification
-- and a collection of modules which utilize the framework
--
-- Copyright (C) 2006-2020  Prat Development Team
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

local _, private = ...

EverlookDBChat = private

--[[ BEGIN STANDARD HEADER ]] --

-- Imports
local LibStub = LibStub
local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local type = type
local EverlookDBChat = EverlookDBChat
local setmetatable, getmetatable = setmetatable, getmetatable
local strfind = strfind
local IsSecureCmd = IsSecureCmd
local wipe = table.wipe

local issecretvalue = issecretvalue or function() return false end

--[[ END STANDARD HEADER ]] --

EverlookDBChat.Version = "EverlookDB Chat v0.1.0"

local am = {}
local om = getmetatable(EverlookDBChat)
if om then
	for k, v in pairs(om) do
		am[k] = v
	end
end
am.__tostring = function()
	return "EverlookDB Chat"
end
setmetatable(EverlookDBChat, am)

EverlookDBChat.IsClassic = WOW_PROJECT_ID == (WOW_PROJECT_CLASSIC or 2)
EverlookDBChat.IsRetail = WOW_PROJECT_ID == (WOW_PROJECT_MAINLINE or 1)
EverlookDBChat.IsMop = WOW_PROJECT_ID == (WOW_PROJECT_MISTS_CLASSIC or 19)
EverlookDBChat.IsForever = WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)

EverlookDBChat.IsModernAPI = EverlookDBChat.IsRetail or EverlookDBChat.IsForever

EverlookDBChat.Frames = {
	["ChatFrame1"] = ChatFrame1,
	["ChatFrame2"] = ChatFrame2,
	["ChatFrame3"] = ChatFrame3,
	["ChatFrame4"] = ChatFrame4,
	["ChatFrame5"] = ChatFrame5,
	["ChatFrame6"] = ChatFrame6,
	["ChatFrame7"] = ChatFrame7,
	["ChatFrame8"] = ChatFrame8,
	["ChatFrame9"] = ChatFrame9,
	["ChatFrame10"] = ChatFrame10
}
EverlookDBChat.HookedFrames = {}
EverlookDBChat.ExternalFrames = {}

local builtinSounds = {
	["Bell"] = "Interface\\AddOns\\EverlookDBChat\\sounds\\Bell.ogg",
	["Chime"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\Chime.ogg",
	["Heart"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\Heart.ogg",
	["IM"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\IM.ogg",
	["Info"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\Info.ogg",
	["Kachink"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\Kachink.ogg",
	["popup"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\Link.ogg",
	["Text1"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\Text1.ogg",
	["Text2"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\Text2.ogg",
	["Xylo"] = "Interface\\AddOns\\EverlookDBChat\\Sounds\\Xylo.ogg",
}

-- Symbolic names for all the events which EverlookDBChat uses
EverlookDBChat.Events = {
	MODULE_ENABLED = "EverlookDBChat_ModuleCreated",
	DISABLED = "EverlookDBChat_Disabled",
	ENABLING = "EverlookDBChat_Starting",
	ENABLED = "EverlookDBChat_Ready",
	STARTUP = "EverlookDBChat_Initialized",
	DEBUG_UPDATE = "EverlookDBChat_DebugModeChanged",
	PRE_OUTBOUND = "EverlookDBChat_PreOutboundChat",
	OUTBOUND = "EverlookDBChat_OutboundChat",
	PRE_ADDMESSAGE = "EverlookDBChat_PreAddMessage",
	POST_ADDMESSAGE = "EverlookDBChat_PostAddMessage",
	POST_ADDMESSAGE_BLOCKED = "EverlookDBChat_PostAddMessageBlocked",
	FRAME_MESSAGE = "EverlookDBChat_FrameMessage",
	SECTIONS_UPDATED = "EverlookDBChat_ChatSectionsUpdated",
	FRAMES_UPDATED = "EverlookDBChat_FramesUpdated",
	FRAMES_REMOVED = "EverlookDBChat_FramesRemoved",
}

EverlookDBChat.EnableTasks = {}

local addon = LibStub("AceAddon-3.0"):NewAddon("EverlookDBChat", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0", "AceHook-3.0")
EverlookDBChat.Addon = addon

-- 2 = disabled, 3 = enabled
local defaults = {
	profile = {
		modules = {
			["Clear"] = 2,
			["AddonMsgs"] = 2,
			["CustomFilters"] = 2,
			["EventNames"] = 2,
			["Substitutions"] = 2,
			["Filtering"] = 2,
			["KeyBindings"] = 3,
			["ChatTabs"] = 2,
			["SideTabs"] = 2,
			["*"] = 3
		}
	},
	realm = {
		PlayerNameBlackList = {
			["you"] = true
		}
	}
}
local SOUND
function addon:OnInitialize()
	local IsAddOnLoaded = C_AddOns.IsAddOnLoaded or IsAddOnLoaded
	-- Prat-3.0 (which this addon is a modified version of) changes the same chat frames.
	if IsAddOnLoaded("Prat-3.0") then
		EverlookDBChat:Print("Prat-3.0 is also turned on. Both change your chat, so turn one of them off.")
	end

	EverlookDBChat.db = LibStub("AceDB-3.0"):New("EverlookDBChatDB", defaults, "Default")

	EverlookDBChatCharDB = EverlookDBChatCharDB or {}

	EverlookDBChat.PlayerNameBlackList = EverlookDBChat.db.realm.PlayerNameBlackList or {}

	EverlookDBChat.callbacks = LibStub("CallbackHandler-1.0"):New(EverlookDBChat, "RegisterChatEvent", "UnregisterChatEvent", "UnregisterAllChatEvents")

	EverlookDBChat.Options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(EverlookDBChat.db)
	EverlookDBChat.Options.args.profiles.order = tonumber(-1)

	EverlookDBChat.Media = LibStub("LibSharedMedia-3.0")
	SOUND = EverlookDBChat.Media.MediaType.SOUND

	for k, v in pairs(builtinSounds) do
		EverlookDBChat.Media:Register(SOUND, k, v)
	end

	EverlookDBChat.AddonName = self.baseName

	EverlookDBChat.builtinSounds = nil

	-- Build the list of frames which we should hook addmessage on
	for _, v in pairs(EverlookDBChat.Frames) do
		if (not IsCombatLog(v)) then
			EverlookDBChat.HookedFrames[v:GetName()] = v
		end
	end

	EverlookDBChat.db.RegisterCallback(self, "OnProfileChanged", "UpdateProfile")
	EverlookDBChat.db.RegisterCallback(self, "OnProfileCopied", "UpdateProfile")
	EverlookDBChat.db.RegisterCallback(self, "OnProfileReset", "UpdateProfile")

	EverlookDBChat:LoadModules()

	self.OnInitalize = nil
end

-- Used for EverlookDBChat/WIM integration
function EverlookDBChat.Format(smf, event, color, ...)
	local PRE_ADDMESSAGE = "EverlookDBChat_PreAddMessage"
	local POST_ADDMESSAGE = "EverlookDBChat_PostAddMessage"
	local FRAME_MESSAGE = "EverlookDBChat_FrameMessage"
	local this = smf
	local formattedText = ""
	local m, info = EverlookDBChat.SplitChatMessage(smf, event, ...)

	if type(m) == "boolean" and m == true then
		return ""
	end

	EverlookDBChat.CurrentMessage = m

	m.DONOTPROCESS = nil
	local process = EverlookDBChat.EventProcessingType.Full

	EverlookDBChat.callbacks:Fire(FRAME_MESSAGE, m, this, event)

	if not m.DONOTPROCESS then
		color = color or info
		local r, g, b, id = color.r or 1, color.g or 1, color.b or 1, 1

		-- Remove all the pattern matches ahead of time
		m.MESSAGE = EverlookDBChat:MatchPatterns(m)

		EverlookDBChat.callbacks:Fire(PRE_ADDMESSAGE, m, this, event, EverlookDBChat.BuildChatText(m), r, g, b, id)

		-- Pattern Matches Put Back IN
		m.MESSAGE = EverlookDBChat:ReplaceMatches(m)

		if process == EverlookDBChat.EventProcessingType.Full then
			-- We are about to send the message
			m.OUTPUT = EverlookDBChat.BuildChatText(m) -- Combine all the chat sections
		elseif process == EverlookDBChat.EventProcessingType.PatternsOnly then
			m.OUTPUT = (m.PRE or "") .. m.MESSAGE .. (m.POST or "")
		else
			if type(m.OUTPUT) == "string" then
				-- Now we have the chatstring that the client was planning to output
				-- For now just do it. (Tack on POST too)
				m.OUTPUT = (m.PRE or "") .. m.OUTPUT .. (m.POST or "")
			end
		end

		-- Allow for message blocking during the patern match phase
		if not m.DONOTPROCESS then
			formattedText = m.OUTPUT
		end

		-- We have called addmessage by now, or we have skipped it
		-- regardless, we call postaddmessage. This was changed to allow
		-- for more flexibility in the customfilters module, speficially
		-- it allows for replacements to occur in blocked messages

		EverlookDBChat.callbacks:Fire(POST_ADDMESSAGE, m, this, event, m.OUTPUT, r, g, b, id)
	end

	m.CAPTUREOUTPUT = nil
	m.OUTPUT = nil
	m.INFO = nil

	EverlookDBChat.CurrentMessage = nil

	return formattedText
end

function addon:OnEnable()
	for _, v in ipairs(EverlookDBChat.EnableTasks) do
		v(self)
	end
	EverlookDBChat.EnableTasks = nil

	EverlookDBChat.RegisterLinkType({
		linkid = "rldui",
		linkfunc = function()
			ReloadUI()
			return false
		end
	}, "EverlookDBChat")

	self:PostEnable()
end

function addon:UpdateProfile()
	self:ScheduleTimer("UpdateProfileDelayed", 0)
end

function addon:UpdateProfileDelayed()
	for _, v in self:IterateModules() do
		if v.db.profile.on then
			if v:IsEnabled() then
				v:Disable()
				v:Enable()
			else
				v:Enable()
			end
		else
			v:Disable()
		end
	end

	EverlookDBChat:UpdateOptions()
end

do
	local org_GetChannelName = GetChannelName
	local chanTable
	EverlookDBChat.EnableTasks[#EverlookDBChat.EnableTasks + 1] = function()
		chanTable = EverlookDBChat.GetChannelTable()
	end
	function EverlookDBChat.GetChannelName(n)
		local a, b, c = org_GetChannelName(n)

		if b == nil and chanTable then
			n = chanTable[n]

			if n ~= nil then
				a, b, c = org_GetChannelName(n)
			end
		end

		return a, b, c
	end
end

function addon:FCF_SetTemporaryWindowType(chatFrame, chatType, chatTarget)
	local name = chatFrame:GetName()

	EverlookDBChat.Frames[name] = chatFrame
	EverlookDBChat.HookedFrames[name] = chatFrame

	if ChatFrameMixin and ChatFrameMixin.MessageEventHandler then
		chatFrame.MessageEventHandler = function(frame, event, ...)
			return addon:ChatFrame_MessageEventHandler(frame, event, ...)
		end
	end

	EverlookDBChat.callbacks:Fire(EverlookDBChat.Events.FRAMES_UPDATED, name, chatFrame, chatType, chatTarget)
end

function addon:FCF_Close(frame)
	local name = frame:GetName()

	EverlookDBChat.Frames[name] = nil
	EverlookDBChat.HookedFrames[name] = nil
	if ChatFrameMixin and ChatFrameMixin.MessageEventHandler then
		frame.MessageEventHandler = ChatFrameMixin.MessageEventHandler
	end

	EverlookDBChat.callbacks:Fire(EverlookDBChat.Events.FRAMES_REMOVED, name, frame)
end

function addon:FCF_CopyChatSettings(chatFrame)
	if not chatFrame.isTemporary then
		local name = chatFrame:GetName()

		EverlookDBChat.Frames[name] = chatFrame

		if not IsCombatLog(chatFrame) then
			EverlookDBChat.HookedFrames[name] = chatFrame

			if ChatFrameMixin and ChatFrameMixin.MessageEventHandler then
				chatFrame.MessageEventHandler = function(frame, event, ...)
					return addon:ChatFrame_MessageEventHandler(frame, event, ...)
				end
			end
		end

		EverlookDBChat.callbacks:Fire(EverlookDBChat.Events.FRAMES_UPDATED, name, chatFrame)
	end
end

function addon:FloatingChatFrame_Update(id)
	local chatFrame = FCF_GetChatFrameByID(id)

	if not chatFrame.isTemporary then
		local name = chatFrame:GetName()

		EverlookDBChat.Frames[name] = chatFrame

		if not IsCombatLog(chatFrame) then
			EverlookDBChat.HookedFrames[name] = chatFrame

			if ChatFrameMixin and ChatFrameMixin.MessageEventHandler then
				chatFrame.MessageEventHandler = function(frame, event, ...)
					return addon:ChatFrame_MessageEventHandler(frame, event, ...)
				end
			end
		end

		EverlookDBChat.callbacks:Fire(EverlookDBChat.Events.FRAMES_UPDATED, name, chatFrame)
	end
end

function addon:PostEnable()
	EverlookDBChat.AddPrintMethods()

	-- TEMP: Gamepad hacks
	for _, v in pairs(EverlookDBChat.HookedFrames) do
		v.SetGamepadFocus = function() end
		v.ClearGamepadFocus = function() end
		v.HasGamepadFocus = function() return false end
		v.IsGamepadMenuOpen = function() return false end
		hooksecurefunc(_G[v:GetName() .. "EditBox"], 'ClearChat', function(editbox)
			if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then
				ChatFrameUtil.DeactivateChat(editbox)
			end
		end)
	end

	if EverlookDBChat.PrintSlashCommand then
		self:RegisterChatCommand("print", EverlookDBChat.PrintSlashCommand)
	end
	-- Inbound Hooking
	if ChatFrame_MessageEventHandler then
		self:RawHook("ChatFrame_MessageEventHandler", true)
	elseif ChatFrameMixin and ChatFrameMixin.MessageEventHandler then
		for _, v in pairs(EverlookDBChat.HookedFrames) do
			v.MessageEventHandler = function(frame, event, ...)
				return addon:ChatFrame_MessageEventHandler(frame, event, ...)
			end
		end
	end

	-- Outbound hooking
	if ChatFrame1EditBox and ChatFrame1EditBox.OnPreSendText then
		EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", function(_, editBox)
			local success, ret = pcall(function()
				addon:ChatEdit_ParseText(editBox)
			end)
			if not success then
				geterrorhandler()(ret)
			end
		end)
	else
		self:SecureHook("ChatEdit_ParseText")
	end

	-- Display Hooking
	EverlookDBChat.DummyFrame = CreateFrame("ScrollingMessageFrame")
	if Mixin and ChatFrameMixin then
		Mixin(EverlookDBChat.DummyFrame, ChatFrameMixin)
	end
	self:RawHook(EverlookDBChat.DummyFrame, "AddMessage", true)

	-- ItemRef Hooking
	self:RawHook(ItemRefTooltip, "SetHyperlink", true)
	self:SecureHook("FCF_SetTemporaryWindowType")
	self:SecureHook("FCF_Close")
	self:SecureHook("FCF_CopyChatSettings")
	self:SecureHook("FloatingChatFrame_Update")

	-- Combat hooking
	self:RegisterEvent("PLAYER_REGEN_ENABLED")

	-- This event fires after EverlookDBChat's hooks are installed
	-- EverlookDBChat's core wont operate until after this event
	EverlookDBChat.callbacks:Fire(EverlookDBChat.Events.SECTIONS_UPDATED)
	EverlookDBChat.callbacks:Fire(EverlookDBChat.Events.ENABLED)
end

function addon:PLAYER_REGEN_ENABLED()
	EverlookDBChat.RebuildChannelTable()
end

function addon:SetHyperlink(frame, ...)
	return EverlookDBChat.SetHyperlinkHook(self.hooks[frame], frame, ...)
end

function addon:ChatEdit_ParseText(editBox, send)
	local command = editBox:GetText()

	-- This is what blizzard does
	local cmd = command:match("^(#%s*[Ss][Hh][Oo][Ww]:*)%s[^%s]") or
		command:match("^(#%s*[Ss][Hh][Oo][Ww][Tt][Oo][Oo][Ll][Tt][Ii][Pp]:*)%s[^%s]") or
		command:match("^(/[^%s]+)");

	-- Hack from blizzard's code
	if (cmd and strfind(cmd, "^#")) then
		-- This is a hack, but the "USE" code below handles bags and slots
		cmd = SLASH_USE1;
	end

	if cmd and IsSecureCmd(cmd) then
		return
	end

	local m = EverlookDBChat.SplitMessageOut
	wipe(m)
	EverlookDBChat.CurrentMessage = m

	if issecretvalue(command) then
		m.MESSAGE = command
	else
		m.MESSAGE = command:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
	end

	m.CTYPE = editBox:GetAttribute("chatType")
	m.TARGET = editBox:GetAttribute("tellTarget")
	m.CHANNEL = editBox:GetAttribute("channelTarget")
	m.LANGUAGE = editBox.language
	m.SEND = send

	if send ~= 1 then
		return
	end

	self:ProcessUserEnteredChat(m)

	if EverlookDBChat.IsModernAPI and InCombatLockdown() then
		EverlookDBChat.CurrentMessage = nil
		return
	end

	editBox:SetAttribute("chatType", m.CTYPE)
	editBox:SetAttribute("tellTarget", m.TARGET)
	editBox:SetAttribute("channelTarget", m.CHANNEL)
	editBox.languague = m.LANGUAGE

	if m.DONOTPROCESS then
		editBox:SetText("")
	else
		editBox:SetText(m.MESSAGE)
	end

	EverlookDBChat.CurrentMessage = nil
end

function addon:ProcessUserEnteredChat(m)
	if m.MESSAGE:len() <= 0 then
		return
	end

	EverlookDBChat.callbacks:Fire(EverlookDBChat.Events.PRE_OUTBOUND, m)

	-- Remove all the pattern matches ahead of time
	m.MESSAGE = EverlookDBChat:MatchPatterns(m, "OUTBOUND")

	EverlookDBChat.callbacks:Fire(EverlookDBChat.Events.OUTBOUND, m)

	-- Pattern Matches Put Back IN
	m.MESSAGE = EverlookDBChat:ReplaceMatches(m, "OUTBOUND")
end

local fieldBlacklist = {
	historyBuffer = true,
	isLayoutDirty = true,
	isDisplayDirty = true,
	onDisplayRefreshedCallback = true,
	onScrollChangedCallback = true,
	onTextCopiedCallback = true,
	scrollOffset = true,
	visibleLines = true,
	highlightTexturePool = true,
	fontStringPool = true,
}
local savedFrame = {}
function EverlookDBChat.CreateProxy(frame)
	for k, v in pairs(frame) do
		if type(v) ~= "function" and not fieldBlacklist[k] then
			savedFrame[k] = EverlookDBChat.DummyFrame[k]
			EverlookDBChat.DummyFrame[k] = v
		end
	end
	EverlookDBChat.DummyFrame.IsShown = function()
		return true
	end
	return EverlookDBChat.DummyFrame
end

function EverlookDBChat.RestoreProxy()
	for k, v in pairs(savedFrame) do
		EverlookDBChat.DummyFrame[k] = v
	end
	for k, v in pairs(EverlookDBChat.DummyFrame) do
		if type(v) ~= "function" and not fieldBlacklist[k] then
			if savedFrame[k] == nil then
				EverlookDBChat.DummyFrame[k] = nil
			end
		end
	end
end

function addon:ChatFrame_MessageEventHandler(this, event, ...)
	local PRE_ADDMESSAGE = "EverlookDBChat_PreAddMessage"
	local POST_ADDMESSAGE = "EverlookDBChat_PostAddMessage"
	local FRAME_MESSAGE = "EverlookDBChat_FrameMessage"
	local POST_ADDMESSAGE_BLOCKED = "EverlookDBChat_PostAddMessageBlocked"

	local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18 = ...
	local isSecret = issecretvalue(arg1)

	EverlookDBChat.loading = nil -- clear any batch message loading that may be happening

	-- This is only ever called on classic
	if not EverlookDBChat.HookedFrames[this:GetName()] then
		if ChatFrame_MessageEventHandler then
			return self.hooks["ChatFrame_MessageEventHandler"](this, event, ...)
		else
			return ChatFrameMixin.MessageEventHandler(this, event, ...)
		end
	end

	local process = EverlookDBChat.EventIsProcessed(event)

	if not isSecret and type(arg1) == "string" and (arg1):find("\r") then
		-- Stupid exploit. Protect our users.
		arg1 = arg1:gsub("\r", " ")
	end

	-- Create a message table. This table contains the chat message in a non-concatenated form
	-- so that it can be modified easily without lots of complex gsub's
	local message, info = EverlookDBChat.SplitChatMessage(this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18)

	-- Handle Default-UI filtering: Since the default UI now provides filtering functions
	-- similar to the way EverlookDBChat's pattern registry works, we need to be sure not to call the
	-- filtering functions twice by calling back into the hook chain - otherwise you could
	-- have side effects of the handler functions being called more than once for a given event.
	-- I don't see any way around this.
	if type(message) == "boolean" and message == true then
		return true
	end

	if not isSecret and not info then
		if ChatFrame_MessageEventHandler then
			return self.hooks["ChatFrame_MessageEventHandler"](this, event, ...)
		else
			return ChatFrameMixin.MessageEventHandler(this, event, ...)
		end
	end

	local m = message --SplitMessage


	-- EverlookDBChat_FrameMessage is fired for every message going to the
	-- chatframe which is displayable (has a chat infotype)
	-- It may not be displayed, in which case no Pre/Post Addmessage
	-- events will fire
	-- Any addons which hook things will operate following this event
	-- but before EverlookDBChat_PreAddMessage, OUTPUT will contain the chat line
	-- it may be modified by other addons.
	--
	-- Right now, edbchat will discard the chat line for chat types that
	-- it is handling
	--
	m.OUTPUT = nil
	m.DONOTPROCESS = nil

	EverlookDBChat.callbacks:Fire(FRAME_MESSAGE, message, this, message.EVENT)

	-- A return value of true means that the message was processed
	-- normally this would result in the OnEvent returning
	-- for that chatframe
	local proxy = EverlookDBChat.CreateProxy(this)
	local CMEResult
	m.CAPTUREOUTPUT = proxy
	if isSecret or issecretvalue(this.chatTarget) then
		CMEResult = EverlookDBChat.MessageEventHandler(proxy, event, ...)
	elseif ChatFrame_MessageEventHandler then
		CMEResult = self.hooks["ChatFrame_MessageEventHandler"](proxy, event, ...)
	else
		CMEResult = ChatFrameMixin.MessageEventHandler(proxy, event, ...)
	end
	EverlookDBChat.RestoreProxy()

	m.CAPTUREOUTPUT = false

	if type(m.OUTPUT) == "string" and not m.DONOTPROCESS then
		EverlookDBChat.CurrentMessage = m
		local r, g, b, id = m.INFO.r, m.INFO.g, m.INFO.b, m.INFO.id

		if not isSecret and process == EverlookDBChat.EventProcessingType.Full or process == EverlookDBChat.EventProcessingType.PatternsOnly then
			-- Remove all the pattern matches ahead of time
			m.MESSAGE = EverlookDBChat:MatchPatterns(m, "FRAME")
		end

		EverlookDBChat.callbacks:Fire(PRE_ADDMESSAGE, message, this, message.EVENT, EverlookDBChat.BuildChatText(message), r, g, b, id)

		if not isSecret and process == EverlookDBChat.EventProcessingType.Full or process == EverlookDBChat.EventProcessingType.PatternsOnly then
			-- Pattern Matches Put Back IN
			m.MESSAGE = EverlookDBChat:ReplaceMatches(m, "FRAME")
		end

		if process == EverlookDBChat.EventProcessingType.Full then
			-- We are about to send the message
			m.OUTPUT = EverlookDBChat.BuildChatText(message) -- Combine all the chat sections
		elseif process == EverlookDBChat.EventProcessingType.PatternsOnly then
			m.OUTPUT = (m.PRE or "") .. m.MESSAGE .. (m.POST or "")
		else
			-- Now we have the chatstring that the client was planning to output
			-- For now just do it. (Tack on POST too)
			m.OUTPUT = (m.PRE or "") .. m.OUTPUT .. (m.POST or "")
		end

		-- Allow for message blocking during the patern match phase
		if m.DONOTPROCESS then
			EverlookDBChat.callbacks:Fire(POST_ADDMESSAGE_BLOCKED, m, this, message.EVENT, m.OUTPUT, r, g, b, id)
		elseif isSecret then
			this:AddMessage(m.OUTPUT, r, g, b, id, m.ACCESSID, m.TYPEID)
		elseif m.OUTPUT:len() > 0 then
			-- Hack to get the censored message display working with EverlookDBChat
			local isChatLineCensored = arg11 and C_ChatInfo.IsChatLineCensored(arg11);
			local msg = isChatLineCensored and arg1 or m.OUTPUT

			-- Hack to strip out timestamps if injected
			local chatTimestampFmt = ChatFrameUtil and ChatFrameUtil.GetTimestampFormat and ChatFrameUtil.GetTimestampFormat()
			if chatTimestampFmt and TimeUtil and TimeUtil.BetterDate then
				msg = msg:gsub(TimeUtil.BetterDate(chatTimestampFmt, time()), '')
			end

			local eventArgs = SafePack(...)
			this:AddMessage(msg, r, g, b, id, m.ACCESSID, m.TYPEID, event, eventArgs, function(text)
				return text
			end)

			-- We have called addmessage by now, or we have skipped it
			-- regardless, we call postaddmessage. This was changed to allow
			-- for more flexibility in the customfilters module, speficially
			-- it allows for replacements to occur in blocked messages

			EverlookDBChat.callbacks:Fire(POST_ADDMESSAGE, m, this, message.EVENT, m.OUTPUT, r, g, b, id, m.ACCESSID, m.TYPEID)

			if (not this:IsShown()) then
				if ((this == DEFAULT_CHAT_FRAME and m.INFO.flashTabOnGeneral) or (this ~= DEFAULT_CHAT_FRAME and m.INFO.flashTab)) then
					if (m.CHATTYPE == "WHISPER" or m.CHATTYPE == "BN_WHISPER") then
						if (not FCFManager_ShouldSuppressMessageFlash(this, m.CHATGROUP, m.CHATTARGET)) then
							FCF_StartAlertFlash(this);
						end
					end
				end
			end

			EverlookDBChat.LastMessage = m
			if not ChatFrame_MessageEventHandler then
				CMEResult = true
			end
		end
	end

	m.CAPTUREOUTPUT = nil

	EverlookDBChat.CurrentMessage = nil

	return CMEResult
end

function addon:AddMessage(frame, text, r, g, b, id, ...)
	local s = EverlookDBChat.SplitMessage
	if s.OUTPUT == nil and s.CAPTUREOUTPUT == frame then
		s.ORG.OUTPUT = text
	else
		self.hooks[frame].AddMessage(frame, text, r, g, b, id, ...)
	end
end

function EverlookDBChat.PlaySound(_, sound)
	if not sound then
		return
	end

	local play = EverlookDBChat.Media:Fetch(SOUND, sound)
	if play == nil then
		return
	end

	PlaySoundFile(play, "Master")
end

function EverlookDBChat.CanSendChatMessage(chatType)
	if EverlookDBChat.IsModernAPI and InCombatLockdown() then
		return false
	end
	if chatType == "SAY" or chatType == "YELL" then
		return IsInInstance("player")
	elseif chatType == "RAID" or chatType == "GUILD" or chatType == "WHISPER" then
		return true
	end

	return false
end

EverlookDBChat.MULTIBYTE_FIRST_CHAR = "^([%a\192-\255]?[\128-\191]*)"
EverlookDBChat.AnyNamePattern = "%f[%a\128-\255]([%a\128-\255]+)%f[^%a\128-\255]"

function EverlookDBChat.GetNamePattern(name)
	local u = name:match(EverlookDBChat.MULTIBYTE_FIRST_CHAR):upper()

	if not u or u:len() == 0 then
		EverlookDBChat:Print("GetNamePattern: name error ", name)
		return
	end

	local l = u:lower()
	local namepat
	if u == l then
		namepat = name:lower()
	elseif u:len() == 1 then
		namepat = "[" .. u .. l .. "]" .. name:sub(2):lower()
	elseif u:len() > 1 then
		namepat = ""
		for i = 1, u:len() do
			namepat = namepat .. "[" .. u:sub(i, i) .. l:sub(i, i) .. "]"
		end
		namepat = namepat .. name:sub(u:len() + 1)
	end

	return "%f[%a\128-\255]" .. namepat .. "%f[^%a\128-\255]"
end

function EverlookDBChat.RegisterChatCommand(cmd, func)
	addon:RegisterChatCommand(cmd, func)
end

EverlookDBChat.RegisterChatCommand("edbchatblacklist", function(name)
	if name and #name > 0 then
		EverlookDBChat:Print("Blacklisting: '" .. tostring(name) .. "'. Reload to activate.")
		EverlookDBChat.db.realm.PlayerNameBlackList[tostring(name):lower()] = true
	end
end)

EverlookDBChat.RegisterChatCommand("edbchatunblacklist", function(name)
	if name and #name > 0 then
		EverlookDBChat:Print("Un-Blacklisting: '" .. tostring(name) .. "'. Reload to activate")
		EverlookDBChat.db.realm.PlayerNameBlackList[tostring(name):lower()] = nil
	end
end)

EverlookDBChat.RegisterChatCommand("edbchatdebugmsg", function()
	if EverlookDBChat.LastMessage then
		EverlookDBChat:PrintLiteral(EverlookDBChat.LastMessage)
	end

	local cc = EverlookDBChat:GetModule("CopyChat")
	if cc then
		cc:DoCopyChat(DEFAULT_CHAT_FRAME, true)
	end
end)

tinsert(EverlookDBChat.EnableTasks, function()
	local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
	if not ldb then
		return
	end

	ldb:NewDataObject("EverlookDB Chat", {
		type = "launcher",
		text = "EverlookDB Chat",
		icon = "Interface\\Addons\\EverlookDBChat\\textures\\icon",
		OnClick = function()
			EverlookDBChat:ToggleOptionsWindow()
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(EverlookDBChat.Version)
		end,
	})
end)
