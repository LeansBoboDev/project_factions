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

-- Clear the inventory of any IsoDeadBody found on a given square
local function clearDeadBodyOnSquare(sq)
    if not sq then return false end
    local objs = sq:getStaticMovingObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if instanceof(obj, "IsoDeadBody") then
            local inv = obj:getContainer()
            if inv then
                inv:getItems():clear()
                inv:removeAllItems()
            end
            return true
        end
    end
    return false
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
    DebugPrintSafehousePlus("[Respawn] setRespawnRegion called, region=" .. tostring(region));
    if not region then
        DebugPrintSafehousePlus("[Respawn] setRespawnRegion: region is nil, aborting");
        return;
    end
    if not region.points then
        DebugPrintSafehousePlus("[Respawn] setRespawnRegion: region.points is nil, aborting");
        return;
    end
    local profession = player:getDescriptor():getCharacterProfession();
    DebugPrintSafehousePlus("[Respawn] setRespawnRegion: profession=" .. tostring(profession));
    local spawn = region.points[profession];
    if (not spawn) then spawn = region.points["unemployed"] end
    DebugPrintSafehousePlus("[Respawn] setRespawnRegion: spawn=" .. tostring(spawn));

    if (spawn) then
        local randSpawnPoint = spawn[(ZombRand(#spawn) + 1)];
        DebugPrintSafehousePlus("[Respawn] setRespawnRegion: chosen point posX=" .. tostring(randSpawnPoint.posX) .. " posY=" .. tostring(randSpawnPoint.posY));
        getWorld():setLuaPosX(randSpawnPoint.posX);
        getWorld():setLuaPosY(randSpawnPoint.posY);
        getWorld():setLuaPosZ(randSpawnPoint.posZ or 0);

        player:setX(randSpawnPoint.posX);
        player:setY(randSpawnPoint.posY);
        player:setZ(randSpawnPoint.posZ or 0);
        setPlayerRespawn(player);
        DebugPrintSafehousePlus("[Respawn] setRespawnRegion: pModData.RespawnX=" .. tostring(player:getModData().RespawnX));
    else
        DebugPrintSafehousePlus("[Respawn] setRespawnRegion: no spawn point found for profession or unemployed");
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
-- username is used in MP: getSteamID() returns a Java long that tostring() formats as
-- scientific notation (e.g. 7.65e16), which differs between client and server contexts.
local function getUniqueId(player)
    if SafehousePlusIsSinglePlayer then
        return tostring(1);
    else
        return player:getUsername();
    end
end

--#endregion

--#region Save Player

local function savePlayerLevels(player)
    local id = getUniqueId(player)
    RespawnData[id].Xp = {};
    RespawnData[id].Levels = {};
    local perks = PerkFactory.PerkList;
    local xpSystem = player:getXp();

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i);
        RespawnData[id].Levels[i] = player:getPerkLevel(perk);
        RespawnData[id].Xp[i] = xpSystem and xpSystem:getXP(perk) or 0;
    end
    DebugPrintSafehousePlus("[Respawn] Levels saved: " .. player:getUsername());
end

local function savePlayerBoosts(player)
    RespawnData[getUniqueId(player)].Boosts = {};
    local perks = PerkFactory.PerkList;
    local boosts = player:getXp();
    if not boosts then return end

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i);
        RespawnData[getUniqueId(player)].Boosts[perk] = boosts:getPerkBoost(perk);
    end
end

local function savePlayerBooks(player)
    local id = getUniqueId(player)
    RespawnData[id].SkillBooks = {}

    local literatures = player:getReadLiterature()
    DebugPrintSafehousePlus("[Respawn] savePlayerBooks: literatures=" .. tostring(literatures))
    if not literatures or literatures:isEmpty() then
        DebugPrintSafehousePlus("[Respawn] savePlayerBooks: nothing to save")
        return
    end
    DebugPrintSafehousePlus("[Respawn] savePlayerBooks: literatures.size=" .. literatures:size())

    -- entrySet():iterator() fails in Kahlua: HashMap$EntrySet is a private inner class.
    -- ItemType enum is not available server-side, so no isItemType filter.
    -- Instead: iterate all script items, probe the HashMap with public containsKey/get.
    local allItems = getScriptManager():getAllItems()
    DebugPrintSafehousePlus("[Respawn] savePlayerBooks: allItems.size=" .. allItems:size())
    local count = 0
    for i = 1, allItems:size() do
        local item = allItems:get(i - 1)
        -- ScriptManager items use getFullName() (e.g. "Base.ElectronicsMag4")
        -- getFullType() only exists on InventoryItem, not on scripting.objects.Item
        local fullName = item:getFullName()
        if fullName and literatures:containsKey(fullName) then
            local val = literatures:get(fullName)
            DebugPrintSafehousePlus("[Respawn] savePlayerBooks: found " .. tostring(fullName) .. " val=" .. tostring(val) .. " type=" .. type(val))
            local nights = type(val) == "number" and val or (val and val:intValue() or 0)
            RespawnData[id].SkillBooks[fullName] = nights
            count = count + 1
        end
    end
    DebugPrintSafehousePlus("[Respawn] Books saved (" .. count .. "): " .. player:getUsername())
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
    local id = getUniqueId(player)
    RespawnData[id].Multipliers = {};
    local perks = PerkFactory.PerkList;

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i);
        RespawnData[id].Multipliers[i] = player:getXp():getMultiplier(perk);
    end
end

local function savePlayerInventory(player)
    RespawnData[getUniqueId(player)].Hotbar = player:getModData().hotbar;
    local WornItems = player:getWornItems();
    RespawnData[getUniqueId(player)].WornItems = {};

    DebugPrintSafehousePlus("[Respawn] savePlayerInventory: WornItems count=" .. WornItems:size() .. " context=" .. (isClient() and "client" or "server"));
    for i = 0, WornItems:size() - 1 do
        local wi = WornItems:get(i);
        RespawnData[getUniqueId(player)].WornItems[i] = wi;
        local loc = wi and tostring(wi:getLocation()) or "nil";
        local typ = wi and wi:getItem() and wi:getItem():getFullType() or "nil";
        DebugPrintSafehousePlus("[Respawn]   WornItem[" .. i .. "] loc=" .. loc .. " type=" .. typ);
    end

    local AttachedItems = player:getAttachedItems();
    RespawnData[getUniqueId(player)].AttachedItems = {};

    for i = 0, AttachedItems:size() - 1 do
        RespawnData[getUniqueId(player)].AttachedItems[i] = AttachedItems:get(i);
    end

    local allItems = player:getInventory():getItems();
    DebugPrintSafehousePlus("[Respawn] savePlayerInventory: inventory item count=" .. allItems:size());
    RespawnData[getUniqueId(player)].Items = allItems:clone();
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
    RespawnData[id].Descriptor.VoiceType   = player:getDescriptor():getVoiceType();
    RespawnData[id].Descriptor.VoicePitch  = player:getDescriptor():getVoicePitch();
    RespawnData[id].Descriptor.VoicePrefix = player:getDescriptor():getVoicePrefix();
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
    local knownRecipes = player:getKnownRecipes();
    local savedRecipes = {};
    if knownRecipes then
        for i = 0, knownRecipes:size() - 1 do
            table.insert(savedRecipes, tostring(knownRecipes:get(i)));
        end
    end
    RespawnData[getUniqueId(player)].Recipes = savedRecipes;
    RespawnData[getUniqueId(player)].ZombieKills = player:getZombieKills();
    RespawnData[getUniqueId(player)].SurvivorKills = player:getSurvivorKills();
    RespawnData[getUniqueId(player)].HoursSurvived = player:getHoursSurvived();
    RespawnData[getUniqueId(player)].LevelUpMultiplier = player:getLevelUpMultiplier();

    DebugPrintSafehousePlus("[Respawn] Player Saved");
end
--#endregion

--#region Load Player

local function loadPlayerLevels(player)
    local id = getUniqueId(player)
    local levels = RespawnData[id].Levels or {}
    local xps = RespawnData[id].Xp or {}
    local perks = PerkFactory.PerkList;

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i);
        local savedLevel = levels[i];
        local savedXp = xps[i] or 0;

        if savedLevel and savedLevel > 0 then
            -- Mesma abordagem do ISPlayerStatsUI: delta até o threshold do nível
            local currentXp = player:getXp():getXP(perk);
            local targetXp = perk:getTotalXpForLevel(savedLevel);
            local delta = targetXp - currentXp;
            if delta ~= 0 then
                player:getXp():AddXP(perk, delta, false, false, false, false);
            end
            -- Restaura progresso dentro do nível (XP acima do threshold)
            local afterXp = player:getXp():getXP(perk);
            if savedXp > afterXp then
                player:getXp():AddXP(perk, savedXp - afterXp, false, false, false, false);
            end
        end
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
    local count = 0
    for book, nights in pairs(RespawnData[getUniqueId(player)].SkillBooks or {}) do
        -- restore into readLiterature HashMap so isLiteratureRead() works correctly
        player:addReadLiterature(book, nights)
        count = count + 1
    end
    DebugPrintSafehousePlus("[Respawn] Books loaded (" .. count .. "): " .. player:getUsername())
end

local function loadPlayerMultipliers(player)
    local id = getUniqueId(player)
    local multipliers = RespawnData[id].Multipliers or {}
    local perks = PerkFactory.PerkList;

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i);
        local amount = multipliers[i];
        if amount then
            player:getXp():addXpMultiplier(perk, amount, 0, 10);
        end
    end
end

local function loadPlayerRecipes(player)
    for _, recipe in ipairs(RespawnData[getUniqueId(player)].Recipes or {}) do
        player:learnRecipe(recipe);
    end
end

local function loadPlayerFavoriteRecipes(player)
    local pModData = player:getModData();

    for k, v in pairs(RespawnData[getUniqueId(player)].FavoriteRecipes or {}) do
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
    if RespawnData[id].WornItems[0] ~= nil then
        -- Original path: WornItem Java objects with location info (SP or pre-B42 MP)
        DebugPrintSafehousePlus("[Respawn] loadPlayerInventory: using WornItems (Java) path");
        for _, WornItem in pairs(RespawnData[id].WornItems) do
            local location = WornItem:getLocation();
            local item = WornItem:getItem();
            DebugPrintSafehousePlus("[Respawn]   equipping loc=" .. tostring(location) .. " item=" .. tostring(item and item:getFullType() or "nil"));
            player:getWornItems():setItem(location, item);
            sendClothing(player, location, item);
        end
    elseif RespawnData[id].WornItemsLocations and #RespawnData[id].WornItemsLocations > 0 then
        -- B42 MP path: locations were serialized as strings by the client
        DebugPrintSafehousePlus("[Respawn] loadPlayerInventory: using WornItemsLocations path, count=" .. #RespawnData[id].WornItemsLocations);
        for _, wiData in ipairs(RespawnData[id].WornItemsLocations) do
            local loc = ItemBodyLocation[wiData.loc]
            DebugPrintSafehousePlus("[Respawn]   trying loc=" .. tostring(wiData.loc) .. " -> resolved=" .. tostring(loc) .. " type=" .. tostring(wiData.type));
            if loc then
                local item = inventory:FindAndReturn(wiData.type)
                DebugPrintSafehousePlus("[Respawn]   FindAndReturn result: " .. (item and item:getFullType() or "NOT FOUND"));
                if item then
                    player:getWornItems():setItem(loc, item)
                    sendClothing(player, loc, item)
                end
            else
                DebugPrintSafehousePlus("[Respawn]   WARNING: ItemBodyLocation['" .. tostring(wiData.loc) .. "'] is nil, skipping");
            end
        end
    else
        -- B42 MP fallback: worn items end up flat in the dead body container (no WornItems collection).
        -- Derive the slot from each item's own body location definition.
        DebugPrintSafehousePlus("[Respawn] loadPlayerInventory: using getBodyLocation() inference path");
        local equippedSlots = {};
        local invItems = inventory:getItems();
        for i = 0, invItems:size() - 1 do
            local item = invItems:get(i);
            if item then
                local loc = nil;
                if item.IsClothing and item:IsClothing() then
                    loc = item:getBodyLocation();
                elseif item.IsInventoryContainer and item:IsInventoryContainer() and item.canBeEquipped then
                    local canEquip = item:canBeEquipped();
                    if type(canEquip) == "string" and canEquip ~= "" then
                        loc = ItemBodyLocation.get(ResourceLocation.of(canEquip));
                    end
                end
                if loc then
                    local locStr = tostring(loc);
                    DebugPrintSafehousePlus("[Respawn]   clothing item: " .. item:getFullType() .. " -> loc=" .. locStr .. " slotFree=" .. tostring(not equippedSlots[locStr]));
                    if not equippedSlots[locStr] then
                        equippedSlots[locStr] = true;
                        player:getWornItems():setItem(loc, item);
                        sendClothing(player, loc, item);
                    end
                end
            end
        end
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

    -- B42 MP fallback: if direct reference was nil, restore by type from modData tracking
    if not player:getPrimaryHandItem() and RespawnData[id].PrimaryHandType then
        local item = inventory:FindAndReturn(RespawnData[id].PrimaryHandType)
        DebugPrintSafehousePlus("[Respawn] PrimaryHandItem restore: type=" .. RespawnData[id].PrimaryHandType .. " found=" .. tostring(item ~= nil))
        if item then player:setPrimaryHandItem(item) end
    end
    if not player:getSecondaryHandItem() and RespawnData[id].SecondaryHandType then
        local item = inventory:FindAndReturn(RespawnData[id].SecondaryHandType)
        DebugPrintSafehousePlus("[Respawn] SecondaryHandItem restore: type=" .. RespawnData[id].SecondaryHandType .. " found=" .. tostring(item ~= nil))
        if item then player:setSecondaryHandItem(item) end
    end

    --Revert unlimited carry
    player:setUnlimitedCarry(isUnlimitedCarry);
    DebugPrintSafehousePlus("[Respawn] loadPlayerInventory: " .. RespawnData[id].Items:size() .. " items restored");
end

local function loadRespawnLocation(player)
    local id = getUniqueId(player)
    DebugPrintSafehousePlus("[Respawn] loadRespawnLocation: id=" .. tostring(id) .. " RespawnData[id]=" .. tostring(RespawnData[id]));
    if not RespawnData[id] then return end
    DebugPrintSafehousePlus("[Respawn] loadRespawnLocation: RespawnData.X=" .. tostring(RespawnData[id].X) .. " Y=" .. tostring(RespawnData[id].Y) .. " Z=" .. tostring(RespawnData[id].Z));
    if RespawnData[id].X ~= nil and RespawnData[id].Y ~= nil and RespawnData[id].Z ~= nil then
        player:setX(RespawnData[id].X);
        player:setY(RespawnData[id].Y);
        player:setZ(RespawnData[id].Z);
        DebugPrintSafehousePlus("[Respawn] loadRespawnLocation: teleported to " .. RespawnData[id].X .. "," .. RespawnData[id].Y);
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
        local d = RespawnData[getUniqueId(player)].Descriptor;
        if d.VoiceType ~= nil then player:getDescriptor():setVoiceType(d.VoiceType) end;
        if d.VoicePitch ~= nil then player:getDescriptor():setVoicePitch(d.VoicePitch) end;
        if d.VoicePrefix ~= nil then player:getDescriptor():setVoicePrefix(d.VoicePrefix) end;
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
        return false;
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

    savePlayer(player);

    local keepInvOption = getSandboxOptions():getOptionByName("SafehousePlus.KeepInventory")
    local keepInv = keepInvOption and keepInvOption:getValue()

    -- Server-side: if B42 already moved items to the dead body before OnPlayerDeath fired,
    -- recover Items/WornItems/AttachedItems directly from the dead body.
    if not isClient() and keepInv then
        local id = getUniqueId(player)
        if RespawnData[id] then
            local sq = player:getSquare()
            if sq then
                local objs = sq:getStaticMovingObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if instanceof(obj, "IsoDeadBody") then
                        if RespawnData[id].Items and RespawnData[id].Items:size() == 0 then
                            local deadInv = obj:getContainer()
                            if deadInv then
                                RespawnData[id].Items = deadInv:getItems():clone()
                                deadInv:getItems():clear()
                                deadInv:removeAllItems()
                                DebugPrintSafehousePlus("[Respawn] Items recovered from dead body: " .. player:getUsername())
                            end
                        end
                        if RespawnData[id].WornItems[0] == nil and obj.getWornItems then
                            local deadWorn = obj:getWornItems()
                            if deadWorn then
                                for j = 0, deadWorn:size() - 1 do
                                    RespawnData[id].WornItems[j] = deadWorn:get(j)
                                end
                                DebugPrintSafehousePlus("[Respawn] WornItems recovered from dead body: " .. player:getUsername())
                            end
                        end
                        if RespawnData[id].AttachedItems[0] == nil and obj.getAttachedItems then
                            local deadAttached = obj:getAttachedItems()
                            if deadAttached then
                                for j = 0, deadAttached:size() - 1 do
                                    RespawnData[id].AttachedItems[j] = deadAttached:get(j)
                                end
                                DebugPrintSafehousePlus("[Respawn] AttachedItems recovered from dead body: " .. player:getUsername())
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    -- Client-side (or SP): clear the dead body and signal death complete
    if not isServer() and keepInv then
        local sq = player:getSquare()
        if not clearDeadBodyOnSquare(sq) then
            local username = player:getUsername()
            local attempts = 0
            local function waitForDeadBody()
                attempts = attempts + 1
                if clearDeadBodyOnSquare(sq) then
                    Events.OnTick.Remove(waitForDeadBody)
                    DebugPrintSafehousePlus("[Respawn] Dead body inventory cleared (deferred): " .. username)
                elseif attempts >= 60 then
                    Events.OnTick.Remove(waitForDeadBody)
                    DebugPrintSafehousePlus("[Respawn] Dead body not found after 60 ticks: " .. username)
                end
            end
            Events.OnTick.Add(waitForDeadBody)
        end
        DebugPrintSafehousePlus("[Respawn] Dead body cleared: " .. player:getUsername());
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
            DebugPrintSafehousePlus("[Respawn] SERVER received setRespawnRegion for " .. player:getUsername());
            DebugPrintSafehousePlus("[Respawn] SERVER setRespawnRegion args=" .. tostring(args));
            DebugPrintSafehousePlus("[Respawn] SERVER setRespawnRegion args.region=" .. tostring(args and args.region));
            DebugPrintSafehousePlus("[Respawn] SERVER setRespawnRegion args.name=" .. tostring(args and args.name));
            removePlayerRespawn(player);
            setRespawnRegion(player, args.region);
            -- setRespawnRegion writes to pModData on the dead player object, but loadRespawnLocation
            -- runs on the NEW player object whose pModData is reloaded from file (may be stale).
            -- Sync to RespawnData (pure Lua in-memory table, survives the object swap) so
            -- loadRespawnLocation finds the chosen coordinates reliably.
            local id = getUniqueId(player)
            if RespawnData[id] then
                local pmd = player:getModData()
                RespawnData[id].X = pmd.RespawnX
                RespawnData[id].Y = pmd.RespawnY
                RespawnData[id].Z = pmd.RespawnZ
                DebugPrintSafehousePlus("[Respawn] setRespawnRegion: synced RespawnData.X=" .. tostring(pmd.RespawnX) .. " Y=" .. tostring(pmd.RespawnY));
            else
                DebugPrintSafehousePlus("[Respawn] setRespawnRegion: WARNING RespawnData[" .. tostring(id) .. "] is nil, cannot sync coords!");
            end
        elseif module == "SafehousePlusRespawn" and command == "loadPlayer" then
            DebugPrintSafehousePlus("Player requested load: " .. player:getUsername());
            DebugPrintSafehousePlus("[Respawn] SERVER loadPlayer: pModData.RespawnX=" .. tostring(player:getModData().RespawnX) .. " Y=" .. tostring(player:getModData().RespawnY));

            if loadPlayer(player) == false then return end

            local healthOption = getSandboxOptions():getOptionByName("SafehousePlus.HealthOnRespawn")
            setHealth(player, healthOption and healthOption:getValue() or 1);

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

    -- Server-side: save player data directly in OnCharacterDeath, which fires inside DoDeath()
    -- BEFORE dropHandItems() — items are still on the character at this point.
    if isServer() then
        Events.OnCharacterDeath.Add(function(character)
            if not character or not instanceof(character, "IsoPlayer") then return end
            if instanceof(character, "IsoAnimal") then return end
            DebugPrintSafehousePlus("[Respawn] OnCharacterDeath SERVER: saving " .. character:getUsername())
            savePlayer(character)
        end)
    end
end

--#endregion

-- Maybe in future make a respawn after quit from the death screen
-- Events.OnInitGlobalModData.Add(function(isNewGame)
--     RespawnData = ModData.getOrCreate("SafehousePlusRespawnData");
-- end)
