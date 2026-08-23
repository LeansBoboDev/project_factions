local GUI = nil
local lastGUI_X = 0
local lastGUI_Y = 0

function UnloadUI()
	if GUI then
		GUI:removeFromUIManager()
		GUI = nil;
	end
end

local onResolutionChange = function()
	if GUI then
		GUI:setX(30);
		GUI:setY(getCore():getScreenHeight() - 129);
	end
end
Events.OnResolutionChange.Add(onResolutionChange)

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

local function update()
	local player = getPlayer();
	if not player then return end

	local square = player:getSquare()
	if not square then return end

	local safehouse, isCustom = getSafehouseWithoutBuilding(square);
	local building = square:getBuilding()

	if isCustom and not building then
		building = safehouse;
	end

	local allowed = not player:isDead() and building;

	if not GUI and allowed then
		local safehouseText = nil;
		local factionText = nil;
		local buttonText = nil;

		local player_faction = GetPlayerFaction(player:getUsername());

		if not player_faction then
			factionText = getText("UI_Text_SafehouseWithoutFaction")
		end

		if safehouse then
			safehouseText = safehouse:getTitle();
			local safehouse_faction = GetPlayerFaction(safehouse:getOwner());
			if safehouse_faction then
				factionText = getText("UI_Text_LabelFaction") .. tostring(safehouse_faction:getName())
				if player_faction == safehouse_faction then
					buttonText = getText("UI_Text_SafehouseView")
				end
			end
		end

		local ok, err = pcall(function()
			GUI = FactionsGUI:new(safehouseText, factionText, buttonText, player_faction);
			GUI:initialise();
			GUI:addToUIManager();
			ISLayoutManager.RegisterWindow('FactionsUI', FactionsGUI, GUI);
			lastGUI_X, lastGUI_Y = GUI.x, GUI.y;
		end)

		if not ok then
			print("[FactionsUI] ERROR creating GUI: " .. tostring(err))
			GUI = nil
		end

	elseif GUI and not allowed then
		if lastGUI_X ~= GUI.x or lastGUI_Y ~= GUI.y then
			ISLayoutManager.OnPostSave();
		end
		GUI:removeFromUIManager()
		GUI = nil;
	end
end
Events.OnGameStart.Add(function() Events.OnTick.Add(update); end)

local function OnServerCommand(module, command, arguments)
	if module == "Factions" and command == "receivePoints" then
		FactionsGUI.points = arguments[1]
		if GUI then
			GUI.points = arguments[1]
		end
	end
end
Events.OnServerCommand.Add(OnServerCommand)
