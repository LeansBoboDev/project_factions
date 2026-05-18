-- ============================================================
-- Redeem Safehouse — Context Menu
-- ============================================================

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] Right-click by: %s", player:getUsername()))

    local square = worldobjects:get(0):getSquare()
    if not square then
        DebugPrintFactionsEconomy("[RedeemSafehouse] No square found")
        return
    end

    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] Square: %d,%d,%d", square:getX(), square:getY(),
        square:getZ()))

    local safehouse = SafeHouse.getSafeHouse(square)
    if not safehouse then
        DebugPrintFactionsEconomy("[RedeemSafehouse] No safehouse at this square")
        return
    end

    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] Safehouse found: %s (owner: %s)", safehouse:getTitle(),
        safehouse:getOwner()))

    local username = player:getUsername()
    local isOwner = safehouse:getOwner() == username
    local isMember = safehouse:getPlayers():contains(username)

    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s — isOwner: %s, isMember: %s", username,
        tostring(isOwner), tostring(isMember)))

    if not isOwner and not isMember then
        DebugPrintFactionsEconomy("[RedeemSafehouse] Player does not belong to this safehouse, skipping")
        return
    end

    DebugPrintFactionsEconomy("[RedeemSafehouse] Adding context menu option")
    context:addOption(getText("ContextMenu_RedeemSafehouse"), player, function()
        DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s sending redeemSafehouse to server", username))
        sendClientCommand(player, "FactionsEconomyCurrency", "redeemSafehouseCurrency", {})
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
