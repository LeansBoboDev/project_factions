require "Vehicles/TimedActions/ISOpenVehicleDoor"
require "Vehicles/TimedActions/ISHotwireVehicle"
require "Vehicles/TimedActions/ISStartVehicleEngine"
require "Vehicles/TimedActions/ISTakeGasolineFromVehicle"
require "Vehicles/TimedActions/ISUninstallVehiclePart"
require "TimedActions/ISSmashWindow"

LuaEventManager.AddEvent("OnFactionsPlusVehicleClaimed")
LuaEventManager.AddEvent("OnFactionsPlusVehicleUnclaimed")

FactionsPlusVehicleClaim = {}

function FactionsPlusVehicleClaim.getClaim(vehicle)
    if not vehicle then return nil end
    if not FactionsPlusVehicleClaimData then return nil end
    return FactionsPlusVehicleClaimData[vehicle:getKeyId()]
end

-- Unclaimed vehicles behave exactly like vanilla (lock/key only). A claim only
-- ever restricts further, on top of whatever the vanilla lock state already allows.
function FactionsPlusVehicleClaim.isAllowed(vehicle, player)
    if not getSandboxOptions():getOptionByName("FactionsPlus.EnableVehicleClaim"):getValue() then return true end

    local claim = FactionsPlusVehicleClaim.getClaim(vehicle)
    if not claim then return true end

    local username = player:getUsername()
    if claim.Owner == username then return true end
    for _, member in ipairs(claim.Members) do
        if member == username then return true end
    end
    return false
end

-- Blocks non-members from opening any vehicle door that exposes lootable storage
-- (trunk, glovebox, truck bed...) regardless of the vanilla lock state, so a claimed
-- vehicle's items stay protected even if it was left unlocked or the lock was bypassed.
-- This is a shared script so the check runs authoritatively on the server as well as
-- (optimistically) on the client, same as vanilla's own isLocked() check below.
local Original_ISOpenVehicleDoor_complete = ISOpenVehicleDoor.complete
function ISOpenVehicleDoor:complete()
    if self.vehicle and self.part and self.part:getItemContainer() then
        if not FactionsPlusVehicleClaim.isAllowed(self.vehicle, self.character) then
            local door = self.part:getDoor()
            if door then
                if door:isOpen() then door:setOpen(false) end
                door:setLocked(true)
                self.vehicle:transmitPartDoor(self.part)
            end
            triggerEvent("OnContainerUpdate")
            return true
        end
    end
    return Original_ISOpenVehicleDoor_complete(self)
end

-- Blocks non-members from hotwiring, starting the engine, siphoning fuel, or
-- uninstalling parts (tires, engine parts...) on a claimed vehicle. Same
-- shared/authoritative pattern as the door check above.
local Original_ISHotwireVehicle_isValid = ISHotwireVehicle.isValid
function ISHotwireVehicle:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.character:getVehicle(), self.character) then
        return false
    end
    return Original_ISHotwireVehicle_isValid(self)
end

local Original_ISStartVehicleEngine_isValid = ISStartVehicleEngine.isValid
function ISStartVehicleEngine:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.character:getVehicle(), self.character) then
        return false
    end
    return Original_ISStartVehicleEngine_isValid(self)
end

local Original_ISTakeGasolineFromVehicle_isValid = ISTakeGasolineFromVehicle.isValid
function ISTakeGasolineFromVehicle:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.vehicle, self.character) then
        return false
    end
    return Original_ISTakeGasolineFromVehicle_isValid(self)
end

local Original_ISUninstallVehiclePart_isValid = ISUninstallVehiclePart.isValid
function ISUninstallVehiclePart:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.vehicle, self.character) then
        return false
    end
    return Original_ISUninstallVehiclePart_isValid(self)
end

-- ISSmashWindow is also used for house/building windows (self.vehiclePart is nil then),
-- so only enforce the claim check for actual vehicle windows.
local Original_ISSmashWindow_isValid = ISSmashWindow.isValid
function ISSmashWindow:isValid()
    if self.vehiclePart and not FactionsPlusVehicleClaim.isAllowed(self.vehiclePart:getVehicle(), self.character) then
        return false
    end
    return Original_ISSmashWindow_isValid(self)
end

-- Server-side block: direct weapon attacks bypass isValid() entirely (Java combat path),
-- so we also intercept complete() on the server to prevent the actual window hit.
local Original_ISSmashWindow_complete = ISSmashWindow.complete
function ISSmashWindow:complete()
    if isServer() and self.vehiclePart then
        if not FactionsPlusVehicleClaim.isAllowed(self.vehiclePart:getVehicle(), self.character) then
            return true
        end
    end
    return Original_ISSmashWindow_complete(self)
end
