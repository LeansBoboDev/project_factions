-- ============================================================
-- Fast Rest — Server Side
-- ============================================================

if not isServer() then return end
if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastRest"):getValue() then return end

local enduranceIncreaser = getSandboxOptions():getOptionByName("FactionsPlus.RestEnduranceReceive"):getValue() / 100

local restingPlayers = {}

local accumulator = 0
local function onTick()
    local delta = GameTime.getInstance():getRealworldSecondsSinceLastUpdate()
    accumulator = accumulator + delta
    if accumulator < 1.0 then return end
    accumulator = 0

    local toRemove = {}
    for username, playerObj in pairs(restingPlayers) do
        if not playerObj:isResting() then
            toRemove[#toRemove + 1] = username
        else
            local stats = playerObj:getStats()
            stats:add(CharacterStat.ENDURANCE, enduranceIncreaser)
            DebugPrintFactionsPlus(string.format(
                "[FastRest][Server] %s endurance=%.4f",
                username,
                stats:get(CharacterStat.ENDURANCE)
            ))
        end
    end
    for _, username in ipairs(toRemove) do
        restingPlayers[username] = nil
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
