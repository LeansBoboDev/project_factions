if isClient() and not FactionsPlusIsSinglePlayer then return end

-- ============================================================
-- Vehicle Claim — Freeze condition while parked
-- ============================================================
-- There's no game hook to cancel vehicle damage outright (crashes, zombie
-- attacks and explosions all apply it straight from Java), so instead every
-- in-game minute we either:
--   - snapshot part conditions, while the vehicle is occupied. This never
--     restores anything - normal wear/crashes caused by the owner/members
--     while driving are recorded as-is, not healed.
--   - once it's empty, enforce that last snapshot as a floor: any further
--     drop in condition (from other players, zombies, explosions...) gets
--     reverted back to it. The vehicle stays frozen exactly as its owner
--     left it - it's never repaired past that, so this can't be used to
--     get free maintenance, only to stop vandalism while unattended.
-- The snapshot lives inside the claim entry itself (ModData-backed), so it
-- is cleared automatically when the vehicle is unclaimed.
--
-- The EveryOneMinute poll alone leaves a gap: if the owner crashes and exits
-- fast enough, the vehicle could go from occupied to empty between two polls
-- without ever recording the crashed state, so the next poll would freeze it
-- at an older, better snapshot than it actually deserves (a free "repair" by
-- accident). To close that, the client also pings us the moment ISExitVehicle
-- completes, so we can snapshot right away instead of waiting for the poll.

local function isVehicleOccupied(vehicle)
    for seat = 0, vehicle:getMaxPassengers() - 1 do
        if vehicle:getCharacter(seat) then return true end
    end
    return false
end

local function captureConditions(vehicle)
    local snapshot = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if part:getInventoryItem() then
            snapshot[i] = part:getCondition()
        end
    end
    return snapshot
end

local function restoreConditions(vehicle, snapshot)
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local item = part:getInventoryItem()
        local savedCondition = snapshot[i]
        if item and savedCondition and part:getCondition() < savedCondition then
            part:setCondition(savedCondition)
            part:doInventoryItemStats(item, 0)
            vehicle:transmitPartCondition(part)
        end
    end
end

local function protectClaimedVehicles()
    if not FactionsPlusVehicleClaimData then return end
    if not getSandboxOptions():getOptionByName("FactionsPlus.EnableVehicleClaim"):getValue() then return end

    local iter = getCell():getVehicles():iterator()
    while iter:hasNext() do
        local vehicle = iter:next()
        local claim = FactionsPlusVehicleClaim.getClaim(vehicle)
        if claim then
            if isVehicleOccupied(vehicle) then
                claim.Condition = captureConditions(vehicle)
            elseif claim.Condition then
                restoreConditions(vehicle, claim.Condition)
            else
                -- First time we see this claimed vehicle (e.g. server just
                -- started) - just establish a baseline, don't change anything.
                claim.Condition = captureConditions(vehicle)
            end
        end
    end
end

Events.EveryOneMinute.Add(protectClaimedVehicles)

local function findVehicleByKeyId(keyId)
    local vehicles = getCell():getVehicles()
    for i = 0, vehicles:size() - 1 do
        local vehicle = vehicles:get(i)
        if vehicle:getKeyId() == keyId then return vehicle end
    end
    return nil
end

-- Sent by the client right as it finishes exiting a vehicle (see
-- ISExitVehicle:perform() in vehicle_claim_commands.lua). We don't trust the
-- client with the snapshot itself - just the keyId - and read the actual
-- condition off our own authoritative vehicle object.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "FactionsPlusVehicle" or command ~= "vehicleExited" then return end

    local claim = FactionsPlusVehicleClaimData and FactionsPlusVehicleClaimData[args.keyId]
    if not claim then return end

    local vehicle = findVehicleByKeyId(args.keyId)
    if vehicle and not isVehicleOccupied(vehicle) then
        claim.Condition = captureConditions(vehicle)
    end
end)
