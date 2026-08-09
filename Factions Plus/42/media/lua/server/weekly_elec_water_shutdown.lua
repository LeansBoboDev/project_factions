if isClient() and not FactionsIsSinglePlayer then return end;
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

local function shouldUtilitiesBeOn()
	local currentTime = getCurrentTime(getSandboxOptions():getOptionByName("FactionsPlus.Timezone"):getValue());
	local stringDays = getSandboxOptions():getOptionByName("FactionsPlus.WaterLightCycle"):getValue();
	for day in string.gmatch(stringDays, "%d+") do
		if tonumber(day) == currentTime.tm_wday then
			return true, currentTime.tm_wday;
		end
	end
	return false, currentTime.tm_wday;
end

local function sendUtilityStateToPlayer(player, on)
	if on then
		getSandboxOptions():set("ElecShutModifier", 2147483647);
		getSandboxOptions():set("WaterShutModifier", 2147483647);
		sendServerCommand(player, "ServerSafehouse", "updateSandbox", { electricityOn = true });
	else
		getSandboxOptions():set("ElecShutModifier", -1);
		getSandboxOptions():set("WaterShutModifier", -1);
		sendServerCommand(player, "ServerSafehouse", "updateSandbox", { electricityOff = true });
	end
end

local function TimeCheck()
	local electricityOn, dayOfWeek = shouldUtilitiesBeOn();

	local function broadcast(on)
		if FactionsPlusIsSinglePlayer then
			sendUtilityStateToPlayer(getPlayer(), on);
		else
			local onlinePlayers = getOnlinePlayers();
			for i = 0, onlinePlayers:size() - 1 do
				sendUtilityStateToPlayer(onlinePlayers:get(i), on);
			end
		end
		if on then
			if printerHandler ~= "off" then
				DebugPrintFactionsPlus('Day Check Water, Lights on: ' .. dayOfWeek);
				printerHandler = "off";
			end
		else
			if printerHandler ~= "on" then
				DebugPrintFactionsPlus('Day Check Water, Lights off: ' .. dayOfWeek);
				printerHandler = "on";
			end
		end
	end

	broadcast(electricityOn);
end

local knownPlayers = {};
local newPlayerCheckTicks = 0;
local NEW_PLAYER_CHECK_INTERVAL = 60;

local function OnTickCheckNewPlayers()
	newPlayerCheckTicks = newPlayerCheckTicks + 1;
	if newPlayerCheckTicks < NEW_PLAYER_CHECK_INTERVAL then return end;
	newPlayerCheckTicks = 0;

	local electricityOn = shouldUtilitiesBeOn();
	local onlinePlayers = getOnlinePlayers();
	local currentPlayers = {};

	for i = 0, onlinePlayers:size() - 1 do
		local player = onlinePlayers:get(i);
		local username = player:getUsername();
		currentPlayers[username] = true;
		if not knownPlayers[username] then
			knownPlayers[username] = true;
			sendUtilityStateToPlayer(player, electricityOn);
		end
	end

	for username in pairs(knownPlayers) do
		if not currentPlayers[username] then
			knownPlayers[username] = nil;
		end
	end
end

Events.EveryHours.Add(TimeCheck);
Events.OnTick.Add(OnTickCheckNewPlayers);
