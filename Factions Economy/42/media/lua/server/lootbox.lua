-- ── Helper ───────────────────────────────────────────────────

local function giveItemToPlayer(player, itemFullName)
    local item = instanceItem(itemFullName)
    if not item then
        DebugPrintFactionsEconomy(string.format("Failed to instance item: %s", itemFullName))
        return false
    end
    if item:getType() == "CorpseAnimal" then
        item:createAndStoreDefaultDeadBody(nil)
    end

    player:getInventory():AddItem(item)
    sendAddItemToContainer(player:getInventory(), item);

    return true
end

-- ── LootBox Recipe ───────────────────────────────────────────

if isClient() and not FactionsIsSinglePlayer then return end

FactionsEconomyLootBoxRecipe = FactionsEconomyLootBoxRecipe or {}

FactionsEconomyLootBoxRecipe.OpenLootBox = function(craftRecipeData, player)
    DebugPrintFactionsEconomy(string.format("%s trying to open a loot box...", player:getUsername()))

    local consumedItems = craftRecipeData:getAllConsumedItems()

    for i = 0, consumedItems:size() - 1 do
        local item         = consumedItems:get(i)
        local sandboxTable = "FactionsEconomy." .. item:getType()

        DebugPrintFactionsEconomy(string.format(
            "%s lootbox opened: %s, Sandbox Table: %s",
            player:getUsername(), item:getType(), sandboxTable
        ))

        local chanceTable = getSandboxOptions():getOptionByName(sandboxTable):getValue()

        -- ── Parse chance table string ────────────────────────
        local result = {}
        for key, value in chanceTable:gmatch("([^/]+)/([^/]+)/") do
            table.insert(result, { key = key, value = tonumber(value) })
        end

        if #result <= 0 then
            DebugPrintFactionsEconomy(string.format("No values found for lootbox: %s", item:getType()))
            return
        end

        -- ── Shuffle ──────────────────────────────────────────
        for j = #result, 2, -1 do
            local x = ZombRand(j) + 1
            result[j], result[x] = result[x], result[j]
        end

        -- ── Roll ─────────────────────────────────────────────
        local maxChances = 0
        while true do
            if maxChances > 20 then
                local randomEntry = result[ZombRand(#result) + 1]
                giveItemToPlayer(player, randomEntry.key)
                DebugPrintFactionsEconomy(string.format(
                    "%s hit roll limit — forced item: %s from lootbox: %s",
                    player:getUsername(), randomEntry.key, item:getType()
                ))
                return
            end

            for _, entry in ipairs(result) do
                local chance = ZombRand(100) + 1
                if entry.value > chance then
                    giveItemToPlayer(player, entry.key)
                    DebugPrintFactionsEconomy(string.format(
                        "%s received: %s from lootbox: %s",
                        player:getUsername(), entry.key, item:getType()
                    ))
                    return
                end
            end

            maxChances = maxChances + 1
        end
    end
end
