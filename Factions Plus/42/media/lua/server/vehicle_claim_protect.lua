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
        if part:getInventoryItem() or part:getWindow() then
            snapshot[i] = part:getCondition()
        end
    end
    return snapshot
end

local function clearBrokenGlassNear(vehicle)
    local vx = math.floor(vehicle:getX())
    local vy = math.floor(vehicle:getY())
    local vz = math.floor(vehicle:getZ())
    for dx = -3, 3 do
        for dy = -3, 3 do
            local sq = getCell():getGridSquare(vx + dx, vy + dy, vz)
            if sq then
                local toRemove = {}
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    if instanceof(obj, "IsoBrokenGlass") then
                        table.insert(toRemove, obj)
                    end
                end
                for _, obj in ipairs(toRemove) do
                    sq:transmitRemoveItemFromSquare(obj)
                end
            end
        end
    end
end

local function restoreConditions(vehicle, snapshot)
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local savedCondition = snapshot[i]
        if savedCondition then
            -- Part was present in snapshot but is now missing (e.g. window destroyed by melee) — reinstall it.
            local wasReinstalled = false
            if part:getWindow() and not part:getInventoryItem() then
                DebugPrintFactionsPlus(string.format("[VehicleProtect] part %d window missing — reinstalling", i))
                VehicleUtils.createPartInventoryItem(part)
                wasReinstalled = true
            end
            if wasReinstalled or part:getCondition() < savedCondition then
                DebugPrintFactionsPlus(string.format("[VehicleProtect] restoring part %d: %d -> %d", i, part:getCondition(), savedCondition))
                part:setCondition(savedCondition)
                local item = part:getInventoryItem()
                if item then
                    part:doInventoryItemStats(item, 0)
                    vehicle:transmitPartCondition(part)
                    vehicle:transmitPartItem(part)
                end
                if part:getWindow() then
                    vehicle:transmitPartWindow(part)
                end
                if wasReinstalled then
                    vehicle:doDamageOverlay()
                    clearBrokenGlassNear(vehicle)
                end
            end
        end
    end
end

local function protectClaimedVehicles()
    if not FactionsPlusVehicleClaimData then
        DebugPrintFactionsPlus("[VehicleProtect] skipped: FactionsPlusVehicleClaimData is nil")
        return
    end
    if not getSandboxOptions():getOptionByName("FactionsPlus.EnableVehicleClaim"):getValue() then
        DebugPrintFactionsPlus("[VehicleProtect] skipped: EnableVehicleClaim is off")
        return
    end

    local count, claimed = 0, 0
    local iter = getCell():getVehicles():iterator()
    while iter:hasNext() do
        local vehicle = iter:next()
        count = count + 1
        local claim = FactionsPlusVehicleClaim.getClaim(vehicle)
        if claim then
            claimed = claimed + 1
            local keyId = vehicle:getKeyId()
            if isVehicleOccupied(vehicle) then
                claim.Condition = captureConditions(vehicle)
                DebugPrintFactionsPlus(string.format("[VehicleProtect] keyId %d occupied — snapshot updated", keyId))
            elseif claim.Condition then
                restoreConditions(vehicle, claim.Condition)
                DebugPrintFactionsPlus(string.format("[VehicleProtect] keyId %d unoccupied — restore applied", keyId))
            else
                claim.Condition = captureConditions(vehicle)
                DebugPrintFactionsPlus(string.format("[VehicleProtect] keyId %d unoccupied — baseline captured (first time)", keyId))
            end
        end
    end
    DebugPrintFactionsPlus(string.format("[VehicleProtect] poll done: %d vehicles checked, %d claimed", count, claimed))
end

local _protectTick = 0
Events.OnTick.Add(function()
    _protectTick = _protectTick + 1
    local interval = getSandboxOptions():getOptionByName("FactionsPlus.VehicleProtectTickInterval"):getValue()
    if _protectTick >= interval then
        _protectTick = 0
        protectClaimedVehicles()
    end
end)

Events.OnFactionsPlusVehicleClaimed.Add(function(vehicle, player)
    local claim = FactionsPlusVehicleClaim.getClaim(vehicle)
    if claim then
        claim.Condition = captureConditions(vehicle)
        DebugPrintFactionsPlus(string.format("[VehicleProtect] keyId %d claimed — initial snapshot captured", vehicle:getKeyId()))
    else
        DebugPrintFactionsPlus(string.format("[VehicleProtect] keyId %d claimed but getClaim returned nil!", vehicle:getKeyId()))
    end
end)

local function findVehicleByKeyId(keyId)
    local vehicles = getCell():getVehicles()
    if not vehicles then return nil end
    -- getVehicles() returns a Java ArrayList server-side: size()/get(i) with 0-based index
    if vehicles.size then
        for i = 0, vehicles:size() - 1 do
            local v = vehicles:get(i)
            if v and v:getKeyId() == keyId then return v end
        end
    else
        for _, v in pairs(vehicles) do
            if v and v:getKeyId() == keyId then return v end
        end
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
