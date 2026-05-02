if not getSandboxOptions():getOptionByName("FactionsPlus.EnableWaterLightCycle"):getValue() then return end;

local function getCurrentTime(timezone, timestamp)
	local function remainder(a, b)
		return a - math.floor(a / b) * b;
	end

	local tm = {};
	local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
	local seconds, minutes, hours, days, year, month;
	local dayOfWeek;

	if timestamp then
		seconds = math.floor(timestamp) + (timezone or 0) * 3600;
	else
		seconds = getTimestamp() + (timezone or 0) * 3600;
	end
	-- Calculate minutes
	minutes   = math.floor(seconds / 60);
	seconds   = seconds - (minutes * 60);
	-- Calculate hours
	hours     = math.floor(minutes / 60);
	minutes   = minutes - (hours * 60);
	-- Calculate days
	days      = math.floor(hours / 24);
	hours     = hours - (days * 24);

	-- Unix time starts in 1970 on a Thursday
	year      = 1970;
	dayOfWeek = 4;

	while true do
		local leapYear = remainder(year, 4) == 0 and (remainder(year, 100) ~= 0 or remainder(year, 400) == 0);
		local daysInYear = 365;
		if leapYear then
			daysInYear = 366;
		end

		if days >= daysInYear then
			if leapYear then
				dayOfWeek = dayOfWeek + 2;
			else
				dayOfWeek = dayOfWeek + 1;
			end
			days = days - daysInYear;
			if dayOfWeek >= 7 then
				dayOfWeek = dayOfWeek - 7;
			end
			year = year + 1;
		else
			tm.tm_yday = days;
			dayOfWeek  = dayOfWeek + days;
			dayOfWeek  = remainder(dayOfWeek, 7);
			-- Calculate the month and day

			month      = 1;
			while month <= 12 do
				local dim = daysInMonth[month];

				-- Add a day to feburary if this is a leap year
				if month == 2 and leapYear then
					dim = dim + 1;
				end

				if days >= dim then
					days = days - dim;
				else
					break;
				end
				month = month + 1;
			end
			break;
		end
	end

	tm.tm_sec  = seconds;
	tm.tm_min  = minutes;
	tm.tm_hour = hours;
	tm.tm_mday = days + 1;
	tm.tm_mon  = month;
	tm.tm_year = year;
	tm.tm_wday = dayOfWeek;
	return tm;
end

-- Variable to handle the print to the server
-- the existence is simple not spam the day check water
-- only when the check is changed
local printerHandler = "on";

local function TimeCheck()
	local currentTime = getCurrentTime(getSandboxOptions():getOptionByName("FactionsPlus.Timezone"):getValue());

	local function enable()
		if FactionsPlusIsSinglePlayer then
			local player = getPlayer();

			-- Turn on water, light
			getSandboxOptions():set("ElecShutModifier", 2147483647);
			getSandboxOptions():set("WaterShutModifier", 2147483647);
			sendServerCommand(player, "ServerSafehouse", "updateSandbox", { electricityOn = true });
			if printerHandler ~= "off" then
				DebugPrintFactionsPlus('Day Check Water, Lights on: ' .. currentTime.tm_wday);
				printerHandler = "off";
			end
		else
			local onlinePlayers = getOnlinePlayers();
			for i = 0, onlinePlayers:size() - 1 do
				local player = onlinePlayers:get(i);

				-- Turn on water, light
				getSandboxOptions():set("ElecShutModifier", 2147483647);
				getSandboxOptions():set("WaterShutModifier", 2147483647);
				sendServerCommand(player, "ServerSafehouse", "updateSandbox", { electricityOn = true });
				if printerHandler ~= "off" then
					DebugPrintFactionsPlus('Day Check Water, Lights on: ' .. currentTime.tm_wday);
					printerHandler = "off";
				end
			end
		end
	end
	local function disable()
		if FactionsPlusIsSinglePlayer then
			local player = getPlayer();

			-- Turn off water, light
			getSandboxOptions():set("ElecShutModifier", -1);
			getSandboxOptions():set("WaterShutModifier", -1);
			sendServerCommand(player, "ServerSafehouse", "updateSandbox", { electricityOff = true });
			if printerHandler ~= "on" then
				DebugPrintFactionsPlus('Day Check Water, Lights off: ' .. currentTime.tm_wday);
				printerHandler = "on";
			end
		else
			local onlinePlayers = getOnlinePlayers();
			for i = 0, onlinePlayers:size() - 1 do
				local player = onlinePlayers:get(i);

				-- Turn off water, light
				getSandboxOptions():set("ElecShutModifier", -1);
				getSandboxOptions():set("WaterShutModifier", -1);
				sendServerCommand(player, "ServerSafehouse", "updateSandbox", { electricityOff = true });
				if printerHandler ~= "on" then
					DebugPrintFactionsPlus('Day Check Water, Lights off: ' .. currentTime.tm_wday);
					printerHandler = "on";
				end
			end
		end
	end

	local stringDays = getSandboxOptions():getOptionByName("FactionsPlus.WaterLightCycle"):getValue();

	local shouldEnable = false;
	-- Swipe the days into a variable
	for day in string.gmatch(stringDays, "%d+") do
		-- Get the day number
		local dayNumber = tonumber(day);

		-- Check if the dayNumber is equals the today number
		if dayNumber == currentTime.tm_wday then
			shouldEnable = true;
			break;
		end
	end

	if shouldEnable then
		enable();
	else
		disable();
	end
end

Events.EveryHours.Add(TimeCheck);
