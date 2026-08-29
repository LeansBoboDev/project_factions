if isClient() and not SafehousePlusIsSinglePlayer then return end

local TPA_EXPIRY = 60

local pendingTPA     = {}
local homeCooldowns  = {}
local pendingConfirm = {}  -- username -> callback applied only when client confirms teleport
local pendingDest    = {}  -- username -> {x,y,z} destination for delayed teleport

-- Global ModData table: { [username] = { bought = N, homes = { {x,y,z,name}, ... } } }
-- PZ persists this automatically, same mechanism as FactionsEconomy currency.
SafehousePlusHomesData = {}

Events.OnInitGlobalModData.Add(function()
    SafehousePlusHomesData = ModData.getOrCreate("SafehousePlusHomes")
end)

local function getSandboxBool(name)
    local opt = getSandboxOptions():getOptionByName(name)
    return opt and opt:getValue()
end

local function getSandboxInt(name, fallback)
    local opt = getSandboxOptions():getOptionByName(name)
    return opt and opt:getValue() or fallback
end

-- cost > 0: appended as " (Cost: N)" by the client
local function msgPlayer(player, key, p1, p2, cost)
    sendServerCommand(player, "SafehousePlus", "message", { key = key, p1 = p1, p2 = p2, cost = cost })
end

-- onConfirm: optional function called only when the teleport actually completes.
-- For immediate teleport it runs now; for delayed it runs when the client sends confirmTeleport.
local function teleportPlayer(player, x, y, z, key, p1, cost, onConfirm)
    local delay = getSandboxInt("SafehousePlus.TeleportDelay", 3)
    if delay <= 0 then
        if onConfirm then onConfirm() end
        player:setX(x)
        player:setY(y)
        player:setZ(z)
        sendServerCommand(player, "SafehousePlus", "teleport", { x = x, y = y, z = z, key = key, p1 = p1, cost = cost })
    else
        local username = player:getUsername()
        if onConfirm then
            pendingConfirm[username] = onConfirm
        end
        pendingDest[username] = { x = x, y = y, z = z }
        sendServerCommand(player, "SafehousePlus", "teleportPending", { x = x, y = y, z = z, key = key, p1 = p1, cost = cost, delay = delay })
    end
end

-- Check-only: returns cost (0 if free/disabled) or false if insufficient. Does NOT deduct.
local function checkCurrency(player, costOption)
    local cost = getSandboxInt(costOption, 0)
    if cost <= 0 or not FactionsEconomyCompatibility then return 0 end
    local username = player:getUsername()
    local balance  = FactionsEconomyCurrencyData and FactionsEconomyCurrencyData[username] or 0
    if balance < cost then
        msgPlayer(player, "IGUI_SafehousePlus_NoFunds", tostring(cost))
        return false
    end
    return cost
end

-- Actually deduct a previously checked amount.
local function deductCurrency(player, cost)
    if cost <= 0 or not FactionsEconomyCompatibility then return end
    local username = player:getUsername()
    FactionsEconomyCurrencyData[username] = (FactionsEconomyCurrencyData[username] or 0) - cost
    DebugPrintSafehousePlus("[Commands] deducted " .. cost .. " from " .. username ..
        " (new balance: " .. FactionsEconomyCurrencyData[username] .. ")")
end

-- Check + deduct in one call (for commands that don't involve delayed teleport).
local function tryDeductCurrency(player, costOption)
    local cost = checkCurrency(player, costOption)
    if cost == false then return false end
    deductCurrency(player, cost)
    return cost
end

-- Returns or creates the player's entry in the global ModData table.
local function getPlayerData(username)
    if not SafehousePlusHomesData[username] then
        SafehousePlusHomesData[username] = { bought = 0, homes = {} }
    end
    return SafehousePlusHomesData[username]
end

local function getHomes(player)
    return getPlayerData(player:getUsername()).homes
end

local function saveHomes(player, homes)
    local pdata = getPlayerData(player:getUsername())
    pdata.homes = homes
end

-- Base slots (sandbox) + slots purchased by the player with /buyhome
local function getEffectiveMaxHomes(player)
    local base  = getSandboxInt("SafehousePlus.MaxHomes", 1)
    local pdata = getPlayerData(player:getUsername())
    return base + (pdata.bought or 0)
end

-- ── /sethome <name> ───────────────────────────────────────────

local function setHome(player, args)
    if not getSandboxBool("SafehousePlus.EnableSetHome") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local name = args and args.name
    if not name then
        msgPlayer(player, "IGUI_SafehousePlus_SetHomeUsage")
        return
    end

    local maxHomes = getEffectiveMaxHomes(player)
    local homes    = getHomes(player)

    for _, h in ipairs(homes) do
        if h.name == name then
            local cost = tryDeductCurrency(player, "SafehousePlus.SetHomeCost")
            if cost == false then return end
            h.x, h.y, h.z = player:getX(), player:getY(), player:getZ()
            saveHomes(player, homes)
            msgPlayer(player, "IGUI_SafehousePlus_HomeSet", name, nil, cost)
            DebugPrintSafehousePlus("[Commands] setHome (overwrite): " .. player:getUsername() ..
                " '" .. name .. "' at " .. player:getX() .. "," .. player:getY() .. " (" .. #homes .. "/" .. maxHomes .. ")")
            return
        end
    end

    if #homes >= maxHomes then
        msgPlayer(player, "IGUI_SafehousePlus_MaxHomesReached", tostring(maxHomes))
        return
    end

    local cost = tryDeductCurrency(player, "SafehousePlus.SetHomeCost")
    if cost == false then return end

    table.insert(homes, { x = player:getX(), y = player:getY(), z = player:getZ(), name = name })
    saveHomes(player, homes)
    msgPlayer(player, "IGUI_SafehousePlus_HomeSet", name, nil, cost)
    DebugPrintSafehousePlus("[Commands] setHome: " .. player:getUsername() ..
        " '" .. name .. "' at " .. player:getX() .. "," .. player:getY() .. " (" .. #homes .. "/" .. maxHomes .. ")")
end

-- ── /home [name] ─────────────────────────────────────────────

local function goHome(player, args)
    if not getSandboxBool("SafehousePlus.EnableHome") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local homes = getHomes(player)
    if #homes == 0 then
        msgPlayer(player, "IGUI_SafehousePlus_NoHome")
        return
    end

    local name = args and args.name
    if not name then
        msgPlayer(player, "IGUI_SafehousePlus_HomeUsage")
        return
    end

    local home
    for _, h in ipairs(homes) do
        if h.name == name then home = h; break end
    end
    if not home then
        msgPlayer(player, "IGUI_SafehousePlus_HomeNotFound", name)
        return
    end

    local cooldown = getSandboxInt("SafehousePlus.HomeCooldown", 300)
    if cooldown > 0 then
        local username  = player:getUsername()
        local lastUse   = homeCooldowns[username] or 0
        local remaining = math.ceil(cooldown - (os.time() - lastUse))
        if remaining > 0 then
            msgPlayer(player, "IGUI_SafehousePlus_HomeCooldown", tostring(remaining))
            return
        end
    end

    local cost = checkCurrency(player, "SafehousePlus.HomeCost")
    if cost == false then return end

    local username = player:getUsername()
    local onConfirm = function()
        deductCurrency(player, cost)
        if cooldown > 0 then homeCooldowns[username] = os.time() end
    end

    teleportPlayer(player, home.x, home.y, home.z, "IGUI_SafehousePlus_TeleportedHome", home.name, cost, onConfirm)
    DebugPrintSafehousePlus("[Commands] goHome: " .. player:getUsername() .. " -> '" .. home.name .. "'")
end

-- ── /buyhome ──────────────────────────────────────────────────

local function buyHome(player)
    if not getSandboxBool("SafehousePlus.EnableBuyHome") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local username = player:getUsername()
    local pdata    = getPlayerData(username)
    local bought   = pdata.bought or 0
    local base     = getSandboxInt("SafehousePlus.BuyHomeCost", 5)
    local increment = getSandboxInt("SafehousePlus.BuyHomeCostIncrement", 0)
    local cost     = base + (bought * increment)

    if cost > 0 and FactionsEconomyCompatibility then
        local balance = FactionsEconomyCurrencyData and FactionsEconomyCurrencyData[username] or 0
        if balance < cost then
            msgPlayer(player, "IGUI_SafehousePlus_NoFunds", tostring(cost))
            return
        end
        FactionsEconomyCurrencyData[username] = balance - cost
        DebugPrintSafehousePlus("[Commands] buyHome: deducted " .. cost .. " from " .. username ..
            " (new balance: " .. FactionsEconomyCurrencyData[username] .. ")")
    else
        cost = 0
    end

    pdata.bought = bought + 1

    local newMax = getEffectiveMaxHomes(player)
    msgPlayer(player, "IGUI_SafehousePlus_BuyHomeSuccess", tostring(newMax), nil, cost)
    DebugPrintSafehousePlus("[Commands] buyHome: " .. username ..
        " bought a slot (cost=" .. cost .. "), total max=" .. newMax)
end

-- ── confirmTeleport (client → server after delayed teleport) ──

local function confirmTeleport(player)
    local username = player:getUsername()
    local dest = pendingDest[username]
    if dest then
        player:setX(dest.x)
        player:setY(dest.y)
        player:setZ(dest.z)
        pendingDest[username] = nil
        DebugPrintSafehousePlus("[Commands] confirmTeleport: server applied position " .. dest.x .. "," .. dest.y .. " for " .. username)
    end
    local cb = pendingConfirm[username]
    if cb then
        cb()
        pendingConfirm[username] = nil
        DebugPrintSafehousePlus("[Commands] confirmTeleport: cooldown applied for " .. username)
    end
end

-- ── /homes ────────────────────────────────────────────────────

local function listHomes(player)
    if not getSandboxBool("SafehousePlus.EnableListHomes") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local homes = getHomes(player)
    local names = {}
    for _, h in ipairs(homes) do
        table.insert(names, h.name)
    end
    sendServerCommand(player, "SafehousePlus", "homeList", { count = #homes, homes = names })
    DebugPrintSafehousePlus("[Commands] listHomes: " .. player:getUsername() .. " has " .. #homes .. " homes")
end

-- ── /delhome <name> ───────────────────────────────────────────

local function delHome(player, args)
    if not getSandboxBool("SafehousePlus.EnableDelHome") then
        msgPlayer(player, "IGUI_SafehousePlus_Disabled")
        return
    end

    local name = args and args.name
    if not name then
        msgPlayer(player, "IGUI_SafehousePlus_DelHomeUsage")
        return
    end

    local homes = getHomes(player)
    for i, h in ipairs(homes) do
        if h.name == name then
            table.remove(homes, i)
            saveHomes(player, homes)
            msgPlayer(player, "IGUI_SafehousePlus_HomeDeleted", name)
            DebugPrintSafehousePlus("[Commands] delHome: " .. player:getUsername() .. " deleted '" .. name .. "'")
            return
        end
    end

    msgPlayer(player, "IGUI_SafehousePlus_HomeNotFound", name)
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

    local cost = tryDeductCurrency(player, "SafehousePlus.TpaCost")
    if cost == false then return end

    pendingTPA[targetPlayer:getUsername()] = { from = senderName, time = os.time() }

    msgPlayer(player, "IGUI_SafehousePlus_TpaSent", targetPlayer:getUsername(), nil, cost)
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

    local cost = checkCurrency(player, "SafehousePlus.TpaAcceptCost")
    if cost == false then return end

    pendingTPA[username] = nil

    local accepter = player
    teleportPlayer(senderPlayer,
        player:getX(), player:getY(), player:getZ(),
        "IGUI_SafehousePlus_TpaTeleported", username, nil,
        function() deductCurrency(accepter, cost) end)
    msgPlayer(player, "IGUI_SafehousePlus_TpaAccepted", nil, nil, cost)
    DebugPrintSafehousePlus("[Commands] tpaAccept: " .. request.from .. " teleported to " .. username)
end

-- ── Event listener ────────────────────────────────────────────

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "SafehousePlus" then return end

    if command == "confirmTeleport" then
        confirmTeleport(player)
    elseif command == "setHome" then
        setHome(player, args)
    elseif command == "goHome" then
        goHome(player, args)
    elseif command == "buyHome" then
        buyHome(player)
    elseif command == "listHomes" then
        listHomes(player)
    elseif command == "delHome" then
        delHome(player, args)
    elseif command == "tpa" then
        tpa(player, args)
    elseif command == "tpaAccept" then
        tpaAccept(player)
    end
end)
