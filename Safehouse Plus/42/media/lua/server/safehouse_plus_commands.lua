if isClient() and not SafehousePlusIsSinglePlayer then return end

local TPA_EXPIRY = 60

local pendingTPA    = {}
local homeCooldowns = {}

local function getSandboxBool(name)
    local opt = getSandboxOptions():getOptionByName(name)
    return opt and opt:getValue()
end

local function getSandboxInt(name, fallback)
    local opt = getSandboxOptions():getOptionByName(name)
    return opt and opt:getValue() or fallback
end

-- Sends a translation key + optional params to the client to resolve with getText()
local function msgPlayer(player, key, p1, p2)
    sendServerCommand(player, "SafehousePlus", "message", { key = key, p1 = p1, p2 = p2 })
end

local function teleportPlayer(player, x, y, z, key, p1)
    player:setX(x)
    player:setY(y)
    player:setZ(z)
    sendServerCommand(player, "SafehousePlus", "teleport", { x = x, y = y, z = z, key = key, p1 = p1 })
end

local function tryDeductCurrency(player, costOption)
    local cost = getSandboxInt(costOption, 0)
    if cost <= 0 or not FactionsEconomyCompatibility then return true end

    local username = player:getUsername()
    local balance  = FactionsEconomyCurrencyData and FactionsEconomyCurrencyData[username] or 0
    if balance < cost then
        msgPlayer(player, "IGUI_SafehousePlus_NoFunds", tostring(cost))
        return false
    end

    FactionsEconomyCurrencyData[username] = balance - cost
    DebugPrintSafehousePlus("[Commands] deducted " .. cost .. " from " .. username ..
        " (new balance: " .. FactionsEconomyCurrencyData[username] .. ")")
    return true
end

-- Returns the homes table from ModData, migrating the old single-home fields if present
local function getHomes(player)
    local md = player:getModData()
    if not md.SafehousePlusHomes then
        md.SafehousePlusHomes = {}
        if md.SafehousePlusHomeX then
            table.insert(md.SafehousePlusHomes, {
                x = md.SafehousePlusHomeX,
                y = md.SafehousePlusHomeY,
                z = md.SafehousePlusHomeZ or 0,
            })
            md.SafehousePlusHomeX = nil
            md.SafehousePlusHomeY = nil
            md.SafehousePlusHomeZ = nil
        end
    end
    return md.SafehousePlusHomes
end

-- Base slots (sandbox) + slots purchased by the player with /buyhome
local function getEffectiveMaxHomes(player)
    local base   = getSandboxInt("SafehousePlus.MaxHomes", 1)
    local bought = player:getModData().SafehousePlusBoughtHomes or 0
    return base + bought
end

-- ── /sethome ─────────────────────────────────────────────────

local function setHome(player)
    if not getSandboxBool("SafehousePlus.EnableSetHome") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local maxHomes = getEffectiveMaxHomes(player)
    local homes    = getHomes(player)

    if #homes >= maxHomes then
        msgPlayer(player, "IGUI_SafehousePlus_MaxHomesReached", tostring(maxHomes))
        return
    end

    if not tryDeductCurrency(player, "SafehousePlus.SetHomeCost") then return end

    table.insert(homes, { x = player:getX(), y = player:getY(), z = player:getZ() })
    msgPlayer(player, "IGUI_SafehousePlus_HomeSet")
    DebugPrintSafehousePlus("[Commands] setHome: " .. player:getUsername() ..
        " at " .. player:getX() .. "," .. player:getY() .. " (" .. #homes .. "/" .. maxHomes .. ")")
end

-- ── /home ─────────────────────────────────────────────────────

local function goHome(player)
    if not getSandboxBool("SafehousePlus.EnableHome") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local homes    = getHomes(player)
    if #homes == 0 then
        msgPlayer(player, "IGUI_SafehousePlus_NoHome")
        return
    end

    local cooldown = getSandboxInt("SafehousePlus.HomeCooldown", 300)
    if cooldown > 0 then
        local username  = player:getUsername()
        local lastUse   = homeCooldowns[username] or 0
        local remaining = cooldown - (os.time() - lastUse)
        if remaining > 0 then
            msgPlayer(player, "IGUI_SafehousePlus_HomeCooldown", tostring(remaining))
            return
        end
    end

    if not tryDeductCurrency(player, "SafehousePlus.HomeCost") then return end

    if cooldown > 0 then
        homeCooldowns[player:getUsername()] = os.time()
    end

    local home = homes[1]
    teleportPlayer(player, home.x, home.y, home.z, "IGUI_SafehousePlus_TeleportedHome")
    DebugPrintSafehousePlus("[Commands] goHome: " .. player:getUsername())
end

-- ── /buyhome ──────────────────────────────────────────────────

local function buyHome(player)
    if not getSandboxBool("SafehousePlus.EnableBuyHome") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local md        = player:getModData()
    local bought    = md.SafehousePlusBoughtHomes or 0
    local base      = getSandboxInt("SafehousePlus.BuyHomeCost", 5)
    local increment = getSandboxInt("SafehousePlus.BuyHomeCostIncrement", 0)
    local cost      = base + (bought * increment)

    if cost > 0 and FactionsEconomyCompatibility then
        local username = player:getUsername()
        local balance  = FactionsEconomyCurrencyData and FactionsEconomyCurrencyData[username] or 0
        if balance < cost then
            msgPlayer(player, "IGUI_SafehousePlus_NoFunds", tostring(cost))
            return
        end
        FactionsEconomyCurrencyData[username] = balance - cost
        DebugPrintSafehousePlus("[Commands] buyHome: deducted " .. cost .. " from " .. username ..
            " (new balance: " .. FactionsEconomyCurrencyData[username] .. ")")
    end

    md.SafehousePlusBoughtHomes = bought + 1

    local newMax = getEffectiveMaxHomes(player)
    msgPlayer(player, "IGUI_SafehousePlus_BuyHomeSuccess", tostring(newMax))
    DebugPrintSafehousePlus("[Commands] buyHome: " .. player:getUsername() ..
        " bought a slot (cost=" .. cost .. "), total max=" .. newMax)
end

-- ── /tpa <target> ─────────────────────────────────────────────

local function tpa(player, args)
    if not getSandboxBool("SafehousePlus.EnableTpa") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
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
        msgPlayer(player, "IGUI_SafehousePlus_TpaTargetNotFound")
        return
    end

    if targetPlayer:getUsername() == senderName then
        msgPlayer(player, "IGUI_SafehousePlus_TpaSelf")
        return
    end

    if not tryDeductCurrency(player, "SafehousePlus.TpaCost") then return end

    pendingTPA[targetPlayer:getUsername()] = { from = senderName, time = os.time() }

    msgPlayer(player, "IGUI_SafehousePlus_TpaSent", targetPlayer:getUsername())
    msgPlayer(targetPlayer, "IGUI_SafehousePlus_TpaReceived", senderName)
    DebugPrintSafehousePlus("[Commands] tpa: " .. senderName .. " -> " .. targetPlayer:getUsername())
end

-- ── /tpaaccept ────────────────────────────────────────────────

local function tpaAccept(player)
    if not getSandboxBool("SafehousePlus.EnableTpa") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local username = player:getUsername()
    local request  = pendingTPA[username]

    if not request then
        msgPlayer(player, "IGUI_SafehousePlus_TpaNoPending")
        return
    end

    if os.time() - request.time > TPA_EXPIRY then
        pendingTPA[username] = nil
        msgPlayer(player, "IGUI_SafehousePlus_TpaExpired")
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
        msgPlayer(player, "IGUI_SafehousePlus_TpaTargetNotFound")
        return
    end

    if not tryDeductCurrency(player, "SafehousePlus.TpaAcceptCost") then return end

    pendingTPA[username] = nil

    teleportPlayer(senderPlayer,
        player:getX(), player:getY(), player:getZ(),
        "IGUI_SafehousePlus_TpaTeleported", username)
    msgPlayer(player, "IGUI_SafehousePlus_TpaAccepted")
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
