-- ============================================================
-- Fast Rest — Client Side
-- ============================================================

if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastRest"):getValue() then return end

local player

local function OnTick()
    if not player then
        Events.OnTick.Remove(OnTick)
        return
    end

    if not player:isResting() then
        sendClientCommand(player, "FastRest", "stopRest", {})
        Events.OnTick.Remove(OnTick)
        player = nil
    end
end

local oldRestStart = ISRestAction.start
function ISRestAction:start()
    oldRestStart(self)
    if self.character ~= getPlayer() then return end
    player = self.character
    sendClientCommand(player, "FastRest", "startRest", {})
    Events.OnTick.Add(OnTick)
end
