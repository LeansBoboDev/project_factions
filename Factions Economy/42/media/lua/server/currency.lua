-- ============================================================
-- Currency System — Server Side
-- ============================================================

if isClient() and not FactionsIsSinglePlayer then return end

-- { ["playerUsername"] = 150 }
FactionsEconomyCurrencyData          = {}

-- {
--   ["playerUsername"] = {
--     Title           = "My Safehouse",
--     Owner           = "playerUsername",
--     Players         = { "playerUsername", "friendUsername" },
--     DateTimeCreated = "2024-01-15 10:30:00",
--     Currency        = 75,
--     Tier            = 5
--   }
-- }
FactionsEconomySafehouseCurrencyData = {}

FactionsEconomyCurrencyRecipe        = FactionsEconomyCurrencyRecipe or {}

-- ── Sandbox Options Cache ────────────────────────────────────

local function getSandboxOption(name)
    return getSandboxOptions():getOptionByName(name):getValue()
end

-- ── Helpers ──────────────────────────────────────────────────

local function ensurePlayerData(username)
    if not FactionsEconomyCurrencyData[username] then
        FactionsEconomyCurrencyData[username] = 0
    end
end

local function addCurrency(username, amount)
    ensurePlayerData(username)
    FactionsEconomyCurrencyData[username] = FactionsEconomyCurrencyData[username] + amount
    DebugPrintFactionsEconomy(string.format("%s currency: %d", username, FactionsEconomyCurrencyData[username]))
end

local function notifyClient(player, textKey, amount)
    sendServerCommand(player, "FactionsEconomyCurrency", "showSay", {
        textKey = textKey,
        amount  = amount,
    })
end

-- ── Tick ─────────────────────────────────────────────────────

local currencyPerTick = getSandboxOption("FactionsEconomy.CurrencyPerTick")
local safehouseCurrencyPerTick = getSandboxOption("FactionsEconomy.SafehouseCurrencyPerTick")

local function giveCurrencyToPlayers()
    if FactionsEconomyIsSinglePlayer then
        local player = getPlayer()
        addCurrency(player:getUsername(), currencyPerTick)
    else
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            addCurrency(onlinePlayers:get(i):getUsername(), currencyPerTick)
        end
    end
end

local function giveSafehouseCurrency()
    for owner, data in pairs(FactionsEconomySafehouseCurrencyData) do
        data.Currency = data.Currency +
            math.floor(safehouseCurrencyPerTick *
                (data.Tier * getSandboxOption("FactionsEconomy.SafehouseCurrencyAdditionalPerTier")))

        DebugPrintFactionsEconomy(string.format("[SafehouseCurrency] %s currency: %d", owner, data.Currency))
    end
end

local frequencyEvents = {
    [1] = { event = Events.EveryOneMinute, label = "EveryOneMinute" },
    [2] = { event = Events.EveryTenMinutes, label = "EveryTenMinutes" },
    [3] = { event = Events.EveryHours, label = "EveryHours" },
    [4] = { event = Events.EveryDays, label = "EveryDays" },
}

local currencyFrequency = getSandboxOption("FactionsEconomy.CurrencyFrequency")
local selectedCurrencyFrequency = frequencyEvents[currencyFrequency]
if selectedCurrencyFrequency then
    DebugPrintFactionsEconomy(string.format("Points Frequency: %s", selectedCurrencyFrequency.label))
    selectedCurrencyFrequency.event.Add(giveCurrencyToPlayers)
end

local safehouseCurrencyFrequency = getSandboxOption("FactionsEconomy.SafehouseCurrencyFrequency")
local safehouseSelectedCurrencyFrequency = frequencyEvents[safehouseCurrencyFrequency]
if safehouseSelectedCurrencyFrequency then
    DebugPrintFactionsEconomy(string.format("Points Frequency: %s", safehouseSelectedCurrencyFrequency.label))
    safehouseSelectedCurrencyFrequency.event.Add(giveSafehouseCurrency)
end

-- ── Mod Data ─────────────────────────────────────────────────

Events.OnInitGlobalModData.Add(function(isNewGame)
    FactionsEconomyCurrencyData = ModData.getOrCreate("FactionsEconomyCurrency")
    FactionsEconomySafehouseCurrencyData = ModData.getOrCreate("FactionsEconomySafehouseCurrency")
end)

-- ── Recipe Functions ─────────────────────────────────────────

FactionsEconomyCurrencyRecipe.ReturnCurrency = function(craftRecipeData, player)
    DebugPrintFactionsEconomy(string.format("%s returned currency", player:getUsername()))
    addCurrency(player:getUsername(), 1)
    notifyClient(player, "IGUI_Shop_Sell")
end

FactionsEconomyCurrencyRecipe.SellSmallScrap = function(craftRecipeData, player)
    DebugPrintFactionsEconomy(string.format("%s sell small scrap", player:getUsername()))
    local price = getSandboxOption("FactionsEconomy.SmallStackScrapValue")
    addCurrency(player:getUsername(), price)
    notifyClient(player, "IGUI_Shop_Sell", price)
end

FactionsEconomyCurrencyRecipe.SellMediumScrap = function(craftRecipeData, player)
    DebugPrintFactionsEconomy(string.format("%s sell medium scrap", player:getUsername()))
    local price = getSandboxOption("FactionsEconomy.MediumStackScrapValue")
    addCurrency(player:getUsername(), price)
    notifyClient(player, "IGUI_Shop_Sell", price)
end

FactionsEconomyCurrencyRecipe.SellLargeScrap = function(craftRecipeData, player)
    DebugPrintFactionsEconomy(string.format("%s sell large scrap", player:getUsername()))
    local price = getSandboxOption("FactionsEconomy.LargeStackScrapValue")
    addCurrency(player:getUsername(), price)
    notifyClient(player, "IGUI_Shop_Sell", price)
end

FactionsEconomyCurrencyRecipe.SellVegetable = function(craftRecipeData, player)
    DebugPrintFactionsEconomy(string.format("%s sell vegetable", player:getUsername()))
    local price = getSandboxOption("FactionsEconomy.VegetableValue")
    addCurrency(player:getUsername(), price)
    notifyClient(player, "IGUI_Shop_Sell", price)
end

-- ── Safehouse Redeem ─────────────────────────────────────────

local function redeemSafehouseCurrency(player)
    local username = player:getUsername()
    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s requested redeem", username))

    local square = player:getCurrentSquare()
    if not square then
        DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s has no current square", username))
        return
    end

    local safehouse = SafeHouse.getSafeHouse(square)
    if not safehouse then
        DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s is not standing in a safehouse", username))
        return
    end

    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] Safehouse found: %s (owner: %s)", safehouse:getTitle(),
        safehouse:getOwner()))

    if not safehouse:playerAllowed(player) then
        DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s does not belong to this safehouse", username))
        return
    end

    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s is allowed, safehouse id: %s", username,
        safehouse:getId()))

    -- TODO: reward logic here
end

-- ── Safehouse Events ─────────────────────────────────────────

LuaEventManager.AddEvent("OnFactionsEconomySafehouseClaimed")
LuaEventManager.AddEvent("OnFactionsEconomySafehouseUpdated")
LuaEventManager.AddEvent("OnFactionsEconomySafehouseUnclaimed")

local function getSafehousePlayers(safehouse)
    local players = {}
    local playerList = safehouse:getPlayers()
    for i = 0, playerList:size() - 1 do
        table.insert(players, playerList:get(i))
    end
    return players
end

local function OnSafehousesChanged()
    local list = SafeHouse.getSafehouseList()
    local currentIds = {}

    for i = 0, list:size() - 1 do
        local safehouse = list:get(i)
        local owner = safehouse:getOwner()
        currentIds[owner] = true

        if not FactionsEconomySafehouseCurrencyData[owner] then
            DebugPrintFactionsEconomy(string.format(
                "[SafehouseTracking] New safehouse claimed: %s (owner: %s, created: %s)",
                safehouse:getTitle(), owner, safehouse:getDatetimeCreatedStr()))

            FactionsEconomySafehouseCurrencyData[owner] = {
                Title           = safehouse:getTitle(),
                Owner           = owner,
                Players         = getSafehousePlayers(safehouse),
                DateTimeCreated = safehouse:getDatetimeCreatedStr(),
                Currency        = 0,
                Tier            = 1
            }

            triggerEvent("OnFactionsEconomySafehouseClaimed", safehouse)
        else
            DebugPrintFactionsEconomy(string.format("[SafehouseTracking] Safehouse updated: %s (owner: %s, created: %s)",
                safehouse:getTitle(), owner, safehouse:getDatetimeCreatedStr()))

            FactionsEconomySafehouseCurrencyData[owner] = {
                Title           = safehouse:getTitle(),
                Owner           = owner,
                Players         = getSafehousePlayers(safehouse),
                DateTimeCreated = safehouse:getDatetimeCreatedStr(),
                Currency        = FactionsEconomySafehouseCurrencyData[owner].Currency,
                Tier            = FactionsEconomySafehouseCurrencyData[owner].Tier
            }

            triggerEvent("OnFactionsEconomySafehouseUpdated", safehouse)
        end
    end

    for owner, _ in pairs(FactionsEconomySafehouseCurrencyData) do
        if not currentIds[owner] then
            DebugPrintFactionsEconomy(string.format("[SafehouseTracking] Safehouse removed: %s", owner))
            FactionsEconomySafehouseCurrencyData[owner] = nil

            triggerEvent("OnFactionsEconomySafehouseUnclaimed", owner)
        end
    end
end

Events.OnSafehousesChanged.Add(OnSafehousesChanged)

-- ── Client Requests ──────────────────────────────────────────

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "FactionsEconomyCurrency" then return end

    if command == "getCurrency" then
        sendServerCommand(player, "FactionsEconomyCurrency", "receiveCurrency", {
            balance = FactionsEconomyCurrencyData[player:getUsername()] or 0
        })
    elseif command == "redeemSafehouseCurrency" then
        redeemSafehouseCurrency(player)
    end
end)
