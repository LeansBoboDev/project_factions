if isClient() and not SafehousePlusIsSinglePlayer then return end

local TPA_EXPIRY = 60  -- seconds a TPA request stays valid

local pendingTPA    = {}  -- [targetUsername] = { from = string, time = number }
local homeCooldowns = {}  -- [username] = os.time() of last /home use

local function getSandboxBool(name)
    local opt = getSandboxOptions():getOptionByName(name)
    return opt and opt:getValue()
end

local function getSandboxInt(name, fallback)
    local opt = getSandboxOptions():getOptionByName(name)
    return opt and opt:getValue() or fallback
end

local function msgPlayer(player, text)
    sendServerCommand(player, "SafehousePlus", "message", { text = text })
end

local function teleportPlayer(player, x, y, z, text)
    player:setX(x)
    player:setY(y)
    player:setZ(z)
    sendServerCommand(player, "SafehousePlus", "teleport", { x = x, y = y, z = z, text = text or "" })
end

-- Returns true and deducts cost. Returns false and notifies player if funds are insufficient.
-- If Economy is not active the cost is silently skipped and returns true.
local function tryDeductCurrency(player, costOption)
    local cost = getSandboxInt(costOption, 0)
    if cost <= 0 or not FactionsEconomyCompatibility then return true end

    local username = player:getUsername()
    local balance  = FactionsEconomyCurrencyData and FactionsEconomyCurrencyData[username] or 0
    if balance < cost then
        msgPlayer(player, getText("IGUI_SafehousePlus_NoFunds", tostring(cost)))
        return false
    end

    FactionsEconomyCurrencyData[username] = balance - cost
    DebugPrintSafehousePlus("[Commands] deducted " .. cost .. " from " .. username ..
        " (new balance: " .. FactionsEconomyCurrencyData[username] .. ")")
    return true
end

-- ── /sethome ─────────────────────────────────────────────────

local function setHome(player)
    if not getSandboxBool("SafehousePlus.EnableSetHome") then
        msgPlayer(player, getText("IGUI_SafehousePlus_Disabled"))
        return
    end
    if not tryDeductCurrency(player, "SafehousePlus.SetHomeCost") then return end

    local md = player:getModData()
    md.SafehousePlusHomeX = player:getX()
    md.SafehousePlusHomeY = player:getY()
    md.SafehousePlusHomeZ = player:getZ()
    msgPlayer(player, getText("IGUI_SafehousePlus_HomeSet"))
    DebugPrintSafehousePlus("[Commands] setHome: " .. player:getUsername() ..
        " at " .. md.SafehousePlusHomeX .. "," .. md.SafehousePlusHomeY)
end

-- ── /home ─────────────────────────────────────────────────────

local function goHome(player)
    if not getSandboxBool("SafehousePlus.EnableHome") then
        msgPlayer(player, getText("IGUI_SafehousePlus_Disabled"))
        return
    end

    local md = player:getModData()
    if not md.SafehousePlusHomeX then
        msgPlayer(player, getText("IGUI_SafehousePlus_NoHome"))
        return
    end

    local cooldown = getSandboxInt("SafehousePlus.HomeCooldown", 300)
    if cooldown > 0 then
        local username  = player:getUsername()
        local lastUse   = homeCooldowns[username] or 0
        local remaining = cooldown - (os.time() - lastUse)
        if remaining > 0 then
            msgPlayer(player, getText("IGUI_SafehousePlus_HomeCooldown", tostring(remaining)))
            return
        end
    end

    if not tryDeductCurrency(player, "SafehousePlus.HomeCost") then return end

    if cooldown > 0 then
        homeCooldowns[player:getUsername()] = os.time()
    end

    teleportPlayer(player,
        md.SafehousePlusHomeX,
        md.SafehousePlusHomeY,
        md.SafehousePlusHomeZ or 0,
        getText("IGUI_SafehousePlus_TeleportedHome"))
    DebugPrintSafehousePlus("[Commands] goHome: " .. player:getUsername())
end

-- ── /buyhome ──────────────────────────────────────────────────

local function buyHome(player)
    if not getSandboxBool("SafehousePlus.EnableBuyHome") then
        msgPlayer(player, getText("IGUI_SafehousePlus_Disabled"))
        return
    end

    local sq        = player:getSquare()
    local safehouse = sq and SafeHouse.getSafeHouse(sq)
    if not safehouse then
        msgPlayer(player, getText("IGUI_SafehousePlus_BuyHomeNoSafehouse"))
        return
    end

    if not tryDeductCurrency(player, "SafehousePlus.BuyHomeCost") then return end

    local username   = player:getUsername()
    safehouse:setOwner(username)
    local playerList = safehouse:getPlayers()
    if not playerList:contains(username) then
        playerList:add(username)
    end
    local onlinePlayers = getOnlinePlayers()
    for i = 0, onlinePlayers:size() - 1 do
        safehouse:updateSafehouse(onlinePlayers:get(i))
    end

    local md = player:getModData()
    md.SafehousePlusHomeX = player:getX()
    md.SafehousePlusHomeY = player:getY()
    md.SafehousePlusHomeZ = player:getZ()

    msgPlayer(player, getText("IGUI_SafehousePlus_BuyHomeSuccess"))
    DebugPrintSafehousePlus("[Commands] buyHome: " .. username .. " claimed safehouse")
end

-- ── /tpa <target> ─────────────────────────────────────────────

local function tpa(player, args)
    if not getSandboxBool("SafehousePlus.EnableTpa") then
        msgPlayer(player, getText("IGUI_SafehousePlus_Disabled"))
        return
    end

    local senderName = player:getUsername()
    local targetName = args.target

    local targetPlayer  = nil
    local onlinePlayers = getOnlinePlayers()
    for i = 0, onlinePlayers:size() - 1 do
        local p = onlinePlayers:get(i)
        if p:getUsername():lower() == targetName:lower() then
            targetPlayer = p
            break
        end
    end

    if not targetPlayer then
        msgPlayer(player, getText("IGUI_SafehousePlus_TpaTargetNotFound"))
        return
    end

    if targetPlayer:getUsername() == senderName then
        msgPlayer(player, getText("IGUI_SafehousePlus_TpaSelf"))
        return
    end

    if not tryDeductCurrency(player, "SafehousePlus.TpaCost") then return end

    pendingTPA[targetPlayer:getUsername()] = { from = senderName, time = os.time() }

    msgPlayer(player, getText("IGUI_SafehousePlus_TpaSent", targetPlayer:getUsername()))
    msgPlayer(targetPlayer, getText("IGUI_SafehousePlus_TpaReceived", senderName))
    DebugPrintSafehousePlus("[Commands] tpa: " .. senderName .. " -> " .. targetPlayer:getUsername())
end

-- ── /tpaaccept ────────────────────────────────────────────────

local function tpaAccept(player)
    if not getSandboxBool("SafehousePlus.EnableTpa") then
        msgPlayer(player, getText("IGUI_SafehousePlus_Disabled"))
        return
    end

    local username = player:getUsername()
    local request  = pendingTPA[username]

    if not request then
        msgPlayer(player, getText("IGUI_SafehousePlus_TpaNoPending"))
        return
    end

    if os.time() - request.time > TPA_EXPIRY then
        pendingTPA[username] = nil
        msgPlayer(player, getText("IGUI_SafehousePlus_TpaExpired"))
        return
    end

    local senderPlayer  = nil
    local onlinePlayers = getOnlinePlayers()
    for i = 0, onlinePlayers:size() - 1 do
        local p = onlinePlayers:get(i)
        if p:getUsername() == request.from then
            senderPlayer = p
            break
        end
    end

    if not senderPlayer then
        pendingTPA[username] = nil
        msgPlayer(player, getText("IGUI_SafehousePlus_TpaTargetNotFound"))
        return
    end

    if not tryDeductCurrency(player, "SafehousePlus.TpaAcceptCost") then return end

    pendingTPA[username] = nil

    teleportPlayer(senderPlayer,
        player:getX(), player:getY(), player:getZ(),
        getText("IGUI_SafehousePlus_TpaTeleported", username))
    msgPlayer(player, getText("IGUI_SafehousePlus_TpaAccepted"))
    DebugPrintSafehousePlus("[Commands] tpaAccept: " .. request.from .. " teleported to " .. username)
end

-- ── Event listener ────────────────────────────────────────────

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "SafehousePlus" then return end

    if command == "setHome" then
        setHome(player)
    elseif command == "goHome" then
        goHome(player)
    elseif command == "buyHome" then
        buyHome(player)
    elseif command == "tpa" then
        tpa(player, args)
    elseif command == "tpaAccept" then
        tpaAccept(player)
    end
end)
