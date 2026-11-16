tinsert(EverlookDBChat.EnableTasks, function()
	-- Register formatting with WIM.
	if (WIM and WIM.RegisterMessageFormatting) then
		WIM.RegisterMessageFormatting("EverlookDB Chat", function(smf, event, ...)
			return EverlookDBChat.Format(smf, event, WIM.nextColor, ...)
		end)
	end
end)
