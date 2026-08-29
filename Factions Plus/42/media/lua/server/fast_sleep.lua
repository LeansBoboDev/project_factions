-- ============================================================
-- Fast Sleep — Server Side
-- ============================================================

if not isServer() then return end
if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastSleep"):getValue() then return end

local fatigueReducer = getSandboxOptions():getOptionByName("FactionsPlus.SleepFatigueReducer"):getValue() / 10000
local enduranceIncreaser = getSandboxOptions():getOptionByName("FactionsPlus.SleepEnduranceReceive"):getValue() / 10000
local SYNC_FATIGUE_ENDURANCE = SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.FATIGUE)
                             + SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.ENDURANCE)

local sleepingPlayers = {}

local accumulator = 0
local function onTick()
    local delta = GameTime.getInstance():getRealworldSecondsSinceLastUpdate()
    accumulator = accumulator + delta
    if accumulator < 1.0 then return end
    accumulator = 0

    for username, playerObj in pairs(sleepingPlayers) do
        if not playerObj then
            sleepingPlayers[username] = nil
        else
            local stats = playerObj:getStats()
            if not stats then
                sleepingPlayers[username] = nil
            else
                stats:remove(CharacterStat.FATIGUE, fatigueReducer)
                stats:add(CharacterStat.ENDURANCE, enduranceIncreaser)
                syncPlayerStats(playerObj, SYNC_FATIGUE_ENDURANCE)
                DebugPrintFactionsPlus(string.format(
                    "[FastSleep][Server] %s fatigue=%.4f endurance=%.4f",
                    username,
                    stats:get(CharacterStat.FATIGUE),
                    stats:get(CharacterStat.ENDURANCE)
                ))
            end
        end
    end
end
Events.OnTick.Add(onTick)

local function onClientCommand(module, command, playerObj, args)
    if module ~= "FastSleep" then return end

    local username = playerObj:getUsername()

    if command == "startSleep" then
        sleepingPlayers[username] = playerObj
        DebugPrintFactionsPlus("[FastSleep][Server] " .. username .. " started sleeping")
    elseif command == "stopSleep" then
        sleepingPlayers[username] = nil
        DebugPrintFactionsPlus("[FastSleep][Server] " .. username .. " stopped sleeping")
    end
end
Events.OnClientCommand.Add(onClientCommand)

