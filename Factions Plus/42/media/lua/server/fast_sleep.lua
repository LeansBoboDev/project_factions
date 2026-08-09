-- ============================================================
-- Fast Sleep — Server Side
-- ============================================================

if not isServer() then return end
if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastSleep"):getValue() then return end

local fatigueReducer = getSandboxOptions():getOptionByName("FactionsPlus.SleepFatigueReducer"):getValue() / 100
local enduranceIncreaser = getSandboxOptions():getOptionByName("FactionsPlus.SleepEnduranceReceive"):getValue() / 100

local function onClientCommand(module, command, playerObj, args)
    if module ~= "FastSleep" then return end

    if command == "tick" then
        local stats = playerObj:getStats()
        stats:remove(CharacterStat.FATIGUE, fatigueReducer)
        stats:add(CharacterStat.ENDURANCE, enduranceIncreaser)
        DebugPrintFactionsPlus(string.format(
            "[FastSleep][Server] %s fatigue=%.4f endurance=%.4f",
            playerObj:getUsername(),
            stats:get(CharacterStat.FATIGUE),
            stats:get(CharacterStat.ENDURANCE)
        ))
    end
end

Events.OnClientCommand.Add(onClientCommand)
