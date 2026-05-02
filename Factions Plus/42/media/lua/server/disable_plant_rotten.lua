if not getSandboxOptions():getOptionByName("FactionsPlus.DisablePlantRotten"):getValue() then return end

function SPlantGlobalObject:rottenThis()
    -- When the code call for rotten, reset grow state
    local maxNbOfGrow = farming_vegetableconf.props[self.typeOfSeed].fullGrown
    self.nbOfGrow = maxNbOfGrow;
end
