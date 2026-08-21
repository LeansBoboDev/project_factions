if isClient() and not FactionsIsSinglePlayer then return end;

--#region Client Requests

local function claimSafehouse(module, command, player, args)
    local faction = GetPlayerFaction(player:getUsername())
    if faction == nil then return end
    if not FactionsData[faction:getName()] then return end

    -- Claim check
    local safehouse = Safehouse.getSafehouse(player:getSquare())
    if not safehouse then
        sendServerCommand(player, "Factions", "claimSafehouseResponse",
            { "Safehouse already claimed" })
        return
    end

    -- Points check
    local points = (FactionsData[faction:getName()]["points"] or 0) - GetFactionUsedPoints(faction)
    if points <= 0 then
        sendServerCommand(player, "Factions", "claimSafehouseResponse",
            { "Not enough points" })
        return
    end

    -- Cost check
    local safehouseCost = GetSafehouseCost(player:getBuilding())
    if safehouseCost > points then
        sendServerCommand(player, "Factions", "claimSafehouseResponse",
            { "Not enough points" })
        return
    end

    -- Safehouse update
    safehouse.setOwner(faction:getOwner())
    safehouse.setPlayers(faction:getPlayers())

    -- Client refresh
    local onlinePlayers = getOnlinePlayers()
    for i = 0, onlinePlayers:size() - 1 do
        local onlinePlayer = onlinePlayers:get(i)
        safehouse.updateSafehouse(onlinePlayer)
    end

    sendServerCommand(player, "Factions", "claimSafehouseResponse",
        { "Success" })
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "Factions" and command == "claimSafehouse" then
        claimSafehouse(module, command, player, args)
    end
end)

--#endregion

--#region Vanilla Safehouse Claim (b42 java patch)

-- Fired server-side by the patched SafehouseClaimPacket right after a vanilla
-- safehouse claim (the "Claim" button in the GUI) is created, before it is
-- synced to clients. The b42 java patch removed the vanilla "one safehouse per
-- player" block, so this is now the only thing stopping a faction from
-- claiming more safehouses than its points afford.
local function onSafehouseClaimed(safehouse, player)
    local faction = GetPlayerFaction(player:getUsername())
    if not faction then
        SafeHouse.removeSafeHouseAndSync(safehouse)
        return
    end

    -- Assign it to the faction first so GetFactionUsedPoints below already
    -- accounts for it, regardless of whether the leader or a member claimed it
    safehouse:setOwner(faction:getOwner())
    safehouse:setPlayers(faction:getPlayers())

    local points = (FactionsData[faction:getName()] and FactionsData[faction:getName()]["points"]) or 0
    local usedPoints = GetFactionUsedPoints(faction)

    if usedPoints > points then
        SafeHouse.removeSafeHouseAndSync(safehouse)
        sendServerCommand(player, "Factions", "claimSafehouseResponse",
            { "Not enough points" })
        return
    end

    sendServerCommand(player, "Factions", "claimSafehouseResponse",
        { "Success" })
end

-- The patched SafehouseClaimPacket triggers this event name, but it only exists
-- as a real Lua event (Events.OnSafehouseClaimed) once something registers it
LuaEventManager.AddEvent("OnSafehouseClaimed")
Events.OnSafehouseClaimed.Add(onSafehouseClaimed)

--#endregion
