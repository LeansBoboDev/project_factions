if not getSandboxOptions():getOptionByName("SafehousePlus.EnableSafehouseCreateKey"):getValue() then return end

local doorlocksystem = {}
doorlocksystem.onFillWorldObjectContextMenu = function(playerId, context, worldobjects, test)
	-- Receive the player
	local player = getSpecificPlayer(playerId)

	-- Swipe objects
	for a, door in ipairs(worldobjects) do
		-- If is a door
		if instanceof(door, 'IsoDoor') then
			-- Add the key option
			local KeyMenu = context:addOption(getText("IGUI_Door_Lock"), worldobjects);
			local subMenu = ISContextMenu:getNew(context);
			doorlocksystem.context = context
			doorlocksystem.subMenu = subMenu
			context:addSubMenu(KeyMenu, subMenu);
			subMenu:addOption(getText("IGUI_Door_Create_Key"), worldobjects, doorlocksystem.userGetKey, player, door)
		end
	end
end

-- Returns true if the door's square belongs to a safehouse the player owns or is a member of
local function BelongsToTheSafehouse(player, door)
    local square = door:getSquare();
    if not square then return false end;
    local safe = SafeHouse.getSafeHouse(square);
    if not safe then return false end;
    local username = player:getUsername();
    return safe:getOwner() == username or safe:getPlayers():contains(username);
end

local function createKey(player, keycode)
	local doorkey = player:getInventory():AddItem('Base.Key1')
	doorkey:setKeyId(keycode)
	doorkey:setName('SafeHouse #' .. keycode)
	player:Say(getText("IGUI_Door_Key_Created"))
end

-- Creates the key for the user
doorlocksystem.userGetKey = function(worldobjects, player, door)
	if BelongsToTheSafehouse(player, door) then
		if FactionsEconomyCompatibility then
			sendClientCommand(player, "FactionsEconomyCurrency", "requestCreateKey", { keycode = door:getKeyId() })
		else
			createKey(player, door:getKeyId())
		end
	else
		player:Say(getText("IGUI_Door_Key_Not_Created"))
	end
end

Events.OnServerCommand.Add(function(module, command, args)
	if module ~= "FactionsEconomyCurrency" then return end

	local player = getSpecificPlayer(0)
	if not player then return end

	if command == "confirmCreateKey" then
		createKey(player, args.keycode)
	elseif command == "denyCreateKey" then
		player:Say(getText("IGUI_Door_Key_No_Currency"))
	end
end)

-- Calls the function when the world create
Events.OnFillWorldObjectContextMenu.Add(doorlocksystem.onFillWorldObjectContextMenu)
