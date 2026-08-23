-- ============================================================
-- Fast Rest — Client Side
-- ============================================================

if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastRest"):getValue() then return end

local oldRestStart = ISRestAction.start
function ISRestAction:start()
    oldRestStart(self)
    if self.character ~= getPlayer() then return end
    sendClientCommand(self.character, "FastRest", "startRest", {})
end

local oldResetResting = ISRestAction.resetResting
function ISRestAction:resetResting()
    oldResetResting(self)
    if self.character ~= getPlayer() then return end
    sendClientCommand(self.character, "FastRest", "stopRest", {})
end
