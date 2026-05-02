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

    -- Reset calendar to current in-game date
    gameTime:setStartDay(actualDay)
    gameTime:setStartMonth(actualMonth)
    gameTime:setStartYear(actualYear)
    gameTime:setStartTimeOfDay(0.0)
    gameTime:save()

    -- Sync sandbox options
    getSandboxOptions():set("StartMonth", actualMonth)
    getSandboxOptions():set("StartDay", actualDay)
    getSandboxOptions():set("StartYear", actualYear)
    getSandboxOptions():set("TimeSinceApo", 0)

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
