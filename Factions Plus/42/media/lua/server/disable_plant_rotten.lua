if isClient() and not FactionsIsSinglePlayer then return end;
if not getSandboxOptions():getOptionByName("FactionsPlus.DisablePlantRotten"):getValue() then return end

-- ============================================================
-- Plant Rotten Disabler
-- ============================================================

-- ── Disable rotten ───────────────────────────────────────────
-- Instead of rotting, keep the plant in harvestable state

local oldRottenThis = SPlantGlobalObject.rottenThis
function SPlantGlobalObject:rottenThis()
    local prop = farming_vegetableconf.props[self.typeOfSeed]
    if not prop then
        oldRottenThis(self)
        return
    end

    -- Reset to harvestable state instead of rotting
    self.state        = "vegetable"
    self.hasVegetable = true
    self.health       = 100
    self:setSpriteName(farming_vegetableconf.getSpriteName(self))
    self:setObjectName(farming_vegetableconf.getObjectName(self))
    self:saveData()
end

-- ── Disable dry ──────────────────────────────────────────────
-- Instead of dying from dehydration, reset water level to minimum

local oldDryThis = SPlantGlobalObject.dryThis
function SPlantGlobalObject:dryThis()
    local prop = farming_vegetableconf.props[self.typeOfSeed]
    if not prop then
        oldDryThis(self)
        return
    end

    -- Reset water to minimum survival level instead of dying
    self.waterLvl      = 10
    self.lastWaterHour = SFarmingSystem.instance.hoursElapsed
    self:saveData()
end
