-- {
--      "State": {
--          "active": true,
--          "expectedTraits": nil,
--          "loopCount": 0,
--          "maxLoop": 600
--      }
--      "Player": playerObject
-- }
local playersData = {}

local function IsSameTraits(a, b)
    if #a ~= #b then
        return false
    end
    local count = {}
    for _, v in ipairs(a) do
        count[v] = (count[v] or 0) + 1
    end
    for _, v in ipairs(b) do
        if not count[v] then
            return false
        end
        count[v] = count[v] - 1
        if count[v] < 0 then
            return false
        end
    end
    return true
end

local function Tick(player, state)
    -- If the state is not active, do nothing
    if not state.active then return false end

    -- Increment the loop counter
    state.loopCount = state.loopCount + 1

    -- If the loop limit is exceeded, stop without applying
    if state.loopCount > state.maxLoop then
        return true
    end

    -- Collect the player's current traits
    local traitsType = {}
    for i = 0, player:getCharacterTraits():getKnownTraits():size() - 1 do
        local trait = CharacterTraitDefinition.getCharacterTraitDefinition(player:getCharacterTraits():getKnownTraits()
            :get(i))
        table.insert(traitsType, trait:getType():getName())
    end

    -- Check if the current traits match the expected traits, if not wait for next tick
    if not IsSameTraits(state.expectedTraits, traitsType) then
        return false
    end

    local levels = {}
    local BoostMap

    -- Reset all perk boosts to 0 before recalculating
    for i = 0, Perks.getMaxIndex() - 1 do
        local PerkName = PerkFactory.getPerk(Perks.fromIndex(i))
        if PerkName and PerkName:getParent() ~= Perks.None then
            player:getXp():setPerkBoost(PerkName, 0)
        end
    end

    -- Set base boost values for Fitness and Strength
    levels[Perks.Fitness] = 5
    levels[Perks.Strength] = 5

    -- Sum XP boosts from each of the player's traits
    for i = 0, player:getCharacterTraits():getKnownTraits():size() - 1 do
        local trait = player:getCharacterTraits():getKnownTraits():get(i)
        local XPBoost = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
        if XPBoost:getXpBoosts() then
            BoostMap = transformIntoKahluaTable(XPBoost:getXpBoosts())
            for perk, level in pairs(BoostMap) do
                levels[perk] = (levels[perk] or 0) + level:intValue()
            end
        end
    end

    -- Sum XP boosts from the player's profession
    local prof = CharacterProfessionDefinition.getCharacterProfessionDefinition(player:getDescriptor()
        :getCharacterProfession())
    if prof and prof:getXpBoosts() then
        BoostMap = transformIntoKahluaTable(prof:getXpBoosts())
        for perk, level in pairs(BoostMap) do
            levels[perk] = (levels[perk] or 0) + level:intValue()
        end
    end

    -- Clamp all boost values between 0 and 3, then apply them
    for perk, level in pairs(levels) do
        if level < 0 then level = 0 end
        if level > 3 then level = 3 end
        player:getXp():setPerkBoost(perk, level)
    end

    -- Sync the player stats and XP with the server
    sendPlayerStatsChange(player)
    SyncXp(player)

    -- Done, signal to remove from the queue
    return true
end

function RequestPlayerXPBoostUpdate(player, expectedTraits)
    for _, entry in ipairs(playersData) do
        if entry.Player == player then
            DebugPrintFactionsPlus("Player is already requested xp boost")
            return
        end
    end

    table.insert(playersData, {
        State = {
            active = true,
            expectedTraits = expectedTraits,
            loopCount = 0,
            maxLoop = 600
        },
        Player = player
    })
end

Events.OnTick.Add(function()
    for i = #playersData, 1, -1 do
        local entry = playersData[i]
        if not entry then
            table.remove(playersData, i)
        else
            local done = Tick(entry.Player, entry.State)
            if done then
                table.remove(playersData, i)
            end
        end
    end
end)
