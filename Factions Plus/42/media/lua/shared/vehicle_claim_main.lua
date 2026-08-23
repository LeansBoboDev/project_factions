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

-- Shows a red halo text and a chat message to the local player when a claimed
-- vehicle action is blocked. Only runs client-side; no-ops on the server.
local function notifyBlocked(character, textKey)
    if isServer() then return end
    HaloTextHelper.addBadText(character, getText("IGUI_FactionsPlus_Vehicle_AccessDenied"))
    if not ISChat or not ISChat.instance or not ISChat.instance.chatText then return end
    local text = getText(textKey)
    local msg = {
        getText           = function(_) return "<RGB:1,0.3,0.3>" .. text end,
        getTextWithPrefix = function(_) return "<RGB:1,0.3,0.3>" .. text end,
        isServerAlert     = function(_) return false end,
        isShowAuthor      = function(_) return false end,
        getAuthor         = function(_) return nil end,
        setShouldAttractZombies = function(_) return false end,
        setOverHeadSpeech       = function(_) return false end,
    }
    ISChat.addLineInChat(msg, 0)
end

-- Blocks non-members from hotwiring, starting the engine, siphoning fuel, or
-- uninstalling parts (tires, engine parts...) on a claimed vehicle. Same
-- shared/authoritative pattern as the door check above.
local Original_ISHotwireVehicle_isValid = ISHotwireVehicle.isValid
function ISHotwireVehicle:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.character:getVehicle(), self.character) then
        notifyBlocked(self.character, "IGUI_FactionsPlus_Vehicle_AccessDenied")
        return false
    end
    return Original_ISHotwireVehicle_isValid(self)
end

local Original_ISStartVehicleEngine_isValid = ISStartVehicleEngine.isValid
function ISStartVehicleEngine:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.character:getVehicle(), self.character) then
        notifyBlocked(self.character, "IGUI_FactionsPlus_Vehicle_AccessDenied")
        return false
    end
    return Original_ISStartVehicleEngine_isValid(self)
end

local Original_ISTakeGasolineFromVehicle_isValid = ISTakeGasolineFromVehicle.isValid
function ISTakeGasolineFromVehicle:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.vehicle, self.character) then
        notifyBlocked(self.character, "IGUI_FactionsPlus_Vehicle_AccessDenied")
        return false
    end
    return Original_ISTakeGasolineFromVehicle_isValid(self)
end

local Original_ISUninstallVehiclePart_isValid = ISUninstallVehiclePart.isValid
function ISUninstallVehiclePart:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.vehicle, self.character) then
        if not self.action then
            notifyBlocked(self.character, "IGUI_FactionsPlus_Vehicle_PartBlocked")
        end
        return false
    end
    return Original_ISUninstallVehiclePart_isValid(self)
end

-- ISSmashWindow is also used for house/building windows (self.vehiclePart is nil then),
-- so only enforce the claim check for actual vehicle windows.
local Original_ISSmashWindow_isValid = ISSmashWindow.isValid
function ISSmashWindow:isValid()
    if self.vehiclePart and not FactionsPlusVehicleClaim.isAllowed(self.vehiclePart:getVehicle(), self.character) then
        notifyBlocked(self.character, "IGUI_FactionsPlus_Vehicle_AccessDenied")
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

-- ============================================================
-- Client-side claim data sync
-- ============================================================
-- vehicle_claim.lua (server-only) sets FactionsPlusVehicleClaimData via ModData, but
-- that global is never initialized on the client. Without it, getClaim() always returns
-- nil on the client, so isAllowed() always returns true and isValid() never fires,
-- letting smashCarWindow() run in ISSmashWindow.start() before the server can block it.
--
-- Fix: initialize the client's copy from ModData on login, then keep it current via
-- targeted broadcasts sent whenever a claim is created or removed.

Events.OnInitGlobalModData.Add(function()
    if isClient() and not FactionsPlusIsSinglePlayer then
        FactionsPlusVehicleClaimData = ModData.getOrCreate("FactionsPlusVehicleClaim")
    end
end)

-- When the player is in the world, request all existing claims from the server.
-- broadcastClaimSync only reaches players online at the moment of a claim, so
-- a player who connects after a claim was made would have a stale (empty) local
-- table and isAllowed() would incorrectly allow part uninstalls/etc.
-- OnGameStart fires before the character is ready in multiplayer, so we wait
-- via OnTick until getSpecificPlayer(0) returns a valid object.
local _allClaimsRequested = false
Events.OnTick.Add(function()
    if _allClaimsRequested then return end
    if not isClient() or FactionsPlusIsSinglePlayer then
        _allClaimsRequested = true
        return
    end
    local player = getSpecificPlayer(0)
    if not player then return end
    sendClientCommand(player, "FactionsPlusVehicle", "getAllClaims", {})
    _allClaimsRequested = true
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "FactionsPlusVehicle" then return end
    if command == "claimSync" then
        if not FactionsPlusVehicleClaimData then FactionsPlusVehicleClaimData = {} end
        FactionsPlusVehicleClaimData[args.keyId] = args.claim
    elseif command == "unclaimSync" then
        if FactionsPlusVehicleClaimData then
            FactionsPlusVehicleClaimData[args.keyId] = nil
        end
    end
end)
