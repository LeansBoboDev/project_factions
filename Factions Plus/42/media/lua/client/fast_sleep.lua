-- ============================================================
-- Fast Sleep — Client Side
-- ============================================================

if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastSleep"):getValue() then return end

local player

local function OnTick()
    if not player or not player:isAsleep() then
        Events.OnTick.Remove(OnTick)
        player = nil
        return
    end

    if player:getStats():get(CharacterStat.FATIGUE) <= 0 then
        getSleepingEvent():wakeUp(player)
        sendClientCommand(player, "FastSleep", "stopSleep", {})
        Events.OnTick.Remove(OnTick)
        player = nil
    end
end

local oldOnSleepWalkToComplete = ISWorldObjectContextMenu.onSleepWalkToComplete
function ISWorldObjectContextMenu.onSleepWalkToComplete(playerId, bed)
    oldOnSleepWalkToComplete(playerId, bed)

    local playerObj = getSpecificPlayer(playerId)
    if not playerObj or not playerObj:isAsleep() then return end

    player = playerObj
    sendClientCommand(player, "FastSleep", "startSleep", {})
    Events.OnTick.Add(OnTick)
end
