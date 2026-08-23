if isClient() and not FactionsIsSinglePlayer then return end;

-- {
--      "FactionName1": {
--          "points": 123,
--          "playerKills": { "username": 42 }
--       }
-- }
FactionsData = {}

Events.OnInitGlobalModData.Add(function(isNewGame)
    FactionsData = ModData.getOrCreate("FactionsData");
end)

-- Parse "100=1;200=2;500=5" into sorted list of {kills, points}
-- Meaning: at X total kills, faction has Y total claim points
local function parsePointsTable(config)
    local thresholds = {}
    for entry in config:gmatch("[^;]+") do
        local k, v = entry:match("(%d+)=(%d+)")
        if k and v then
            table.insert(thresholds, { kills = tonumber(k), points = tonumber(v) })
        end
    end
    table.sort(thresholds, function(a, b) return a.kills < b.kills end)
    return thresholds
end

local function getPointsForKills(thresholds, kills)
    local points = 0
    for _, entry in ipairs(thresholds) do
        if kills >= entry.kills then
            points = entry.points
        else
            break
        end
    end
    return points
end

local function getPlayerByUsername(username)
    local online = getOnlinePlayers()
    for i = 0, online:size() - 1 do
        local p = online:get(i)
        if p:getUsername() == username then
            return p
        end
    end
    return nil
end

function RefreshFactionPlayersPoints(faction)
    if not faction then return end
    if not FactionsData[faction:getName()] then return end

    local points = FactionsData[faction:getName()]["points"]

    local function sendToPlayer(username)
        local player = getPlayerByUsername(username)
        if player then
            sendServerCommand(player, "Factions", "receivePoints", { points })
            DebugPrintFactions(username .. " refreshed points: " .. tostring(points))
        end
    end

    -- Send to all members (Java collection, iterate with size/get)
    local members = faction:getPlayers()
    for i = 0, members:size() - 1 do
        sendToPlayer(members:get(i))
    end
    -- Also send to owner (may not be in getPlayers())
    sendToPlayer(faction:getOwner())
end

Events.EveryTenMinutes.Add(function()
    local factions = Faction.getFactions()
    for i = 0, factions:size() - 1 do
        local faction = factions:get(i)
        RefreshFactionPlayersPoints(faction)
    end
end)

--#region Client Requests

local function updateFactionPoints(module, command, player, args)
    local username = player:getUsername()
    local faction = GetPlayerFaction(username)
    if faction == nil then return end

    local factionName = faction:getName()
    if not FactionsData[factionName] then
        FactionsData[factionName] = { points = 0, playerKills = {} }
    end
    if not FactionsData[factionName].playerKills then
        FactionsData[factionName].playerKills = {}
    end

    -- Accumulate per-player kills (persisted, so session resets don't double-count)
    local previousKills = FactionsData[factionName].playerKills[username] or 0
    local newKills = previousKills + (args.kills or 0)
    FactionsData[factionName].playerKills[username] = newKills

    -- Parse the points config and compute delta
    local config = SandboxVars.Factions.PointsPerZombieKills
    if not config or config == "" then
        DebugPrintFactions("PointsPerZombieKills is not configured")
        return
    end

    local thresholds = parsePointsTable(config)
    local previousPoints = getPointsForKills(thresholds, previousKills)
    local newPoints = getPointsForKills(thresholds, newKills)
    local pointsDelta = newPoints - previousPoints

    DebugPrintFactions(username .. " kills: " .. previousKills .. " -> " .. newKills ..
        " | points delta: " .. pointsDelta)

    if pointsDelta > 0 then
        FactionsData[factionName]["points"] = (FactionsData[factionName]["points"] or 0) + pointsDelta
        DebugPrintFactions(factionName .. " total points: " .. FactionsData[factionName]["points"])
        RefreshFactionPlayersPoints(faction)
    end
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "Factions" and command == "updateFactionPoints" then
        updateFactionPoints(module, command, player, args)
    end
end)

--#endregion
