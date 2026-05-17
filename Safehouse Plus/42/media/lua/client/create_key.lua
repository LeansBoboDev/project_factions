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

-- Creates the key for the user
doorlocksystem.userGetKey = function(worldobjects, player, door)
	-- Verify if the player belongs to the safehouse
	if BelongsToTheSafehouse(player, door) then
		-- Gets the door id
		local keycode = door:getKeyId();
		-- Create a key
		local doorkey = player:getInventory():AddItem('Base.Key1');
		-- Change the key id to the door id
		doorkey:setKeyId(keycode);
		-- Change the name and the keycode
		doorkey:setName('SafeHouse #' .. keycode);
		player:Say(getText("IGUI_Door_Key_Created"));
	else
		player:Say(getText("IGUI_Door_Key_Not_Created"));
	end
end

-- Calls the function when the world create
Events.OnFillWorldObjectContextMenu.Add(doorlocksystem.onFillWorldObjectContextMenu)
