-- ============================================================
-- Chat Command Listener + Server Message Listener
-- ============================================================

-- ── Client Command Hook ──────────────────────────────────────

local oldOnCommandEntered = ISChat.onCommandEntered
function ISChat:onCommandEntered()
    oldOnCommandEntered(self)
    for _, stream in ipairs(ISChat.allChatStreams) do
        if luautils.stringStarts(stream.command, "/") then
            DebugPrintFactionsEconomy(string.format("Command executed: %s", stream.command))
        end
    end
end

-- ── Server Message Listener (client side) ────────────────────

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "FactionsEconomyCurrency" then return end

    if command == "showSay" then
        local player = getPlayer()
        if not player then return end

        local message
        if args.amount then
            message = string.format("%s + %d", getText(args.textKey), args.amount)
        else
            message = getText(args.textKey)
        end

        HaloTextHelper.addGoodText(player, message)
    end
end)
