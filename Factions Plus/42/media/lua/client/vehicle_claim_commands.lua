-- ============================================================
-- Vehicle Claim — Chat Commands & Radial Menu
-- ============================================================

require "Vehicles/TimedActions/ISEnterVehicle"
require "Vehicles/TimedActions/ISExitVehicle"
require "Vehicles/TimedActions/ISAttachTrailerToVehicle"
require "Vehicles/TimedActions/ISDetachTrailerFromVehicle"

local function addLineToChat(message, color)
    if type(color) ~= "string" then
        color = "<RGB:1,1,1>"
    end

    local msg = {
        getText           = function(_) return color .. message end,
        getTextWithPrefix = function(_) return color .. message end,
        isServerAlert     = function(_) return false end,
        isShowAuthor      = function(_) return false end,
        getAuthor         = function(_) return nil end,
        setShouldAttractZombies = function(_) return false end,
        setOverHeadSpeech       = function(_) return false end,
    }

    if not ISChat.instance then return end
    if not ISChat.instance.chatText then return end
    ISChat.addLineInChat(msg, 0)
end

local function resolveKey(key, p1)
    if p1 ~= nil then return getText(key, p1) end
    return getText(key)
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "FactionsPlusVehicle" then return end
    if command == "message" then
        addLineToChat(resolveKey(args.key, args.p1))
    end
end)

local _originalOnCommandEntered = ISChat.onCommandEntered

ISChat.onCommandEntered = function(self)
    local input = ISChat.instance.textEntry:getText()

    if input and luautils.stringStarts(input, "/") then
        local parts = {}
        for word in input:sub(2):gmatch("%S+") do
            table.insert(parts, word)
        end
        local cmd = parts[1] and parts[1]:lower()

        if cmd == "vehicleclaim" then
            sendClientCommand("FactionsPlusVehicle", "claim", {})
            ISChat.instance.textEntry:setText("")
            ISChat.instance:unfocus()
            return
        end
    end

    _originalOnCommandEntered(self)
end

-- ============================================================
-- Vehicle Claim — Radial Menu ("hold V" while driving)
-- ============================================================

local function onClaimVehicle(playerObj, vehicle)
    local keyId = vehicle and vehicle:getKeyId() or nil
    sendClientCommand(playerObj, "FactionsPlusVehicle", "claim", { keyId = keyId })
end

-- Inside vehicle: radial menu while seated/driving
local _originalShowRadialMenu = ISVehicleMenu.showRadialMenu

ISVehicleMenu.showRadialMenu = function(playerObj)
    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    local wasVisible = menu:isReallyVisible()

    _originalShowRadialMenu(playerObj)

    if wasVisible then return end

    local vehicle = playerObj:getVehicle()
    if not vehicle then return end

    menu:addSlice(getText("IGUI_FactionsPlus_Vehicle_ClaimOption"),
        getTexture("media/ui/vehicles/factions_vehicle_claim.png"), onClaimVehicle, playerObj, vehicle)
end

-- Outside vehicle: radial menu while standing near it (pressing V outside)
local _originalShowRadialMenuOutside = ISVehicleMenu.showRadialMenuOutside

ISVehicleMenu.showRadialMenuOutside = function(playerObj)
    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    local wasVisible = menu:isReallyVisible()

    _originalShowRadialMenuOutside(playerObj)

    if wasVisible then return end

    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if not vehicle then return end

    if menu:isEmpty() then return end

    menu:addSlice(getText("IGUI_FactionsPlus_Vehicle_ClaimOption"),
        getTexture("media/ui/vehicles/factions_vehicle_claim.png"), onClaimVehicle, playerObj, vehicle)
end

-- ============================================================
-- Vehicle Claim — Entering & Towing
-- ============================================================
-- ISEnterVehicle and the tow actions only exist client-side, so unlike the
-- door/hotwire/siphon/uninstall checks in the shared script, these are
-- optimistic (client-authoritative), same trust level as vanilla's own
-- entering/towing rules.


local Original_ISEnterVehicle_isValid = ISEnterVehicle.isValid
function ISEnterVehicle:isValid()
    if not self.started and not FactionsPlusVehicleClaim.isAllowed(self.vehicle, self.character) then
        HaloTextHelper.addBadText(self.character, getText("IGUI_FactionsPlus_Vehicle_AccessDenied"))
        return false
    end
    return Original_ISEnterVehicle_isValid(self)
end

local Original_ISAttachTrailerToVehicle_isValid = ISAttachTrailerToVehicle.isValid
function ISAttachTrailerToVehicle:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.vehicleA, self.character) or
            not FactionsPlusVehicleClaim.isAllowed(self.vehicleB, self.character) then
        HaloTextHelper.addBadText(self.character, getText("IGUI_FactionsPlus_Vehicle_AccessDenied"))
        return false
    end
    return Original_ISAttachTrailerToVehicle_isValid(self)
end

local Original_ISDetachTrailerFromVehicle_isValid = ISDetachTrailerFromVehicle.isValid
function ISDetachTrailerFromVehicle:isValid()
    if not FactionsPlusVehicleClaim.isAllowed(self.vehicle, self.character) or
            not FactionsPlusVehicleClaim.isAllowed(self.vehicle:getVehicleTowing(), self.character) then
        HaloTextHelper.addBadText(self.character, getText("IGUI_FactionsPlus_Vehicle_AccessDenied"))
        return false
    end
    return Original_ISDetachTrailerFromVehicle_isValid(self)
end

-- ============================================================
-- Vehicle Claim — Notify server on exit
-- ============================================================
-- Lets the server snapshot the vehicle's condition the moment someone gets
-- out, instead of waiting for the next EveryOneMinute poll (see
-- vehicle_claim_protect.lua). Without this, a driver who crashes and hops
-- out fast enough could exit before the next poll ever records the crashed
-- state, so the vehicle would later get "repaired" back to an older,
-- better snapshot for free.

local Original_ISExitVehicle_perform = ISExitVehicle.perform
function ISExitVehicle:perform()
    local vehicle = self.character:getVehicle()
    Original_ISExitVehicle_perform(self)
    if vehicle then
        sendClientCommand(self.character, "FactionsPlusVehicle", "vehicleExited", { keyId = vehicle:getKeyId() })
    end
end
