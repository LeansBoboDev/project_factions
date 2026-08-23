if isClient() and not FactionsPlusIsSinglePlayer then return end

-- { [vehicle:getKeyId()] = { KeyId = 123, Owner = "playerUsername", Members = { "friendUsername" } } }
FactionsPlusVehicleClaimData = {}

local broadcastClaimSync

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

-- Returns the vehicle the player is in, or a nearby vehicle matching keyId (for outside claiming).
local function findVehicle(player, args)
    local v = player:getVehicle()
    if v then return v end
    local keyId = args and args.keyId
    if not keyId then return nil end
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    for dx = -4, 4 do
        for dy = -4, 4 do
            local sq = getCell():getGridSquare(px + dx, py + dy, pz)
            if sq then
                local candidate = sq:getVehicleContainer()
                if candidate and candidate:getKeyId() == keyId then
                    return candidate
                end
            end
        end
    end
    return nil
end

local function claimVehicle(player, args)
    if not getSandboxOption("FactionsPlus.EnableVehicleClaim") then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_Disabled")
        return
    end

    local username = player:getUsername()
    local vehicle = findVehicle(player, args)
    if not vehicle then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NoVehicle")
        return
    end

    local keyId = vehicle:getKeyId()
    if not player:getInventory():haveThisKeyId(keyId) then
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NoKey")
        return
    end

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

    local vehicleName = "Vehicle #" .. tostring(keyId)
    local ok, name = pcall(function() return vehicle:getScript():getFullName() end)
    if ok and name and name ~= "" then vehicleName = name end

    FactionsPlusVehicleClaimData[keyId] = {
        KeyId        = keyId,
        Owner        = username,
        Members      = {},
        VehicleName  = vehicleName,
    }

    deductCurrency(player, cost)

    broadcastClaimSync(keyId, FactionsPlusVehicleClaimData[keyId])
    DebugPrintFactionsPlus(string.format("[VehicleClaim] %s claimed vehicle (keyId %d)", username, keyId))
    notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_Claimed")
    triggerEvent("OnFactionsPlusVehicleClaimed", vehicle, player)
end

local function unclaimVehicle(player, args)
    local username = player:getUsername()
    local vehicle = findVehicle(player, args)
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
    broadcastClaimSync(keyId, nil)
    DebugPrintFactionsPlus(string.format("[VehicleClaim] %s unclaimed vehicle (keyId %d)", username, keyId))
    notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_Unclaimed")
    triggerEvent("OnFactionsPlusVehicleUnclaimed", vehicle, username)
end

local function setMember(player, targetUsername, add, args)
    local username = player:getUsername()
    local vehicle = findVehicle(player, args)
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
        broadcastClaimSync(keyId, claim)
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_MemberAdded", targetUsername)
        DebugPrintFactionsPlus(string.format("[VehicleClaim] %s added %s to vehicle (keyId %d)", username,
            targetUsername, keyId))
    else
        for i, member in ipairs(claim.Members) do
            if member == targetUsername then
                table.remove(claim.Members, i)
                broadcastClaimSync(keyId, claim)
                notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_MemberRemoved", targetUsername)
                DebugPrintFactionsPlus(string.format("[VehicleClaim] %s removed %s from vehicle (keyId %d)", username,
                    targetUsername, keyId))
                return
            end
        end
        notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_NotMember", targetUsername)
    end
end

-- Broadcasts a claim add or remove to every connected client so their local
-- FactionsPlusVehicleClaimData stays current for client-side isValid() checks.
broadcastClaimSync = function(keyId, claim)
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        if claim then
            sendServerCommand(players:get(i), "FactionsPlusVehicle", "claimSync", {
                keyId = keyId,
                claim = { Owner = claim.Owner, Members = claim.Members, VehicleName = claim.VehicleName },
            })
        else
            sendServerCommand(players:get(i), "FactionsPlusVehicle", "unclaimSync", { keyId = keyId })
        end
    end
end

Events.OnInitGlobalModData.Add(function(isNewGame)
    FactionsPlusVehicleClaimData = ModData.getOrCreate("FactionsPlusVehicleClaim")
    -- Direct weapon attacks on vehicle windows go through VehicleCommands.damageWindow
    -- (module='vehicle', command='damageWindow'), completely bypassing ISSmashWindow.
    -- Wrap VehicleCommands.OnClientCommand here (after all scripts are loaded) to block
    -- that path for claimed vehicles.
    if VehicleCommands and VehicleCommands.OnClientCommand then
        local _orig = VehicleCommands.OnClientCommand
        Events.OnClientCommand.Remove(_orig)
        VehicleCommands.OnClientCommand = function(module, command, player, args)
            if module == "vehicle" and command == "damageWindow" and args then
                local vehicle = getVehicleById(args.vehicle)
                if vehicle and not FactionsPlusVehicleClaim.isAllowed(vehicle, player) then
                    DebugPrintFactionsPlus(string.format("[VehicleClaim] blocked direct window attack on vehicle (keyId %d) by %s",
                        vehicle:getKeyId(), player:getUsername()))
                    return
                end
            end
            _orig(module, command, player, args)
        end
        Events.OnClientCommand.Add(VehicleCommands.OnClientCommand)
    end
end)

local function sendMyVehicles(player)
    local username = player:getUsername()
    local list = {}
    for keyId, claim in pairs(FactionsPlusVehicleClaimData) do
        if claim.Owner == username then
            table.insert(list, {
                keyId   = keyId,
                name    = claim.VehicleName or ("Vehicle #" .. tostring(keyId)),
                members = claim.Members or {},
            })
        end
    end
    sendServerCommand(player, "FactionsPlusVehicle", "myVehiclesList", { vehicles = list })
end

local function unclaimByKeyId(player, args)
    local username = player:getUsername()
    local keyId = args and args.keyId
    if not keyId then return end

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
    broadcastClaimSync(keyId, nil)
    DebugPrintFactionsPlus(string.format("[VehicleClaim] %s unclaimed vehicle (keyId %d) via panel", username, keyId))
    notifyPlayer(player, "IGUI_FactionsPlus_Vehicle_Unclaimed")
    sendMyVehicles(player)
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "FactionsPlusVehicle" then return end

    if command == "claim" then
        claimVehicle(player, args)
    elseif command == "unclaim" then
        unclaimVehicle(player, args)
    elseif command == "addMember" then
        setMember(player, args.username, true, args)
    elseif command == "removeMember" then
        setMember(player, args.username, false, args)
    elseif command == "getMyVehicles" then
        sendMyVehicles(player)
    elseif command == "unclaimByKeyId" then
        unclaimByKeyId(player, args)
    elseif command == "getAllClaims" then
        local count = 0
        for keyId, claim in pairs(FactionsPlusVehicleClaimData) do
            sendServerCommand(player, "FactionsPlusVehicle", "claimSync", {
                keyId = keyId,
                claim = { Owner = claim.Owner, Members = claim.Members, VehicleName = claim.VehicleName },
            })
            count = count + 1
        end
        DebugPrintFactionsPlus(string.format("[VehicleClaim] getAllClaims for %s: sent %d claims", player:getUsername(), count))
    end
end)
