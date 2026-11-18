-- /echat (also /edbchat): the chat-command pattern every EverlookDB addon shares, from EverlookUI (the parser only;
-- the window stays AceConfig). Every module is an on/off setting (/echat timestamps off), and find, clear, copy and
-- focus also work here, so they keep working when another addon (Prat-3.0) owns /find, /clear or /copychat.
-- The standalone commands (/find, /clear, /copychat, /chatfocus, /alias, ...) stay as they are.
local _, private = ...

local UI = LibStub("EverlookUI-1")
local NAME = "EverlookDB Chat"

local app = UI:NewApp({
	name = NAME, addon = "EverlookDBChat", slash = "/echat", aliases = { "/edbchat" },
	tagline = "Chat improvements, each one a module you can turn on or off.", accent = { 1.0, 0.824, 0.0 },
	settingsPanel = false, chatSearch = false, windowDesc = "the settings (also under Settings > AddOns)",
})
private.app = app
function app:Toggle() private:ToggleOptionsWindow() end
function app:Open() if not private:IsOptionsWindowShown() then private:ToggleOptionsWindow() end end
function app:Close() if private:IsOptionsWindowShown() then private:ToggleOptionsWindow() end end
function app:IsShown() return private:IsOptionsWindowShown() end
function app:OpenSearch() self:Open() end

local BOOL = { on = true, off = true, toggle = true, enable = true, disable = true }

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function getModule(name) return private.Addon and private.Addon:GetModule(name, true) end

-- The module a command runs, or nil after saying it is off and how to turn it on.
local function needModule(name, key)
	local m = getModule(name)
	if m and m:IsEnabled() then return m end
	app:Print("|cffff6060" .. name .. " is off.|r Turn it on: /echat " .. key .. " on")
	return nil
end

-- "/echat clear off" (a module's on/off) on a command that has the module's name.
local function moduleSwitch(key, rest)
	local def = app:GetSetting(key)
	if def and BOOL[trim(rest):lower()] then app:SetFromText(def, rest) return true end
	return false
end

------------------------------------------------------------------------
-- Modules as settings: the same values the "Module control" page writes (2 = off, 3 = on).
------------------------------------------------------------------------
function private:AddModuleSettings()
	for name, m in private.Addon:IterateModules() do
		local key = tostring(m.moduleName or name):lower()
		if not app:GetSetting(key) then
			local desc
			if m.GetDescription then
				local ok, d = pcall(m.GetDescription, m)
				desc = ok and type(d) == "string" and d or nil
			end
			app:Setting({ key = key, type = "bool", label = m.moduleName or name, desc = desc,
				get = function() return m.db and m.db.profile.on and true or false end,
				set = function(on)
					private.db.profile.modules[m.moduleName or name] = on and 3 or 2
					if m.db then m.db.profile.on = on end
					if on then m:Enable() else m:Disable() end
					if private.UpdateOptions then private:UpdateOptions() end
				end })
		end
	end
end

if private.EnableTasks then
	private.EnableTasks[#private.EnableTasks + 1] = function() private:AddModuleSettings() end
end

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------
app:Command("find", "find <words>", "search the chat window for a word", function(rest)
	local m = needModule("Search", "search")
	if m then m:Find(trim(rest), true) end
end)

app:Command("clear", "clear [all]", "clear this chat window, or every window", function(rest)
	if moduleSwitch("clear", rest) then return end
	local function clear(f) if f and f.Clear then f:Clear() end end
	if trim(rest):lower() == "all" then
		for i = 1, (NUM_CHAT_WINDOWS or 10) do clear(_G["ChatFrame" .. i]) end
	else
		clear(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
	end
end, { "cls" })

app:Command("copy", "copy", "copy this chat window's text", function()
	local m = needModule("CopyChat", "copychat")
	local f = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	if m and f then m:DoCopyChat(f) end
end)

app:Command("focus", "focus", "focus on: hide General, Trade and the other numbered channels (Calm)", function()
	local m = needModule("Calm", "calm")
	if m then m:ToggleFocus() end
end)

function private.Blacklist(name, add)
	name = trim(name)
	if name == "" then
		app:Print("|cffff6060name a player.|r Example: /echat " .. (add and "" or "un") .. "blacklist you")
		return
	end
	local list = private.db.realm.PlayerNameBlackList
	list[name:lower()] = add or nil
	app:Print((add and "won't colour '" or "colours '") .. name .. "' as a player name again. /reload to apply.")
end

app:Command("blacklist", "blacklist <word>", "never colour this word as a player name", function(rest) private.Blacklist(rest, true) end)
app:Command("unblacklist", "unblacklist <word>", "take a word off that list", function(rest) private.Blacklist(rest, false) end)

app:Command("aliases", "aliases [pattern]", "list your /alias commands", function(rest)
	local m = needModule("Alias", "alias")
	if m then m:listAliases(trim(rest) ~= "" and trim(rest) or nil) end
end)

-- "/echat search off" switches the Search module; anything else opens the window (it has no search box).
app:Command("search", "search", "", function(rest)
	if moduleSwitch("search", rest) then return end
	app:Open()
end).hidden = true

function private.DebugMessage()
	if private.LastMessage and private.PrintLiteral then private:PrintLiteral(private.LastMessage) end
	local cc = private.GetModule and private:GetModule("CopyChat")
	if cc then cc:DoCopyChat(DEFAULT_CHAT_FRAME, true) end
end
app:Command("debugmsg", "debugmsg", "", function() private.DebugMessage() end).hidden = true

-- Placement mode: /echat move (flips), /echat unlock, /echat lock.
app:Movable({
	what = "the chat and see where the chat box goes",
	get = function()
		local m = getModule("Placement")
		return not (m and m:IsEnabled() and m:IsUnlocked())
	end,
	set = function(locked)
		local m = needModule("Placement", "placement")
		if m then m:SetUnlocked(not locked) end
	end,
})

------------------------------------------------------------------------
-- Reset and status
------------------------------------------------------------------------
app:Reset(nil, "every " .. NAME .. " setting in this profile", function() private.db:ResetProfile() end)

app:StatusLines(function()
	local on, total = 0, 0
	for _, m in private.Addon:IterateModules() do
		total = total + 1
		if m.db and m.db.profile.on then on = on + 1 end
	end
	return { on .. " of " .. total .. " modules on (/echat get lists them).",
		"Also: /find, /clear, /copychat, /chatfocus, /alias, /tt." }
end)

app:RegisterSlash("EDBCHAT")
