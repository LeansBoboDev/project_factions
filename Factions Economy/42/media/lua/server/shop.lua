if isClient() and not FactionsEconomyIsSinglePlayer then return end;

ShopItems = {};

local function LoadShopItems()
    local path = "FactionsEconomyShopItems.ini"
    local fileReader = getFileReader(path, true)
    if not fileReader then
        print("[FactionEconomy] ERROR: FactionsEconomyShopItems.ini not found in Zomboid/Lua/")
        ShopItems = {}
        return
    end
    ShopItems = {}
    local line = fileReader:readLine()
    while line do
        if not line:match("^%s*#") and line:match("%S") then
            local category, target, quantity, price = line:match("^([^|]+)|([^|]+)|(%d+)|(%d+)%s*$")
            if category then
                if not ShopItems[category] then ShopItems[category] = {} end
                table.insert(ShopItems[category], { type = "ITEM", target = target, quantity = tonumber(quantity), price = tonumber(price) })
            else
                print("[FactionEconomy] WARNING: invalid shop line: " .. line)
            end
        end
        line = fileReader:readLine()
    end
    fileReader:close()
    DebugPrintFactionsEconomy("Shop items loaded")
end

-- args.rowIndex, example: 1,2,3
-- args.rowId, example: "survival", "farming"
local function buyItem(module, command, player, args)
    local rowId    = args.rowId
    local index    = args.rowIndex

    -- Validate category
    local category = ShopItems[rowId]
    if not category then
        DebugPrintFactionsEconomy(string.format("Row not found: %s, player: %s", tostring(rowId), player:getUsername()))
        return
    end

    -- Validate item
    -- item.type, item.target, item.quantity, item.price
    local item = category[index]
    if not item then
        DebugPrintFactionsEconomy(string.format("Item not found at index: %s, player: %s", tostring(index),
            player:getUsername()))
        return
    end

    if item.type ~= "ITEM" then return end

    local username = player:getUsername()

    -- No currency registered for the player
    local balance = FactionsEconomyCurrencyData[username]
    if not balance then
        DebugPrintFactionsEconomy(string.format("No currency registered for: %s", username))
        return
    end

    -- Check if player has enough currency to buy the item
    if balance < item.price then
        DebugPrintFactionsEconomy(string.format("Not enough currency — %s: %d/%d", username, balance, item.price))
        return
    end

    -- Deduct the price from the player's balance
    FactionsEconomyCurrencyData[username] = balance - item.price
    DebugPrintFactionsEconomy(string.format("%s bought %s for %d", username, item.target, item.price))

    -- Spawn and deliver items to the player
    -- B42: instanceItem + AddItem + sendAddItemToContainer per unit
    for i = 1, item.quantity do
        local newItem = instanceItem(item.target)
        if newItem then
            player:getInventory():AddItem(newItem)
            sendAddItemToContainer(player:getInventory(), newItem)
        else
            DebugPrintFactionsEconomy(string.format("Failed to instance item: %s", item.target))
        end
    end
end

local function getShopItems(module, command, player, args)
    sendServerCommand(player, "FactionsEconomyShop", "receiveShopItems", ShopItems)
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "FactionsEconomyShop" and command == "buyItem" then
        buyItem(module, command, player, args);
    elseif module == "FactionsEconomyShop" and command == "getShopItems" then
        getShopItems(module, command, player, args);
    end
end)

LoadShopItems();
