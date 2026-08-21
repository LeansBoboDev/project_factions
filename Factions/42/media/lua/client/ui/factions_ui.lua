local GUI = nil
local lastGUI_X = 0
local lastGUI_Y = 0

-- Remove the UI if exist
function UnloadUI()
	if GUI then
		GUI:removeFromUIManager()
		GUI = nil;
	end
end

-- Treatment for resolutions change
local onResolutionChange = function()
	if GUI then
		GUI:setX(30);
		GUI:setY(getCore():getScreenHeight() - 129);
	end
end
Events.OnResolutionChange.Add(onResolutionChange)

-- Treatment for getting the safehous from custom sources
local function getSafehouseWithoutBuilding(square)
	local safehouse = SafeHouse.getSafeHouse(square);
	if safehouse then
		for x = safehouse:getX() + 2, safehouse:getX2() - 4 do
			for y = safehouse:getY() + 2, safehouse:getY2() - 4 do
				local sq = getCell():getGridSquare(x, y, 0);
				if sq then
					if sq:getBuilding() then
						return safehouse, false;
					end
				end
			end
		end
	end
	return safehouse, true;
end

-- Creates or destroys UI, if player is inside/outside the safehouse
local function update()
	local player = getPlayer();
	if player then
		local square = player:getSquare()
		if square then
			-- Treatment for nil safehouses
			local safehouse, isCustom = getSafehouseWithoutBuilding(square);
			local building = square:getBuilding()
			-- Check building does not exist and safehouse is custom
			if isCustom and not building then
				building = safehouse;
			end
			-- Check if player is not dead and the building variable exist
			local allowed = not player:isDead() and building;

			-- Check if gui does not exist and allowed is enabled
			if not GUI and allowed then
				-- Texts for the buttons
				local safehouseText = nil;
				local factionText = nil;
				local buttonText = nil;

				-- This is the faction of the safehouse the player are in
				local safehouse_faction = nil;
				-- This is the faction of the player
				local player_faction = GetPlayerFaction(player:getUsername());

				-- Add this building to the global variable building
				building = building;

				-- Check if the safehouse exist
				if safehouse then
					safehouseText = safehouse:getTitle();
					safehouse_faction = GetPlayerFaction(safehouse:getOwner());
					-- Check if the faction from the safehouse exist
					if safehouse_faction then
						-- Creates the text
						factionText = getText("UI_Text_LabelFaction") .. tostring(safehouse_faction:getName())
						-- Check if the player faction is the same as the safehouse faction
						if player_faction == safehouse_faction then
							buttonText = getText("UI_Text_SafehouseView")
						end
					end
				end

				-- Instanciate the Button UI
				GUI = FactionsGUI:new(safehouseText, factionText, buttonText, player_faction);
				GUI:initialise();
				GUI:addToUIManager();
				ISLayoutManager.RegisterWindow('FactionsUI', FactionsGUI, GUI);
				lastGUI_X, lastGUI_Y = GUI.x, GUI.y;
			elseif GUI and (not allowed or building ~= building) then
				building = nil
				-- Save the UI position
				if lastGUI_X ~= GUI.x or lastGUI_Y ~= GUI.y then
					ISLayoutManager.OnPostSave();
				end
				-- Remove the Button UI if exist
				GUI:removeFromUIManager()
				GUI = nil;
			end
		end
	end
end
Events.OnGameStart.Add(function() Events.OnTick.Add(update); end)

-- Alert the online players specific behaviours
local function updatePoints(points)
	if GUI then
		GUI.points = points
	end
end

local function OnServerCommand(module, command, arguments)
	-- Receives alerts from the server
	if module == "Factions" and command == "receivePoints" then
		updatePoints(arguments[0]);
	end
end
Events.OnServerCommand.Add(OnServerCommand)
