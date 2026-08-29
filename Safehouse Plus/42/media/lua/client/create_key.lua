if not getSandboxOptions():getOptionByName("SafehousePlus.EnableSafehouseCreateKey"):getValue() then return end

local function chatMsg(text)
    if not ISChat or not ISChat.instance then return end
    local mock = {
        getTextWithPrefix = function() return "<RGB:1,1,1>" .. text end,
        getAuthor         = function() return nil end,
    }
    ISChat.addLineInChat(mock, 0)
end

local doorlocksystem = {}
doorlocksystem.onFillWorldObjectContextMenu = function(playerId, context, worldobjects, test)
	-- Receive the player
	local player = getSpecificPlayer(playerId)

	-- Swipe objects
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
	chatMsg(getText("IGUI_Door_Key_Created"))
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
		chatMsg(getText("IGUI_Door_Key_Not_Created"))
	end
end

Events.OnServerCommand.Add(function(module, command, args)
	if module ~= "FactionsEconomyCurrency" then return end

	local player = getSpecificPlayer(0)
	if not player then return end

	if command == "confirmCreateKey" then
		createKey(player, args.keycode)
	elseif command == "denyCreateKey" then
		chatMsg(getText("IGUI_Door_Key_No_Currency"))
	end
end)

-- Calls the function when the world create
Events.OnFillWorldObjectContextMenu.Add(doorlocksystem.onFillWorldObjectContextMenu)
