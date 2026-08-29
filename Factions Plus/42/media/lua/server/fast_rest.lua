-- ============================================================
-- Fast Rest — Server Side
-- ============================================================

if not isServer() then return end
if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastRest"):getValue() then return end

local enduranceIncreaser = getSandboxOptions():getOptionByName("FactionsPlus.RestEnduranceReceive"):getValue() / 10000
local SYNC_ENDURANCE = SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.ENDURANCE)

local restingPlayers = {}

local accumulator = 0
local function onTick()
    local delta = GameTime.getInstance():getRealworldSecondsSinceLastUpdate()
    accumulator = accumulator + delta
    if accumulator < 1.0 then return end
    accumulator = 0

    for username, playerObj in pairs(restingPlayers) do
        if not playerObj then
            restingPlayers[username] = nil
        else
            local stats = playerObj:getStats()
            if not stats then
                restingPlayers[username] = nil
            else
                stats:add(CharacterStat.ENDURANCE, enduranceIncreaser)
                syncPlayerStats(playerObj, SYNC_ENDURANCE)
                DebugPrintFactionsPlus(string.format(
                    "[FastRest][Server] %s endurance=%.4f",
                    username,
                    stats:get(CharacterStat.ENDURANCE)
                ))
            end
        end
    end
end
Events.OnTick.Add(onTick)

local function onClientCommand(module, command, playerObj, args)
    if module ~= "FastRest" then return end

    local username = playerObj:getUsername()

    if command == "startRest" then
        restingPlayers[username] = playerObj
        DebugPrintFactionsPlus("[FastRest][Server] " .. username .. " started resting")
    elseif command == "stopRest" then
        restingPlayers[username] = nil
        DebugPrintFactionsPlus("[FastRest][Server] " .. username .. " stopped resting")
    end
end
Events.OnClientCommand.Add(onClientCommand)

