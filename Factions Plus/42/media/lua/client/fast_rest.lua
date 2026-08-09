-- ============================================================
-- Fast Rest — Client Side
-- ============================================================

if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastRest"):getValue() then return end


local player

local accumulator = 0
local function OnTick()
    local delta = GameTime.getInstance():getRealworldSecondsSinceLastUpdate()
    accumulator = accumulator + delta

    if accumulator < 1.0 then return end
    accumulator = 0

    if player:isResting() then
        local stats = player:getStats()

        local enduranceIncreaser = getSandboxOptions():getOptionByName("FactionsPlus.RestEnduranceReceive"):getValue() / 100

        stats:add(CharacterStat.ENDURANCE, enduranceIncreaser)
        sendPlayerStat(player, CharacterStat.ENDURANCE)

        DebugPrintFactionsPlus(string.format(
            "[FastRest] endurance=%.4f",
            stats:get(CharacterStat.ENDURANCE)
        ))
    else
        Events.OnTick.Remove(OnTick)
    end
end

local oldRestStart = ISRestAction.start
function ISRestAction:start()
    oldRestStart(self)

    if self.character ~= getPlayer() then return end

    player = self.character
    accumulator = 0
    Events.OnTick.Add(OnTick)
end

local oldResetResting = ISRestAction.resetResting
function ISRestAction:resetResting()
    oldResetResting(self)
    Events.OnTick.Remove(OnTick)
end
