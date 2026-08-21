if isClient() and not FactionsPlusIsSinglePlayer then return end

-- { [vehicle:getKeyId()] = { KeyId = 123, Owner = "playerUsername", Members = { "friendUsername" } } }
FactionsPlusVehicleClaimData = {}

local function getSandboxOption(name)
    return getSandboxOptions():getOptionByName(name):getValue()
end

local function notifyPlayer(player, textKey, p1)
    sendServerCommand(player, "FactionsPlusVehicle", "message", { key = textKey, p1 = p1 })
end

local function countOwnedVehicles(username)
    local count = 0
    for _, claim in pairs(FactionsPlusVehicleClaimData) do
        if claim.Owner == username then
            count = count + 1
        end
    end
    return count
end

-- Cost is optional and paid through Factions Economy's currency, if that mod is present.
local function checkCurrency(player)
    local cost = getSandboxOption("FactionsPlus.VehicleClaimCost")
    if cost <= 0 or not FactionsEconomyCompatibility then return 0 end
    local username = player:getUsername()
    local balance = FactionsEconomyCurrencyData and FactionsEconomyCurrencyData[username] or 0
    if balance < cost then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NoFunds", tostring(cost))
        return false
    end
    return cost
end

local function deductCurrency(player, cost)
    if cost <= 0 or not FactionsEconomyCompatibility then return end
    local username = player:getUsername()
    FactionsEconomyCurrencyData[username] = (FactionsEconomyCurrencyData[username] or 0) - cost
    DebugPrintFactionsPlus(string.format("[VehicleClaim] deducted %d from %s (new balance: %d)", cost, username,
        FactionsEconomyCurrencyData[username]))
end

local function claimVehicle(player)
    if not getSandboxOption("FactionsPlus.EnableVehicleClaim") then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_Disabled")
        return
    end

    local username = player:getUsername()
    local vehicle = player:getVehicle()
    if not vehicle then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NoVehicle")
        return
    end

    local keyId = vehicle:getKeyId()
    if FactionsPlusVehicleClaimData[keyId] then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_AlreadyClaimed")
        return
    end

    local maxClaims = getSandboxOption("FactionsPlus.VehicleClaimMax")
    if maxClaims > 0 and countOwnedVehicles(username) >= maxClaims then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_MaxClaims", tostring(maxClaims))
        return
    end

    local cost = checkCurrency(player)
    if cost == false then return end

    FactionsPlusVehicleClaimData[keyId] = {
        KeyId   = keyId,
        Owner   = username,
        Members = {},
    }

    deductCurrency(player, cost)
    vehicle:setLocked(true)

    DebugPrintFactionsPlus(string.format("[VehicleClaim] %s claimed vehicle (keyId %d)", username, keyId))
    notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_Claimed")
    triggerEvent("OnFactionsPlusVehicleClaimed", vehicle, player)
end

local function unclaimVehicle(player)
    local username = player:getUsername()
    local vehicle = player:getVehicle()
    if not vehicle then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NoVehicle")
        return
    end

    local keyId = vehicle:getKeyId()
    local claim = FactionsPlusVehicleClaimData[keyId]
    if not claim then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NotClaimed")
        return
    end
    if claim.Owner ~= username then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NotOwner")
        return
    end

    FactionsPlusVehicleClaimData[keyId] = nil
    DebugPrintFactionsPlus(string.format("[VehicleClaim] %s unclaimed vehicle (keyId %d)", username, keyId))
    notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_Unclaimed")
    triggerEvent("OnFactionsPlusVehicleUnclaimed", vehicle, username)
end

local function setMember(player, targetUsername, add)
    local username = player:getUsername()
    local vehicle = player:getVehicle()
    if not vehicle then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NoVehicle")
        return
    end
    if not targetUsername or targetUsername == "" then return end

    local keyId = vehicle:getKeyId()
    local claim = FactionsPlusVehicleClaimData[keyId]
    if not claim then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NotClaimed")
        return
    end
    if claim.Owner ~= username then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NotOwner")
        return
    end

    if add then
        for _, member in ipairs(claim.Members) do
            if member == targetUsername then
                notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_AlreadyMember", targetUsername)
                return
            end
        end
        table.insert(claim.Members, targetUsername)
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_MemberAdded", targetUsername)
        DebugPrintFactionsPlus(string.format("[VehicleClaim] %s added %s to vehicle (keyId %d)", username,
            targetUsername, keyId))
    else
        for i, member in ipairs(claim.Members) do
            if member == targetUsername then
                table.remove(claim.Members, i)
                notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_MemberRemoved", targetUsername)
                DebugPrintFactionsPlus(string.format("[VehicleClaim] %s removed %s from vehicle (keyId %d)", username,
                    targetUsername, keyId))
                return
            end
        end
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NotMember", targetUsername)
    end
end

Events.OnInitGlobalModData.Add(function(isNewGame)
    FactionsPlusVehicleClaimData = ModData.getOrCreate("FactionsPlusVehicleClaim")
end)

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "FactionsPlusVehicle" then return end

    if command == "claim" then
        claimVehicle(player)
    elseif command == "unclaim" then
        unclaimVehicle(player)
    elseif command == "addMember" then
        setMember(player, args.username, true)
    elseif command == "removeMember" then
        setMember(player, args.username, false)
    end
end)
