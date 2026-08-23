if not isClient() and not FactionsIsSinglePlayer then return end

local lastKillCount = 0

local function onZombieDead()
    local player = getPlayer()
    if not player then return end

    local current = player:getZombieKills()
    local delta = current - lastKillCount
    if delta > 0 then
        lastKillCount = current
        sendClientCommand("Factions", "updateFactionPoints", { kills = delta })
        print("[Factions-Kills] Sent " .. delta .. " kill(s) to server (total: " .. current .. ")")
    end
end

Events.OnGameStart.Add(function()
    local player = getPlayer()
    if player then
        lastKillCount = player:getZombieKills()
        print("[Factions-Kills] Initialized kill count: " .. lastKillCount)
    end
    Events.OnZombieDead.Add(onZombieDead)
end)
