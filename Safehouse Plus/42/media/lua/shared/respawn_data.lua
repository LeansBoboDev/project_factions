if not getSandboxOptions():getOptionByName("SafehousePlus.EnableRespawnMechanic"):getValue() then return end

local RespawnData = {};

--#region Utils

-- Clear all items from the player inventory
local function clearInventory(player)
    local isUnlimitedCarry = player:isUnlimitedCarry();
    player:setUnlimitedCarry(true);
    local inventory = player:getInventory();

    -- Collect worn items before removing (loop while modifying causes errors)
    local wornItems = {};
    for i = 0, player:getWornItems():size() - 1 do
        wornItems[i + 1] = player:getWornItems():get(i):getItem();
    end
    for _, item in ipairs(wornItems) do
        player:removeWornItem(item);
    end

    -- Collect inventory items before clearing (needed for sendRemoveItemFromContainer)
    local inventoryItems = {};
    local items = inventory:getItems();
    for i = 0, items:size() - 1 do
        inventoryItems[i + 1] = items:get(i);
    end

    player:getWornItems():clear();
    player:getAttachedItems():clear();
    player:setPrimaryHandItem(nil);
    player:setSecondaryHandItem(nil);
    inventory:getItems():clear();
    inventory:removeAllItems();
    player:setInventory(inventory);

    -- Notify client of all removals
    sendEquip(player);
    for _, item in ipairs(inventoryItems) do
        sendRemoveItemFromContainer(inventory, item);
    end

    player:setUnlimitedCarry(isUnlimitedCarry);
end

-- Clear all bandages attached to the player
local function clearBandages(player)
    local items = player:getWornItems();
    local parts = player:getBodyDamage():getBodyParts();

    for i = items:size() - 1, 0, -1 do
        if (items:get(i):getLocation() == "Bandage") then
            player:getInventory():Remove(items:get(i):getItem());
            items:remove(items:get(i):getItem());
        end
    end

    for i = 0, parts:size() - 1 do
        parts:get(i):setBandaged(false, 0);
    end

    player:resetModelNextFrame();
end

-- Remove all wounds from the player
local function clearWounds(player)
    local parts = player:getBodyDamage():getBodyParts();

    for i = 0, parts:size() - 1 do
        parts:get(i):SetBitten(true);
        parts:get(i):setScratched(true, true);
        parts:get(i):setCut(true, true);
    end

    player:getBodyDamage():setBodyPartsLastState();

    for i = 0, parts:size() - 1 do
        parts:get(i):SetBitten(false);
        parts:get(i):setScratched(false, true);
        parts:get(i):setScratchTime(0);
        parts:get(i):setCut(false, true);
        parts:get(i):setCutTime(0);
        parts:get(i):setBiteTime(0);
        parts:get(i):SetBitten(false);
        parts:get(i):SetInfected(false);
        parts:get(i):setInfectedWound(false);
        parts:get(i):SetFakeInfected(false);
    end
end

-- Currently player position will be the next respawn position
local function setPlayerRespawn(player)
    local pModData = player:getModData();
    pModData.RespawnX = player:getX();
    pModData.RespawnY = player:getY();
    pModData.RespawnZ = player:getZ();
end

-- Set the player respawn based on the Menu Regions from map selector
local function setRespawnRegion(player, region)
    local spawn = region.points[player:getDescriptor():getCharacterProfession()];
    if (not spawn) then spawn = region.points["unemployed"] end

    if (spawn) then
        local randSpawnPoint = spawn[(ZombRand(#spawn) + 1)];
        getWorld():setLuaPosX(randSpawnPoint.posX);
        getWorld():setLuaPosY(randSpawnPoint.posY);
        getWorld():setLuaPosZ(randSpawnPoint.posZ or 0);

        player:setX(randSpawnPoint.posX);
        player:setY(randSpawnPoint.posY);
        player:setZ(randSpawnPoint.posZ or 0);
        setPlayerRespawn(player);
    end
end

-- Remove the currently player respawn saved
local function removePlayerRespawn(player)
    local pModData = player:getModData();
    pModData.RespawnX = nil;
    pModData.RespawnY = nil;
    pModData.RespawnZ = nil;
end

-- Get the coords of the player respawn { x = 123, y = 123, z = 123 }
local function getPlayerRespawn(player)
    local pModData = player:getModData();
    return { x = pModData.RespawnX, y = pModData.RespawnY, z = pModData.RespawnZ };
end

-- Update player health to a disered amount
local function setHealth(player, health)
    local parts = player:getBodyDamage():getBodyParts();
    health = 80 + (20 * health / 100);

    for i = 0, parts:size() - 1 do
        parts:get(i):SetHealth(health);
    end
end

-- Returns the player unique id
local function getUniqueId(player)
    if SafehousePlusIsSinglePlayer then
        -- I don't know how to detect split screen players 🤭
        -- Split screen players cannot die at same time
        return tostring(1);
    else
        if player:getSteamID() then
            return tostring(player:getSteamID());
        else
            return tostring(player:getOnlineID());
        end
    end
end

--#endregion

--#region Save Player

local function savePlayerLevels(player)
    RespawnData[getUniqueId(player)].Xp = {};
    RespawnData[getUniqueId(player)].Levels = {};
    local perks = PerkFactory.PerkList;

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i);

        RespawnData[getUniqueId(player)].Levels[perk] = player:getPerkLevel(perk);
        RespawnData[getUniqueId(player)].Xp[perk] = player:getXp():getXP(perk);
    end
    DebugPrintSafehousePlus("[Respawn] Levels saved: " .. player:getUsername());
end

local function savePlayerBoosts(player)
    RespawnData[getUniqueId(player)].Boosts = {};
    local perks = PerkFactory.PerkList;
    local boosts = player:getXp();

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i);
        RespawnData[getUniqueId(player)].Boosts[perk] = boosts:getPerkBoost(perk);
    end
end

local function savePlayerBooks(player)
    local id = getUniqueId(player)
    RespawnData[id].SkillBooks = {}

    local literatures = player:getReadLiterature()
    if not literatures then return end

    if literatures:isEmpty() then return end

    local iterator = literatures:entrySet():iterator()

    while iterator:hasNext() do
        local entry = iterator:next()
        local fullType = entry:getKey()
        local pages = entry:getValue():intValue()

        RespawnData[id].SkillBooks[fullType] = pages
    end
end

local function savePlayerMedia(player)
    RespawnData[getUniqueId(player)].Media = {};

    for _, media in pairs(RecMedia) do
        for _, line in pairs(media.lines or {}) do
            if (player:isKnownMediaLine(line.text)) then
                table.insert(RespawnData[getUniqueId(player)].Media, line.text);
            end;
        end
    end
end

local function savePlayerMultipliers(player)
    RespawnData[getUniqueId(player)].Multipliers = {};
    local perks = PerkFactory.PerkList;

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i);
        RespawnData[getUniqueId(player)].Multipliers[perk] = player:getXp():getMultiplier(perk);
    end
end

local function savePlayerInventory(player)
    RespawnData[getUniqueId(player)].Hotbar = player:getModData().hotbar;
    local WornItems = player:getWornItems();
    RespawnData[getUniqueId(player)].WornItems = {};

    for i = 0, WornItems:size() - 1 do
        RespawnData[getUniqueId(player)].WornItems[i] = WornItems:get(i);
    end

    local AttachedItems = player:getAttachedItems();
    RespawnData[getUniqueId(player)].AttachedItems = {};

    for i = 0, AttachedItems:size() - 1 do
        RespawnData[getUniqueId(player)].AttachedItems[i] = AttachedItems:get(i);
    end

    RespawnData[getUniqueId(player)].Items = player:getInventory():getItems():clone();
end

local function saveHandItems(player)
    player:dropHeavyItems();

    RespawnData[getUniqueId(player)].PrimaryHandItem = player:getPrimaryHandItem();
    player:setPrimaryHandItem(nil);

    RespawnData[getUniqueId(player)].SecondaryHandItem = player:getSecondaryHandItem();
    player:setSecondaryHandItem(nil);
end

local function saveRespawnBaseLocation(player)
    local pModData = player:getModData();
    RespawnData[getUniqueId(player)].X = pModData.RespawnX;
    RespawnData[getUniqueId(player)].Y = pModData.RespawnY;
    RespawnData[getUniqueId(player)].Z = pModData.RespawnZ;
end

local function savePlayerModel(player)
    local function colorToTable(color)
        if not color then return nil end;
        return { r = color:getRedFloat(), g = color:getGreenFloat(), b = color:getBlueFloat() };
    end

    local visual                           = player:getHumanVisual();
    local id                               = getUniqueId(player);
    RespawnData[id].Visual                 = {};
    RespawnData[id].Visual.SkinTexture     = visual:getSkinTextureIndex();
    RespawnData[id].Visual.SkinTextureName = visual:getSkinTexture();
    RespawnData[id].Visual.NonAttachedHair = visual:getNonAttachedHair();
    RespawnData[id].Visual.BodyHair        = visual:getBodyHairIndex();
    RespawnData[id].Visual.HairModel       = visual:getHairModel();
    RespawnData[id].Visual.BeardModel      = visual:getBeardModel();
    RespawnData[id].Visual.SkinColor       = colorToTable(visual:getSkinColor());
    RespawnData[id].Visual.HairColor       = colorToTable(visual:getHairColor());
    RespawnData[id].Visual.BeardColor      = colorToTable(visual:getBeardColor());

    RespawnData[id].Descriptor             = {};
    RespawnData[id].Descriptor.Age         = player:getAge();
    RespawnData[id].Descriptor.Female      = player:isFemale();
    RespawnData[id].Descriptor.Forename    = player:getDescriptor():getForename();
    RespawnData[id].Descriptor.Surname     = player:getDescriptor():getSurname();
end

local function savePlayerNutrition(player)
    RespawnData[getUniqueId(player)].Nutrition = {};
    RespawnData[getUniqueId(player)].Nutrition.Calories = player:getNutrition():getCalories();
    RespawnData[getUniqueId(player)].Nutrition.Proteins = player:getNutrition():getProteins();
    RespawnData[getUniqueId(player)].Nutrition.Lipids = player:getNutrition():getLipids();
    RespawnData[getUniqueId(player)].Nutrition.Carbohydrates = player:getNutrition():getCarbohydrates();
    RespawnData[getUniqueId(player)].Nutrition.Weight = player:getNutrition():getWeight();
end


local function savePlayerStats(player)
    local playerStatus = player:getStats();

    RespawnData[getUniqueId(player)].Stats = {};
    RespawnData[getUniqueId(player)].Stats.ANGER = playerStatus:get(CharacterStat.ANGER);
    RespawnData[getUniqueId(player)].Stats.BOREDOM = playerStatus:get(CharacterStat.BOREDOM);
    RespawnData[getUniqueId(player)].Stats.DISCOMFORT = playerStatus:get(CharacterStat.DISCOMFORT);
    RespawnData[getUniqueId(player)].Stats.ENDURANCE = playerStatus:get(CharacterStat.ENDURANCE);
    RespawnData[getUniqueId(player)].Stats.FATIGUE = playerStatus:get(CharacterStat.FATIGUE);
    RespawnData[getUniqueId(player)].Stats.FITNESS = playerStatus:get(CharacterStat.FITNESS);
    -- RespawnData[getUniqueId(player)].Stats.FOOD_SICKNESS = playerStatus:get(CharacterStat.FOOD_SICKNESS);
    RespawnData[getUniqueId(player)].Stats.HUNGER = playerStatus:get(CharacterStat.HUNGER);
    RespawnData[getUniqueId(player)].Stats.IDLENESS = playerStatus:get(CharacterStat.IDLENESS);
    -- RespawnData[getUniqueId(player)].Stats.INTOXICATION = playerStatus:get(CharacterStat.INTOXICATION);
    RespawnData[getUniqueId(player)].Stats.MORALE = playerStatus:get(CharacterStat.MORALE);
    -- RespawnData[getUniqueId(player)].Stats.NICOTINE_WITHDRAWAL = playerStatus:get(CharacterStat.NICOTINE_WITHDRAWAL);
    RespawnData[getUniqueId(player)].Stats.PAIN = playerStatus:get(CharacterStat.PAIN);
    RespawnData[getUniqueId(player)].Stats.PANIC = playerStatus:get(CharacterStat.PANIC);
    -- RespawnData[getUniqueId(player)].Stats.POISON = playerStatus:get(CharacterStat.POISON);
    RespawnData[getUniqueId(player)].Stats.SANITY = playerStatus:get(CharacterStat.SANITY);
    -- RespawnData[getUniqueId(player)].Stats.SICKNESS = playerStatus:get(CharacterStat.SICKNESS);s
    RespawnData[getUniqueId(player)].Stats.STRESS = playerStatus:get(CharacterStat.STRESS);
    RespawnData[getUniqueId(player)].Stats.TEMPERATURE = playerStatus:get(CharacterStat.TEMPERATURE);
    RespawnData[getUniqueId(player)].Stats.THIRST = playerStatus:get(CharacterStat.THIRST);
    RespawnData[getUniqueId(player)].Stats.UNHAPPINESS = playerStatus:get(CharacterStat.UNHAPPINESS);
    -- RespawnData[getUniqueId(player)].Stats.WETNESS = playerStatus:get(CharacterStat.WETNESS);
end

local function savePlayerFavoriteRecipes(player)
    local pModData = player:getModData();
    RespawnData[getUniqueId(player)].FavoriteRecipes = {};

    for k, v in pairs(pModData) do
        if (k:sub(0, 16) == "craftingFavorite") then
            RespawnData[getUniqueId(player)].FavoriteRecipes[k] = v;
        end
    end
end

local function savePlayer(player)
    RespawnData[getUniqueId(player)] = {};

    -- Save player inventory if keep inventory is true
    if getSandboxOptions():getOptionByName("SafehousePlus.KeepInventory"):getValue() then
        saveHandItems(player);
        DebugPrintSafehousePlus("[Respawn] Hand items saved: " .. player:getUsername());

        savePlayerInventory(player);
        DebugPrintSafehousePlus("[Respawn] Inventoy items saved: " .. player:getUsername());

        clearInventory(player);
    end

    saveRespawnBaseLocation(player);
    savePlayerLevels(player);
    savePlayerBoosts(player);
    savePlayerBooks(player);
    savePlayerMedia(player);
    savePlayerMultipliers(player);
    savePlayerModel(player);
    savePlayerNutrition(player);

    if getSandboxOptions():getOptionByName("SafehousePlus.KeepStats"):getValue() then
        savePlayerStats(player);
        DebugPrintSafehousePlus("[Respawn] Stats saved: " .. player:getUsername());
    end

    savePlayerFavoriteRecipes(player);

    local knownTraits = player:getCharacterTraits():getKnownTraits();
    local savedTraits = {};
    local prof = CharacterProfessionDefinition.getCharacterProfessionDefinition(player:getDescriptor()
        :getCharacterProfession());
    for i = 0, knownTraits:size() - 1 do
        local traitName = tostring(CharacterTraitDefinition.getCharacterTraitDefinition(knownTraits:get(i)):getType()
            :getName());
        table.insert(savedTraits, traitName);
    end
    for i = 0, prof:getGrantedTraits():size() - 1 do
        local grantedName = tostring(prof:getGrantedTraits():get(i):getName());
        for j = #savedTraits, 1, -1 do
            if savedTraits[j] == grantedName then
                table.remove(savedTraits, j);
                break;
            end
        end
    end
    RespawnData[getUniqueId(player)].Traits = savedTraits;
    RespawnData[getUniqueId(player)].Profession = player:getDescriptor():getCharacterProfession();
    RespawnData[getUniqueId(player)].Recipes = player:getKnownRecipes();
    RespawnData[getUniqueId(player)].ZombieKills = player:getZombieKills();
    RespawnData[getUniqueId(player)].SurvivorKills = player:getSurvivorKills();
    RespawnData[getUniqueId(player)].HoursSurvived = player:getHoursSurvived();
    RespawnData[getUniqueId(player)].LevelUpMultiplier = player:getLevelUpMultiplier();

    DebugPrintSafehousePlus("[Respawn] Player Saved");
end
--#endregion

--#region Load Player

local function loadPlayerLevels(player)
    for perk, level in pairs(RespawnData[getUniqueId(player)].Levels or {}) do
        player:level0(perk);

        local i = 0;
        while (i < level) do
            player:LevelPerk(perk, false);
            i = i + 1;
        end

        player:getXp():setXPToLevel(perk, level);
        player:getXp():AddXP(perk, RespawnData[getUniqueId(player)].Xp[perk], true, false, false);
    end
end

local function loadPlayerBoosts(player)
    local prof =
        CharacterProfessionDefinition.getCharacterProfessionDefinition(RespawnData[getUniqueId(player)].Profession);
    for perk, boost in pairs(RespawnData[getUniqueId(player)].Boosts or {}) do
        prof:addXPBoost(perk, boost);
    end

    player:getDescriptor():setProfessionSkills(prof);
    player:getDescriptor():setCharacterProfession(RespawnData[getUniqueId(player)].Profession);
end

local function loadPlayerTraits(player)
    local traits = RespawnData[getUniqueId(player)].Traits;
    if not traits then
        DebugPrintSafehousePlus("[Respawn] WARNING: no Traits data to load");
        return;
    end

    local knownTraits = player:getCharacterTraits():getKnownTraits();
    for i = knownTraits:size() - 1, 0, -1 do
        player:getCharacterTraits():remove(knownTraits:get(i));
    end

    for _, traitName in pairs(traits) do
        player:getCharacterTraits():add(CharacterTrait.get(ResourceLocation.of(traitName)));
    end

    local prof = CharacterProfessionDefinition.getCharacterProfessionDefinition(RespawnData[getUniqueId(player)]
        .Profession);
    for i = 0, prof:getGrantedTraits():size() - 1 do
        player:getCharacterTraits():add(prof:getGrantedTraits():get(i));
    end
end

local function loadPlayerBooks(player)
    for book, pages in pairs(RespawnData[getUniqueId(player)].SkillBooks or {}) do
        player:setAlreadyReadPages(book, pages);
    end
end

local function loadPlayerMultipliers(player)
    for perk, amount in pairs(RespawnData[getUniqueId(player)].Multipliers or {}) do
        player:getXp():addXpMultiplier(perk, amount, 0, 10);
    end
end

local function loadPlayerRecipes(player)
    if RespawnData[getUniqueId(player)].Recipes then
        for i = 0, RespawnData[getUniqueId(player)].Recipes:size() - 1 do
            player:learnRecipe(RespawnData[getUniqueId(player)].Recipes:get(i));
        end
    end
end

local function loadPlayerFavoriteRecipes(player)
    local pModData = player:getModData();

    for k, v in pairs(RespawnData[getUniqueId(player)].FavoriteRecipes) do
        pModData[k] = v;
    end
end

local function loadPlayerMedia(player)
    for _, id in ipairs(RespawnData[getUniqueId(player)].Media or {}) do
        player:addKnownMediaLine(id);
    end
end

local function loadPlayerInventory(player)
    local id = getUniqueId(player);
    local inventory = player:getInventory();

    --Needed in case if player inventory will be full
    local isUnlimitedCarry = player:isUnlimitedCarry();
    player:setUnlimitedCarry(true);

    --Add items one by one and notify client
    for i = 0, RespawnData[id].Items:size() - 1 do
        local item = RespawnData[id].Items:get(i);
        item:setEquipParent(player);
        item:setContainer(inventory);
        inventory:AddItem(item);
        sendAddItemToContainer(inventory, item);
    end

    --Set back worn items, clothes, belts, etc
    for _, WornItem in pairs(RespawnData[id].WornItems or {}) do
        local location = WornItem:getLocation();
        local item = WornItem:getItem();
        player:getWornItems():setItem(location, item);
        sendClothing(player, location, item);
    end

    --Set back attached items, items in belts
    for _, AttachedItem in pairs(RespawnData[id].AttachedItems or {}) do
        player:getAttachedItems():setItem(AttachedItem:getLocation(), AttachedItem:getItem());
    end

    --Restore hotbar UI order
    if (RespawnData[id].Hotbar ~= nil) then
        player:getModData().hotbar = RespawnData[id].Hotbar;
    end

    --Put item in hand/s
    player:setPrimaryHandItem(RespawnData[id].PrimaryHandItem);
    player:setSecondaryHandItem(RespawnData[id].SecondaryHandItem);

    --Revert unlimited carry
    player:setUnlimitedCarry(isUnlimitedCarry);
    DebugPrintSafehousePlus("[Respawn] loadPlayerInventory: " .. RespawnData[id].Items:size() .. " items restored");
end

local function loadRespawnLocation(player)
    if ((RespawnData[getUniqueId(player)].X ~= nil) and (RespawnData[getUniqueId(player)].Y ~= nil) and (RespawnData[getUniqueId(player)].Z ~= nil)) then
        player:setX(RespawnData[getUniqueId(player)].X);
        player:setY(RespawnData[getUniqueId(player)].Y);
        player:setZ(RespawnData[getUniqueId(player)].Z);
    end;
end

local function loadPlayerModel(player)
    if (RespawnData[getUniqueId(player)].Visual) then
        local visual = player:getHumanVisual();
        local v = RespawnData[getUniqueId(player)].Visual;
        visual:setSkinTextureIndex(v.SkinTexture);
        visual:setSkinTextureName(v.SkinTextureName);
        visual:setNonAttachedHair(v.NonAttachedHair);
        visual:setBodyHairIndex(v.BodyHair);
        visual:setHairModel(v.HairModel);
        visual:setBeardModel(v.BeardModel);
        if v.SkinColor then visual:setSkinColor(ImmutableColor.new(v.SkinColor.r, v.SkinColor.g, v.SkinColor.b, 1)) end;
        if v.HairColor then visual:setHairColor(ImmutableColor.new(v.HairColor.r, v.HairColor.g, v.HairColor.b, 1)) end;
        if v.BeardColor then visual:setBeardColor(ImmutableColor.new(v.BeardColor.r, v.BeardColor.g, v.BeardColor.b, 1)) end;
    end

    if (RespawnData[getUniqueId(player)].Descriptor) then
        player:setAge(RespawnData[getUniqueId(player)].Descriptor.Age);
        player:setFemale(RespawnData[getUniqueId(player)].Descriptor.Female);
        player:getDescriptor():setFemale(RespawnData[getUniqueId(player)].Descriptor.Female);
        player:getDescriptor():setForename(RespawnData[getUniqueId(player)].Descriptor.Forename);
        player:getDescriptor():setSurname(RespawnData[getUniqueId(player)].Descriptor.Surname);
    end
end

local function loadPlayerNutrition(player)
    player:getNutrition():setCalories(RespawnData[getUniqueId(player)].Nutrition.Calories);
    player:getNutrition():setProteins(RespawnData[getUniqueId(player)].Nutrition.Proteins);
    player:getNutrition():setLipids(RespawnData[getUniqueId(player)].Nutrition.Lipids);
    player:getNutrition():setCarbohydrates(RespawnData[getUniqueId(player)].Nutrition.Carbohydrates);
    player:getNutrition():setWeight(RespawnData[getUniqueId(player)].Nutrition.Weight);
end


local function loadPlayerStats(player)
    local playerStatus = player:getStats();

    playerStatus:set(CharacterStat.ANGER, RespawnData[getUniqueId(player)].Stats.ANGER or 0.0);
    playerStatus:set(CharacterStat.BOREDOM, RespawnData[getUniqueId(player)].Stats.BOREDOM or 0.0);
    playerStatus:set(CharacterStat.DISCOMFORT, RespawnData[getUniqueId(player)].Stats.DISCOMFORT or 0.0);
    playerStatus:set(CharacterStat.ENDURANCE, RespawnData[getUniqueId(player)].Stats.ENDURANCE or 0.0);
    playerStatus:set(CharacterStat.FATIGUE, RespawnData[getUniqueId(player)].Stats.FATIGUE or 0.0);
    playerStatus:set(CharacterStat.FITNESS, RespawnData[getUniqueId(player)].Stats.FITNESS or 0.0);
    -- playerStatus:set(CharacterStat.FOOD_SICKNESS, RespawnData[getUniqueId(player)].Stats.FOOD_SICKNESS or 0.0);
    playerStatus:set(CharacterStat.HUNGER, RespawnData[getUniqueId(player)].Stats.HUNGER or 0.0);
    playerStatus:set(CharacterStat.IDLENESS, RespawnData[getUniqueId(player)].Stats.IDLENESS or 0.0);
    -- playerStatus:set(CharacterStat.INTOXICATION, RespawnData[getUniqueId(player)].Stats.INTOXICATION or 0.0);
    playerStatus:set(CharacterStat.MORALE, RespawnData[getUniqueId(player)].Stats.MORALE or 0.0);
    -- playerStatus:set(CharacterStat.NICOTINE_WITHDRAWAL, RespawnData[getUniqueId(player)].Stats.NICOTINE_WITHDRAWAL or 0.0);
    playerStatus:set(CharacterStat.PAIN, RespawnData[getUniqueId(player)].Stats.PAIN or 0.0);
    playerStatus:set(CharacterStat.PANIC, RespawnData[getUniqueId(player)].Stats.PANIC or 0.0);
    -- playerStatus:set(CharacterStat.POISON, RespawnData[getUniqueId(player)].Stats.POISON or 0.0);
    playerStatus:set(CharacterStat.SANITY, RespawnData[getUniqueId(player)].Stats.SANITY or 0.0);
    -- playerStatus:set(CharacterStat.SICKNESS, RespawnData[getUniqueId(player)].Stats.SICKNESS or 0.0);s
    playerStatus:set(CharacterStat.STRESS, RespawnData[getUniqueId(player)].Stats.STRESS or 0.0);
    playerStatus:set(CharacterStat.TEMPERATURE, RespawnData[getUniqueId(player)].Stats.TEMPERATURE or 0.0);
    playerStatus:set(CharacterStat.THIRST, RespawnData[getUniqueId(player)].Stats.THIRST or 0.0);
    playerStatus:set(CharacterStat.UNHAPPINESS, RespawnData[getUniqueId(player)].Stats.UNHAPPINESS or 0.0);
    -- playerStatus:set(CharacterStat.WETNESS, RespawnData[getUniqueId(player)].Stats.WETNESS or 0.0);
end

local function loadPlayer(player)
    DebugPrintSafehousePlus("[Respawn] loadPlayer started: " .. player:getUsername());

    local id = getUniqueId(player);
    if not RespawnData[id] then
        DebugPrintSafehousePlus("[Respawn] ERROR: no RespawnData found for id=" .. tostring(id));
        return;
    end

    clearInventory(player);

    if getSandboxOptions():getOptionByName("SafehousePlus.KeepInventory"):getValue() then
        loadPlayerInventory(player);
        DebugPrintSafehousePlus("[Respawn] Inventory loaded: " .. player:getUsername());
    end

    -- Requires to be done on client side too
    sendServerCommand(player, "SafehousePlusRespawn", "receiveRespawnStats", RespawnData[id]);
    DebugPrintSafehousePlus("[Respawn] receiveRespawnStats sent to client: " .. player:getUsername());

    loadPlayerLevels(player);
    DebugPrintSafehousePlus("[Respawn] Levels loaded: " .. player:getUsername());

    loadPlayerBooks(player);
    DebugPrintSafehousePlus("[Respawn] Books loaded: " .. player:getUsername());

    loadPlayerMultipliers(player);
    loadPlayerRecipes(player);
    loadPlayerFavoriteRecipes(player);
    loadPlayerMedia(player);
    loadPlayerNutrition(player);

    if getSandboxOptions():getOptionByName("SafehousePlus.KeepStats"):getValue() then
        loadPlayerStats(player);
        DebugPrintSafehousePlus("[Respawn] Stats loaded: " .. player:getUsername());
    end

    player:setZombieKills(RespawnData[id].ZombieKills);
    player:setSurvivorKills(RespawnData[id].SurvivorKills);
    player:setHoursSurvived(RespawnData[id].HoursSurvived);
    clearWounds(player);

    loadPlayerModel(player);
    loadPlayerBoosts(player);
    loadPlayerTraits(player);
    player:setLevelUpMultiplier(RespawnData[id].LevelUpMultiplier);
    clearBandages(player);

    DebugPrintSafehousePlus("[Respawn] loadPlayer finished: " .. player:getUsername());
end

--#endregion

--#region Server Communication

-- On death we need to save player data
Events.OnPlayerDeath.Add(function(player)
    DebugPrintSafehousePlus("[Respawn] Saving iso player: " .. player:getUsername());

    -- Save player data
    savePlayer(player);

    -- Clear inventory for our and other players if keep inventory is true
    if getSandboxOptions():getOptionByName("SafehousePlus.KeepInventory"):getValue() then
        clearInventory(player);
        DebugPrintSafehousePlus("[Respawn] Dead body cleared: " .. player:getUsername());

        -- Tell client the corpse is dead
        player:setOnDeathDone(true);
    end
end);

-- Create a global function to load from clientside
if SafehousePlusIsSinglePlayer then
    function LoadPlayer(player)
        loadPlayer(player);
    end

    function LoadRespawnLocation(player)
        loadRespawnLocation(player);
    end

    function SetPlayerRespawn(player)
        setPlayerRespawn(player);
    end

    function SetHealth(player, health)
        setHealth(player, health);
    end

    function RemovePlayerRespawn(player)
        removePlayerRespawn(player);
    end

    function SetRespawnRegion(player, region)
        setRespawnRegion(player, region);
    end

    function GetPlayerRespawn(player)
        return getPlayerRespawn(player);
    end
else -- If not create a server command
    -- For some reason some stats requires to be updated on client side
    -- call this only in client side
    function UnsafeLocallyUpdate(playerData)
        DebugPrintSafehousePlus("Data received!");
        local player = getPlayer();
        RespawnData[getUniqueId(player)] = playerData;
        loadPlayerLevels(player);
        loadPlayerBooks(player);
        loadPlayerMultipliers(player);
        loadPlayerRecipes(player);
        loadPlayerFavoriteRecipes(player);
        loadPlayerMedia(player);
        loadPlayerNutrition(player);
        loadPlayerModel(player);
        DebugPrintSafehousePlus("All necessary loades finished!");
    end

    Events.OnClientCommand.Add(function(module, command, player, args)
        if module == "SafehousePlusRespawn" and command == "setRespawnRegion" then
            removePlayerRespawn(player);
            setRespawnRegion(player, args.region);
        elseif module == "SafehousePlusRespawn" and command == "loadPlayer" then
            DebugPrintSafehousePlus("Player requested load: " .. player:getUsername());

            loadPlayer(player);

            setHealth(player, getSandboxOptions():getOptionByName("SafehousePlus.HealthOnRespawn"):getValue());

            loadRespawnLocation(player);

            setPlayerRespawn(player);

            sendHumanVisual(player);
            sendEquip(player);
            syncVisuals(player);
        elseif module == "SafehousePlusRespawn" and command == "getRespawn" then
            local coords = getPlayerRespawn(player);
            sendServerCommand(player, "SafehousePlusRespawn", "receiveRespawn", coords);
        elseif module == "SafehousePlusRespawn" and command == "setPlayerRespawn" then
            setPlayerRespawn(player);
        end
    end)
end

--#endregion

-- Maybe in future make a respawn after quit from the death screen
-- Events.OnInitGlobalModData.Add(function(isNewGame)
--     RespawnData = ModData.getOrCreate("SafehousePlusRespawnData");
-- end)
