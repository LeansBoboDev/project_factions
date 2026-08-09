-- ============================================================
-- Fast Rest — Server Side
-- ============================================================

if not isServer() then return end
if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastRest"):getValue() then return end

local enduranceIncreaser = getSandboxOptions():getOptionByName("FactionsPlus.RestEnduranceReceive"):getValue() / 100

local function onClientCommand(module, command, playerObj, args)
    if module ~= "FastRest" then return end

    if command == "addEndurance" then
        local stats = playerObj:getStats()
        stats:add(CharacterStat.ENDURANCE, enduranceIncreaser)
        DebugPrintFactionsPlus(string.format(
            "[FastRest][Server] %s endurance=%.4f",
            playerObj:getUsername(),
            stats:get(CharacterStat.ENDURANCE)
        ))
    end
end

Events.OnClientCommand.Add(onClientCommand)
