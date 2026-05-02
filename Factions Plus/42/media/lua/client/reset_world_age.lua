local function OnServerCommand(module, command, arguments)
	-- The server needs to send us the message to update sandbox
	-- because the client also need to update their sandbox options
	-- indie stone....
	if module == "ResetWorldAge" and command == "updateSandbox" then
		local gameTime    = getGameTime()
		local actualDay   = arguments.actualDay
		local actualMonth = arguments.actualMonth
		local actualYear  = arguments.actualYear

		DebugPrintFactionsPlus("Actual Calendar: " .. "D:" .. actualDay .. " M:" .. actualMonth .. " Y:" .. actualYear);

		gameTime:setStartDay(actualDay);
		gameTime:setStartMonth(actualMonth);
		gameTime:setStartYear(actualYear);
		gameTime:setStartTimeOfDay(0.0);
		gameTime:save();

		getSandboxOptions():set("StartMonth", actualMonth);
		getSandboxOptions():set("StartDay", actualDay);
		getSandboxOptions():set("StartYear", actualYear);
		getSandboxOptions():set("TimeSinceApo", 0);
	end
end

Events.OnServerCommand.Add(OnServerCommand)
