-- ============================================================
-- Water Need Reducer
-- ============================================================

if not getSandboxOptions():getOptionByName("FactionsPlus.EnableReduceWaterNeed"):getValue() then return end

-- ── FluidContainer water consumption (B42) ──────────────────
-- Halve the millilitres consumed per watering use
local function onGameStart()
    ZomboidGlobals.farmingFluidContainerMillilitresPerUse =
        ZomboidGlobals.farmingFluidContainerMillilitresPerUse *
        getSandboxOptions():getOptionByName("FactionsPlus.ReduceWaterNeedPercentage"):getValue()

    DebugPrintFactionsPlus(string.format("farmingFluidContainerMillilitresPerUse reduced to: %d",
        ZomboidGlobals.farmingFluidContainerMillilitresPerUse))
end
Events.OnGameStart.Add(onGameStart)

-- ── Drainable water consumption (legacy items) ──────────────
-- Apply the same percentage multiplier as FluidContainer
local oldUseItemOneUnit = ISWaterPlantAction.useItemOneUnit
function ISWaterPlantAction:useItemOneUnit()
    local percentage = getSandboxOptions():getOptionByName("FactionsPlus.ReduceWaterNeedPercentage"):getValue()

    -- Accumulate fractional usage — only consume when it reaches 1.0
    self._useAccumulator = (self._useAccumulator or 0) + percentage
    if self._useAccumulator >= 1.0 then
        self._useAccumulator = self._useAccumulator - 1.0
        oldUseItemOneUnit(self)
    end
end
