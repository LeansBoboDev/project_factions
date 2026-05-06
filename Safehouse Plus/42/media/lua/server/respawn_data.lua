if not getSandboxOptions():getOptionByName("SafehousePlus.EnableRespawnMechanic"):getValue() then return end

local RespawnData = {}

--#region Save
local function savePerks(player)
    local username = player:getUsername()
    RespawnData[username]["Perks"] = {}
    local perks = PerkFactory.PerkList

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i)
        RespawnData[username].Perk[tostring(perk)] = {}

        local level = player:getPerkLevel(perk)
        local exp = player:getXp():getXP(perk)
        local boost = player:getXp():getMultiplier(perk)
        local minLV
        local maxLV
        if (level == 0 or level == 1) then
            minLV = 1
            maxLV = 2
        elseif (level == 2 or level == 3) then
            minLV = 3
            maxLV = 4
        elseif (level == 4 or level == 5) then
            minLV = 5
            maxLV = 6
        elseif (level == 6 or level == 7) then
            minLV = 7
            maxLV = 8
        elseif (level == 8 or level == 9) then
            minLV = 9
            maxLV = 10
        else
            minLV = 0
            maxLV = 0
            boost = 0
        end
        RespawnData[username]["Perks"][tostring(perk)].Boost = boost
        RespawnData[username]["Perks"][tostring(perk)].MinLV = minLV
        RespawnData[username]["Perks"][tostring(perk)].MaxLV = maxLV

        RespawnData[username]["Perks"][tostring(perk)].Level = level
        RespawnData[username]["Perks"][tostring(perk)].Exp = exp

        DebugPrintFactionsPlus(string.format("[savePerks] Perk saved %s level: %d", tostring(perk), level))
    end
end

local function saveTraits(player)
    local function removeByValue(tbl, value)
        for i = #tbl, 1, -1 do
            if tbl[i] == value then
                table.remove(tbl, i)
            end
        end
    end

    local username = player:getUsername()
    RespawnData[username]["Traits"] = {}

    for i = 0, player:getCharacterTraits():getKnownTraits():size() - 1 do
        local traitName = tostring(CharacterTraitDefinition.getCharacterTraitDefinition(player:getCharacterTraits()
            :getKnownTraits()
            :get(i)):getType():getName())

        table.insert(RespawnData[username]["Traits"],
            traitName)

        DebugPrintFactionsPlus(string.format("[saveTraits] Trait saved: %s", traitName))
    end

    local prof = CharacterProfessionDefinition.getCharacterProfessionDefinition(player:getDescriptor()
        :getCharacterProfession())
    for i = 0, prof:getGrantedTraits():size() - 1 do
        local traitName = tostring(prof:getGrantedTraits():get(i):getName())
        removeByValue(RespawnData[username]["Traits"], traitName)

        DebugPrintFactionsPlus(string.format("[saveTraits] Trait removed: %s, because the profission already give it",
            traitName))
    end
end

local function saveBookPages(player)
    local username = player:getUsername()
    RespawnData[username]["Books"] = {}

    local allItems = getScriptManager():getAllItems()
    for i = 1, allItems:size() do
        local Search_SkillBook = allItems:get(i - 1)
        if Search_SkillBook:getItemType() == ItemType.LITERATURE then
            if Search_SkillBook:getSkillTrained() ~= "" and SkillBook[Search_SkillBook:getSkillTrained()] ~= nil then
                local bookName = Search_SkillBook:getFullName()
                RespawnData[username]["Books"][bookName] = player:getAlreadyReadPages(bookName)

                DebugPrintFactionsPlus(string.format(
                    "[saveBookPages] Book pages added: %s, pages: %d",
                    bookName, player:getAlreadyReadPages(bookName)))
            end
        end
    end
end

local function saveLiteratureReads(player)
    local username = player:getUsername()
    RespawnData[username]["Recipes"] = {}

    local getAlreadyReadBook = player:getAlreadyReadBook()
    for i = 0, getAlreadyReadBook:size() - 1 do
        RespawnData[username]["ReadBooks"][i] = getAlreadyReadBook:get(i)
        DebugPrintFactionsPlus(string.format(
            "[saveLiteratureReads] Book read added: %s",
            RespawnData[username]["ReadBooks"][i]))
    end
    local TeachedRecipesName = player:getKnownRecipes()
    for i = 0, TeachedRecipesName:size() - 1 do
        RespawnData[username]["ReadRecipes"][i] = TeachedRecipesName:get(i)
        DebugPrintFactionsPlus(string.format(
            "[saveLiteratureReads] Recipe read added: %s",
            RespawnData[username]["ReadRecipes"][i]))
    end
end

local function saveMedia(player)
    local username = player:getUsername()
    RespawnData[username]["Media"] = {}

    local MediaGuid = {}
    local MediaCat = nil
    local MediaName = nil
    local cd = instanceItem("Base.Disc_Retail")
    local vhs1 = instanceItem("Base.VHS_Home")
    local vhs2 = instanceItem("Base.VHS_Retail")
    if cd:getRecordedMediaIndex() == -1 then
        MediaCat = getZomboidRadio():getRecordedMedia():getAllMediaForCategory(cd:getScriptItem():getRecordedMediaCat());
        for i = 0, MediaCat:size() - 1 do
            MediaName = MediaCat:get(i)
            for j = 0, MediaName:getLineCount() - 1 do
                if player:isKnownMediaLine(MediaName:getLine(j):getTextGuid()) then
                    table.insert(MediaGuid, MediaName:getLine(j):getTextGuid())
                end
            end
        end
    end
    if vhs1:getRecordedMediaIndex() == -1 then
        MediaCat = getZomboidRadio():getRecordedMedia():getAllMediaForCategory(vhs1:getScriptItem():getRecordedMediaCat());
        for i = 0, MediaCat:size() - 1 do
            MediaName = MediaCat:get(i)
            for j = 0, MediaName:getLineCount() - 1 do
                if player:isKnownMediaLine(MediaName:getLine(j):getTextGuid()) then
                    table.insert(MediaGuid, MediaName:getLine(j):getTextGuid())
                end
            end
        end
    end
    if vhs2:getRecordedMediaIndex() == -1 then
        MediaCat = getZomboidRadio():getRecordedMedia():getAllMediaForCategory(vhs2:getScriptItem():getRecordedMediaCat());
        for i = 0, MediaCat:size() - 1 do
            MediaName = MediaCat:get(i)
            for j = 0, MediaName:getLineCount() - 1 do
                if player:isKnownMediaLine(MediaName:getLine(j):getTextGuid()) then
                    table.insert(MediaGuid, MediaName:getLine(j):getTextGuid())
                end
            end
        end
    end
    for i = 0, #MediaGuid - 1 do
        RespawnData["Media"][i] = MediaGuid[i + 1]
        DebugPrintFactionsPlus(string.format("[saveMedia] Media added: %s", MediaGuid[i + 1]))
    end
end

local function saveStats(player)
    local username = player:getUsername()
    RespawnData[username]["ZombieKills"] = player:getZombieKills()

    local FavouriteWeapon = {}
    for iPData, vPData in pairs(player:getModData()) do
        if (string.find(iPData, "Fav:")) then
            FavouriteWeapon[tostring(iPData)] = vPData
        end
    end

    RespawnData[username]["FavouriteWeapon"] = FavouriteWeapon
end
--#endregion Save

local function OnPlayerDeath(player)
    RespawnData[player:getUsername()] = {}
    savePerks(player)
    saveTraits(player)
    saveBookPages(player)
    saveLiteratureReads(player)
    saveMedia(player)
    saveStats(player)

    DebugPrintFactionsPlus(string.format("[OnPlayerDeath] Player fully saved: %s", player:getUsername()))
end

local function OnPlayerCreated(playerIndex, player)
    Events.OnPlayerUpdate.Add(function(updatedPlayer)
        if updatedPlayer ~= player then return end
        if player:isPlayerMoving() then return end
    end)
end

Events.OnPlayerDeath.Add(OnPlayerDeath)
Events.OnCreatePlayer.Add(OnPlayerCreated)
Events.OnInitGlobalModData.Add(function(isNewGame)
    RespawnData = ModData.getOrCreate("FactionsPlusRespawn")
end)
