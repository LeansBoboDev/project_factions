-- ============================================================
-- Currency System — Server Side
-- ============================================================

if isClient() and not FactionsEconomyIsSinglePlayer then return end

-- { ["playerUsername"] = 150 }
FactionsEconomyCurrencyData          = {}

-- Keyed by safehouse:getOnlineID() (a stable id derived from the safehouse's x,y —
-- NOT by owner username), so a player owning more than one safehouse gets one
-- independent entry per safehouse instead of them colliding into a single record.
-- {
--   [123456] = {
--     Id              = 123456,
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

local function getSafehousePlayers(safehouse)
    local players = {}
    local playerList = safehouse:getPlayers()
    for i = 0, playerList:size() - 1 do
        table.insert(players, playerList:get(i))
    end
    return players
end

local function AddSafehouseToData(safehouse)
    local id = safehouse:getOnlineID()
    local owner = safehouse:getOwner()
    local existing = FactionsEconomySafehouseCurrencyData[id]

    if not existing then
        -- Migrate pre-multi-safehouse data that used to be keyed by owner username.
        local legacy = FactionsEconomySafehouseCurrencyData[owner]
        if type(legacy) == "table" and legacy.Owner == owner then
            existing = legacy
            FactionsEconomySafehouseCurrencyData[owner] = nil
            DebugPrintFactionsEconomy(string.format("[SafehouseMigration] Migrated legacy data for %s to id %d", owner,
                id))
        end
    end

    FactionsEconomySafehouseCurrencyData[id] = {
        Id              = id,
        Title           = safehouse:getTitle(),
        Owner           = owner,
        Players         = getSafehousePlayers(safehouse),
        DateTimeCreated = safehouse:getDatetimeCreatedStr(),
        Currency        = existing and existing.Currency or 0,
        Tier            = existing and existing.Tier or 1
    }
end

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

-- Forward declaration: the vanilla Events.OnSafehousesChanged is only ever
-- triggered client-side by the game engine (zombie.iso.areas.SafeHouse.addSafeHouse/
-- removeSafeHouse gate the trigger behind `if (GameClient.client)`, which is never
-- true on a dedicated server process). So on dedicated servers this event never
-- fires and safehouses never get registered into FactionsEconomySafehouseCurrencyData.
-- We call this function manually below instead of relying solely on the event.
local OnSafehousesChanged

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
    OnSafehousesChanged()
    for id, data in pairs(FactionsEconomySafehouseCurrencyData) do
        data.Currency = data.Currency +
            math.floor(safehouseCurrencyPerTick *
                (data.Tier * getSandboxOption("FactionsEconomy.SafehouseCurrencyAdditionalPerTier")))

        DebugPrintFactionsEconomy(string.format("[SafehouseCurrency] %s (id %s) currency: %d", data.Owner, id,
            data.Currency))
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

FactionsEconomyCurrencyRecipe.UpgradeSafehouse = function(craftRecipeData, player)
    local username = player:getUsername()
    DebugPrintFactionsEconomy(string.format("[UpgradeSafehouse] %s requested upgrade", username))

    local square = player:getCurrentSquare()
    if not square then
        DebugPrintFactionsEconomy(string.format("[UpgradeSafehouse] %s has no current square", username))
        return
    end

    local safehouse = SafeHouse.getSafeHouse(square)
    if not safehouse then
        DebugPrintFactionsEconomy(string.format("[UpgradeSafehouse] %s is not standing in a safehouse", username))
        return
    end

    if safehouse:getOwner() ~= username then
        DebugPrintFactionsEconomy(string.format("[UpgradeSafehouse] %s is not the owner of %s", username,
            safehouse:getTitle()))
        return
    end

    local data = FactionsEconomySafehouseCurrencyData[safehouse:getOnlineID()]
    if not data then
        DebugPrintFactionsEconomy(string.format("[UpgradeSafehouse] no data found for %s", username))
        return
    end

    data.Tier = data.Tier + 1
    DebugPrintFactionsEconomy(string.format("[UpgradeSafehouse] %s upgraded to tier %d", safehouse:getTitle(), data.Tier))
    notifyClient(player, "IGUI_Safehouse_Upgraded")
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

    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s is allowed, safehouse: %s", username,
        safehouse:getTitle()))

    local owner = safehouse:getOwner()
    local safeData = FactionsEconomySafehouseCurrencyData[safehouse:getOnlineID()]
    if not safeData then
        DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] No tracking data for safehouse owner: %s", owner))
        AddSafehouseToData(safehouse)
        notifyClient(player, "IGUI_Safehouse_Redeem", 0)
        return
    end

    addCurrency(player:getUsername(), safeData.Currency)
    notifyClient(player, "IGUI_Safehouse_Redeem", safeData.Currency)
    safeData.Currency = 0
end

-- ── Safehouse Events ─────────────────────────────────────────

LuaEventManager.AddEvent("OnFactionsEconomySafehouseClaimed")
LuaEventManager.AddEvent("OnFactionsEconomySafehouseUpdated")
LuaEventManager.AddEvent("OnFactionsEconomySafehouseUnclaimed")

OnSafehousesChanged = function()
    local list = SafeHouse.getSafehouseList()
    local currentIds = {}

    for i = 0, list:size() - 1 do
        local safehouse = list:get(i)
        local id = safehouse:getOnlineID()
        local owner = safehouse:getOwner()
        currentIds[id] = true

        if not FactionsEconomySafehouseCurrencyData[id] then
            AddSafehouseToData(safehouse)
            triggerEvent("OnFactionsEconomySafehouseClaimed", safehouse)
        else
            AddSafehouseToData(safehouse)
            triggerEvent("OnFactionsEconomySafehouseUpdated", safehouse)
        end
    end

    for id, data in pairs(FactionsEconomySafehouseCurrencyData) do
        if not currentIds[id] then
            FactionsEconomySafehouseCurrencyData[id] = nil

            triggerEvent("OnFactionsEconomySafehouseUnclaimed", data.Owner)
        end
    end
end

Events.EveryTenMinutes.Add(OnSafehousesChanged)

-- ── Client Requests ──────────────────────────────────────────

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "FactionsEconomyCurrency" then return end

    if command == "getCurrency" then
        sendServerCommand(player, "FactionsEconomyCurrency", "receiveCurrency", {
            balance = FactionsEconomyCurrencyData[player:getUsername()] or 0
        })
    elseif command == "redeemSafehouseCurrency" then
        redeemSafehouseCurrency(player)
    elseif command == "getSafehouseCurrency" then
        local safehouseId = args.safehouseId
        DebugPrintFactionsEconomy(string.format("[GetSafehouseCurrency] %s requested id=%s", player:getUsername(), tostring(safehouseId)))
        if not safehouseId then return end
        local safeData = FactionsEconomySafehouseCurrencyData[safehouseId]
        if not safeData then
            DebugPrintFactionsEconomy(string.format("[GetSafehouseCurrency] no safeData for id=%s", tostring(safehouseId)))
            sendServerCommand(player, "FactionsEconomyCurrency", "safehouseCurrencyInfo", { amount = 0 })
            return
        end
        local username = player:getUsername()
        local allowed = safeData.Owner == username
        if not allowed then
            for _, name in ipairs(safeData.Players) do
                if name == username then allowed = true; break end
            end
        end
        DebugPrintFactionsEconomy(string.format("[GetSafehouseCurrency] %s allowed=%s currency=%d", username, tostring(allowed), safeData.Currency))
        if not allowed then return end
        sendServerCommand(player, "FactionsEconomyCurrency", "safehouseCurrencyInfo", {
            amount = safeData.Currency
        })
    elseif command == "getScoreboard" then
        -- Staff roles are only known while the player is online (no offline role
        -- lookup is exposed to Lua on dedicated servers), so build the lookup from
        -- the current online player list before filtering.
        -- For offline players whose role can't be checked, "admin" is excluded by
        -- name since the PZ dedicated server always creates that account.
        local excludedRoles = { admin = true, observer = true }
        local excludedUsernames = { admin = true }
        local onlineRoles = {}
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            local onlinePlayer = onlinePlayers:get(i)
            onlineRoles[onlinePlayer:getUsername()] = onlinePlayer:getAccessLevel()
        end

        local entries = {}
        for username, balance in pairs(FactionsEconomyCurrencyData) do
            local role = onlineRoles[username]
            local roleExcluded = role and excludedRoles[role:lower()]
            local nameExcluded = not role and excludedUsernames[username:lower()]
            if not roleExcluded and not nameExcluded then
                table.insert(entries, { username = username, balance = balance })
            end
        end
        table.sort(entries, function(a, b) return a.balance > b.balance end)
        local top = {}
        for i = 1, math.min(20, #entries) do
            top[i] = entries[i]
        end
        sendServerCommand(player, "FactionsEconomyCurrency", "scoreboardData", { entries = top })
    elseif command == "requestCreateKey" then
        local username = player:getUsername()
        local cost     = getSandboxOption("FactionsEconomy.CreateKeyCost")
        local balance  = FactionsEconomyCurrencyData[username] or 0

        DebugPrintFactionsEconomy(string.format("[CreateKey] %s requested key (cost: %d, balance: %d)", username, cost,
            balance))

        if balance >= cost then
            FactionsEconomyCurrencyData[username] = balance - cost
            sendServerCommand(player, "FactionsEconomyCurrency", "confirmCreateKey", { keycode = args.keycode })
            DebugPrintFactionsEconomy(string.format("[CreateKey] %s key confirmed, new balance: %d", username,
                FactionsEconomyCurrencyData[username]))
        else
            sendServerCommand(player, "FactionsEconomyCurrency", "denyCreateKey", {})
            DebugPrintFactionsEconomy(string.format("[CreateKey] %s insufficient funds", username))
        end
    end
end)
