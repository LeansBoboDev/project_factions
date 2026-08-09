if isClient() and not FactionsIsSinglePlayer then return end;
-- ============================================================
-- Calendar Reset — Server Side
-- ============================================================
if not getSandboxOptions():getOptionByName("FactionsPlus.EnableCalendarReset"):getValue() then return end

-- ── Helpers ──────────────────────────────────────────────────

local function notifyClient(player, actualDay, actualMonth, actualYear)
    sendServerCommand(player, "ResetWorldAge", "updateSandbox", {
        actualDay   = actualDay,
        actualMonth = actualMonth,
        actualYear  = actualYear,
    })
end

-- ── Calendar Reset ───────────────────────────────────────────

Events.EveryDays.Add(function()
    local gameTime    = getGameTime()
    local actualDay   = gameTime:getDay()
    local actualMonth = gameTime:getMonth()
    local actualYear  = gameTime:getYear()

    DebugPrintFactionsPlus(string.format("Actual Calendar: D:%d M:%d Y:%d", actualDay, actualMonth, actualYear))

    -- Capture delta before reset so worldAge-based timers stay coherent
    local deltaWorldAgeDays = gameTime:getWorldAgeHours() / 24

    -- Reset calendar to current in-game date (makes getWorldAgeHours() → 0)
    gameTime:setStartDay(actualDay)
    gameTime:setStartMonth(actualMonth)
    gameTime:setStartYear(actualYear)
    gameTime:setStartTimeOfDay(0.0)
    gameTime:save()

    -- Reset TimeSinceApo so the apocalypse-day offset stays at zero
    getSandboxOptions():set("TimeSinceApo", 1)

    -- Adjust farming plow timestamps so the 30-day expiry still works correctly
    if SFarmingSystem and SFarmingSystem.instance then
        local count = SFarmingSystem.instance.system:getObjectCount()
        for i = 1, count do
            local obj = SFarmingSystem.instance:getLuaObjectByIndex(i)
            if obj and obj.plowDay then
                obj.plowDay = obj.plowDay - deltaWorldAgeDays
            end
        end
        DebugPrintFactionsPlus(string.format("[CalendarReset] adjusted %d farming objects", count))
    end

    -- Adjust trap lastUpdate timestamps so bait age tracking stays accurate
    if STrapSystem and STrapSystem.instance then
        local count = STrapSystem.instance.system:getObjectCount()
        for i = 1, count do
            local obj = STrapSystem.instance.system:getObjectByIndex(i - 1):getModData()
            if obj and obj.lastUpdate then
                obj.lastUpdate = obj.lastUpdate - deltaWorldAgeDays
            end
        end
        DebugPrintFactionsPlus(string.format("[CalendarReset] adjusted %d trap objects", count))
    end

    -- Notify all clients to sync their sandbox
    if FactionsPlusIsSinglePlayer then
        notifyClient(getPlayer(), actualDay, actualMonth, actualYear)
    else
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            notifyClient(onlinePlayers:get(i), actualDay, actualMonth, actualYear)
        end
    end

    DebugPrintFactionsPlus("Calendar has been reset!")
end)
