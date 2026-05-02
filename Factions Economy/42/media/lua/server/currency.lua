-- ============================================================
-- Currency System — Server Side
-- ============================================================

if isClient() and not FactionsIsSinglePlayer then return end

FactionsEconomyCurrencyData   = {}
FactionsEconomyCurrencyRecipe = FactionsEconomyCurrencyRecipe or {}

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

local frequencyEvents = {
    [1] = { event = Events.EveryOneMinute, label = "EveryOneMinute" },
    [2] = { event = Events.EveryTenMinutes, label = "EveryTenMinutes" },
    [3] = { event = Events.EveryHours, label = "EveryHours" },
    [4] = { event = Events.EveryDays, label = "EveryDays" },
}

local freq = getSandboxOption("FactionsEconomy.CurrencyFrequency")
local selected = frequencyEvents[freq]
if selected then
    DebugPrintFactionsEconomy(string.format("Points Frequency: %s", selected.label))
    selected.event.Add(giveCurrencyToPlayers)
end

-- ── Mod Data ─────────────────────────────────────────────────

Events.OnInitGlobalModData.Add(function(isNewGame)
    FactionsEconomyCurrencyData = ModData.getOrCreate("FactionsEconomyCurrency")
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

-- ── Client Requests ──────────────────────────────────────────

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "FactionsEconomyCurrency" then return end

    if command == "getCurrency" then
        sendServerCommand(player, "FactionsEconomyCurrency", "receiveCurrency", {
            balance = FactionsEconomyCurrencyData[player:getUsername()] or 0
        })
    end
end)
