FactionsCompatibility = true;
FactionsName = "Factions";
FactionsIsSinglePlayer = false;

if not isClient() and not isServer() then
	FactionsIsSinglePlayer = true;
end

function DebugPrintFactions(log)
	if FactionsIsSinglePlayer then
		print("[" .. FactionsName .. "] " .. log);
	else
		if isClient() then
			print("[" .. FactionsName .. "-Client] " .. log);
		else
			if isServer() then
				print("[" .. FactionsName .. "-Server] " .. log);
			else
				print("[" .. FactionsName .. "-Unkown] " .. log);
			end
		end
	end
end

function GetPlayerFaction(username)
	-- Get all factions from the server
	local factions = Faction.getFactions();
	for i = 0, factions:size() - 1 do
		local faction = factions:get(i);
		-- If the player is the owner simple return the faction
		if faction:isOwner(username) then
			return faction;
		end
		local players = faction:getPlayers();
		-- If not we swipe the players in faction and see if the actual player is on it
		for j = 0, players:size() - 1 do
			local player = players:get(j);
			if player == username then
				return faction;
			end
		end
	end
	return nil;
end

function IsSafehouseFromPlayerFaction(player, safehouse)
	if not safehouse then
		return nil
	end

	local owner = safehouse:getOwner();

	-- Verify if the player is the owner of the safehouse
	if player:getUsername() == owner then
		return true;
	end

	-- Getting the faction owner username
	local faction = GetPlayerFaction(player:getUsername())

	-- Player does not belong to any faction
	if not faction then
		return nil
	end

	-- Verify if the player is the owner of the faction
	if player:getUsername() == faction:getOwner() then
		return true;
	end

	-- Iterate all players in faction
	for i, username in pairs(faction:getPlayers()) do
		-- If player belongs to the faction, we return true
		if player:getUsername() == username then
			return true
		end
	end

	return false
end

function GetSafehouseCost(building)
	if not building then
		return 99999
	end

	local offset
	if instanceof(building, "IsoBuilding") then
		offset = 0

		local definition = building:getDef()
		if definition then
			return math.ceil(((definition:getH() - offset) * (definition:getW() - offset)) / 100) - 1;
		else
			return 99999
		end
	elseif instanceof(building, "SafeHouse") then
		offset = 4

		return math.ceil(((building:getH() - offset) * (building:getW() - offset)) / 100) - 1;
	end
end

function GetFactionUsedPoints(faction)
	local owner = faction:getOwner()

	local pointsUsed = 0
	for i = 0, SafeHouse.getSafehouseList():size() - 1 do
		local safehouse = SafeHouse.getSafehouseList():get(i);

		if safehouse:getOwner() == owner then
			pointsUsed = pointsUsed + GetSafehouseCost(safehouse)
		end
	end

	return pointsUsed
end

function IsSpawnPoint(square)
	if not square then
		DebugPrintFactions("[isSpawnPoint] square is nil")
		return false
	end

	local status, regions = pcall(getServerSpawnRegions)
	if not status or not regions then
		DebugPrintFactions("[isSpawnPoint] getServerSpawnRegions() failed or returned nil. Are you in singleplayer?")
		return false
	end

	for regionIndex, region in ipairs(regions) do
		if not region.points then
			DebugPrintFactions("[isSpawnPoint] region.points is nil for region index: " .. regionIndex)
		else
			for pointIndex, point in ipairs(region.points) do
				if not (point.posX and point.posY and point.worldX and point.worldY) then
					DebugPrintFactions(string.format(
						"[isSpawnPoint] Invalid point structure at region %d, point %d. point = %s",
						regionIndex, pointIndex, tostring(point)
					))
				else
					local gx = point.posX:doubleValue() + point.worldX:doubleValue() * 300.0
					local gy = point.posY:doubleValue() + point.worldY:doubleValue() * 300.0
					local gridSquare = getCell():getGridSquare(gx, gy, 0)

					if not gridSquare then
						DebugPrintFactions(string.format(
							"[isSpawnPoint] getGridSquare returned nil at x=%d y=%d",
							gx, gy
						))
					else
						local building = gridSquare:getBuilding()
						if not building then
							DebugPrintFactions(string.format(
								"[isSpawnPoint] No building found at x=%d y=%d", gx, gy
							))
						else
							local def = building:getDef()
							if square:getX() >= def:getX() and square:getX() < def:getX2()
								and square:getY() >= def:getY() and square:getY() < def:getY2() then
								DebugPrintFactions(string.format(
									"[isSpawnPoint] Square is inside building at spawn region %d, point %d",
									regionIndex, pointIndex
								))
								return true
							end
						end
					end
				end
			end
		end
	end

	DebugPrintFactions("[isSpawnPoint] Square is not inside any spawn region.")
	return false
end

function GetFloorCount(building)
	if not building then return 0 end
	local def = building:getDef()
	if def then
		local level = 0;
		if def then
			local rooms = def:getRooms();
			if rooms then
				for i = 0, rooms:size() - 1 do
					local room = rooms:get(i);
					local z = room:getZ();
					if z > level then
						level = z;
					end
				end
			end
		end
		return level;
	else
		return 0
	end
end

function IsSomeoneInside(square, faction, level)
	-- If player doesn't belongs to any faction return nil
	if not faction then
		return nil;
	end

	if square then
		local building = square:getBuilding();
		if building then
			local def = building:getDef();
			local leader = faction:getOwner();
			if not level then
				level = GetFloorCount(def);
			end
			local x = def:getX() - 2;
			while x < (def:getX2() + 2) do
				x = x + 1;
				local y = def:getY() - 2;
				while y < def:getY2() + 2 do
					y = y + 1;
					local z = 0;
					while z < level do
						local _square = getCell():getGridSquare(x, y, z);
						if _square then
							for i = 0, _square:getMovingObjects():size() - 1 do
								local o = _square:getMovingObjects():get(i);
								if not o:getSquare():getProperties():has(IsoFlagType.exterior) and o:getBuilding() then
									if instanceof(o, "IsoPlayer") then
										local member = false;

										for j = 0, faction:getPlayers():size() - 1 do
											local player = faction:getPlayers():get(j);
											if player == o:getUsername() then
												member = true;
												break
											end
										end

										if leader == o:getUsername() then
											member = true;
										end

										if not member then
											return true
										end
									elseif instanceof(o, "IsoZombie") then
										return true
									end
								end
							end
						end
						z = z + 1
					end
				end
			end
		end
	end

	return false
end

function IsResidential(square)
	local residential = false;
	if square then
		local building = square:getBuilding();
		if building then
			local has_kitchen, has_bedroom, has_bathroom;
			local rooms = building:getDef():getRooms();
			for i = 0, rooms:size() - 1 do
				local room = rooms:get(i);
				if room:getName() == "kitchen" then
					has_kitchen = true;
				elseif room:getName() == "bathroom" then
					has_bathroom = true;
				elseif room:getName() == "bedroom" or room:getName() == "livingroom" then
					has_bedroom = true;
				end
			end
			residential = has_bathroom and (has_kitchen or has_bedroom);
		end
	end

	return residential;
end
