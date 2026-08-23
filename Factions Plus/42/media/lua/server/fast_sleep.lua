-- ============================================================
-- Fast Sleep — Server Side
-- ============================================================

if not isServer() then return end
if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastSleep"):getValue() then return end

local fatigueReducer = getSandboxOptions():getOptionByName("FactionsPlus.SleepFatigueReducer"):getValue() / 100
local enduranceIncreaser = getSandboxOptions():getOptionByName("FactionsPlus.SleepEnduranceReceive"):getValue() / 100

local sleepingPlayers = {}

local accumulator = 0
local function onTick()
    local delta = GameTime.getInstance():getRealworldSecondsSinceLastUpdate()
    accumulator = accumulator + delta
    if accumulator < 1.0 then return end
    accumulator = 0

    local toRemove = {}
    for username, playerObj in pairs(sleepingPlayers) do
        if not playerObj:isAsleep() then
            toRemove[#toRemove + 1] = username
        else
            local stats = playerObj:getStats()
            stats:remove(CharacterStat.FATIGUE, fatigueReducer)
            stats:add(CharacterStat.ENDURANCE, enduranceIncreaser)
            DebugPrintFactionsPlus(string.format(
                "[FastSleep][Server] %s fatigue=%.4f endurance=%.4f",
                username,
                stats:get(CharacterStat.FATIGUE),
                stats:get(CharacterStat.ENDURANCE)
            ))
        end
    end
    for _, username in ipairs(toRemove) do
        sleepingPlayers[username] = nil
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
